'use strict';
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');

const base = path.resolve(__dirname, '..');
const phase = process.argv[2];
if (!['original', 'patched'].includes(phase)) throw new Error('Use original or patched');
const folder = path.join(base, phase === 'original' ? 'evidence/fixtures/capture-04/etc/common' : 'patches/capture-04/etc/common');
const texts = Object.fromEntries(['Global.qml', 'VehicleEvent.qml'].map(name => [name, fs.readFileSync(path.join(folder, name), 'utf8')]));
const menu = JSON.parse(fs.readFileSync(path.join(base, 'evidence/fixtures/capture-04/menu-system-units-key-enter.json'))).functions.find(fn => fn.name === 'key_enter');
function extract(text, marker) {
  const start = text.indexOf(marker);
  if (start < 0 || text.indexOf(marker, start + marker.length) >= 0) throw new Error('Expected one source marker: ' + marker);
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
// Execute decoded menu instructions. Resolve every lookup from the captured cache.
function enter(scope) {
  const regs = {6: 0};
  const instructions = new Map(menu.bytecode.map(op => [op.offset, op]));
  let accumulator;
  let offset = 0;
  for (let count = 0; count < 500; count++) {
    const op = instructions.get(offset);
    if (!op) throw new Error('Missing instruction ' + offset);
    const args = op.args;
    const refs = op.references || {};
    let next = offset + op.size;
    const parameters = () => Array.from({length: args.argc}, (_, index) => regs[args.argv + index]);
    switch (op.name) {
    case 'LoadQmlContextPropertyLookup': accumulator = scope[refs.index]; break;
    case 'GetLookup': accumulator = accumulator[refs.index]; break;
    case 'StoreReg': regs[args.reg] = accumulator; break;
    case 'LoadReg': accumulator = regs[args.reg]; break;
    case 'MoveReg': regs[args.destReg] = regs[args.srcReg]; break;
    case 'MoveConst': regs[args.destTemp] = refs.constIndex.value; break;
    case 'LoadZero': accumulator = 0; break;
    case 'LoadInt': accumulator = args.value; break;
    case 'CmpStrictEqual': accumulator = regs[args.lhs] === accumulator; break;
    case 'CmpLt': accumulator = regs[args.lhs] < accumulator; break;
    case 'UNot': accumulator = !accumulator; break;
    case 'Increment': accumulator++; break;
    case 'SetLookup': regs[args.base][refs.index] = accumulator; break;
    case 'StoreNameSloppy': scope[refs.name] = accumulator; break;
    case 'CallPropertyLookup': accumulator = regs[args.base][refs.lookupIndex](...parameters()); break;
    case 'CallQmlContextPropertyLookup': accumulator = scope[refs.index](...parameters()); break;
    case 'Jump': next = op.target_offset; break;
    case 'JumpFalse': if (!accumulator) next = op.target_offset; break;
    case 'JumpTrue': if (accumulator) next = op.target_offset; break;
    case 'Ret': return accumulator;
    default: throw new Error('Unsupported instruction ' + op.name);
    }
    offset = next;
  }
  throw new Error('Menu instruction limit');
}
const metricHandler = new vm.Script(extract(texts['Global.qml'], 'onMetricSystemChanged:'));
const temperatureHandler = new vm.Script(extract(texts['Global.qml'], 'onTemperatureUnitChanged:'));
const overrideHandlers = Object.fromEntries(['speedUnitOverride', 'tempUnitOverride'].map(key => {
  const marker = 'on' + key[0].toUpperCase() + key.slice(1) + 'Changed:';
  return [key, new vm.Script(texts['Global.qml'].includes(marker) ? extract(texts['Global.qml'], marker) : '')];
}));
const notify = new vm.Script(extract(texts['VehicleEvent.qml'], 'onUnitInfoNotify:'));
const restoreLines = texts['Global.qml'].split(/\r?\n/).filter(line => /^\s*(metricSystem|temperatureUnit|rtc24h|speedUnitOverride|tempUnitOverride)=Funcs\.restore_properity\(/.test(line));
if (restoreLines.length !== (phase === 'original' ? 3 : 5)) throw new Error('Unexpected saved unit restore assignments');
if (phase === 'patched' && !restoreLines.slice(0, 2).every(line => /UnitOverride=/.test(line))) throw new Error('Restore override flags before display values');
const restore = new vm.Script(restoreLines.join('\n'));
function harness(saved = {}, model = 1) {
  const db = {...saved};
  const writes = [];
  const values = {metricSystem: 1, temperatureUnit: 1, rtc24h: 1, followUnit: 1, consumptionUnit: 0, pressureUnit: 0, speedUnitOverride: 0, tempUnitOverride: 0};
  const native = {trip: 1, temperature: 1, time: 1};
  const state = {};
  const context = vm.createContext({console: {log() {}}, Number, Qt: {platform: {os: 'linux'}},
    Funcs: {setProperty(key, value) { db[key] = value; }, restore_properity(key, fallback) { return db[key] ?? fallback; }},
    getTripUnit: () => native.trip, getTempUnit: () => native.temperature, getTime24h: () => native.time,
    mHandleId: {setUnit2(type, data) { writes.push({type, data: Number(data)}); }, getTripUnit: () => native.trip, getTempUnit: () => native.temperature, getTime24h: () => native.time},
    mTrucksModel: model, mPressed: 0, mMenuBackId: {mIndex: 4}, key_back() {},
    mSystemUnitId: {currentIndex: 0, itemAt(index) { return {mIndex: index}; }}, mGlobalId: {item: state}
  }, {codeGeneration: {strings: false, wasm: false}});
  for (const key of Object.keys(values)) {
    const descriptor = {enumerable: true, get: () => values[key], set(value) {
      const next = Number(value);
      const changed = values[key] !== next;
      values[key] = next;
      if (changed && key === 'metricSystem') metricHandler.runInContext(context, {timeout: 100});
      if (changed && key === 'temperatureUnit') temperatureHandler.runInContext(context, {timeout: 100});
      if (changed && overrideHandlers[key]) overrideHandlers[key].runInContext(context, {timeout: 100});
    }};
    Object.defineProperty(state, key, descriptor);
    Object.defineProperty(context, key, descriptor);
  }
  Object.defineProperty(context, 'outSideTempUnit', {get: () => values.temperatureUnit ? '℃' : '℉'});
  for (const name of ['c2f', 'getWaterTemp', 'getOutSideTemp', 'getGearBoxTemp', 'getOilTemp', 'getDiffOilTemp', 'isWaterTempVisible', 'isOutSideTempVisible', 'isOilTempVisible', 'isDiffOilTempVisible']) {
    const args = name === 'c2f' ? 'temp, f' : name.startsWith('get') ? 'unit' : '';
    new vm.Script('function ' + name + '(' + args + '){' + extract(texts['Global.qml'], 'function ' + name + '(') + '}').runInContext(context, {timeout: 100});
  }
  state.c2f = context.c2f;
  new vm.Script('function setUnit2(type, data){' + extract(texts['VehicleEvent.qml'], 'function setUnit2(') + '}').runInContext(context, {timeout: 100});
  if (texts['VehicleEvent.qml'].includes('function followVehicleUnits(')) new vm.Script('function followVehicleUnits(){' + extract(texts['VehicleEvent.qml'], 'function followVehicleUnits(') + '}').runInContext(context, {timeout: 100});
  context.mEventHandleId = {item: {setUnit2: context.setUnit2}};
  return {context, state, db, native, writes, restore() { restore.runInContext(context, {timeout: 100}); },
    select(row) { context.mSystemUnitId.currentIndex = row; enter(context); },
    notify() { notify.runInContext(context, {timeout: 100}); },
    snapshot() { return {metricSystem: state.metricSystem, temperatureUnit: state.temperatureUnit}; }
  };
}
const rows = [];
function check(name, expected, action) {
  let actual;
  let error;
  try { actual = action(); } catch (failure) { error = failure.name + ': ' + failure.message; }
  const pass = !error && JSON.stringify(actual) === JSON.stringify(expected);
  rows.push({name, expected, actual: actual === undefined ? null : actual, ...(error ? {error} : {}), pass});
}
const sequences = [];
for (let model = 0; model <= 8; model++) {
  const h = harness({}, model);
  check(`model${model}/C-to-F`, {metricSystem: 1, temperatureUnit: 0}, () => { h.select(2); return h.snapshot(); });
  check(`model${model}/KMH-to-MPH-preserves-F`, {metricSystem: 0, temperatureUnit: 0}, () => { h.select(1); h.native.trip = 0; h.notify(); return h.snapshot(); });
  check(`model${model}/saved-independent-values`, {metricSystem: 0, temperatureUnit: 0}, () => ({metricSystem: h.db.metricSystem, temperatureUnit: h.db.temperatureUnit}));
  const reboot = harness(h.db, model);
  check(`model${model}/reboot-plus-native-snapshot`, {metricSystem: 0, temperatureUnit: 0}, () => { reboot.restore(); reboot.notify(); return reboot.snapshot(); });
  sequences.push({model, state: h.snapshot(), saved: h.db, nativeSnapshot: {...h.native}, nativeWrites: h.writes, reboot: reboot.snapshot()});
}
for (const metricSystem of [0, 1]) for (const temperatureUnit of [0, 1]) {
  const h = harness({metricSystem, temperatureUnit, speedUnitOverride: 1, tempUnitOverride: 1});
  check(`restore/${metricSystem}/${temperatureUnit}`, {metricSystem, temperatureUnit}, () => { h.restore(); h.notify(); return h.snapshot(); });
  check(`temperature-change-preserves-speed/${metricSystem}/${temperatureUnit}`, {metricSystem, temperatureUnit: Number(!temperatureUnit)}, () => { h.state.metricSystem = metricSystem; h.state.temperatureUnit = temperatureUnit; h.select(2); h.notify(); return h.snapshot(); });
}
for (const storage of ['number', 'string']) for (const override of [0, 1]) {
  const value = number => storage === 'string' ? String(number) : number;
  const h = harness({metricSystem: value(0), temperatureUnit: value(0), speedUnitOverride: value(override), tempUnitOverride: value(override)});
  check(`restore-coercion/${storage}/override${override}`, {metricSystem: override ? 0 : 1, temperatureUnit: override ? 0 : 1}, () => { h.restore(); h.notify(); return h.snapshot(); });
}
for (const row of [1, 2]) {
  const h = harness();
  h.select(row);
  h.native.trip = row === 1 ? 1 : 0;
  h.native.temperature = row === 2 ? 1 : 0;
  check(`manual-row${row}/other-field-still-follows`, {metricSystem: 0, temperatureUnit: 0}, () => { h.notify(); return h.snapshot(); });
  check(`manual-row${row}/native-write-preserved`, [{type: row === 1 ? 2 : 1, data: 0}], () => h.writes);
  check(`manual-row${row}/only-selected-override`, row === 1 ? [1, 0] : [0, 1], () => [h.state.speedUnitOverride, h.state.tempUnitOverride]);
}
{
  const h = harness();
  h.native.trip = 0;
  h.native.temperature = 0;
  check('fresh/native-units-follow', {metricSystem: 0, temperatureUnit: 0}, () => { h.notify(); return h.snapshot(); });
  check('fresh/native-follow-does-not-create-overrides', [0, 0], () => [h.state.speedUnitOverride, h.state.tempUnitOverride]);
  h.context.setUnit2(5, 0);
  check('clock-write-does-not-create-overrides', [0, 0], () => [h.state.speedUnitOverride, h.state.tempUnitOverride]);
  check('clock-native-write-preserved', [{type: 5, data: 0}], () => h.writes);
  h.state.metricSystem = 0;
  h.state.temperatureUnit = 0;
  h.context.setUnit2(1, 0);
  h.context.setUnit2(2, 0);
  h.native.trip = 1;
  h.native.temperature = 1;
  h.native.time = 0;
  check('return-to-follow/applies-current-native-snapshot', {metricSystem: 1, temperatureUnit: 1}, () => { h.context.followVehicleUnits(); return h.snapshot(); });
  check('return-to-follow/clears-saved-overrides', [0, 0], () => [h.db.speedUnitOverride, h.db.tempUnitOverride]);
  const reboot = harness(h.db);
  reboot.native.trip = 0;
  reboot.native.temperature = 0;
  check('return-to-follow/reboot-resumes-native-follow', {metricSystem: 0, temperatureUnit: 0}, () => { reboot.restore(); reboot.notify(); return reboot.snapshot(); });
  check('return-to-follow/no-extra-native-write', [{type: 5, data: 0}, {type: 1, data: 0}, {type: 2, data: 0}], () => h.writes);
}
{
  const h = harness();
  h.state.followUnit = 0;
  h.state.speedUnitOverride = 1;
  h.state.tempUnitOverride = 1;
  h.state.metricSystem = 0;
  h.state.temperatureUnit = 0;
  check('return-to-follow/follow-disabled-retains-display-values', {metricSystem: 0, temperatureUnit: 0}, () => { h.context.followVehicleUnits(); return h.snapshot(); });
  check('return-to-follow/follow-disabled-clears-overrides', [0, 0], () => [h.db.speedUnitOverride, h.db.tempUnitOverride]);
  check('return-to-follow/follow-disabled-no-native-write', [], () => h.writes);
}
const h = harness();
const temperatures = [
  {key: 'waterTemp', getter: 'getWaterTemp', hidden: 0xFE, unavailable: 0xFF, placeholder: '---', error: 0xFC},
  {key: 'outSideTemp', getter: 'getOutSideTemp', hidden: 0xFF, unavailable: 0xFE, placeholder: '---', error: 0xFC},
  {key: 'gearBoxTemp', getter: 'getGearBoxTemp', unavailable: 0xFF, placeholder: '--.-'},
  {key: 'oilTemp', getter: 'getOilTemp', hidden: 0xFE, unavailable: 0xFF, placeholder: '---'},
  {key: 'diffOilTemp', getter: 'getDiffOilTemp', hidden: 0xFE, unavailable: 0xFF, placeholder: '---'}
];
for (const unit of [0, 1]) {
  h.state.temperatureUnit = unit;
  const suffix = ' ' + (unit ? '℃' : '℉');
  for (const sensor of temperatures) {
    for (const raw of [-40, 0, 20, 100, 120]) for (const withUnit of [0, 1]) {
      h.context[sensor.key] = raw;
      const expected = String(unit ? raw : Math.round(raw * 1.8 + 32)) + (withUnit ? suffix : '');
      check(`${sensor.key}/u${unit}/raw${raw}/suffix${withUnit}`, expected, () => h.context[sensor.getter](withUnit));
    }
    for (const raw of [sensor.unavailable, sensor.hidden].filter(value => value !== undefined)) {
      h.context[sensor.key] = raw;
      check(`${sensor.key}/u${unit}/sentinel${raw}`, sensor.placeholder + suffix, () => h.context[sensor.getter](1));
    }
    if (sensor.error !== undefined) {
      h.context[sensor.key] = sensor.error;
      check(`${sensor.key}/u${unit}/error${sensor.error}`, 'E' + suffix, () => h.context[sensor.getter](1));
    } else {
      h.context[sensor.key] = 0xFC;
      check(`${sensor.key}/u${unit}/undocumented252-preserved`, String(unit ? 252 : 486) + suffix, () => h.context[sensor.getter](1));
    }
  }
}
check('native-clock-follow-preserved', 0, () => { h.native.time = 0; h.notify(); return h.state.rtc24h; });
const resultPath = path.join(base, 'analysis/capture-04/unit-state-replay-results.json');
const results = phase === 'patched' && fs.existsSync(resultPath) ? JSON.parse(fs.readFileSync(resultPath, 'utf8')) : {};
results.failureModes = ['A native unit snapshot overwrites an independent manual selection', 'A speed choice overwrites the saved temperature choice', 'A temperature choice overwrites the speed choice', 'A reboot or late native snapshot replaces saved manual choices', 'A string database value changes override semantics', 'An unselected field stops native follow', 'Return to vehicle units leaves a saved override or sends a native command', 'A supported temperature getter converts an unavailable or hidden sentinel', 'A temperature label differs from the selected scale', 'Native clock follow changes unintentionally'];
results.scope = 'Actual QML source functions and handlers in Node VM. Decoded runtime menu instructions drive selections. Mock native unit snapshots reproduce overwrite conditions. No Qt lifecycle, MCU response, or device proof.';
results.menu = {code_file_offset: menu.code_file_offset, code_sha256: menu.code_sha256, speedBranch: [229, 275], temperatureBranch: [277, 323]};
results[phase] = {source: folder, hashes: Object.fromEntries(Object.entries(texts).map(([name, text]) => [name, crypto.createHash('sha256').update(text).digest('hex')])), count: rows.length, passed: rows.filter(row => row.pass).length, failed: rows.filter(row => !row.pass).length, sequences, rows};
fs.mkdirSync(path.dirname(resultPath), {recursive: true});
fs.writeFileSync(resultPath, JSON.stringify(results, null, 2) + '\n');
console.log(JSON.stringify({phase, count: rows.length, passed: results[phase].passed, failed: results[phase].failed, resultPath}));
if (phase === 'patched' && results[phase].failed) process.exitCode = 1;
