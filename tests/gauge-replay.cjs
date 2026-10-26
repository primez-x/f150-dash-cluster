'use strict';
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');

const base = path.resolve(__dirname, '..');
const original = path.join(base, 'evidence/fixtures/capture-04/etc/common');
const candidate = path.join(base, 'patches/capture-04/etc/common');
const phase = process.argv[2];
if (!['original', 'patched'].includes(phase)) throw new Error('Use original or patched');
const source = phase === 'original' ? original : candidate;
const resultPath = path.join(base, 'analysis/capture-04/gauge-replay-results.json');
const texts = Object.fromEntries(['Global.qml', 'VehicleEvent.qml'].map(name => [name, fs.readFileSync(path.join(source, name), 'utf8')]));
function extract(text, marker) {
  const escaped = marker.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const matches = [...text.matchAll(new RegExp('^[ \\t]*' + escaped, 'gm'))];
  if (matches.length !== 1) throw new Error('Expected one source marker: ' + marker);
  const start = matches[0].index;
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
for (const name of ['tpms_pressure', 'getTpmsPressure', 'getIdleStartSavingFuel', 'getIdleResetSavingsFuel', 'getFuelConsumption', 'getFuelPercentage', 'getLpkData', 'getLPK', 'isLpkVisible']) {
  const args = ['tpms_pressure', 'getFuelConsumption'].includes(name) ? 'value' : name === 'getTpmsPressure' ? 'index' : name === 'getLPK' ? 'unit' : '';
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
function bind(name) {
  const match = texts['Global.qml'].match(new RegExp('^[ \\t]*property \\w+ ' + name + ':[ \\t]*(.+)$', 'm'));
  const expression = match ? new vm.Script('(' + match[1].split('//')[0] + ')') : null;
  Object.defineProperty(context, name, {configurable: true, get() { return expression ? expression.runInContext(context, {timeout: 100}) : undefined; }});
}
for (const name of ['fuelPercentageValid', 'mainTankPercentageValid', 'subTankPercentageValid', 'lpkValid', 'lpkUnit']) bind(name);
for (const name of ['mFuelUnit', 'mLpkUnit']) {
  const match = texts['Global.qml'].match(new RegExp('property var ' + name + ':\\s*(\\[[\\s\\S]*?\\])'));
  if (!match) throw new Error('Missing unit table ' + name);
  context[name] = new vm.Script('(' + match[1] + ')').runInContext(context, {timeout: 100});
}
let fuelSamples = [0, 0, 0];
const fuelNative = vm.createContext({mGlobalId: {item: context}, getDte: () => 300, getFuelPercentage: () => fuelSamples[0],
  getFuelFillerRight: () => 1, getFuelState: () => 0, getFuelTank: index => index ? 30 : 60,
  getTankFuelPercetage: index => fuelSamples[index + 1], getTankFuelState: () => 0}, {codeGeneration: {strings: false, wasm: false}});
const fuelHandler = new vm.Script(extract(texts['VehicleEvent.qml'], 'onFuelInfoNotify:'));
for (const raw of [-1, 0, 1, 50, 100, 101, 254, 255, 256]) {
  fuelSamples = [raw, raw, raw];
  fuelHandler.runInContext(fuelNative, {timeout: 100});
  const valid = raw >= 0 && raw <= 100;
  for (const name of ['fuelPercentage', 'mainTankPercentage', 'subTankPercentage']) {
    check(`fuel/${name}/raw${raw}/raw-preserved`, raw, () => context[name]);
    check(`fuel/${name}/raw${raw}/validity`, valid, () => context[name + 'Valid']);
  }
  check(`fuel/raw${raw}/formatted`, valid ? raw + '%' : '---%', () => call('getFuelPercentage()'));
}
fuelSamples = [50, 255, 75];
fuelHandler.runInContext(fuelNative, {timeout: 100});
check('fuel/independent-tank-validity', [true, false, true], () => [context.fuelPercentageValid, context.mainTankPercentageValid, context.subTankPercentageValid]);
const lpkBehavior = /(?:^|\n)\s*Behavior on lpk\s*\{/.test(texts['Global.qml']);
let lpkSample = 0;
let lpkMode = 0;
const lpkNative = vm.createContext({mGlobalId: {item: context}, getLpk: () => lpkSample, getLpkUnit: () => lpkMode}, {codeGeneration: {strings: false, wasm: false}});
const lpkHandler = new vm.Script(extract(texts['VehicleEvent.qml'], 'onLpkInfoNotify:'));
const lpkStates = [];
for (let unit = 0; unit < 3; unit++) for (const mode of [0, 1]) {
  context.consumptionUnit = unit;
  lpkMode = mode;
  for (const raw of [0, 5, 12.3, 100, 120, 32766, 32767]) {
    lpkSample = raw;
    lpkHandler.runInContext(lpkNative, {timeout: 100});
    const valid = raw !== 32766 && raw !== 32767;
    const converted = mode === 1 ? raw.toFixed(1) : unit === 0 ? raw.toFixed(1) : raw === 0 ? 0 : (unit === 1 ? 100 / raw : 235.2156 / raw).toFixed(1);
    const label = mode === 1 ? 'L/h' : ['l/100km', 'km/l', 'MPG'][unit];
    check(`lpk/u${unit}/mode${mode}/raw${raw}/validity`, valid, () => context.lpkValid);
    check(`lpk/u${unit}/mode${mode}/raw${raw}/label`, label, () => context.lpkUnit);
    check(`lpk/u${unit}/mode${mode}/raw${raw}/text`, (valid ? converted : '--.-') + ' ' + label, () => call('getLPK(1)'));
    check(`lpk/u${unit}/mode${mode}/raw${raw}/data`, valid ? mode === 0 && raw > 100 ? 0 : converted : 0, () => call('getLpkData()'));
    check(`lpk/u${unit}/mode${mode}/raw${raw}/numeric-binding`, true, () => Number.isFinite(Number(call('getLpkData()'))));
    check(`lpk/u${unit}/mode${mode}/raw${raw}/visibility`, raw !== 32766, () => call('isLpkVisible()'));
    lpkStates.push({unit, mode, raw, valid: context.lpkValid, label: context.lpkUnit, text: call('getLPK(1)'), data: call('getLpkData()')});
  }
}
check('lpk/raw-measurement-has-no-animation', false, () => lpkBehavior);
const transitions = [];
for (const [from, to] of [[12.3, 32767], [32767, 5], [12.3, 32766], [32766, 5]]) {
  context.consumptionUnit = 0;
  context.lpkUnitIndex = 0;
  const samples = lpkBehavior ? [0.25, 0.5, 0.75, 1].map(fraction => from + (to - from) * fraction) : [to];
  const rendered = samples.map(raw => { context.lpk = raw; return call('getLPK(0)'); });
  const expected = to === 32766 || to === 32767 ? '--.-' : to.toFixed(1);
  check(`lpk/transition/${from}-to-${to}/immediate-target`, [expected], () => rendered);
  transitions.push({from, to, samples, rendered});
}
const hash = folder => Object.fromEntries(['Global.qml', 'VehicleEvent.qml'].map(name => [name, crypto.createHash('sha256').update(fs.readFileSync(path.join(folder, name))).digest('hex')]));
const results = phase === 'patched' && fs.existsSync(resultPath) ? JSON.parse(fs.readFileSync(resultPath, 'utf8')) : {};
results.failureModes = ['Incorrect pressure scale for bar, kgf/cm2, and psi', 'Wrong wheel after front or rear swap', 'Unavailable pressure loses placeholder', 'Small RPM updates retain stale values, including 100 to zero', 'DPC handler throws before all four values refresh', 'Metric consumption modes select wrong fuel volume units', 'US MPG mode selects metric or imperial volume', 'Unavailable fuel loses placeholder or unit', 'Fuel percentages outside 0..100 remain real readings', 'One invalid tank changes sibling validity', 'Flow mode receives distance-consumption conversion or labels', 'Hidden or unavailable consumption becomes a real number', 'Raw consumption animation interpolates sentinel transitions'];
results.scope = 'Actual QML source blocks and scalar bindings in isolated Node VM with mocked measurement getters. Sentinel animation replay models the declared raw Behavior endpoints. No Qt renderer, animation engine, device accuracy, or active compiled-consumer proof.';
results.conversionReference = 'https://www.nist.gov/pml/special-publication-811/nist-guide-si-appendix-b-conversion-factors/nist-guide-si-appendix-b9';
results[phase] = {source, hashes: hash(source), count: rows.length, passed: rows.filter(row => row.pass).length, failed: rows.filter(row => !row.pass).length, rows, rpmStates, dpcStates, lpkStates, transitions};
results.originalHashes = hash(original);
results.patchHashes = hash(candidate);
fs.mkdirSync(path.dirname(resultPath), {recursive: true});
fs.writeFileSync(resultPath, JSON.stringify(results, null, 2) + '\n');
console.log(JSON.stringify({phase, count: rows.length, passed: results[phase].passed, failed: results[phase].failed, resultPath}));
if (phase === 'patched' && results[phase].failed) process.exitCode = 1;
