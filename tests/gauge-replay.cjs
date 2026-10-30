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
  const match = texts['Global.qml'].match(new RegExp('^[ \\t]*(?:readonly )?property \\w+ ' + name + ':[ \\t]*(.+)$', 'm'));
  const expression = match ? new vm.Script('(' + match[1].split('//')[0] + ')') : null;
  Object.defineProperty(context, name, {configurable: true, get() { return expression ? expression.runInContext(context, {timeout: 100}) : undefined; }});
}
for (const name of ['fuelPercentageValid', 'mainTankPercentageValid', 'subTankPercentageValid', 'lpkValid', 'lpkUnit']) bind(name);
for (const name of ['mFuelUnit', 'mLpkUnit']) {
  const match = texts['Global.qml'].match(new RegExp('property var ' + name + ':\\s*(\\[[\\s\\S]*?\\])'));
  if (!match) throw new Error('Missing unit table ' + name);
  context[name] = new vm.Script('(' + match[1] + ')').runInContext(context, {timeout: 100});
}
// The compiled fuel gauges (ui1, ui2, ui3 FuelMeter) draw fuelPercentage, mainTankPercentage, and subTankPercentage directly.
// A reading outside 0..100 must keep the last valid gauge value. The raw byte stays in the *Raw property for the data log.
let fuelSamples = [0, 0, 0];
let fuelState = 0;
const fuelNames = ['fuelPercentage', 'mainTankPercentage', 'subTankPercentage'];
for (const name of fuelNames) context[name] = 0;
for (const name of ['fuelLowPercent', 'fuelCriticalPercent']) bind(name);
try {
  new vm.Script('function fuelWarningLevel(percent, state, valid){' + extract(texts['Global.qml'], 'function fuelWarningLevel(') + '}').runInContext(context, {timeout: 100});
} catch (missing) { /* the original source has no percent-based warning */ }
const fuelNative = vm.createContext({mGlobalId: {item: context}, getDte: () => 300, getFuelPercentage: () => fuelSamples[0],
  getFuelFillerRight: () => 1, getFuelState: () => fuelState, getFuelTank: index => index ? 30 : 60,
  getTankFuelPercetage: index => fuelSamples[index + 1], getTankFuelState: () => 0}, {codeGeneration: {strings: false, wasm: false}});
const fuelHandler = new vm.Script(extract(texts['VehicleEvent.qml'], 'onFuelInfoNotify:'));
const fuelFrame = (raw, state = 0) => { fuelSamples = Array.isArray(raw) ? raw : [raw, raw, raw]; fuelState = state; fuelHandler.runInContext(fuelNative, {timeout: 100}); };
let lastValid = 0;
for (const raw of [-1, 0, 1, 50, 100, 101, 254, 255, 256]) {
  fuelFrame(raw);
  const valid = raw >= 0 && raw <= 100;
  if (valid) lastValid = raw;
  for (const name of fuelNames) {
    check(`fuel/${name}/raw${raw}/gauge-value`, lastValid, () => context[name]);
    check(`fuel/${name}/raw${raw}/raw-preserved`, raw, () => context[name + 'Raw']);
    check(`fuel/${name}/raw${raw}/validity`, valid, () => context[name + 'Valid']);
  }
  check(`fuel/raw${raw}/formatted`, valid ? raw + '%' : '---%', () => call('getFuelPercentage()'));
}
check('fuel/frame-time-recorded', true, () => context.fuelFrameMs > 0);
// Low-fuel warning (fuelLevel: 0 normal, 1 low, 2 critical) from the percent, whatever the adapter state. The adapter state
// still wins when higher. An invalid reading shows at least the low warning.
for (const [raw, state, expected] of [[50, 0, 0], [13, 0, 0], [12, 0, 1], [6, 0, 1], [5, 0, 2], [0, 0, 2], [50, 1, 1], [50, 2, 2],
  [8, 2, 2], [60, 0, 0], [255, 0, 1], [60, 0, 0], [255, 2, 2]]) {
  fuelFrame(raw, state);
  check(`fuel-warning/raw${raw}/state${state}/after${lastValid}`, expected, () => context.fuelLevel);
  if (raw <= 100) lastValid = raw;
}
fuelFrame([50, 255, 75]);
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
    // The compiled FuelInfo and MpgInfo pages label getLpkData() with fuelUnit (distance consumption), so flow mode (L/h) shows 0.
    check(`lpk/u${unit}/mode${mode}/raw${raw}/data`, valid && mode === 0 ? raw > 100 ? 0 : converted : 0, () => call('getLpkData()'));
    check(`lpk/u${unit}/mode${mode}/raw${raw}/numeric-binding`, true, () => Number.isFinite(Number(call('getLpkData()'))));
    check(`lpk/u${unit}/mode${mode}/raw${raw}/visibility`, raw !== 32766, () => call('isLpkVisible()'));
    lpkStates.push({unit, mode, raw, valid: context.lpkValid, label: context.lpkUnit, text: call('getLPK(1)'), data: call('getLpkData()')});
  }
}
check('lpk/raw-measurement-has-no-animation', false, () => lpkBehavior);
// Travel and idle times arrive in minutes. The compiled SinceInfoItem page labels the travel time "h:m".
context.Funcs = {prefixInteger: (num, length) => (Array(length).join('0') + num).slice(-length)};
for (const name of ['getSinceResetTravelTime', 'getSinceStartTravelTime', 'getIdleUseTime']) {
  new vm.Script('function ' + name + '(){' + extract(texts['Global.qml'], 'function ' + name + '(') + '}').runInContext(context, {timeout: 100});
  const property = name === 'getIdleUseTime' ? 'idleUseTime' : name.slice(3, 4).toLowerCase() + name.slice(4);
  for (const [minutes, expected] of [[0, '0:00'], [5, '0:05'], [65, '1:05'], [600, '10:00'], [6039, '100:39'], [65535, name === 'getIdleUseTime' ? '1092:15' : '--:--']]) {
    context[property] = minutes;
    check(`time/${name}/minutes${minutes}`, expected, () => call(name + '()'));
  }
}
// The compiled OilLifeinfo page shows trucksOilLifeTrip next to tripUnit. The adapter sends a 16-bit distance in km, like odo and trip.
for (const name of ['tripFactor', 'trucksOilLifeTrip']) bind(name);
const trailerNative = vm.createContext({mGlobalId: {item: context}, getTrucksTrailerDistance: () => 0, getTrucksTrailerGain: () => 0,
  getTrucksTrailerOilLifePercentage: () => 80, getTrucksTrailerOilLifeTrip: () => trailerTrip, getTrucksTrailerFrontRadarState: () => 0,
  getTrucksTrailerRrearRadarState: () => 0, getTrucksTrailerOilPressure: () => 0}, {codeGeneration: {strings: false, wasm: false}});
const trailerHandler = new vm.Script(extract(texts['VehicleEvent.qml'], 'onTrucksTrailerInfoNotify:'));
let trailerTrip = 0;
for (const metric of [1, 0]) for (const [raw, expected] of [[0, '0'], [1000, metric ? '1000' : '621'], [8047, metric ? '8047' : '5000'], [65534, metric ? '65534' : '40721'], [65535, '---']]) {
  context.metricSystem = metric;
  trailerTrip = raw;
  trailerHandler.runInContext(trailerNative, {timeout: 100});
  check(`oil-life-trip/metric${metric}/raw${raw}/shown`, expected, () => String(context.trucksOilLifeTrip));
  check(`oil-life-trip/metric${metric}/raw${raw}/raw-preserved`, raw, () => context.trucksOilLifeTripRaw);
}
// Oil-life reset. The 2011-2014 F150 profile (truck model 1, vehicle model 1) uses the vendor's own Ford setup
// command from Vehicle > Assist row 59. Other profiles keep the vendor command.
const oilParam = new vm.Script('(function(index){' + extract(texts['Global.qml'], 'function f150_11_14_param_id(') + '})');
for (const [model, vehicle, expected] of [[1, 1, [['ford', 14, 8, 100]]], [8, 0, [['reset2']]], [1, 0, [['reset2']]], [1, 2, [['reset2']]], [7, 0, [['reset2']]]]) {
  const sent = [];
  const item = {vehicleModel: vehicle, fordSetupInfo: new Array(90).fill(30)};
  const oilContext = vm.createContext({mTrucksModel: String(model), Qt: {platform: {os: 'linux'}}, console: {log() {}}, mGlobalId: {item},
    mHandleId: {setOilLifeReset2: () => sent.push(['reset2']), setFordSetup: (v, id, data) => sent.push(['ford', v, id, data])}},
    {codeGeneration: {strings: false, wasm: false}});
  item.f150_11_14_param_id = oilParam.runInContext(oilContext, {timeout: 100});
  for (const name of ['resetOilLife', 'setFordSetup']) {
    const args = name === 'setFordSetup' ? 'vehicle, id, data' : '';
    new vm.Script('function ' + name + '(' + args + '){' + extract(texts['VehicleEvent.qml'], 'function ' + name + '(') + '}').runInContext(oilContext, {timeout: 100});
  }
  check(`oil-life-reset/model${model}/vehicle${vehicle}/command`, expected, () => { oilContext.resetOilLife(); return sent; });
  check(`oil-life-reset/model${model}/vehicle${vehicle}/shown-value`, model === 1 && vehicle === 1 ? 100 : 30, () => item.fordSetupInfo[59]);
}
// The compiled Dashboard (023 fn 11) takes the next key release while doorInfo is set, before the menu gets the key.
// The popup Loader (023 fn 17) is active for doorInfo && !menuBarIndex. The menu must keep every key; the popup must not change.
bind('doorInfo');
for (const [menu, enabled, door, radar] of [[0, 1, 0, 0], [0, 1, 4, 0], [0, 1, 0, 2], [1, 1, 4, 0], [1, 1, 0, 2], [1, 1, 4, 2], [0, 0, 4, 0], [0, 0, 0, 2]]) {
  Object.assign(context, {menuBarIndex: menu, doorInfoEnabled: enabled, doorLeftFront: door, doorRightFront: 0, doorLeftRear: 0,
    doorRightRear: 0, doorHood: 0, doorTrunk: 0, radarEnabled: radar});
  const popup = !menu && ((enabled && door) || radar);
  const name = `door-popup/menu${menu}/enabled${enabled}/door${door}/radar${radar}`;
  check(name + '/popup', Boolean(popup), () => Boolean(context.doorInfo && !context.menuBarIndex));
  check(name + '/key-taken-by-popup', Boolean(popup), () => Boolean(context.doorInfo));
}
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
results.failureModes = ['Incorrect pressure scale for bar, kgf/cm2, and psi', 'Wrong wheel after front or rear swap', 'Unavailable pressure loses placeholder', 'Small RPM updates retain stale values, including 100 to zero', 'DPC handler throws before all four values refresh', 'Metric consumption modes select wrong fuel volume units', 'US MPG mode selects metric or imperial volume', 'Unavailable fuel loses placeholder or unit', 'Fuel readings outside 0..100 reach the gauges or lose the raw byte', 'The low-fuel warning ignores the fuel percent or an invalid reading', 'One invalid tank changes sibling validity', 'Flow mode receives distance-consumption conversion or labels', 'Hidden or unavailable consumption becomes a real number', 'Raw consumption animation interpolates sentinel transitions', 'Flow readings reach pages labeled with a distance-consumption unit', 'Travel or idle minutes lose the leading zero', 'Oil-life trip ignores the distance unit or shows the unavailable sentinel as a number', 'Oil-life reset sends no command or the wrong command for the truck profile'];
results.scope = 'Actual QML source blocks and scalar bindings in isolated Node VM with mocked measurement getters. Sentinel animation replay models the declared raw Behavior endpoints. No Qt renderer, animation engine, device accuracy, or active compiled-consumer proof.';
results.conversionReference = 'https://www.nist.gov/pml/special-publication-811/nist-guide-si-appendix-b-conversion-factors/nist-guide-si-appendix-b9';
results[phase] = {source, hashes: hash(source), count: rows.length, passed: rows.filter(row => row.pass).length, failed: rows.filter(row => !row.pass).length, rows, rpmStates, dpcStates, lpkStates, transitions};
results.originalHashes = hash(original);
results.patchHashes = hash(candidate);
fs.mkdirSync(path.dirname(resultPath), {recursive: true});
fs.writeFileSync(resultPath, JSON.stringify(results, null, 2) + '\n');
console.log(JSON.stringify({phase, count: rows.length, passed: results[phase].passed, failed: results[phase].failed, resultPath}));
if (phase === 'patched' && results[phase].failed) process.exitCode = 1;
