'use strict';
// Replay the Tow/Haul layout switch with the actual QML source handlers in a Node VM.
// The original phase must reproduce the missing switch. The patched phase must pass every case.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');

const base = path.resolve(__dirname, '..');
const phase = process.argv[2];
if (!['original', 'patched'].includes(phase)) throw new Error('Use original or patched');
const folder = path.join(base, phase === 'original' ? 'evidence/fixtures/capture-04/etc/common' : 'patches/capture-04/etc/common');
const texts = Object.fromEntries(['Global.qml', 'VehicleEvent.qml'].map(name => [name, fs.readFileSync(path.join(folder, name), 'utf8')]));
const TOW = 90;
const failureModes = [
  'Tow/Haul on does not show the towing layout',
  'Tow/Haul off does not return to the layout the driver used before',
  'Repeated alarm frames during Tow/Haul undo a manual layout change',
  'Tow/Haul off overrides a layout the driver chose while towing',
  'A restart with Tow/Haul off leaves the towing layout on screen',
  'A restart with Tow/Haul still on loses the layout to return to',
  'Tow/Haul off moves a driver who chose the towing layout before Tow/Haul',
  'Other telltale changes switch the layout',
  'A flashing TOW telltale counts as off',
  'Telltale frames before the first TOW state switch the layout'
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
  return text.slice(brace + 1, end - 1);
}
function propertyDefault(name, fallback) {
  const match = texts['Global.qml'].match(new RegExp('property int ' + name + ':\\s*(-?\\d+)'));
  return match ? Number(match[1]) : fallback;
}
const script = code => new vm.Script(code || '');
const alarmHandler = script(extract(texts['Global.qml'], 'onAlarmChangedChanged:'));
const towFunction = extract(texts['Global.qml'], 'function updateTowDashboard(');
const savedHandler = script(extract(texts['Global.qml'], 'onDashboardBeforeTowChanged:'));
const dashboardHandler = script(extract(texts['Global.qml'], 'onDashboardChanged:'));
const notify = script(extract(texts['VehicleEvent.qml'], 'onAlarmInfoNotify:'));
const restoreLines = texts['Global.qml'].split(/\r?\n/).filter(line => /^\s*(dashboard|dashboardBeforeTow)=Funcs\.restore_properity\(/.test(line));
if (restoreLines.length !== (phase === 'original' ? 1 : 2)) throw new Error('Unexpected saved layout restore assignments');
const restore = script(restoreLines.join('\n'));

// One cluster boot: saved database, Global properties with change handlers, and the native alarm table.
function boot(db) {
  const values = {dashboard: 0, dashboardBeforeTow: propertyDefault('dashboardBeforeTow', -1), towState: propertyDefault('towState', -1), alarmChanged: 0, ill: 0};
  const native = new Array(300).fill(0);
  const handlers = {dashboard: dashboardHandler, dashboardBeforeTow: savedHandler, alarmChanged: alarmHandler};
  const state = {alarmMax: 300, alarmTable: [], towDashboard: propertyDefault('towDashboard', 1)};
  const context = vm.createContext({Math, Number, console: {log() {}}, mGlobalId: {item: state},
    Funcs: {setProperty(key, value) { db[key] = String(value); }, restore_properity(key, fallback) { return db[key] ?? fallback; }},
    getAlarm: id => native[id]}, {codeGeneration: {strings: false, wasm: false}});
  for (const key of Object.keys(values)) {
    const descriptor = {enumerable: true, get: () => values[key], set(value) {
      const next = Math.trunc(Number(value));
      const changed = values[key] !== next;
      values[key] = next;
      if (changed && handlers[key]) handlers[key].runInContext(context, {timeout: 100});
    }};
    Object.defineProperty(state, key, descriptor);
    Object.defineProperty(context, key, descriptor);
  }
  for (const key of ['alarmMax', 'alarmTable', 'towDashboard']) Object.defineProperty(context, key, {get: () => state[key]});
  if (towFunction !== null) script('function updateTowDashboard(){' + towFunction + '}').runInContext(context, {timeout: 100});
  restore.runInContext(context, {timeout: 100});
  return {
    state,
    frame(changes) { Object.assign(native, changes); notify.runInContext(context, {timeout: 100}); return values.dashboard; },
    choose(layout) { state.dashboard = layout; return values.dashboard; }
  };
}

const rows = [];
function check(name, mode, expected, run) {
  let actual;
  try { actual = run(); } catch (error) { actual = 'error: ' + error.message; }
  rows.push({name, failureMode: failureModes[mode], expected, actual, pass: JSON.stringify(actual) === JSON.stringify(expected)});
}
const towLayout = propertyDefault('towDashboard', 1);
const driver = towLayout === 3 ? 4 : 3;
const other = towLayout === 5 ? 0 : 5;
const [ON, OFF] = [{[TOW]: 1}, {[TOW]: 0}];

check('tow-on-shows-towing-layout', 0, towLayout, () => { const c = boot({dashboard: String(driver)}); c.frame(OFF); return c.frame(ON); });
check('tow-off-returns-to-driver-layout', 1, driver, () => { const c = boot({dashboard: String(driver)}); c.frame(OFF); c.frame(ON); return c.frame(OFF); });
check('repeat-frames-keep-manual-change', 2, other, () => { const c = boot({dashboard: String(driver)}); c.frame(ON); c.choose(other); c.frame(ON); return c.frame({[TOW]: 1, 12: 1}); });
check('tow-off-keeps-manual-change', 3, other, () => { const c = boot({dashboard: String(driver)}); c.frame(ON); c.choose(other); return c.frame(OFF); });
check('restart-tow-off-returns-to-driver-layout', 4, [towLayout, driver], () => {
  const db = {dashboard: String(driver)};
  const first = boot(db); first.frame(ON);
  const second = boot(db); return [second.state.dashboard, second.frame(OFF)];
});
check('restart-tow-on-keeps-return-layout', 5, [towLayout, driver], () => {
  const db = {dashboard: String(driver)};
  const first = boot(db); first.frame(ON);
  const second = boot(db); return [second.frame(ON), second.frame(OFF)];
});
check('driver-chosen-towing-layout-stays', 6, towLayout, () => { const c = boot({dashboard: String(towLayout)}); c.frame(ON); return c.frame(OFF); });
check('other-telltales-do-not-switch', 7, [driver, driver], () => { const c = boot({dashboard: String(driver)}); return [c.frame({12: 1, 24: 1}), c.frame({12: 0, 24: 0})]; });
check('flashing-tow-counts-as-on', 8, [towLayout, towLayout, driver], () => { const c = boot({dashboard: String(driver)}); return [c.frame({[TOW]: 2}), c.frame({[TOW]: 3}), c.frame(OFF)]; });
check('first-frame-tow-off-no-switch', 9, driver, () => { const c = boot({dashboard: String(driver)}); return c.frame(OFF); });
check('saved-return-cleared-after-tow-off', 4, '-1', () => { const db = {dashboard: String(driver)}; const c = boot(db); c.frame(ON); c.frame(OFF); return db.dashboardBeforeTow ?? '-1'; });

const resultPath = path.join(base, 'analysis/capture-04/tow-layout-replay-results.json');
const results = fs.existsSync(resultPath) ? JSON.parse(fs.readFileSync(resultPath, 'utf8')) : {};
results.failureModes = failureModes;
results.scope = 'Actual Global.qml and VehicleEvent.qml handlers in Node VM with mock native alarm frames and a mock settings database. Alarm 90 is the TOW telltale shown by all six stock layouts. No Qt lifecycle, MCU response, or vehicle proof.';
results[phase] = {source: folder, hashes: Object.fromEntries(Object.entries(texts).map(([name, text]) => [name, crypto.createHash('sha256').update(text).digest('hex')])),
  towLayout, count: rows.length, passed: rows.filter(row => row.pass).length, failed: rows.filter(row => !row.pass).length, rows};
fs.mkdirSync(path.dirname(resultPath), {recursive: true});
fs.writeFileSync(resultPath, JSON.stringify(results, null, 2) + '\n');
console.log(JSON.stringify({phase, count: rows.length, passed: results[phase].passed, failed: results[phase].failed, resultPath}));
if (phase === 'patched' && results[phase].failed) process.exitCode = 1;
