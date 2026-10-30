'use strict';
// Replay the GPS clock with the actual QML source in a Node VM: Global.qml clock functions and the VehicleEvent.qml GPS handlers.
// The original phase must reproduce the missing sync. The patched phase must pass every case.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');

const base = path.resolve(__dirname, '..');
const phase = process.argv[2];
if (!['original', 'patched'].includes(phase)) throw new Error('Use original or patched');
const folder = path.join(base, phase === 'original' ? 'evidence/fixtures/capture-04/etc/common' : 'patches/capture-04/etc/common');
const texts = Object.fromEntries(['Global.qml', 'VehicleEvent.qml'].map(name => [name, fs.readFileSync(path.join(folder, name), 'utf8')]));
const failureModes = [
  'A valid GPS time after power-up does not set the MCU clock',
  'The clock is set again on every GPS fix',
  'An invalid fix (status V), a bad checksum, an invalid date, or a GPS date before 2026 sets the clock',
  'The clock is set while GPS auto time is off',
  'UTC to local time crosses a date, month, or year boundary wrongly',
  'Daylight saving time starts or ends at the wrong instant',
  'A zone without daylight saving time (Arizona, Hawaii, Saskatchewan, Mexico) moves by an hour',
  'The time zone is wrong for the position',
  'A short trip across a zone line, or one stray fix, changes the zone',
  'A clock that drifts or was set by hand is not corrected; a small difference causes a rewrite',
  'A position outside the zone grid, or a fix without a position, loses the zone',
  'After power-up the dashboard shows a wrong time before the first GPS time',
  'A clock with a plausible date (constant power) shows dashes',
  'The 12-hour format or AM/PM is lost',
  'A clock set by hand after a power cut shows dashes',
  'GPS auto time is off by default'
];

function extract(text, marker) {
  const start = text.indexOf(marker);
  if (start < 0) return null;
  if (text.indexOf(marker, start + marker.length) >= 0) throw new Error('Expected one source marker: ' + marker);
  const brace = text.indexOf('{', start);
  let depth = 1;
  let end = brace + 1;
  while (depth && end < text.length) {
    if (text[end] === '{') depth++;
    if (text[end] === '}') depth--;
    end++;
  }
  if (depth) throw new Error('Unclosed source block');
  return text.slice(start, end);
}
const handlerBody = (text, marker) => { const block = extract(text, marker); return block === null ? '' : block.slice(block.indexOf('{') + 1, -1); };
// Global.qml clock state: each "property ... gpsClock*: value" line becomes a VM global with the same default.
// Array values may span lines (the generated zone grid): read to the matching bracket.
const props = {};
for (const match of texts['Global.qml'].matchAll(/^\s*(?:readonly )?property \w+ (gpsClock\w+):[ \t]*/gm)) {
  const text = texts['Global.qml'], start = match.index + match[0].length;
  if (text[start] !== '[') { props[match[1]] = text.slice(start, text.indexOf('\n', start)).replace(/\s*\/\/.*$/, ''); continue; }
  let depth = 0, end = start;
  do { if (text[end] === '[') depth++; if (text[end] === ']') depth--; end++; } while (depth && end < text.length);
  props[match[1]] = text.slice(start, end);
}
const functionNames = [...texts['Global.qml'].matchAll(/^\s*function (gpsClock\w+|rtcTrusted)\(/gm)].map(match => match[1]);
const globalFunctions = ['getRtcTime', 'getAmPm', ...functionNames].map(name => extract(texts['Global.qml'], 'function ' + name + '(')).filter(Boolean);
const restoreLines = texts['Global.qml'].split(/\r?\n/).filter(line => /^\s*gpsClock\w+=Funcs\.restore_properity\(/.test(line));
const syncFunction = extract(texts['VehicleEvent.qml'], 'function syncRtcFromGps(');
const setRtcFunction = extract(texts['VehicleEvent.qml'], 'function setRtc(');
// Saved-setting default from the declaration; an int property without a value starts at 0.
const autoDefault = Number((texts['Global.qml'].match(/^\s*property int gpsAutoSetRtcEnabled(?::\s*(\d+))?/m) || [])[1] || 0);
const dateTimeHandler = handlerBody(texts['VehicleEvent.qml'], 'onGpsDateTimeInfoNotify:');
const latLongHandler = handlerBody(texts['VehicleEvent.qml'], 'onGpsLatLongInfoNotify:');

// NMEA RMC sentence with a valid checksum. utc: Date; lat and lon in signed degrees.
function rmc(utc, lat, lon, {status = 'A', checksum = true, date: rawDate} = {}) {
  const p = n => String(n).padStart(2, '0');
  const dm = (v, width) => { const a = Math.abs(v), d = Math.floor(a); return String(d).padStart(width, '0') + ((a - d) * 60).toFixed(4).padStart(7, '0'); };
  const time = p(utc.getUTCHours()) + p(utc.getUTCMinutes()) + p(utc.getUTCSeconds()) + '.00';
  const date = rawDate || p(utc.getUTCDate()) + p(utc.getUTCMonth() + 1) + p(utc.getUTCFullYear() % 100);
  const pos = lat === null ? ',,,' : dm(lat, 2) + ',' + (lat < 0 ? 'S' : 'N') + ',' + dm(lon, 3) + ',' + (lon < 0 ? 'W' : 'E');
  const body = 'GNRMC,' + time + ',' + status + ',' + pos + ',0.0,0.0,' + date + ',,,A';
  let sum = 0;
  for (const ch of body) sum ^= ch.charCodeAt(0);
  return '$' + body + (checksum === true ? '*' + sum.toString(16).toUpperCase().padStart(2, '0') : checksum === false ? '' : '*' + checksum);
}

// One cluster power cycle: the saved settings database, the MCU clock, and the GPS receiver.
// The mock MCU clock runs with GPS time: each fix first raises the MCU clock notification (0x32) at the MCU time.
// The actual VehicleEvent setRtc wrapper runs; the native mHandleId.setRtc moves the MCU clock.
// skew() moves the MCU clock as a drift would.
function boot(db, {auto = autoDefault, mcu = ['2020-01-10', '00:00'], h24 = 1} = {}) {
  const writes = [];
  const clock = {offset: null, utc: 0};
  const p2 = n => String(n).padStart(2, '0');
  const showMcu = () => { if (clock.offset === null) return; const d = new Date(clock.utc + clock.offset);
    item.rtcDate = d.getUTCFullYear() + '-' + p2(d.getUTCMonth() + 1) + '-' + p2(d.getUTCDate()); item.rtcTime = p2(d.getUTCHours()) + ':' + p2(d.getUTCMinutes()); };
  const gps = {sentence: ''};
  const g = {gpsAutoSetRtcEnabled: auto, rtcDate: mcu[0], rtcTime: mcu[1], rtc24h: h24};
  const context = vm.createContext({Math, Number, String, Date, parseInt, parseFloat, isNaN, console: {log() {}},
    Funcs: {setProperty(key, value) { db[key] = String(value); }, restore_properity(key, fallback) { return db[key] ?? fallback; },
      prefixInteger: (n, w) => String(n).padStart(w, '0')}}, {codeGeneration: {strings: false, wasm: false}});
  Object.assign(context, g);
  for (const [name, value] of Object.entries(props)) context[name] = vm.runInContext('(' + value + ')', context);
  for (const fn of globalFunctions) vm.runInContext(fn, context, {timeout: 200});
  vm.runInContext(restoreLines.join('\n'), context);
  const item = context;
  const handle = {getGpsNmea: () => gps.sentence, getGpsIsFixed: () => 'A', getGpsInView: () => 9, getGpsLatitude: () => 0, getGpsLongitude: () => 0,
    setRtc(rtc) { writes.push(rtc); clock.offset = Date.parse(rtc.replace(' ', 'T') + 'Z') - clock.utc; showMcu(); }};
  const vctx = vm.createContext({Math, Number, String, console: {log() {}}, mGlobalId: {item}, mHandleId: handle, VehicleEvent: {NMEA_TYPE_RMC: 2}},
    {codeGeneration: {strings: false, wasm: false}});
  Object.assign(vctx, handle);
  vm.runInContext(setRtcFunction, vctx, {timeout: 200});
  if (syncFunction) vm.runInContext(syncFunction, vctx, {timeout: 200});
  return {
    writes, item, db,
    // One GPS fix: the native plugin raises the date-time and the position notifications.
    fix(sentence, utc) { clock.utc = utc.getTime(); showMcu(); gps.sentence = sentence; vm.runInContext(dateTimeHandler, vctx, {timeout: 200}); vm.runInContext(latLongHandler, vctx, {timeout: 200}); return writes.length; },
    // A drive: one fix per second from start for seconds, at a fixed place.
    at(utc, lat, lon, opts) { return this.fix(rmc(utc, lat, lon, opts), utc); },
    drive(start, seconds, lat, lon) { for (let s = 0; s < seconds; s++) this.at(new Date(start.getTime() + s * 1000), lat, lon); return writes.length; },
    skew(minutes) { clock.offset += minutes * 60000; showMcu(); },
    // The Date and time menu: mEventHandleId.item.setRtc(text).
    menuSet(rtc) { vm.runInContext('setRtc(' + JSON.stringify(rtc) + ')', vctx, {timeout: 200}); },
    clock() { return [item.getRtcTime ? item.getRtcTime() : null, item.getAmPm ? item.getAmPm() : null]; }
  };
}

const rows = [];
function check(name, mode, expected, run) {
  let actual;
  try { actual = run(); } catch (error) { actual = 'error: ' + error.message; }
  rows.push({name, failureMode: failureModes[mode], expected, actual, pass: JSON.stringify(actual) === JSON.stringify(expected)});
}
const T = s => new Date(s);
const CHI = [41.88, -87.63], FTW = [41.08, -85.14], PHX = [33.45, -112.07], NAVAJO = [36.73, -110.25], REGINA = [50.45, -104.6],
  HNL = [21.31, -157.86], ANC = [61.22, -149.9], STJ = [47.56, -52.71], MEX = [19.43, -99.13], HAVANA = [23.11, -82.37], GULF = [25.0, -90.0];
const once = (where, utc, opts = {}, fixOpts) => { const c = boot({}, opts); c.at(T(utc), ...where, fixOpts); return c.writes; };

check('first-fix-sets-local-time', 0, ['2026-07-15 13:30:05'], () => once(CHI, '2026-07-15T18:30:05Z'));
check('later-fixes-do-not-rewrite', 1, 1, () => { const c = boot({}); return c.drive(T('2026-07-15T18:30:05Z'), 600, ...CHI); });
check('status-v-sets-nothing', 2, [], () => { const c = boot({}); c.at(T('2026-07-15T18:30:05Z'), ...CHI, {status: 'V'}); return c.writes; });
check('bad-checksum-sets-nothing', 2, [], () => { const c = boot({}); c.at(T('2026-07-15T18:30:05Z'), ...CHI, {checksum: '00'}); return c.writes; });
check('sentence-without-checksum-accepted', 2, ['2026-07-15 13:30:05'], () => { const c = boot({}); c.at(T('2026-07-15T18:30:05Z'), ...CHI, {checksum: false}); return c.writes; });
check('gps-week-rollover-date-rejected', 2, [], () => once(CHI, '2006-11-30T18:30:05Z'));
check('month-13-rejected', 2, [], () => once(CHI, '2026-07-15T18:30:05Z', {}, {date: '151326'}));
check('auto-time-off-sets-nothing', 3, [], () => once(CHI, '2026-07-15T18:30:05Z', {auto: 0}));
check('new-year-crosses-back-a-day', 4, ['2026-12-31 21:30:00'], () => once(CHI, '2027-01-01T03:30:00Z'));
check('month-end-crosses-back', 4, ['2027-02-28 22:15:00'], () => once(CHI, '2027-03-01T04:15:00Z'));
check('leap-day', 4, ['2028-02-29 18:00:00'], () => once(CHI, '2028-03-01T00:00:00Z'));
check('dst-start-before', 5, ['2027-03-14 01:59:59'], () => once(CHI, '2027-03-14T07:59:59Z'));
check('dst-start-at', 5, ['2027-03-14 03:00:00'], () => once(CHI, '2027-03-14T08:00:00Z'));
check('dst-end-before', 5, ['2026-11-01 01:59:59'], () => once(CHI, '2026-11-01T06:59:59Z'));
check('dst-end-at', 5, ['2026-11-01 01:00:00'], () => once(CHI, '2026-11-01T07:00:00Z'));
check('dst-transition-rewrites-clock', 5, ['2026-11-01 01:59:00', '2026-11-01 01:00:00'], () => {
  const c = boot({}); c.drive(T('2026-11-01T06:59:00Z'), 91, ...CHI); return c.writes; });
check('arizona-no-dst', 6, ['2026-07-15 11:30:05', '2026-01-15 11:30:05'], () => [...once(PHX, '2026-07-15T18:30:05Z'), ...once(PHX, '2026-01-15T18:30:05Z')]);
check('hawaii-no-dst', 6, ['2026-07-15 08:30:05'], () => once(HNL, '2026-07-15T18:30:05Z'));
check('saskatchewan-no-dst', 6, ['2026-07-15 12:30:05'], () => once(REGINA, '2026-07-15T18:30:05Z'));
check('mexico-city-no-dst', 6, ['2026-07-15 12:30:05'], () => once(MEX, '2026-07-15T18:30:05Z'));
check('navajo-nation-has-dst', 7, ['2026-07-15 12:30:05'], () => once(NAVAJO, '2026-07-15T18:30:05Z'));
check('eastern-indiana', 7, ['2026-07-15 14:30:05'], () => once(FTW, '2026-07-15T18:30:05Z'));
check('alaska', 7, ['2026-07-15 10:30:05'], () => once(ANC, '2026-07-15T18:30:05Z'));
check('newfoundland-half-hour', 7, ['2026-07-15 16:00:05'], () => once(STJ, '2026-07-15T18:30:05Z'));
check('cuba-rule-not-guessed', 7, [], () => once(HAVANA, '2026-07-15T18:30:05Z'));
check('zone-change-after-hold', 8, ['2026-07-15 13:30:00', '2026-07-15 14:31:30'], () => {
  const c = boot({}); c.drive(T('2026-07-15T18:30:00Z'), 30, ...CHI); c.drive(T('2026-07-15T18:30:30Z'), 120, ...FTW); return c.writes; });
check('stray-fix-keeps-zone', 8, ['2026-07-15 13:30:00'], () => {
  const c = boot({}); c.drive(T('2026-07-15T18:30:00Z'), 30, ...CHI); c.drive(T('2026-07-15T18:30:30Z'), 20, ...FTW);
  c.drive(T('2026-07-15T18:30:50Z'), 120, ...CHI); return c.writes; });
check('drift-corrected', 9, ['2026-07-15 13:30:00', '2026-07-15 13:32:30'], () => {
  const c = boot({}); c.drive(T('2026-07-15T18:30:00Z'), 150, ...CHI); c.skew(-5); c.drive(T('2026-07-15T18:32:30Z'), 31, ...CHI); return c.writes; });
check('one-minute-difference-kept', 9, 1, () => {
  const c = boot({}); c.drive(T('2026-07-15T18:30:00Z'), 150, ...CHI); c.skew(1); return c.drive(T('2026-07-15T18:32:30Z'), 60, ...CHI); });
check('outside-grid-keeps-zone', 10, ['2026-07-15 13:30:00'], () => { const c = boot({}); c.drive(T('2026-07-15T18:30:00Z'), 5, ...CHI); c.drive(T('2026-07-15T18:30:05Z'), 300, ...GULF); return c.writes; });
check('saved-zone-used-without-position', 10, ['2026-07-15 13:30:05'], () => {
  const db = {}; boot(db).at(T('2026-07-15T18:00:00Z'), ...CHI); const c = boot(db); c.at(T('2026-07-15T18:30:05Z'), null, null); return c.writes; });
check('no-zone-no-position-no-write', 10, [], () => { const c = boot({}); c.at(T('2026-07-15T18:30:05Z'), null, null); return c.writes; });
check('reset-clock-shows-dashes', 11, ['--:--', ''], () => boot({}, {mcu: ['2020-01-10', '00:03']}).clock());
check('reset-clock-dashes-without-auto-time', 11, ['--:--', ''], () => boot({}, {auto: 0, mcu: ['2000-01-01', '00:03']}).clock());
check('clock-shows-after-gps-time', 11, ['13:30', ''], () => { const c = boot({}); c.at(T('2026-07-15T18:30:05Z'), ...CHI); return c.clock(); });
check('plausible-clock-shows-before-gps', 12, ['9:05', ''], () => boot({}, {mcu: ['2026-10-30', '09:05']}).clock());
check('manual-set-after-power-cut-shows', 14, ['9:05', ''], () => {
  const c = boot({}, {auto: 0, mcu: ['2000-01-01', '00:03']}); c.menuSet('2000-01-01 09:05:00'); return c.clock(); });
check('auto-time-on-by-default', 15, 1, () => autoDefault);
check('twelve-hour-format', 13, ['1:30', 'PM'], () => { const c = boot({}, {h24: 0}); c.at(T('2026-07-15T18:30:05Z'), ...CHI); return c.clock(); });

const resultPath = path.join(base, 'analysis/capture-04/clock-sync-replay-results.json');
const results = fs.existsSync(resultPath) ? JSON.parse(fs.readFileSync(resultPath, 'utf8')) : {};
results.failureModes = failureModes;
results.scope = 'Actual Global.qml clock functions and VehicleEvent.qml GPS handlers in Node VM, with generated NMEA RMC sentences, a mock MCU clock, and a mock settings database. No Qt lifecycle, GPS receiver, MCU response, or vehicle proof.';
results[phase] = {source: folder, hashes: Object.fromEntries(Object.entries(texts).map(([name, text]) => [name, crypto.createHash('sha256').update(text).digest('hex')])),
  count: rows.length, passed: rows.filter(row => row.pass).length, failed: rows.filter(row => !row.pass).length, rows};
fs.mkdirSync(path.dirname(resultPath), {recursive: true});
fs.writeFileSync(resultPath, JSON.stringify(results, null, 2) + '\n');
console.log(JSON.stringify({phase, count: rows.length, passed: results[phase].passed, failed: results[phase].failed, resultPath}));
if (phase === 'patched' && results[phase].failed) process.exitCode = 1;
