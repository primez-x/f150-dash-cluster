'use strict';
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');

const base = path.resolve(__dirname, '..');
const original = path.join(base, 'installed/capture-04/rootfs/etc/common');
const candidate = path.join(base, 'patches/capture-04/etc/common');
const phase = process.argv[2];
if (!['original', 'patched'].includes(phase)) throw new Error('Use original or patched');
const source = phase === 'original' ? original : candidate;
const resultPath = path.join(base, 'analysis/capture-04/gauge-replay-results.json');
const texts = Object.fromEntries(['Global.qml', 'VehicleEvent.qml'].map(name => [name, fs.readFileSync(path.join(source, name), 'utf8')]));
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
const context = vm.createContext({}, {codeGeneration: {strings: false, wasm: false}});
for (const name of ['tpms_pressure', 'getTpmsPressure', 'getIdleStartSavingFuel', 'getIdleResetSavingsFuel']) {
  const args = name === 'tpms_pressure' ? 'value' : name === 'getTpmsPressure' ? 'index' : '';
  new vm.Script('function ' + name + '(' + args + '){' + extract(texts['Global.qml'], 'function ' + name + '(') + '}').runInContext(context, {timeout: 100});
}
const handlers = Object.fromEntries(['onSpeedInfoNotify', 'onDpcInfoNotify'].map(name => [name, new vm.Script(extract(texts['VehicleEvent.qml'], name + ':'))]));
const rows = [];
function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map(key => [key, canonical(value[key])]));
  return value;
}
function check(name, expected, action) {
  let actual;
  let error;
  try { actual = action(); } catch (failure) { error = failure.name + ': ' + failure.message; }
  const pass = !error && JSON.stringify(canonical(actual)) === JSON.stringify(canonical(expected));
  rows.push({name, expected, actual: actual === undefined ? null : actual, ...(error ? {error} : {}), pass});
}
function call(code) { return new vm.Script(code).runInContext(context, {timeout: 100}); }
const pressures = [101, 222, 247, 318, 355];
const pressureNames = ['tpmsLFPressure', 'tpmsRFPressure', 'tpmsLRPressure', 'tpmsRRPressure', 'tpmsRearPressure'];
const divisors = [1, 100, 98.0665, 6.894757293168];
for (let unit = 0; unit < 4; unit++) {
  context.pressureUnit = unit;
  for (const frontSwap of [false, true]) for (const rearSwap of [false, true]) {
    context.frontTpmsDoorExchange = frontSwap;
    context.rearTpmsDoorExchange = rearSwap;
    pressureNames.forEach((name, index) => { context[name] = pressures[index]; });
    const map = [frontSwap ? 1 : 0, frontSwap ? 0 : 1, rearSwap ? 3 : 2, rearSwap ? 2 : 3, 4];
    for (let position = 0; position < 5; position++) {
      const raw = pressures[map[position]];
      const expected = unit === 0 ? raw : (raw / divisors[unit]).toFixed(1);
      check(`pressure/u${unit}/front${frontSwap}/rear${rearSwap}/p${position}`, expected, () => call(`getTpmsPressure(${position})`));
    }
    pressureNames.forEach(name => { context[name] = 4095; });
    for (let position = 0; position < 5; position++) check(`pressure-unavailable/u${unit}/front${frontSwap}/rear${rearSwap}/p${position}`, '---', () => call(`getTpmsPressure(${position})`));
  }
  for (const raw of [0, 100, 220, 350]) check(`pressure-boundary/u${unit}/raw${raw}`, unit === 0 ? raw : (raw / divisors[unit]).toFixed(1), () => call(`tpms_pressure(${raw})`));
}
context.mGlobalId = {item: {vehicleSpeed: 0, tachoSpeed: 0}};
let speed = 0;
let rpm = 0;
context.getVehicleSpeed = () => speed;
context.getTachoSpeed = () => rpm;
const rpmStates = [];
context.mGlobalId.item.tachoSpeed = 100;
check('rpm/seed100-to-zero', {vehicleSpeed: 0, vehicleSpeedDelta: 0, tachoSpeed: 0, tachoSpeedDelta: 100}, () => {
  handlers.onSpeedInfoNotify.runInContext(context, {timeout: 100});
  const state = {...context.mGlobalId.item};
  rpmStates.push({initialRpm: 100, input: {speed, rpm}, state});
  return state;
});
context.mGlobalId = {item: {vehicleSpeed: 0, tachoSpeed: 0}};
let previousRpm = 0;
let previousSpeed = 0;
for (const next of [100, 0, 800, 850, 730, 1000, 999, 120, 0]) {
  rpm = next;
  speed += 7;
  check(`rpm/${rpmStates.length}/value${next}`, {vehicleSpeed: speed, vehicleSpeedDelta: Math.abs(speed - previousSpeed), tachoSpeed: next, tachoSpeedDelta: Math.abs(next - previousRpm)}, () => {
    handlers.onSpeedInfoNotify.runInContext(context, {timeout: 100});
    const state = {...context.mGlobalId.item};
    rpmStates.push({input: {speed, rpm}, state});
    return state;
  });
  previousRpm = next;
  previousSpeed = speed;
}
const dpcStates = [];
for (const values of [[11, 22, 33, 44], [0, 5, 0, 9]]) {
  context.mGlobalId = {item: {dpcFrontLeft: -1, dpcFrontRight: -2, dpcRearLeft: -3, dpcRearRight: -4}};
  context.getDpcFrontLevel = index => values[index];
  context.getDpcRearLevel = index => values[index + 2];
  check('dpc/' + values.join('-'), {dpcFrontLeft: values[0], dpcFrontRight: values[1], dpcRearLeft: values[2], dpcRearRight: values[3]}, () => {
    try { handlers.onDpcInfoNotify.runInContext(context, {timeout: 100}); }
    finally { dpcStates.push({input: values, state: {...context.mGlobalId.item}}); }
    return {...context.mGlobalId.item};
  });
}
for (let unit = 0; unit < 3; unit++) {
  context.consumptionUnit = unit;
  for (const raw of [0, 1000, 65535]) {
    context.idleStartSavingsFuel = raw;
    const expected = (raw === 65535 ? '----' : unit === 2 ? (raw / 3785.411784).toFixed(2) : String(raw)) + (unit === 2 ? 'gal' : 'ml');
    check(`idle-start/u${unit}/raw${raw}`, expected, () => call('getIdleStartSavingFuel()'));
  }
  for (const raw of [0, 3.785411784, 65535]) {
    context.idleResetSavingsFuel = raw;
    const expected = (raw === 65535 ? '----' : unit === 2 ? (raw / 3.785411784).toFixed(1) : String(raw)) + (unit === 2 ? 'gal' : 'L');
    check(`idle-reset/u${unit}/raw${raw}`, expected, () => call('getIdleResetSavingsFuel()'));
  }
}
const hash = folder => Object.fromEntries(['Global.qml', 'VehicleEvent.qml'].map(name => [name, crypto.createHash('sha256').update(fs.readFileSync(path.join(folder, name))).digest('hex')]));
const results = phase === 'patched' && fs.existsSync(resultPath) ? JSON.parse(fs.readFileSync(resultPath, 'utf8')) : {};
results.failureModes = ['Incorrect pressure scale for bar, kgf/cm2, and psi', 'Wrong wheel after front or rear swap', 'Unavailable pressure loses placeholder', 'Small RPM updates retain stale values, including 100 to zero', 'DPC handler throws before all four values refresh', 'Metric consumption modes select wrong fuel volume units', 'US MPG mode selects metric or imperial volume', 'Unavailable fuel loses placeholder or unit'];
results.scope = 'Actual QML source blocks in isolated Node VM with mocked measurement getters. Math and state logic only. No Qt runtime or device accuracy proof.';
results.conversionReference = 'https://www.nist.gov/pml/special-publication-811/nist-guide-si-appendix-b-conversion-factors/nist-guide-si-appendix-b9';
results[phase] = {source, hashes: hash(source), count: rows.length, passed: rows.filter(row => row.pass).length, failed: rows.filter(row => !row.pass).length, rows, rpmStates, dpcStates};
results.originalHashes = hash(original);
results.patchHashes = hash(candidate);
fs.writeFileSync(resultPath, JSON.stringify(results, null, 2) + '\n');
console.log(JSON.stringify({phase, count: rows.length, passed: results[phase].passed, failed: results[phase].failed, resultPath}));
if (phase === 'patched' && results[phase].failed) process.exitCode = 1;
