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
  'Factory is a native vnM page with one shell inquiry on entry.',
  'General settings shows the 19 vendor rows, sends the vendor setter for rows with an effect, and shows a reason for the rest.',
  'General settings runs the original system inquiry once on entry, without arguments.',
  'Compiled Factory pages open on release and return to the Factory row with their compiled Back values.',
  'ADB, Debug logging, USB image preview, Car model options, and Screen grid send the vendor values.',
  'Factory code contains no vendor code gate and loads no retired Factory file.',
  'Display > Dashboard layout offers two segments, Daily and Towing; OK switches the layout and a Tow/Haul choice shows a note.'
];
const report = {schema_version: 2, authority: 'PC source and reduced decoded vendor metadata replay',
  command: 'node tests/settings-menu-replay.cjs', expected_cases: expected,
  source_verification: 'failed', qt_verification: 'Root owns Qt 5.14.2 checks.',
  vehicle_verification: 'Not run', cases: 0,
  page_contracts: {
    factory: {owner: 'patches/capture-04/etc/vnM.qml', page: 'factory',
      controls: 'General settings, five compiled setup pages, ADB, Debug logging, USB image preview, Screen grid, Car model options',
      return: 'Back returns to System'},
    general: {owner: 'patches/capture-04/etc/vnM.qml', page: 'general', controls: '19 vendor rows',
      setter: 'mGlobalId.item.setFactory(index)', context: ['mGlobalId', 'mTranslationId']},
    compiled_pages: 'vnM hosts FactorySeniorSetting, FactoryOdoSetup, FactoryTankSetup, FactoryVehicleModel, and FactoryShellCmd by menuSettingsSubPageItemSetup.',
    keys: 'vnM key(code,state) acts on release. Qt owns the press, hold, and Modes checks.'
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
  const menuText = fs.readFileSync(path.join(pages, 'vnM.qml'), 'utf8');
  check(!/mFactoryPasswd|mPasswdSelect|PasswdTumber|key_enter_hold/.test(menuText), 'Factory page contains no vendor code gate');
  check(!/vnF\.qml|vnB\.qml/.test(menuText.replace(/\/\/.*$/gm, '')), 'Menu code loads no retired Factory file');
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
  report.lifecycle_contract = {factory: {original_delay_ms: 50, candidate: 'vnM.openPage("general") calls the inquiry once on entry',
    target: 'mEventHandleId.item.systemInquire()', arguments: [],
    timer_anchor: 'qrc:/Trucks/menu/system/factory/FactoryGenericSetup.qml:381',
    call_anchor: 'qrc:/Trucks/menu/system/factory/FactoryGenericSetup.qml:385'},
    boundary: 'Source replay verifies the command target and arguments. The 50 ms delay of the original page is not kept.'};

  // vnM engine in a VM. Property bindings and Connections handlers are read from vnM.qml and run as getters and setters.
  const binding = name => {
    const match = new RegExp('readonly property \\w+ ' + name + ': ').exec(menuText);
    assert.ok(match, 'Missing binding ' + name);
    const lines = menuText.slice(match.index + match[0].length).split('\n');
    let expression = lines[0];
    // Continuation lines are indented deeper than the property, or close a bracket at the property indent.
    for (let i = 1; i < lines.length && (/^\s{5,}\S/.test(lines[i]) || /^\s{4}[\])}]/.test(lines[i])); i++) expression += '\n' + lines[i];
    return expression;
  };
  const literal = name => vm.runInNewContext('(' + binding(name) + ')');
  const noEffect = literal('mFactoryNoEffect');
  check(JSON.stringify(noEffect) === JSON.stringify([6, 10, 11, 12, 13, 16, 17]), 'Factory rows with no effect');
  const titles = Array.from({length: 19}, (unused, index) => 'Setting ' + index);
  let states = Array(19).fill(0);
  const calls = [];
  const log = [];
  const g = {menuBarIndex: 1, language: 0, gpsAutoSetRtcEnabled: 0, getRtcTime() { return '12:00'; }, getAmPm() { return ''; },
    uartDebugEnabled: 0, mediaImageEnabled: 0, modelCarSelection: false, screenGridEnabled: 0,
    fordSetupInfoChanged: false, mainTentChanged: false, swcUp: 1, swcDown: 2, swcBack: 3, swcLeft: 4, swcEnter: 5, swcRight: 6,
    swcModes: 7, setFactory(index) { calls.push(index); states[index] = index === 7 ? (states[index] + 1) % 5 : (states[index] ? 0 : 1); }};
  const e = {systemInquire(...args) { log.push(['systemInquire', ...args]); },
    shellCmdInquire(...args) { log.push(['shellCmdInquire', ...args]); }, adb(value) { log.push(['adb', value]); }};
  const timer = {stop() {}, restart() {}};
  const menu = methods(menuText, {Number, String, Math, mTrucksModel: 1,
    mGlobalId: {item: g}, mTranslationId: {item: {mSystemLanguages: ['English'], mFactoryItems: titles, get mFactoryItemsState() { return states; }}},
    mEventHandleId: {item: e}, mArmTimer: timer, mSentTimer: timer, mFordReadBack: timer, mServiceReadBack: timer,
    mPath: ['home', 'system', 'factory'], mCursors: [1, 5], mCursor: 0, mPressed: false, mHeldKey: -1, mEditing: false,
    mEditValue: 0, mEditStart: 0, mEditFields: [], mEditField: 0, mArmedRow: -1, mSentRow: -1, mFactoryEntry: 0,
    mFactoryNoEffect: noEffect, mDebugLevels: literal('mDebugLevels'), mDebugTexts: literal('mDebugTexts'),
    mFactoryUrls: literal('mFactoryUrls'), mTitles: literal('mTitles')});
  for (const name of ['mPage', 'mRows', 'mFocusRow', 'mHostedUrl']) {
    const expression = binding(name);
    Object.defineProperty(menu, name, {get() { return vm.runInContext(expression, menu); }});
  }
  for (const name of ['menuSettingsPageIndex', 'menuSettingsSubPageItemSetup']) {
    const body = handler(menuText, 'on' + name[0].toUpperCase() + name.slice(1) + 'Changed:');
    let current = 0;
    Object.defineProperty(g, name, {get() { return current; },
      set(next) { if (next !== current) { current = next; vm.runInContext(body, menu); } }});
  }
  const open = title => {
    menu.mCursor = menu.mRows.findIndex(row => row.title === title);
    assert.ok(menu.mCursor >= 0, 'Missing row ' + title);
    menu.release(g.swcEnter);
  };
  const factoryTitles = ['General settings', 'Advanced settings', 'Fuel tank setup', 'Vehicle profile', 'Odometer setup',
    'Service commands', 'ADB debugging: enable', 'ADB debugging: disable', 'Debug logging', 'USB image preview', 'Screen grid',
    'Car model options'];
  check(JSON.stringify(menu.mRows.map(row => row.title)) === JSON.stringify(factoryTitles), 'Factory rows and order');
  menu.closePage();
  check(menu.mPage === 'system', 'Factory Back returns to System');
  open('Factory');
  check(menu.mPage === 'factory' && JSON.stringify(log) === JSON.stringify([['shellCmdInquire']]), 'Factory entry runs one shell inquiry');
  check(g.menuSettingsPageIndex === 0 && g.menuSettingsSubPageItemSetup === 0, 'Factory is a native page');

  // General settings.
  log.length = 0;
  open('General settings');
  check(menu.mPage === 'general' && JSON.stringify(log) === JSON.stringify([['systemInquire']]), 'General entry runs one system inquiry without arguments');
  const general = menu.mRows;
  check(general.length === 19 && general.every((row, index) => row.title === titles[index]), 'General shows the 19 vendor rows');
  for (let index = 0; index < 19; index++) {
    const row = general[index];
    if (noEffect.includes(index)) check(row.kind === 'unavailable' && row.value === 'No effect in this firmware', 'General row with no effect ' + index);
    else check(row.kind === 'toggle' && row.op === 'factory' && row.arg === index, 'General row ' + index);
  }
  check(general[7].value === '200' && general[7].current === undefined && general[0].value === 'Off' && general[0].current === 0, 'General start values');
  check(/\["200", "210", "240", "260", "290"\]/.test(menuText), 'General row-seven labels match the decoded vendor binding');
  for (let index = 0; index < 19; index++) {
    menu.mCursor = index;
    const before = calls.length;
    menu.release(g.swcEnter);
    if (noEffect.includes(index)) check(calls.length === before, 'General row with no effect sends nothing ' + index);
    else check(calls[calls.length - 1] === index, 'General setter index ' + index);
  }
  check(menu.mRows[0].value === 'On' && menu.mRows[0].current === 1 && menu.mRows[7].value === '210', 'General rows follow the setting');
  menu.mCursor = 0;
  menu.release(g.swcUp);
  check(menu.mCursor === 18, 'General Up wraps');
  menu.release(g.swcDown);
  check(menu.mCursor === 0, 'General Down wraps');
  menu.release(g.swcBack);
  check(menu.mPage === 'factory' && menu.mCursor === 0, 'General Back returns to the Factory row');

  // Reuse the existing decoded-instruction runner for the vendor setter parity.
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
  check(JSON.stringify(originalFactory.calls.filter(index => !noEffect.includes(index))) === JSON.stringify(calls),
    'Vendor factory setter parity for rows with an effect');
  const stateArray = vendorFactory.translation_state_array;
  const stateProperties = [...stateArray.expression.matchAll(/mGlobalId\.item\.(\w+)/g)].map(match => match[1]);
  check(stateProperties.length === 19, 'Decoded Translation supplies 19 factory states');
  check(stateProperties[7] === 'mLc76VehicleSpeedMaxIndex', 'Row seven uses the vendor maximum-speed index');
  for (const row of vendorFactory.state_bindings) {
    const expectedExpression = row.row === 7 ? 'mSpeedMaxIndex[mGlobalId.item.mLc76VehicleSpeedMaxIndex]' :
      'mTranslationId.item.mFactoryItemsState[' + row.row + ']';
    check(row.expression === expectedExpression, 'Original state source for factory row ' + row.row);
  }
  check(/t\.mFactoryItemsState/.test(menuText) && /t\.mFactoryItems\[i\]/.test(menuText), 'Candidate reuses the original Translation rows and states');
  report.factory_state_reconciliation = {rows: 19, source: stateArray.source,
    source_sha256: stateArray.source_sha256, compiled_unit_sha256: stateArray.compiled_unit_sha256,
    function_index: stateArray.function_index, code_sha256: stateArray.code_sha256,
    row7_state_property: stateProperties[7], result: 'All row state sources match vendor bindings.'};

  // Compiled Factory pages. Odometer, Fuel tank, and Vehicle profile return with value 1, the others with 0.
  const urls = menu.mFactoryUrls;
  for (const [title, value, back] of [['Advanced settings', 1, 0], ['Fuel tank setup', 3, 1], ['Vehicle profile', 4, 1],
                                      ['Odometer setup', 2, 1], ['Service commands', 6, 0]]) {
    open(title);
    check(menu.mPage === 'fsub' + value && g.menuSettingsSubPageItemSetup === value && g.menuSettingsPageIndex === 1 &&
      menu.mHostedUrl === urls[value] && /^qrc:\/Trucks\/menu\/system\/factory\/Factory\w+\.qml$/.test(urls[value]), 'Compiled page opens ' + title);
    g.menuSettingsSubPageItemSetup = back;
    check(menu.mPage === 'factory' && menu.mRows[menu.mCursor].title === title && g.menuSettingsSubPageItemSetup === 0 &&
      g.menuSettingsPageIndex === 0 && menu.mHostedUrl === '', 'Compiled page Back returns to the Factory row ' + title);
  }
  open('Advanced settings');
  g.menuSettingsSubPageItemSetup = 2;
  check(menu.mPage === 'fsub1' && menu.mHostedUrl === urls[2], 'Advanced settings opens Odometer setup in place');
  g.menuSettingsSubPageItemSetup = 1;
  check(menu.mPage === 'fsub1' && menu.mHostedUrl === urls[1], 'Odometer Back returns to Advanced settings');
  g.menuSettingsSubPageItemSetup = 5;
  check(menu.mPage === 'factory' && g.menuSettingsSubPageItemSetup === 0, 'A page value with no compiled page returns to Factory');
  open('Service commands');
  g.menuSettingsPageIndex = 0;
  check(menu.mPage === 'factory' && g.menuSettingsSubPageItemSetup === 0, 'A compiled page that leaves the settings page returns to Factory');
  open('Vehicle profile');
  menu.closeMenu();
  check(g.menuBarIndex === 0 && menu.mPage === 'factory' && g.menuSettingsSubPageItemSetup === 0 && g.menuSettingsPageIndex === 0,
    'Closing the menu closes a compiled page');
  g.menuBarIndex = 1;

  // Tools.
  for (const [title, value] of [['ADB debugging: enable', 1], ['ADB debugging: disable', 0]]) {
    log.length = 0;
    open(title);
    check(JSON.stringify(log) === JSON.stringify([['adb', value]]), 'ADB command ' + value);
  }
  open('Debug logging');
  check(menu.mEditing && menu.mEditValue === 0, 'Debug logging opens the editor at the current level');
  menu.release(g.swcDown); menu.release(g.swcDown); menu.release(g.swcDown);
  check(g.uartDebugEnabled === 0, 'Debug logging edit sends nothing before OK');
  menu.release(g.swcEnter);
  check(g.uartDebugEnabled === 4 && menu.mFocusRow.value === 'UART transmit', 'Debug logging sets the vendor value');
  g.uartDebugEnabled = 3;
  check(menu.mFocusRow.value === 'Value 3' && menu.mFocusRow.current === -1 && menu.mFocusRow.start === 2, 'Debug logging outside the list');
  menu.release(g.swcEnter); menu.release(g.swcBack);
  check(g.uartDebugEnabled === 3 && !menu.mEditing, 'Debug logging cancel keeps the value');
  g.uartDebugEnabled = 0;
  open('USB image preview');
  check(g.mediaImageEnabled === 1, 'USB image preview on');
  menu.release(g.swcEnter);
  check(g.mediaImageEnabled === 0, 'USB image preview off');
  open('Car model options');
  check(g.modelCarSelection === true && menu.mFocusRow.current === 1, 'Car model options toggle');
  open('Screen grid');
  check(g.screenGridEnabled === 1 && g.menuBarIndex === 0, 'Screen grid shows the grid and closes the menu');
  g.menuBarIndex = 1;

  // Display > Dashboard layout: two segments (Daily, Towing) for Global dashboard 0 and 1. OK switches the layout.
  Object.assign(g, {dashboard: 0, dashboardBeforeTow: -1, towDashboard: 1, overSpeedWarningEnabled: 0, vehicleSpeedUnit: 'mph',
    getOverSpeedWaningSpeed() { return '70'; }, getBrightnessLevel() { return 5; }});
  menu.mPath = ['home', 'display'];
  menu.mCursors = [0];
  const layout = () => menu.mRows.find(row => row.title === 'Dashboard layout');
  check(layout().kind === 'toggle' && JSON.stringify(layout().seg) === JSON.stringify(['Daily', 'Towing']) &&
    layout().current === 0 && layout().value === 'Daily' && layout().note === undefined, 'Layout row shows two segments at Daily');
  open('Dashboard layout');
  check(g.dashboard === 1 && layout().current === 1 && layout().value === 'Towing' && !menu.mEditing, 'Layout OK selects Towing');
  menu.release(g.swcEnter);
  check(g.dashboard === 0 && layout().current === 0, 'Layout OK selects Daily');
  Object.assign(g, {dashboard: 1, dashboardBeforeTow: 0});
  check(layout().current === 1 && layout().value === 'Towing · Tow/Haul' && layout().note === 'Tow/Haul',
    'Layout row notes the Tow/Haul choice');
  menu.release(g.swcEnter);
  check(g.dashboard === 0 && layout().note === undefined, 'Layout choice while towing selects Daily');
  check(!/"Layout "|mLayouts/.test(menuText), 'Menu offers no retired layout numbers');

  report.pages = ['vnM.qml'].map(name => ({path: 'patches/capture-04/etc/' + name,
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
