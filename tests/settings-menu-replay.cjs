'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');

const base = path.resolve(__dirname, '..');
const reportPath = path.join(base, 'analysis/capture-04/settings-menu-candidate.json');
const fixtures = path.join(base, 'evidence/fixtures/capture-04');
const pages = path.join(base, 'patches/capture-04/etc');
const expected = [
  'Factory rows forward all 19 indexes to the existing setter.',
  'General settings Back, Left, and the Back row return to the factory catalog on release.',
  'Factory and Units Up/Down wrap without changes on press or hold.',
  'Factory source contains no gate, odometer, shell, or update route.',
  'Models zero through eight preserve vendor unit assignments and native calls.',
  'Distance changes preserve temperature. Temperature changes preserve distance.',
  'Each independent unit row shows Manual or Follow from the saved override.',
  'The Follow row calls followVehicleUnits once and sends no extra CAN command.',
  'Unsupported models show a reason and cannot change units.',
  'Units Back and the Back row return to System Settings.',
  'Mode release advances selection. Mode hold activates the selected row.',
  'Repeated mode hold events preserve vendor repeated activation and release advance.',
  'Page completion selects the first row after Repeater creates the controls.',
  'Factory completion starts the original 50 ms one-shot system inquiry. Units completion sends no query.'
];
const report = {schema_version: 2, authority: 'PC source and reduced decoded vendor metadata replay',
  command: 'node tests/settings-menu-replay.cjs', expected_cases: expected,
  source_verification: 'failed', qt_verification: 'Root owns Qt 5.14.2 checks.',
  vehicle_verification: 'Not run', cases: 0,
  page_contracts: {
    factory_catalog: {base: 'qrc:/Trucks/common/ItemInfo.qml', width:820, height:510,
      controls:'15 labeled settings and diagnostic entries plus Back',
      verification:'Host Qt owns actual catalog key and action checks.',
      return:'menuSettingsPageIndex=0'},
    general: {base: 'qrc:/Trucks/common/ItemInfo.qml', width: 820, height: 510,
      controls: '19 vendor rows plus Back', setter: 'mGlobalId.item.setFactory(index)',
      return: 'menuSettingsSubPageItemSetup=0',
      context: ['mGlobalId', 'mTranslationId'],
      navigation: 'Back now resets the subpage index and returns to the direct catalog.'},
    units: {base: 'qrc:/Trucks/common/ItemInfo.qml', width: 600, height: 510,
      controls: ['Consumption', 'Distance', 'Temperature', 'Pressure', 'Follow vehicle units', 'Back'],
      context: ['mGlobalId', 'mTranslationId', 'mEventHandleId', 'mTrucksModel'],
      supported_models: '0 through 8', unsupported: 'Visible reason plus Back',
      manual_state: 'Independent saved speedUnitOverride and tempUnitOverride',
      follow: 'mEventHandleId.item.followVehicleUnits()'},
    keys: 'Inherited ItemInfo.key(key,state) dispatches overridden key_back/up/down/left/right/enter/modes methods.',
    states: 'General and Units preserve vendor state behavior. The catalog activates a mode hold once and consumes the matching release.'
  }, limitations: [
    'Source replay does not prove QML component rendering or native context lookup.',
    'Loader offsets and identities come from reduced metadata fixtures. This replay does not verify native binary bytes.',
    'The candidate generator and ui-loader-replay own exact checks against the pinned original Launcher.',
    'No target binary, native plugin, calibration, polling, or hardware changed.'
  ]};
let cases = 0;
function check(condition, message) { cases++; assert.ok(condition, message); }
function declaration(text, name) {
  const marker = 'function ' + name + '(';
  const start = text.indexOf(marker);
  assert.ok(start >= 0, 'Missing function ' + name);
  const brace = text.indexOf('{', start);
  let depth = 1;
  let end = brace + 1;
  while (depth && end < text.length) {
    if (text[end] === '{') depth++;
    if (text[end] === '}') depth--;
    end++;
  }
  assert.equal(depth, 0, 'Unclosed function ' + name);
  return text.slice(start, end);
}
function methods(text, scope) {
  const context = vm.createContext(scope, {codeGeneration: {strings: false, wasm: false}});
  for (const match of text.matchAll(/function\s+(\w+)\(/g)) {
    vm.runInContext(declaration(text, match[1]), context);
  }
  return context;
}
function handler(text, marker) {
  const start = text.indexOf(marker);
  assert.ok(start >= 0, 'Missing handler ' + marker);
  const suffix = text.slice(start + marker.length).trimStart();
  if (!suffix.startsWith('{')) return suffix.split(/\r?\n/)[0];
  const wrapper = declaration('function callback() ' + suffix, 'callback');
  return wrapper.slice(wrapper.indexOf('{') + 1, -1);
}
function unitScope(model = 1, follow = 1) {
  const state = {consumptionUnit: 0, metricSystem: 1, temperatureUnit: 1, pressureUnit: 0,
    speedUnitOverride: 0, tempUnitOverride: 0, followUnit: follow, menuSettingsPageIndex: 1,
    swcHome: 2, swcBack: 3, swcUp: 19, swcDown: 20, swcLeft: 21, swcRight: 22,
    swcEnter: 23, swcModes: 26};
  const calls = [];
  const scope = {Number, mTrucksModel: model, mPressed: 0, mGlobalId: {item: state},
    mSystemUnitId: {currentIndex: 0, count: 6, itemAt(index) { return {mIndex: index}; }},
    mMenuBackId: {mIndex: 5}, calls,
    mTranslationId: {item: {getSystemUnit(index) { return ['L/100km', 'km', 'C', 'kPa'][index]; }}},
    mEventHandleId: {item: {setUnit2(type, data) { calls.push({type, data: Number(data)}); },
      followVehicleUnits() { calls.push({follow: true}); }}}};
  return scope;
}
try {
  const provenance = JSON.parse(fs.readFileSync(path.join(fixtures, 'manifest.json')));
  report.fixtures = ['menu-system-units-key-enter.json', 'factory-generic-key-enter.json',
    'system-settings-loaders.json'].map(name => {
    const bytes = fs.readFileSync(path.join(fixtures, name));
    const sha256 = crypto.createHash('sha256').update(bytes).digest('hex');
    const record = provenance.files.find(record => record.path === name);
    check(Boolean(record), 'Fixture provenance record ' + name);
    check(record.export_sha256 === sha256, 'Fixture SHA-256 ' + name);
    return {path: 'evidence/fixtures/capture-04/' + name, sha256,
      authority: 'Reduced decoded metadata; no native byte verification'};
  });
  const catalogText = fs.readFileSync(path.join(pages, 'vnF.qml'), 'utf8');
  check(catalogText.includes('mFactoryMenu'), 'Factory entry exposes a direct settings catalog');
  check(!/mFactoryPasswd|mPasswdSelect|PasswdTumber|key_enter_hold/.test(catalogText), 'Direct catalog contains no vendor code gate');
  const factoryText = fs.readFileSync(path.join(pages, 'vnB.qml'), 'utf8');
  const unitText = fs.readFileSync(path.join(pages, 'vnU.qml'), 'utf8');
  const lifecycleBytes = fs.readFileSync(path.join(fixtures, 'settings-page-lifecycle.json'));
  const lifecycleHash = crypto.createHash('sha256').update(lifecycleBytes).digest('hex');
  check(lifecycleHash === '624ca9646190d349c685a6244bd237894cbfbe31c4dd26835c6a762f10c0bba6', 'Lifecycle fixture SHA-256');
  report.lifecycle_fixture = {path: 'evidence/fixtures/capture-04/settings-page-lifecycle.json',
    export_bytes: lifecycleBytes.length, export_sha256: lifecycleHash,
    recipe: 'Retain original FactoryGenericSetup root and view completion functions, query-timer object and callback. Retain original MenuSystemUnits root and view completion functions and total timer count. Preserve resolved bytecode and omit unrelated objects, functions, and string tables.',
    sources: [{source: 'analysis/capture-04/qml-cache/085-Trucks_menu_system_factory_FactoryGenericSetup.qml.json',
      source_sha256: '6b19ec3407da3cfa8c33c17d03df401ca851ce81ada40a79d3d137ef9195560c'},
    {source: 'analysis/capture-04/qml-cache/073-Trucks_menu_system_MenuSystemUnits.qml.json',
      source_sha256: 'f6efb07133345d7aa9b4bc9bfe3a51db345719d9c3d0742debd5f1994e71ea33'}]};
  const lifecycle = JSON.parse(lifecycleBytes);
  const factoryLifecycle = lifecycle.units.find(unit => unit.qrc_path.endsWith('/FactoryGenericSetup.qml'));
  const unitLifecycle = lifecycle.units.find(unit => unit.qrc_path.endsWith('/MenuSystemUnits.qml'));
  const originalTimer = factoryLifecycle.timers[0];
  check(originalTimer.id === 'mPostActionTimerId', 'Original factory query timer identity');
  check(originalTimer.bindings.find(binding => binding.property === 'interval').value.value === 50, 'Original query delay');
  const queryCode = factoryLifecycle.functions.find(fn => fn.index ===
    originalTimer.bindings.find(binding => binding.property === 'onTriggered').function_index).bytecode;
  check(JSON.stringify(queryCode.filter(op => op.references && op.references.index)
    .map(op => op.references.index).slice(0, 2)) === JSON.stringify(['mEventHandleId', 'item']), 'Original inquiry target');
  check(queryCode.some(op => op.name === 'CallPropertyLookup' && op.references.lookupIndex === 'systemInquire' && op.args.argc === 0), 'Original inquiry has no arguments');
  const rootCode = factoryLifecycle.functions.find(fn => fn.index === factoryLifecycle.root_completion_function).bytecode;
  check(rootCode.some(op => op.references && op.references.index === 'mPostActionTimerId') &&
    rootCode.some(op => op.name === 'CallPropertyLookup' && op.references.lookupIndex === 'restart' && op.args.argc === 0), 'Original completion starts the timer');
  check(unitLifecycle.timer_count === 0 && !unitLifecycle.functions.find(fn =>
    fn.index === unitLifecycle.root_completion_function).bytecode.some(op => op.name.startsWith('Call')), 'Original Units completion sends no query');
  report.lifecycle_contract = {factory: {delay_ms: 50, repeat: false,
    start: 'Root Component.onCompleted calls mPostActionTimerId.restart()',
    target: 'mEventHandleId.item.systemInquire()', arguments: [],
    timer_anchor: 'qrc:/Trucks/menu/system/factory/FactoryGenericSetup.qml:381',
    call_anchor: 'qrc:/Trucks/menu/system/factory/FactoryGenericSetup.qml:385',
    start_anchor: 'qrc:/Trucks/menu/system/factory/FactoryGenericSetup.qml:391'},
    units: {timer_count: 0, root_completion: 'No operation',
      view_completion: 'Set preferredHighlightBegin=1, preferredHighlightEnd=0.1, mCompleted=1, and currentIndex=0.',
      anchor: 'qrc:/Trucks/menu/system/MenuSystemUnits.qml:232'},
    boundary: 'Source callback replay verifies the command target and schedule request. Qt owns actual timer scheduling.'};
  const queryCalls = [];
  let queryStarts = 0;
  const factory = methods(factoryText, {mPressed: 0,
    mFactoryRows: {currentIndex: 0, count: 20},
    mGlobalId: {item: {menuSettingsPageIndex: 1, menuSettingsSubPageItemSetup:5, setFactory(index) { factory.calls.push(index); }}},
    mPostActionTimerId: {restart() { queryStarts++; }},
    mEventHandleId: {item: {systemInquire(...args) { queryCalls.push(args); }}},
    calls: []});
  const timerMatch = factoryText.match(/\bTimer\s*\{/);
  check(Boolean(timerMatch), 'Factory preserves the vendor startup query timer');
  const timerBlock = declaration('function callback() ' + factoryText.slice(timerMatch.index + 5), 'callback');
  check(/\bid:\s*mPostActionTimerId\b/.test(timerBlock) && /\binterval:\s*50\b/.test(timerBlock), 'Factory timer identity and 50 ms delay');
  check(!/\brepeat:\s*true\b/.test(timerBlock) && !/\brunning:\s*true\b/.test(timerBlock), 'Factory timer starts only through completion');
  factory.mFactoryRows.currentIndex = 19;
  vm.runInContext(handler(factoryText, 'Component.onCompleted:'), factory);
  check(factory.mFactoryRows.currentIndex === 0, 'Factory opens on the first setting');
  check(queryStarts === 1 && queryCalls.length === 0, 'Factory completion schedules one delayed query');
  vm.runInContext(handler(timerBlock, 'onTriggered:'), factory);
  check(queryCalls.length === 1 && queryCalls[0].length === 0, 'Factory timer calls the original inquiry without arguments');
  for (let index = 0; index < 19; index++) {
    factory.mFactoryRows.currentIndex = index;
    factory.key_enter(1); factory.key_enter(2);
    check(factory.calls.length === index, 'Factory press/hold must not change a value');
    factory.key_enter(0);
    check(factory.calls[index] === index, 'Factory index ' + index);
  }
  factory.mFactoryRows.currentIndex = 19;
  factory.key_enter(0);
  check(factory.mGlobalId.item.menuSettingsSubPageItemSetup === 0, 'General settings Back row returns to the catalog');
  for (const name of ['key_back', 'key_left']) {
    factory.mGlobalId.item.menuSettingsSubPageItemSetup = 5;
    factory[name](1); factory[name](2);
    check(factory.mGlobalId.item.menuSettingsSubPageItemSetup === 5, name + ' press/hold');
    factory[name](0);
    check(factory.mGlobalId.item.menuSettingsSubPageItemSetup === 0, name + ' release');
  }
  factory.mFactoryRows.currentIndex = 0; factory.key_up(0);
  check(factory.mFactoryRows.currentIndex === 19, 'Factory wrap up');
  factory.key_down(0);
  check(factory.mFactoryRows.currentIndex === 0, 'Factory wrap down');
  check(!/Passwd|FactoryOdo|FactoryShell|setUpdate|setOdo|setShell/.test(factoryText), 'Normal factory scope');
  check(/mFactoryItems\[index\]/.test(factoryText) && /mFactoryItemsState\[index\]/.test(factoryText), 'Reuse vendor rows');

  // Reuse the existing decoded-instruction runner, without replaying unrelated cases.
  const runnerText = fs.readFileSync(path.join(base, 'tests/unit-state-replay.cjs'), 'utf8');
  const vendorMenu = JSON.parse(fs.readFileSync(path.join(fixtures, 'menu-system-units-key-enter.json')));
  const vendorEnter = vm.runInNewContext('(' + declaration(runnerText, 'enter') + ')', {
    menu: vendorMenu.functions.find(fn => fn.name === 'key_enter'), Number});
  const vendorFactory = JSON.parse(fs.readFileSync(path.join(fixtures, 'factory-generic-key-enter.json')));
  const originalFactoryEnter = vm.runInNewContext('(' + declaration(runnerText, 'enter') + ')', {
    menu: vendorFactory.functions.find(fn => fn.name === 'key_enter'), Number});
  const originalFactory = {Number, mPressed: 0, calls: [], mMenuBackId: {mIndex: 100},
    mMenuFuncId: {currentIndex: 0, itemAt(index) { return {mIndex: index === 19 ? 100 : index}; }},
    mGlobalId: {item: {menuSettingsPageIndex: 1, menuSettingsSubPageItemSetup: 5,
      setFactory(index) { originalFactory.calls.push(index); }}}};
  for (let index = 0; index < 19; index++) {
    originalFactory.mMenuFuncId.currentIndex = index; originalFactoryEnter(originalFactory);
    check(originalFactory.calls[index] === factory.calls[index], 'Vendor factory setter parity');
  }
  originalFactory.mMenuFuncId.currentIndex = 19; originalFactoryEnter(originalFactory);
  check(originalFactory.mGlobalId.item.menuSettingsPageIndex === 1 &&
    originalFactory.mGlobalId.item.menuSettingsSubPageItemSetup === 0, 'Original factory Back keeps the gate parent page');
  const modeBytes = fs.readFileSync(path.join(fixtures, 'mode-key-functions.json'));
  const modeHash = crypto.createHash('sha256').update(modeBytes).digest('hex');
  check(modeHash === 'f143b3ecbf011dd3427f1444b11383fe00ba8ec2cb3b6a2f68f425cacce68d3c', 'Mode fixture SHA-256');
  const modeFixture = JSON.parse(modeBytes);
  const runnerSource = declaration(runnerText, 'enter');
  const modeRunnerSource = runnerSource.replace('const regs = {6: 0};', 'const regs = {6: scope.replayState};');
  check(modeRunnerSource !== runnerSource, 'Mode runner accepts the replay event state');
  const modeSequences = [[0], [1, 0], [1, 2, 0], [1, 2, 2, 0], [1, 2, 2, 2, 0],
    [1, 2, 2, 2, 2, 0], [1, 2, 3, 0], [1, 2, 2, 0, 1, 0]];
  report.mode_key_replay = [];
  for (const kind of ['factory', 'units']) {
    const unit = modeFixture.units.find(unit => unit.qrc_path ===
      (kind === 'factory' ? vendorFactory.qrc_path : vendorMenu.qrc_path));
    check(Boolean(unit), 'Mode unit identity ' + kind);
    check(unit.compiled_unit_sha256 === (kind === 'factory' ? vendorFactory : vendorMenu).compiled_unit_sha256,
      'Mode unit matches the Enter fixture');
    const runMode = vm.runInNewContext('(' + modeRunnerSource + ')', {menu: unit.functions[0]});
    for (const sequence of modeSequences) {
      const actions = [];
      const vendorActions = [];
      const candidate = kind === 'factory' ? methods(factoryText, {
        mPressed: 0, calls: [], value: false, mFactoryRows: {currentIndex: 0, count: 20},
        mGlobalId: {item: {setFactory(index) { candidate.calls.push(index); candidate.value = !candidate.value; }}}
      }) : methods(unitText, unitScope());
      const vendor = kind === 'factory' ? {
        Number, mPressed: 0, calls: [], value: false, mMenuBackId: {mIndex: 100},
        mMenuFuncId: {currentIndex: 0, count: 20, itemAt(index) { return {mIndex: index}; }},
        mGlobalId: {item: {setFactory(index) { vendor.calls.push(index); vendor.value = !vendor.value; }}}
      } : unitScope();
      const view = kind === 'factory' ? candidate.mFactoryRows : candidate.mSystemUnitId;
      const vendorView = kind === 'factory' ? vendor.mMenuFuncId : vendor.mSystemUnitId;
      view.currentIndex = vendorView.currentIndex = kind === 'factory' ? 0 : 1;
      const enterMethod = candidate.key_enter;
      const downMethod = candidate.key_down;
      candidate.key_enter = state => { actions.push(['enter', state, view.currentIndex]); return enterMethod(state); };
      candidate.key_down = state => { actions.push(['down', state, view.currentIndex]); return downMethod(state); };
      vendor.key_enter = state => {
        vendorActions.push(['enter', state, vendorView.currentIndex]);
        return (kind === 'factory' ? originalFactoryEnter : vendorEnter)(vendor);
      };
      vendor.key_down = state => {
        vendorActions.push(['down', state, vendorView.currentIndex]);
        if (state === 0) vendorView.currentIndex = (vendorView.currentIndex + 1) % vendorView.count;
        return state === 0 ? 1 : 0;
      };
      for (const state of sequence) {
        candidate.key_modes(state); vendor.replayState = state; runMode(vendor);
        check(JSON.stringify(actions) === JSON.stringify(vendorActions), 'Mode action parity ' + kind);
        check(view.currentIndex === vendorView.currentIndex, 'Mode selection parity ' + kind);
        check(JSON.stringify(candidate.calls) === JSON.stringify(vendor.calls), 'Mode mutation parity ' + kind);
        if (kind === 'factory') check(candidate.value === vendor.value, 'Factory repeated toggle parity');
        else for (const key of ['metricSystem', 'temperatureUnit']) {
          check(Number(candidate.mGlobalId.item[key]) === Number(vendor.mGlobalId.item[key]), 'Units repeated toggle parity');
        }
      }
      report.mode_key_replay.push({page: kind, sequence, parity: 'passed',
        activations: actions.filter(action => action[0] === 'enter').length,
        advances: actions.filter(action => action[0] === 'down').length});
    }
  }
  report.mode_key_fixture = {path: 'evidence/fixtures/capture-04/mode-key-functions.json',
    export_bytes: modeBytes.length, export_sha256: modeHash,
    recipe: 'Select key_modes from FactoryGenericSetup and MenuSystemUnits. Retain unit qrc path and SHA-256, function index, name, source location, code offset, code SHA-256, and resolved bytecode. Omit all other functions and string tables.',
    sources: [{source: 'analysis/capture-04/qml-cache/085-Trucks_menu_system_factory_FactoryGenericSetup.qml.json',
      source_sha256: '6b19ec3407da3cfa8c33c17d03df401ca851ce81ada40a79d3d137ef9195560c'},
    {source: 'analysis/capture-04/qml-cache/073-Trucks_menu_system_MenuSystemUnits.qml.json',
      source_sha256: 'f6efb07133345d7aa9b4bc9bfe3a51db345719d9c3d0742debd5f1994e71ea33'}]};
  report.mode_key_limit = 'Repeated state-2 events activate repeatedly, then state-0 advances, matching vendor functions. Native event repetition and release suppression remain unverified. No debounce change was made.';
  const speedLabels = factoryText.match(/\["200",\s*"210",\s*"240",\s*"260",\s*"290"\]/);
  check(Boolean(speedLabels), 'Factory row-seven labels match decoded vendor binding');
  const stateArray = vendorFactory.translation_state_array;
  const stateProperties = [...stateArray.expression.matchAll(/mGlobalId\.item\.(\w+)/g)].map(match => match[1]);
  check(stateProperties.length === 19, 'Decoded Translation supplies 19 factory states');
  check(stateProperties[7] === 'mLc76VehicleSpeedMaxIndex', 'Row seven uses the vendor maximum-speed index');
  for (const row of vendorFactory.state_bindings) {
    const expectedExpression = row.row === 7 ? 'mSpeedMaxIndex[mGlobalId.item.mLc76VehicleSpeedMaxIndex]' :
      'mTranslationId.item.mFactoryItemsState[' + row.row + ']';
    check(row.expression === expectedExpression, 'Original state source for factory row ' + row.row);
  }
  check(factoryText.includes('mFactoryItemsState[index]'), 'Candidate reuses the original Translation state array');
  report.factory_state_reconciliation = {rows: 19, source: stateArray.source,
    source_sha256: stateArray.source_sha256, compiled_unit_sha256: stateArray.compiled_unit_sha256,
    function_index: stateArray.function_index, code_sha256: stateArray.code_sha256,
    row7_state_property: stateProperties[7], result: 'All row state sources match vendor bindings.'};
  report.factory_vendor_evidence = {authority: 'One-time decoded binding review; row-seven labels also checked by portable source replay',
    unit: vendorFactory.qrc_path, compiled_unit_sha256: vendorFactory.compiled_unit_sha256,
    source_metadata_sha256: '6b19ec3407da3cfa8c33c17d03df401ca851ce81ada40a79d3d137ef9195560c',
    source_metadata: 'analysis/capture-04/qml-cache/085-Trucks_menu_system_factory_FactoryGenericSetup.qml.json',
    row_objects: '2 through 20 are settings; object 21 is Back', settings: 19, back: 1,
    widgets: {switches: 18, selectors: 1, back: 1},
    model_visibility: 'No row visible/enabled bindings, model references, or removeItem/takeItem calls occur in the decoded unit.',
    row7: {labels: [200, 210, 240, 260, 290], labels_anchor: 'qrc:/Trucks/menu/system/factory/FactoryGenericSetup.qml:128',
      data_binding: 'mSpeedMaxIndex[mGlobalId.item.mLc76VehicleSpeedMaxIndex]', data_anchor: 'qrc:/Trucks/menu/system/factory/FactoryGenericSetup.qml:207'},
    differences: ['Candidate uses 19 MenuSetupButton controls instead of 18 switches and one selector. Current boolean values use ON/OFF text.'],
    startup_query: 'The candidate preserves the original delayed, one-shot systemInquire call. Source lifecycle replay checks the target, empty arguments, delay, and completion trigger.',
    regression_result: 'No setting-count, model-filter, row-seven-label, or startup-query regression found. The widget presentation difference remains explicit.'};
  for (let model = 0; model < 9; model++) {
    for (let row = 0; row < 4; row++) {
      for (let value = 0; value < (row === 3 ? 4 : row === 0 ? 3 : 2); value++) {
        const source = methods(unitText, unitScope(model));
        const vendor = unitScope(model);
        const key = ['consumptionUnit', 'metricSystem', 'temperatureUnit', 'pressureUnit'][row];
        source.mGlobalId.item[key] = vendor.mGlobalId.item[key] = value;
        source.mSystemUnitId.currentIndex = vendor.mSystemUnitId.currentIndex = row;
        source.key_enter(1); source.key_enter(2);
        check(source.calls.length === 0 && source.mGlobalId.item[key] === value, 'No unit press/hold mutation');
        source.key_enter(0); vendorEnter(vendor);
        for (const stateKey of ['consumptionUnit', 'metricSystem', 'temperatureUnit', 'pressureUnit']) {
          check(Number(source.mGlobalId.item[stateKey]) === Number(vendor.mGlobalId.item[stateKey]), 'Vendor parity ' + stateKey);
        }
        check(JSON.stringify(source.calls) === JSON.stringify(vendor.calls), 'Native call parity');
        if (row === 1 || row === 2) {
          check(source.mGlobalId.item[row === 1 ? 'speedUnitOverride' : 'tempUnitOverride'] === 1, 'Manual before native command');
        }
      }
    }
  }
  const units = methods(unitText, unitScope());
  check(!/\bTimer\s*\{/.test(unitText), 'Units preserves the original timer-free startup');
  check(unitText.includes('Component.onCompleted:'), 'Units completion selection hook');
  units.mSystemUnitId.currentIndex = 5;
  vm.runInContext(handler(unitText, 'Component.onCompleted:'), units);
  check(units.mSystemUnitId.currentIndex === 0, 'Units opens on the first setting');
  check(units.unitData(1).endsWith('Follow') && units.unitData(2).endsWith('Follow'), 'Initial Follow state');
  units.mSystemUnitId.currentIndex = 1; units.key_enter(0);
  check(units.unitData(1).endsWith('Manual') && units.unitData(2).endsWith('Follow'), 'Independent distance state');
  units.mSystemUnitId.currentIndex = 2; units.key_enter(0);
  check(units.unitData(1).endsWith('Manual') && units.unitData(2).endsWith('Manual'), 'Independent temperature state');
  const eventText = fs.readFileSync(path.join(pages, 'common/VehicleEvent.qml'), 'utf8');
  const nativeWrites = [];
  const eventScope = methods(eventText.slice(eventText.indexOf('function followVehicleUnits()'),
    eventText.indexOf('function setVehicleColor(')), {mGlobalId: units.mGlobalId,
    mHandleId: {getTripUnit: () => 0, getTempUnit: () => 1, getTime24h: () => 0,
      setUnit2(...args) { nativeWrites.push(args); }}});
  let follows = 0;
  units.mEventHandleId.item.followVehicleUnits = () => { follows++; eventScope.followVehicleUnits(); };
  units.mSystemUnitId.currentIndex = 4; units.key_enter(0);
  check(follows === 1 && nativeWrites.length === 0, 'Follow uses one wrapper call without native writes');
  check(units.mGlobalId.item.metricSystem === 0 && units.mGlobalId.item.temperatureUnit === 1,
    'Follow restores native values');
  check(units.unitData(1).endsWith('Follow') && units.unitData(2).endsWith('Follow'), 'Follow state restored');
  const local = methods(unitText, unitScope(1, 0));
  for (let row = 0; row < 5; row++) { local.mSystemUnitId.currentIndex = row; local.key_enter(0); }
  check(local.calls.length === 0, 'No native calls when vehicle unit sync is absent');
  check(local.unitData(1).endsWith('Manual') && local.unitData(2).endsWith('Manual'), 'No false Follow state');
  for (const model of [-1, 9, 10, 'unsupported']) {
    const source = methods(unitText, unitScope(model));
    check(!source.supportedModel(), 'Unsupported model ' + model);
    for (let row = 0; row < 5; row++) { source.mSystemUnitId.currentIndex = row; source.key_enter(0); }
    check(source.calls.length === 0, 'Unsupported model sends no commands');
  }
  units.mSystemUnitId.currentIndex = 0; units.key_up(0);
  check(units.mSystemUnitId.currentIndex === 5, 'Units wrap up');
  units.key_down(0);
  check(units.mSystemUnitId.currentIndex === 0, 'Units wrap down');
  units.mSystemUnitId.currentIndex = 5; units.key_enter(0);
  check(units.mGlobalId.item.menuSettingsPageIndex === 0, 'Units Back row');
  for (const name of ['key_back', 'key_left']) {
    units.mGlobalId.item.menuSettingsPageIndex = 1;
    units[name](1); units[name](2);
    check(units.mGlobalId.item.menuSettingsPageIndex === 1, 'Units press/hold stays open');
    units[name](0);
    check(units.mGlobalId.item.menuSettingsPageIndex === 0, 'Units return on release');
  }
  for (const page of [factory, units]) {
    const view = page === factory ? page.mFactoryRows : page.mSystemUnitId;
    view.currentIndex = 0; page.key_modes(0);
    check(view.currentIndex === 1, 'Modes release advances');
    const before = page.calls.length;
    page.key_modes(2);
    check(page.calls.length === before + 1, 'Modes hold activates');
  }
  check(unitText.includes('Unit controls unavailable for this vehicle model'), 'Unsupported reason visible');
  check(unitText.includes('Follow vehicle units') && unitText.includes('MenuSetupButton'), 'Follow action uses vendor style');
  const system = JSON.parse(fs.readFileSync(path.join(fixtures, 'system-settings-loaders.json')));
  report.integration = [
    ['qrc:/Trucks/menu/system/MenuSystemFactory.qml', 'file:/etc/vnF.qml'],
    ['qrc:/Trucks/menu/system/MenuSystemUnits.qml', 'file:/etc/vnU.qml']
  ].map(([original, replacement]) => {
    const record = system.strings.find(record => record.value === original);
    check(Boolean(record), 'Decoded loader metadata record');
    check(replacement.length === 17, 'Written loader URI has 17 UTF-16 units');
    return {unit: system.qrc_path, string_index: record.index, record_file_offset: record.file_offset,
      verification: 'Reduced decoded metadata only; original Launcher bytes are not checked here.',
      length_file_offset: record.file_offset + 4, text_file_offset: record.file_offset + 24, original, replacement,
      replacement_length_utf16_units: replacement.length,
      replacement_utf16_hex: Buffer.from(replacement, 'utf16le').toString('hex'),
      replacement_utf16_bytes: Buffer.from(replacement, 'utf16le').length,
      original_utf16_bytes: Buffer.from(original, 'utf16le').length};
  });
  report.pages = ['vnF.qml', 'vnB.qml', 'vnU.qml'].map(name => ({path: 'patches/capture-04/etc/' + name,
    sha256: crypto.createHash('sha256').update(fs.readFileSync(path.join(pages, name))).digest('hex')}));
  report.source_verification = 'passed';
} catch (error) {
  report.failure = error.message;
  process.exitCode = 1;
} finally {
  report.cases = cases;
  fs.mkdirSync(path.dirname(reportPath), {recursive: true});
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify({status: report.source_verification, cases, report: reportPath,
    ...(report.failure ? {failure: report.failure} : {})}));
}
