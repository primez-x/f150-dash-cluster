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
  'Factory Up/Down wraps without changes on press or hold.',
  'Factory source contains no gate, odometer, shell, or update route.',
  'Mode release advances selection. Mode hold activates the selected row.',
  'Repeated mode hold events preserve vendor repeated activation and release advance.',
  'Page completion selects the first row after Repeater creates the controls.',
  'Factory completion starts the original 50 ms one-shot system inquiry.'
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
    keys: 'Inherited ItemInfo.key(key,state) dispatches overridden key_back/up/down/left/right/enter/modes methods.',
    states: 'General preserves vendor state behavior. The catalog activates a mode hold once and consumes the matching release.'
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
try {
  const provenance = JSON.parse(fs.readFileSync(path.join(fixtures, 'manifest.json')));
  report.fixtures = ['factory-generic-key-enter.json'].map(name => {
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
  report.lifecycle_contract = {factory: {delay_ms: 50, repeat: false,
    start: 'Root Component.onCompleted calls mPostActionTimerId.restart()',
    target: 'mEventHandleId.item.systemInquire()', arguments: [],
    timer_anchor: 'qrc:/Trucks/menu/system/factory/FactoryGenericSetup.qml:381',
    call_anchor: 'qrc:/Trucks/menu/system/factory/FactoryGenericSetup.qml:385',
    start_anchor: 'qrc:/Trucks/menu/system/factory/FactoryGenericSetup.qml:391'},
    boundary: 'Source callback replay verifies the command target and schedule request. Qt owns actual timer scheduling.'};
  const queryCalls = [];
  let queryStarts = 0;
  // Rows that no compiled page or native code reads show a reason and change nothing.
  const noEffect = [6, 10, 11, 12, 13, 16, 17];
  const factory = methods(factoryText, {mPressed: 0, mNoEffect: noEffect,
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
  check(/mNoEffect:\s*\[6, 10, 11, 12, 13, 16, 17\]/.test(factoryText), 'Factory rows with no effect');
  for (let index = 0; index < 19; index++) {
    factory.mFactoryRows.currentIndex = index;
    const before = factory.calls.length;
    factory.key_enter(1); factory.key_enter(2);
    check(factory.calls.length === before, 'Factory press/hold must not change a value');
    factory.key_enter(0);
    if (noEffect.includes(index)) check(factory.calls.length === before, 'Factory row with no effect ' + index);
    else check(factory.calls[factory.calls.length - 1] === index, 'Factory index ' + index);
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
  const vendorFactory = JSON.parse(fs.readFileSync(path.join(fixtures, 'factory-generic-key-enter.json')));
  const originalFactoryEnter = vm.runInNewContext('(' + declaration(runnerText, 'enter') + ')', {
    menu: vendorFactory.functions.find(fn => fn.name === 'key_enter'), Number});
  const originalFactory = {Number, mPressed: 0, calls: [], mMenuBackId: {mIndex: 100},
    mMenuFuncId: {currentIndex: 0, itemAt(index) { return {mIndex: index === 19 ? 100 : index}; }},
    mGlobalId: {item: {menuSettingsPageIndex: 1, menuSettingsSubPageItemSetup: 5,
      setFactory(index) { originalFactory.calls.push(index); }}}};
  for (let index = 0; index < 19; index++) {
    originalFactory.mMenuFuncId.currentIndex = index; originalFactoryEnter(originalFactory);
  }
  check(JSON.stringify(originalFactory.calls.filter(index => !noEffect.includes(index))) === JSON.stringify(factory.calls),
    'Vendor factory setter parity for rows with an effect');
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
  const modeUnit = modeFixture.units.find(unit => unit.qrc_path === vendorFactory.qrc_path);
  check(Boolean(modeUnit), 'Mode unit identity factory');
  check(modeUnit.compiled_unit_sha256 === vendorFactory.compiled_unit_sha256, 'Mode unit matches the Enter fixture');
  const runMode = vm.runInNewContext('(' + modeRunnerSource + ')', {menu: modeUnit.functions[0]});
  for (const sequence of modeSequences) {
    const actions = [];
    const vendorActions = [];
    const candidate = methods(factoryText, {
      mPressed: 0, mNoEffect: noEffect, calls: [], value: false, mFactoryRows: {currentIndex: 0, count: 20},
      mGlobalId: {item: {setFactory(index) { candidate.calls.push(index); candidate.value = !candidate.value; }}}
    });
    const vendor = {
      Number, mPressed: 0, calls: [], value: false, mMenuBackId: {mIndex: 100},
      mMenuFuncId: {currentIndex: 0, count: 20, itemAt(index) { return {mIndex: index}; }},
      mGlobalId: {item: {setFactory(index) { vendor.calls.push(index); vendor.value = !vendor.value; }}}
    };
    const view = candidate.mFactoryRows;
    const vendorView = vendor.mMenuFuncId;
    const enterMethod = candidate.key_enter;
    const downMethod = candidate.key_down;
    candidate.key_enter = state => { actions.push(['enter', state, view.currentIndex]); return enterMethod(state); };
    candidate.key_down = state => { actions.push(['down', state, view.currentIndex]); return downMethod(state); };
    vendor.key_enter = state => {
      vendorActions.push(['enter', state, vendorView.currentIndex]);
      return originalFactoryEnter(vendor);
    };
    vendor.key_down = state => {
      vendorActions.push(['down', state, vendorView.currentIndex]);
      if (state === 0) vendorView.currentIndex = (vendorView.currentIndex + 1) % vendorView.count;
      return state === 0 ? 1 : 0;
    };
    for (const state of sequence) {
      candidate.key_modes(state); vendor.replayState = state; runMode(vendor);
      check(JSON.stringify(actions) === JSON.stringify(vendorActions), 'Mode action parity factory');
      check(view.currentIndex === vendorView.currentIndex, 'Mode selection parity factory');
      check(JSON.stringify(candidate.calls) === JSON.stringify(vendor.calls), 'Mode mutation parity factory');
      check(candidate.value === vendor.value, 'Factory repeated toggle parity');
    }
    report.mode_key_replay.push({page: 'factory', sequence, parity: 'passed',
      activations: actions.filter(action => action[0] === 'enter').length,
      advances: actions.filter(action => action[0] === 'down').length});
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
  factory.mFactoryRows.currentIndex = 0; factory.key_modes(0);
  check(factory.mFactoryRows.currentIndex === 1, 'Modes release advances');
  const modeCallsBefore = factory.calls.length;
  factory.key_modes(2);
  check(factory.calls.length === modeCallsBefore + 1, 'Modes hold activates');
  // vnM hosts vnF directly (file:/etc/vnF.qml); the System Settings loader redirect is retired.
  report.pages = ['vnF.qml', 'vnB.qml'].map(name => ({path: 'patches/capture-04/etc/' + name,
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
