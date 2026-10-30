'use strict';
// Replay steering wheel key events through the actual onSwcInfoNotify source in a Node VM.
// Input: the key trace from the truck (menu-v2 install, 2026-10-30) plus synthetic bounce shapes.
// The original phase must reproduce the extra presses. The patched phase must pass every case.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const base = path.resolve(__dirname, '..');
const phase = process.argv[2];
if (!['original', 'patched'].includes(phase)) throw new Error('Use original or patched');
const file = path.join(base, phase === 'original' ? 'evidence/fixtures/capture-04/etc/common/VehicleEvent.qml' :
  'patches/capture-04/etc/common/VehicleEvent.qml');
const text = fs.readFileSync(file, 'utf8');
const TRACE = path.join(base, 'analysis/capture-04/vehicle-runs/menu-v2-install-1/Launcher-later.log');
const RESULT = path.join(base, 'analysis/capture-04/swc-debounce-replay-results.json');
const [UP, DOWN, LEFT, RIGHT, ENTER] = [19, 20, 21, 22, 23];
const failureModes = [
  'A bounce after a release reaches the pages as a second press',
  'A chain of bounces reaches the pages as several presses',
  'Bounce at the start of a hold ends the hold or loses the final release',
  'A short press of another key right after a release reaches the pages',
  'Fast real presses are dropped or changed',
  'A release reaches the pages late or never',
  'A dropped key swallows a later real press or release',
  'Events reach the pages out of order',
  'A dropped event leaves no trace in the Launcher log'
];

function block(marker) {
  const start = text.indexOf(marker);
  if (start < 0) throw new Error('Missing source marker: ' + marker);
  if (text.indexOf(marker, start + marker.length) >= 0) throw new Error('Expected one source marker: ' + marker);
  const rest = text.slice(start + marker.length).trimStart();
  if (!rest.startsWith('{')) return rest.split(/\r?\n/)[0];
  let depth = 1;
  let end = 1;
  while (depth && end < rest.length) {
    if (rest[end] === '{') depth++;
    if (rest[end] === '}') depth--;
    end++;
  }
  if (depth) throw new Error('Unclosed source block: ' + marker);
  return rest.slice(1, end - 1);
}
const handler = new vm.Script(block('onSwcInfoNotify:'));
const functions = [...text.matchAll(/^    function (swc\w+)\(([^)]*)\)/gm)].map(match =>
  'function ' + match[1] + '(' + match[2] + '){' + block('function ' + match[1] + '(' + match[2] + ')') + '}');
const defaults = Object.fromEntries([...text.matchAll(/^    (?:readonly )?property (?:int|double) (mSwc\w+): (-?\d+)/gm)]
  .map(match => [match[1], Number(match[2])]));
// The settle Timer: interval and onTriggered, read from the source.
const settle = /Timer \{\s*id: mSwcSettleTimer\s+interval: (\w+)\s+onTriggered: (.+)/.exec(text);

// One cluster: native events at virtual times, a virtual Timer, and the Global key properties the pages read.
function cluster() {
  let clock = 0;
  let due = null;
  let native = {key: 0, state: 0};
  const delivered = [];
  const drops = [];
  const values = {swcKey: 0, swcState: 0, swcChanged: 0};
  const global = {};
  for (const name of Object.keys(values)) Object.defineProperty(global, name, {get: () => values[name], set(value) {
    const changed = values[name] !== value;
    values[name] = value;
    if (name === 'swcChanged' && changed) delivered.push([clock, values.swcKey, values.swcState]);
  }});
  const context = vm.createContext({mGlobalId: {item: global}, Date: {now: () => clock}, Number, Math,
    console: {log(line) { if (String(line).startsWith('viknav-key-drop ')) drops.push(String(line)); }},
    getSwcKey: () => native.key, getSwcState: () => native.state}, {codeGeneration: {strings: false, wasm: false}});
  Object.assign(context, defaults);
  if (settle)
    context.mSwcSettleTimer = {
      restart() { due = clock + (/^\d+$/.test(settle[1]) ? Number(settle[1]) : context[settle[1]]); },
      stop() { due = null; }};
  vm.runInContext(functions.join('\n'), context);
  const advance = time => {
    while (due !== null && due <= time) {
      clock = due;
      due = null;
      vm.runInContext(settle[2], context);
    }
    clock = time;
  };
  return {
    send(time, key, state) { advance(time); native = {key, state}; handler.runInContext(context, {timeout: 100}); },
    finish() { advance(clock + 1000); return {delivered, drops}; }
  };
}
// Synthetic times are offsets from START, a clock value well after power-up.
const START = 1000000;
function run(start, events) {
  const c = cluster();
  for (const [time, key, state] of events) c.send(start + time, key, state);
  return c.finish();
}
const presses = result => result.delivered.filter(event => event[2] === 1).map(event => [event[0], event[1]]);
const shape = result => result.delivered.map(event => event[1] + ':' + event[2]).join(' ');

const rows = [];
function check(name, mode, expected, actual) {
  rows.push({name, failureMode: failureModes[mode], expected, actual, pass: JSON.stringify(actual) === JSON.stringify(expected)});
}

// The truck trace. vnM logged each event as the pages received it; menu-v2 had no filter, so the lines are the native events.
const trace = fs.readFileSync(TRACE, 'utf8').split(/\r?\n/).map(line => /viknav-key (\d+) (\d+) (\d+) /.exec(line))
  .filter(Boolean).map(match => [Number(match[1]), Number(match[2]), Number(match[3])]);
// Physical presses (time, key): presses that start 120 ms or more after the previous release.
// Every other press in the trace starts 9-20 ms after a release.
const physical = [
  ...[29641, 31390, 33130, 34860, 36790, 38621, 40331, 41951, 43621, 44910].map(t => [t, DOWN]),
  ...[47630, 49031, 50600, 51900, 53290, 54530, 55820, 57170, 58470, 59920].map(t => [t, UP]),
  ...[61216, 61446, 61666, 61886, 62107].map(t => [t, DOWN]),
  ...[63136, 63326, 63526, 63716, 63907].map(t => [t, UP]),
  [66216, DOWN], [69698, UP], [72088, RIGHT],
  ...[73578, 73929, 74249, 75109, 75459, 75859, 76079, 76299].map(t => [t, DOWN]),
  ...[80629, 81149, 81595, 95575].map(t => [t, LEFT])
];
const truck = run(0, trace);
check('truck-trace-one-press-per-physical-press', 1, physical, presses(truck));
check('truck-trace-every-press-has-one-release', 5, true, (() => {
  const open = new Set();
  for (const [time, key, state] of truck.delivered) {
    if (state === 1) { if (open.size) return 'press at ' + time + ' while ' + [...open] + ' is down'; open.add(key); }
    if (state === 2 && !open.has(key)) return 'hold without press at ' + time;
    if (state === 0) { if (!open.delete(key)) return 'release without press at ' + time; }
    // A hold without a release in the trace (66216, 69698): the next press of another key ends the hold.
    if (state === 2) open.delete(key);
  }
  return open.size === 0 || 'press without release';
})());
// The Up taps had no bounce: the pages get the same events, and each release at most the settle time later.
const upTaps = events => events.filter(([t, k]) => k === UP && t < 64100).map(([t, k, s]) => s === 1 ? 'press@' + t : 'release');
check('truck-trace-up-taps-unchanged', 4, upTaps(trace), upTaps(truck.delivered));
check('truck-trace-releases-within-60-ms', 5, true, truck.delivered.filter(e => e[2] === 0).every(([time, key]) => {
  const raw = trace.filter(([t, k, s]) => k === key && s === 0 && t <= time).pop();
  return Boolean(raw) && time - raw[0] <= 60;
}));
// A bounce line stands for two events: the press and the waiting release it joins.
check('truck-trace-drop-lines-cover-every-dropped-event', 8, trace.length - truck.delivered.length,
  truck.drops.reduce((sum, line) => sum + (line.endsWith(' bounce') ? 2 : 1), 0));
check('truck-trace-quick-other-key-dropped', 3, [], presses(truck).filter(([, k]) => k === ENTER));

// Synthetic shapes.
check('release-bounce-one-tap', 0, '20:1 20:0', shape(run(START, [[0, DOWN, 1], [80, DOWN, 0], [90, DOWN, 1], [101, DOWN, 0]])));
check('bounce-chain-one-tap', 1, '20:1 20:0',
  shape(run(START, [[0, DOWN, 1], [80, DOWN, 0], [90, DOWN, 1], [100, DOWN, 0], [120, DOWN, 1], [130, DOWN, 0]])));
check('press-bounce-keeps-hold', 2, '20:1 20:2 20:0',
  shape(run(START, [[0, DOWN, 1], [10, DOWN, 0], [20, DOWN, 1], [900, DOWN, 2], [1500, DOWN, 0]])));
check('other-key-after-release-dropped-with-hold-and-release', 3, '20:1 20:0',
  shape(run(START, [[0, DOWN, 1], [80, DOWN, 0], [89, ENTER, 1], [990, ENTER, 2], [1100, ENTER, 0]])));
check('other-key-bounce-chain-dropped', 3, '20:1 20:0',
  shape(run(START, [[0, DOWN, 1], [80, DOWN, 0], [89, ENTER, 1], [100, ENTER, 0], [110, ENTER, 1], [120, ENTER, 0]])));
check('fast-taps-pass', 4, '20:1 20:0 20:1 20:0 19:1 19:0',
  shape(run(START, [[0, DOWN, 1], [40, DOWN, 0], [160, DOWN, 1], [200, DOWN, 0], [320, UP, 1], [370, UP, 0]])));
check('release-arrives-after-settle', 5, [[START, DOWN, 1], [START + 130, DOWN, 0]],
  run(START, [[0, DOWN, 1], [80, DOWN, 0]]).delivered);
check('clock-set-backward-keeps-presses', 4, '20:1 20:0 19:1 19:0',
  shape(run(START, [[0, DOWN, 1], [80, DOWN, 0], [-60000, UP, 1], [-59950, UP, 0]])));
check('first-press-after-power-up-passes', 4, '20:1 20:0', shape(run(0, [[7, DOWN, 1], [90, DOWN, 0]])));
check('dropped-key-without-release-does-not-swallow-next-press', 6, '20:1 20:0 23:1 23:0',
  shape(run(START, [[0, DOWN, 1], [80, DOWN, 0], [89, ENTER, 1], [2000, ENTER, 1], [2080, ENTER, 0]])));
check('order-kept-across-keys', 7, '20:1 20:0 19:1 19:0',
  shape(run(START, [[0, DOWN, 1], [80, DOWN, 0], [129, DOWN, 1], [140, DOWN, 0], [400, UP, 1], [470, UP, 0]])));

const passed = rows.filter(row => row.pass).length;
const report = {phase, source: path.relative(base, file), trace: path.relative(base, TRACE), trace_events: trace.length,
  delivered: truck.delivered.length, drops: truck.drops, cases: rows.length, passed, failure_modes: failureModes, rows};
if (phase === 'patched') fs.writeFileSync(RESULT, JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify({phase, cases: rows.length, passed, failed: rows.filter(row => !row.pass).map(row => row.name)}));
if (phase === 'patched' ? passed !== rows.length : rows[0].pass) process.exit(1);
