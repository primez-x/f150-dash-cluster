"""Probe cached main loader URLs with Qt 5.14.2 and private QML fixtures."""
import argparse
import ctypes
import hashlib
import importlib.util
import json
import os
import re
from pathlib import Path
import subprocess
import struct
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
RESULT = ROOT / "analysis/capture-04/qt-ui-loader-results.json"
HOST = ROOT / "analysis/capture-04/qt-host"
MAIN_OFFSET = 39536
MAIN_SIZE = 12308
ORIGINAL_SHA256 = "2451c3fb6f6c1344625aa2882760eaaccd3dc0979ad1296c9028838e77e2823b"
PHASES = ("empty-source-control", "original-vendor-header", "original-adapted", "patched-adapted",
          "patched-settings-adapted", "patched-settings-redirects", "candidate-compile", "settings-pages")


def require(condition, message):
    if not condition:
        raise RuntimeError("QT_PROBE_GUARD: " + str(message))


def deployment_imports(text):
    entries = re.findall(r'^\s*import\s+([^\n]+)', text, re.M)
    for entry in entries:
        quoted = re.match(r'^"([^"\n]+)"(?:\s+as\s+\w+)?\s*$', entry)
        if quoted:
            require(quoted.group(1).startswith("qrc:/"), "Wrapper import must use an absolute qrc URL: " + entry)
        else:
            require(re.fullmatch(r'[A-Za-z_]\w*(?:\.\w+)*(?:\s+\d+\.\d+)?(?:\s+as\s+\w+)?\s*', entry) is not None,
                    "Wrapper import must name a module: " + entry)
    return entries


def child(phase, fixture, candidate_dir=None):
    require(phase in PHASES, 'Probe validation failed: phase in PHASES')
    fixture = fixture.resolve(strict=True)
    require(fixture.is_dir() and fixture.parent == HOST.resolve(strict=True), 'Fixture must resolve to a direct child of qt-host')
    original = (ROOT / "installed/capture-04/rootfs/usr/bin/Launcher").read_bytes()
    require(hashlib.sha256(original).hexdigest() == ORIGINAL_SHA256, 'Probe validation failed: hashlib.sha256(original).hexdigest() == ORIGINAL_SHA256')
    os.environ.update(QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                      QV4_FORCE_INTERPRETER="1",
                      QML_FORCE_DISK_CACHE="1", QML_DISK_CACHE_PATH=str(fixture / "cache"),
                      XDG_CACHE_HOME=str(fixture / "xdg"),
                      XDG_RUNTIME_DIR=str(fixture / "runtime"),
                      QT_LOGGING_RULES="qt.qml.diskcache.debug=true")
    os.environ.pop("QSG_RENDER_LOOP", None)
    (fixture / "runtime").mkdir(mode=0o700)
    from PyQt5 import QtCore, QtGui, QtQml, sip
    messages = []
    QtCore.qInstallMessageHandler(lambda kind, context, message: messages.append(message))
    app = QtGui.QGuiApplication([])
    require(QtCore.qVersion() == '5.14.2', QtCore.qVersion())
    source = (ROOT / "installed/capture-04/rootfs/usr/bin/Launcher" if not phase.startswith("patched")
              else Path(candidate_dir) / "Launcher")
    raw = source.read_bytes()
    unit = bytearray(raw[MAIN_OFFSET:MAIN_OFFSET + MAIN_SIZE])
    require(unit[:8] == b'qv4cdata', "Probe validation failed: unit[:8] == b'qv4cdata'")
    require(struct.unpack_from('<II', unit, 8) == (37, 331266), "Probe validation failed: struct.unpack_from('<II', unit, 8) == (37, 331266)")
    require(struct.unpack_from('<I', unit, 24)[0] == MAIN_SIZE, "Probe validation failed: struct.unpack_from('<I', unit, 24)[0] == MAIN_SIZE")
    original_digest = hashlib.sha256(raw).hexdigest()
    manifest_digest = None
    if phase.startswith("patched"):
        manifest = json.loads((source.parent / "manifest.json").read_text())
        manifest_digest = manifest["candidate"]["sha256"]
        require(original_digest == manifest_digest, 'Probe validation failed: original_digest == manifest_digest')
        reconstructed = bytearray(original[MAIN_OFFSET:MAIN_OFFSET + MAIN_SIZE])
        for length_start, payload_start, capacity, value in (
                (46804, 46824, 58, "file:/etc/vnV.qml"),
                (47188, 47208, 46, "file:/etc/vnG.qml")):
            encoded = value.encode("utf-16le")
            struct.pack_into("<I", reconstructed, length_start - MAIN_OFFSET, len(value))
            relative = payload_start - MAIN_OFFSET
            reconstructed[relative:relative + capacity] = encoded + bytes(capacity - len(encoded))
        require(unit == reconstructed, 'Candidate main differs beyond the two reviewed redirect records')
    else:
        require(raw == original, 'Probe validation failed: raw == original')
    result = dict(phase=phase, qt_version=QtCore.qVersion(), pyqt_version=QtCore.PYQT_VERSION_STR,
                  sip_version=sip.SIP_VERSION_STR, source=str(source),
                  source_sha256=hashlib.sha256(raw).hexdigest(),
                  main_unit_sha256=hashlib.sha256(unit).hexdigest(), messages=messages,
                  original_identity_validated=True, candidate_manifest_sha256=manifest_digest,
                  candidate_main_reconstruction_validated=phase.startswith("patched"))
    # Generate an official host cache. Only the compile hash enters the test buffer.
    probe = fixture / "Probe.qml"
    probe.write_text('import QtQuick 2.12\nItem { property int probeValue: 7 }\n')
    engine = QtQml.QQmlEngine()
    engine.setImportPathList([QtCore.QLibraryInfo.location(QtCore.QLibraryInfo.Qml2ImportsPath), "qrc:/qt-project.org/imports"])
    component = QtQml.QQmlComponent(engine, QtCore.QUrl.fromLocalFile(str(probe)))
    obj = component.create()
    require(obj is not None, [e.toString() for e in component.errors()])
    app.processEvents()
    caches = list(fixture.rglob("*.qmlc"))
    require(caches, 'Host Probe.qml did not produce a disk cache')
    data = caches[0].read_bytes()
    require(data[:8] == b'qv4cdata', "Probe validation failed: data[:8] == b'qv4cdata'")
    result["host_hash_source"] = str(caches[0])
    result["vendor_compile_hash_hex"] = bytes(unit[28:76]).hex()
    result["host_compile_hash_hex"] = data[28:76].hex()
    if phase.endswith("adapted"):
        unit[28:76] = data[28:76]
    result["host_hash_adaptation_requested"] = phase.endswith("adapted")
    result["in_memory_header_adaptation"] = bytes(unit[28:76]).hex() != result["vendor_compile_hash_hex"]
    result["test_unit_sha256"] = hashlib.sha256(unit).hexdigest()
    obj.deleteLater()
    del component, engine
    app.processEvents()
    common = fixture / "common"
    common.mkdir()
    (fixture / "Trucks").mkdir()
    props = "\n".join("property int " + name + ": " + str(value) for name, value in {
        "splashEnd": 1, "vehicleModel": 0, "screenFlipEnabled": 0,
        "frontTpmsDoorExchange": 0, "mLinkMfiBus": 0, "brightnessMin": 0,
        "brightnessMax": 0, "vehicleSpeedDelta": 0, "vehicleSpeedDuration": 0,
        "tachoSpeedDelta": 0, "tachoSpeedDuration": 0, "autoRun": 0, "acc": 0}.items())
    def marker(name, extra=""):
        return 'import QtQuick 2.12\nItem { objectName: "' + name + '"\n' + extra + '\n}\n'
    files = {"main.qml": "", "functions.js": ".pragma library\n",
             "common/KeyEmulation.qml": marker("key-stub"),
             "common/Verification.qml": marker("verification-stub"),
             "common/LinkEvent.qml": marker("link-stub"),
             "common/Translation.qml": marker("translation-stub"),
             "common/Global.qml": marker("embedded-global", props),
             "common/VehicleEvent.qml": marker("embedded-vehicle"),
             "Trucks/Dashboard.qml": marker("dashboard-stub")}
    ui_units = {}
    if phase in ("settings-pages", "patched-settings-redirects"):
        allowed = ["ItemInfo.qml", "MenuSetupButton.qml", "MenuItemButton.qml",
                   "MenuItemSelectButton.qml", "GlowImage.qml", "GlowText.qml",
                   "FuelConsumptionUnit.qml", "TripUnit.qml", "TemperatureUnit.qml", "PressureUnit.qml"]
        if phase == "patched-settings-redirects":
            require(original_digest == "74f3d2ecfe80bbf2b8d58d7812ba277af5289f9dc48cae73d14f59944d6d6005", "Direct factory candidate identity mismatch")
            allowed = [name for name in allowed if name not in ("FuelConsumptionUnit.qml", "TripUnit.qml", "TemperatureUnit.qml", "PressureUnit.qml", "MenuItemSelectButton.qml")]
            allowed.append("MenuListProgressbar.qml")
        for name in allowed:
            metadata = next((ROOT / "analysis/capture-04/qml-cache").glob("*" + name + ".json"))
            decoded = json.loads(metadata.read_text())
            require(all((entry['type'] != 1 or entry['uri'].startswith('Qt') for entry in decoded['imports'])), "Probe validation failed: all((entry['type'] != 1 or entry['uri'].startswith('Qt') for entry in decoded['imports']))")
            start = decoded["file_offset"]
            payload = original[start:start + decoded["unit_size"]]
            require(hashlib.sha256(payload).hexdigest() == decoded['sha256'], "Probe validation failed: hashlib.sha256(payload).hexdigest() == decoded['sha256']")
            require(payload[:8] == b'qv4cdata', "Probe validation failed: payload[:8] == b'qv4cdata'")
            require(struct.unpack_from('<II', payload, 8) == (37, 331266), "Probe validation failed: struct.unpack_from('<II', payload, 8) == (37, 331266)")
            require(decoded['qrc_path'].startswith('Trucks/') and '..' not in Path(decoded['qrc_path']).parts, "Probe validation failed: decoded['qrc_path'].startswith('Trucks/') and '..' not in Path(decoded['qrc_path']).parts")
            ui_units["qrc:/" + decoded["qrc_path"]] = payload
            files[decoded["qrc_path"]] = ""
        if phase == "patched-settings-redirects":
            start, size = 4644064, 22704
            settings_unit = bytearray(original[start:start+size])
            for length_start, payload_start, capacity, value in (
                    (4660020, 4660040, 88, "file:/etc/vnU.qml"),
                    (4660372, 4660392, 92, "file:/etc/vnF.qml")):
                encoded = value.encode("utf-16le")
                struct.pack_into("<I", settings_unit, length_start-start, len(value))
                relative = payload_start-start
                settings_unit[relative:relative+capacity] = encoded + bytes(capacity-len(encoded))
            require(raw[start:start+size] == settings_unit, "Settings unit differs beyond two reviewed redirects")
            ui_units["qrc:/Trucks/menu/system/MenuSystemSettings.qml"] = bytes(settings_unit)
            files["Trucks/menu/system/MenuSystemSettings.qml"] = ""
            for name in ("MenuSystemLanguage", "MenuSystemDateTime", "MenuSystemGeneric", "MenuSystemVersion"):
                files["Trucks/menu/system/" + name + ".qml"] = marker("safe-" + name)
            result["settings_unit_reconstruction_validated"] = True
        for name in ("check", "right_h", "select_h", "select_n"):
            alias = "Trucks/images/menu/" + name + ".png"
            target = fixture / alias
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((ROOT / "recovered-resources/latest-Launcher" / alias).read_bytes())
            files[alias] = None
    if phase == "settings-pages":
        for name, index in (("FactorySeniorSetting",1),("FactoryOdoSetup",2),("FactoryTankSetup",3),
                            ("FactoryVehicleModel",4),("FactoryShellCmd",6)):
            back = 1 if index in (2,3,4) else 0
            files["Trucks/menu/system/factory/"+name+".qml"] = ('import QtQuick 2.12\nItem { objectName: "vendor-page-'+str(index)+'"; '
                'function key(code,state) { if(state===0 && (code===mGlobalId.item.swcBack || code===mGlobalId.item.swcLeft)) '
                '{ mGlobalId.item.menuSettingsSubPageItemSetup='+str(back)+'; return 1 } return 0 } }')
    for name, text in files.items():
        (fixture / name).parent.mkdir(parents=True, exist_ok=True)
        if text is None:
            continue
        (fixture / name).write_text(text)
    external = {"file:///etc/vnG.qml": fixture / "ExternalGlobal.qml",
                "file:///etc/vnV.qml": fixture / "ExternalVehicle.qml"}
    external["file:///etc/vnG.qml"].write_text(marker("external-global", props))
    external["file:///etc/vnV.qml"].write_text(marker("external-vehicle"))
    if phase == "settings-pages":
        external["file:///etc/vnB.qml"] = fixture / "Factory.qml"
        external["file:///etc/qmldir"] = fixture / "isolated-etc-qmldir"
        external["file:///etc/qmldir"].write_text("")
    if phase == "patched-settings-redirects":
        external["file:///etc/vnU.qml"] = fixture / "RouteUnits.qml"
        external["file:///etc/vnF.qml"] = fixture / "RouteFactory.qml"
        external["file:///etc/vnU.qml"].write_text(marker("route-units"))
        external["file:///etc/vnF.qml"].write_text('import QtQuick 2.12\nItem { objectName: "route-factory"; Component.onCompleted: mGlobalId.item.factoryRouteCreations++ }')
        external["file:///etc/qmldir"] = fixture / "isolated-etc-qmldir"
        external["file:///etc/qmldir"].write_text("")
        result["safe_directory_probe_mapping"] = {"file:///etc/qmldir": str(external["file:///etc/qmldir"])}
    qrc = fixture / "fixture.qrc"
    qrc.write_text('<RCC><qresource prefix="/">' + ''.join('<file>' + name + '</file>' for name in files) + '</qresource></RCC>')
    subprocess.run([sys.executable, "-m", "PyQt5.pyrcc_main", "-o", str(fixture / "resources.py"), str(qrc)], check=True, capture_output=True, text=True)
    spec = importlib.util.spec_from_file_location("fixture_resources", fixture / "resources.py")
    resources = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(resources)
    if phase == "candidate-compile":
        candidate_root = ROOT / "patches/capture-04/etc/common"
        vehicle_text = (candidate_root / "VehicleEvent.qml").read_text()
        native_block = vehicle_text.split("    VehicleEvent{", 1)[1].split("    // VehicleEvent Plugins end", 1)[0]
        declarations = re.findall(r"^        ([A-Za-z_][A-Za-z0-9_]*):", native_block, re.M)
        properties = sorted({name for name in declarations if name != "id" and not name.startswith("on")})
        signals = sorted({name[2].lower() + name[3:] for name in declarations if name.startswith("on")})
        enums = sorted(set(re.findall(r"VehicleEvent\.([A-Z][A-Z0-9_]+)", vehicle_text)))
        mock_dir = fixture / "plugins/VehicleEvent"
        mock_dir.mkdir(parents=True)
        (mock_dir / "qmldir").write_text("module plugins.VehicleEvent\nVehicleEvent 1.0 NativeVehicleMock.qml\n")
        mock = "import QtQuick 2.12\nItem {\nenum Constants { " + ", ".join(enums) + " }\n"
        mock += "\n".join("property var " + name for name in properties) + "\n"
        mock += "\n".join("signal " + name + "()" for name in signals) + "\n}\n"
        (mock_dir / "NativeVehicleMock.qml").write_text(mock)
        engine = QtQml.QQmlEngine()
        engine.setImportPathList([str(fixture), QtCore.QLibraryInfo.location(QtCore.QLibraryInfo.Qml2ImportsPath), "qrc:/qt-project.org/imports"])
        compiled = []
        for name in ("Global.qml", "VehicleEvent.qml"):
            source_path = candidate_root / name
            content = source_path.read_bytes()
            imports = deployment_imports(content.decode("utf-8"))
            isolated = fixture / ("isolated-" + name)
            isolated.mkdir()
            safe_copy = isolated / name
            safe_copy.write_bytes(content)
            component = QtQml.QQmlComponent(engine, QtCore.QUrl.fromLocalFile(str(safe_copy)))
            compiled.append(dict(source=str(source_path), sha256=hashlib.sha256(content).hexdigest(),
                                 status=int(component.status()), ready=component.status() == QtQml.QQmlComponent.Ready,
                                 errors=[error.toString() for error in component.errors()], instantiated=False,
                                 source_bytes_unchanged=source_path.read_bytes() == content,
                                 deployment_imports=imports, sibling_resources_present=False))
        result.update(compile_only=compiled, mock_properties=properties, mock_signals=signals,
                      mock_enums=enums, passed=all(entry["ready"] and entry["source_bytes_unchanged"] for entry in compiled),
                      limitation="Compile-only with a generated native type mock. Native method semantics and runtime context remain unverified.")
        print(json.dumps(result), flush=True)
        return 0 if result["passed"] else 1
    callbacks = []
    intercepted = []
    denied = []
    class Interceptor(QtQml.QQmlAbstractUrlInterceptor):
        def intercept(self, url, kind):
            value = url.toString()
            intercepted.append(value)
            if value in external:
                return QtCore.QUrl.fromLocalFile(str(external[value]))
            if url.scheme() in ("http", "https", "ftp"):
                denied.append(value)
                return QtCore.QUrl("qrc:/denied.qml")
            if url.isLocalFile():
                path = Path(url.toLocalFile()).resolve()
                qt = Path(QtCore.QLibraryInfo.location(QtCore.QLibraryInfo.PrefixPath)).resolve()
                if not path.is_relative_to(fixture.resolve()) and not path.is_relative_to(qt):
                    denied.append(value)
                    return QtCore.QUrl("qrc:/denied.qml")
            return url
    class Cache(ctypes.Structure):
        _fields_ = [("data", ctypes.c_void_p), ("unused1", ctypes.c_void_p), ("unused2", ctypes.c_void_p)]
    callback_type = ctypes.CFUNCTYPE(ctypes.c_void_p, ctypes.c_void_p)
    class Hook(ctypes.Structure):
        _fields_ = [("version", ctypes.c_int), ("callback", callback_type)]
    buffer = ctypes.create_string_buffer(bytes(unit))
    cache = Cache(ctypes.addressof(buffer), None, None)
    ui_buffers = {url: ctypes.create_string_buffer(payload) for url, payload in ui_units.items()}
    ui_caches = {url: Cache(ctypes.addressof(value), None, None) for url, value in ui_buffers.items()}
    @callback_type
    def lookup(pointer):
        url = sip.wrapinstance(pointer, QtCore.QUrl).toString()
        callbacks.append(url)
        if phase in ("settings-pages", "patched-settings-redirects"):
            return ctypes.addressof(ui_caches[url]) if url in ui_caches else None
        return ctypes.addressof(cache) if url == "qrc:/main.qml" and phase != "empty-source-control" else None
    library = ctypes.CDLL(str(Path(QtCore.QLibraryInfo.location(QtCore.QLibraryInfo.LibrariesPath)) / "libQt5Qml.so.5"))
    register = library._ZN11QQmlPrivate11qmlregisterENS_16RegistrationTypeEPv
    register.argtypes = [ctypes.c_int, ctypes.c_void_p]
    register.restype = ctypes.c_int
    unregister = library._ZN11QQmlPrivate13qmlunregisterENS_16RegistrationTypeEy
    unregister.argtypes = [ctypes.c_int, ctypes.c_ulonglong]
    hook = Hook(0, lookup)
    result["registration_result"] = register(6, ctypes.byref(hook))
    interceptor = Interceptor()
    engine = QtQml.QQmlApplicationEngine()
    engine.setImportPathList([QtCore.QLibraryInfo.location(QtCore.QLibraryInfo.Qml2ImportsPath), "qrc:/qt-project.org/imports"])
    set_interceptor = library._ZN10QQmlEngine17setUrlInterceptorEP26QQmlAbstractUrlInterceptor
    set_interceptor.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
    set_interceptor(ctypes.c_void_p(sip.unwrapinstance(engine)), ctypes.c_void_p(sip.unwrapinstance(interceptor)))
    engine.rootContext().setContextProperty("mTrucksModel", 0)
    if phase in ("settings-pages", "patched-settings-redirects"):
        engine.rootContext().setContextProperty("mTrucksModel", 1)
        return settings_pages(fixture, result, app, engine, callbacks, intercepted, denied, ui_units)
    engine.load(QtCore.QUrl("qrc:/main.qml"))
    for unused in range(30):
        app.processEvents()
        time.sleep(0.01)
    roots = engine.rootObjects()
    objects = [obj for root in roots for obj in [root] + root.findChildren(QtCore.QObject)]
    markers = sorted({obj.objectName() for obj in objects if obj.objectName()})
    result.update(cache_callbacks=callbacks, intercepted_urls=intercepted, denied_urls=denied,
                  root_count=len(roots), markers=markers,
                  cached_main_hit="qrc:/main.qml" in callbacks)
    result["stub_global_values"] = {name: obj.property(name) for obj in objects
                                    if obj.objectName() in {"embedded-global", "external-global"}
                                    for name in ("mLinkMfiBus", "brightnessMin", "brightnessMax", "autoRun")}
    expected = {"embedded-global", "embedded-vehicle"} if phase.startswith("original") else {"external-global", "external-vehicle"}
    result["expected_markers"] = sorted(expected)
    if phase == "empty-source-control":
        expected = set()
    result["expected_markers"] = sorted(expected)
    actual_pair = set(markers) & {"embedded-global", "embedded-vehicle", "external-global", "external-vehicle"}
    requested_external = {value for value in intercepted if value in external}
    result["requested_external_urls"] = sorted(requested_external)
    routes_match = requested_external == (set(external) if phase.startswith("patched") else set())
    result["passed"] = bool(roots) and actual_pair == expected and result["cached_main_hit"] and routes_match and not denied
    result["cache_main_supplied"] = phase != "empty-source-control" and result["cached_main_hit"]
    if phase == "empty-source-control":
        result["passed"] = not roots and not result["cache_main_supplied"] and not denied
    result["empty_source_fallback_rejected"] = not roots if phase == "empty-source-control" else None
    for root in roots:
        root.setProperty("visible", False)
    del objects, roots, engine
    app.processEvents()
    unregister(6, ctypes.cast(lookup, ctypes.c_void_p).value)
    result["source_bytes_unchanged"] = hashlib.sha256(source.read_bytes()).hexdigest() == original_digest
    result["message_classifications"] = {"cache_miss_debug": [value for value in messages if "from disk cache" in value and "No such file" in value],
                                         "host_runtime_permissions": [value for value in messages if "wrong permissions" in value],
                                         "qml_errors": [value for value in messages if "TypeError" in value or "ReferenceError" in value],
                                         "expected_control_error": [value for value in messages if phase == "empty-source-control" and "QQmlApplicationEngine failed" in value]}
    result["passed"] = result["passed"] and result["source_bytes_unchanged"] and not result["message_classifications"]["qml_errors"]
    print(json.dumps(result), flush=True)
    return 0 if result["passed"] else 1


def settings_pages(fixture, result, app, engine, callbacks, intercepted, denied, ui_units):
    from PyQt5 import QtCore, QtGui, QtQml, QtQuick, QtTest
    titles = ["Front TPMS side exchange", "Rear TPMS side exchange", "Fuel filler side", "Tyre pressure",
              "Reverse alarm", "Tachometer range", "Sub tank", "Maximum speed", "Vehicle angle",
              "Outside temperature", "Eco information", "Gear information", "Oil temperature", "Range",
              "Clock", "Doors", "Oil pressure", "Chassis state", "Screen flip"]
    precompiled = []
    for url in ui_units:
        dependency = QtQml.QQmlComponent(engine, QtCore.QUrl(url))
        precompiled.append(dict(url=url, ready=dependency.status() == QtQml.QQmlComponent.Ready,
                                errors=[error.toString() for error in dependency.errors()]))
    result["precompiled_ui_dependencies"] = precompiled
    require(all((entry['ready'] for entry in precompiled)), precompiled)
    pages = []
    for name, alias in (("vnB.qml", "Factory.qml"), ("vnU.qml", "Units.qml"), ("vnF.qml", "Catalog.qml")):
        source = ROOT / "patches/capture-04/etc" / name
        content = source.read_bytes()
        copy = fixture / alias
        copy.write_bytes(content)
        component = QtQml.QQmlComponent(engine, QtCore.QUrl.fromLocalFile(str(copy)))
        pages.append(dict(source=str(source), copy=str(copy), sha256=hashlib.sha256(content).hexdigest(),
                          ready=component.status() == QtQml.QQmlComponent.Ready,
                          errors=[error.toString() for error in component.errors()]))
    result["settings_compile"] = pages
    if result["phase"] == "settings-pages":
        route_fixture = json.loads((ROOT/"evidence/fixtures/capture-04/factory-code-records.json").read_text())
        for route in route_fixture["routes"]:
            if route["index"] != 5:
                prepared = QtQml.QQmlComponent(engine, QtCore.QUrl(route["qrc_path"]))
                require(prepared.status() == QtQml.QQmlComponent.Ready, "Factory route marker compile failed")
    result["registered_ui_units"] = {url: hashlib.sha256(payload).hexdigest() for url, payload in ui_units.items()}
    if not all(page["ready"] for page in pages):
        result.update(passed=False, gap="Candidate page compile failed with actual captured UI component metadata.")
        print(json.dumps(result), flush=True)
        return 1
    harness = fixture / "SettingsHarness.qml"
    harness.write_text("""import QtQuick 2.12
import QtQuick.Window 2.12
Window {
    width: 1920; height: 932; visible: true; color: "#101317"
    property string pageUrl: ""
    property string previewTitle: "Host Qt fixture preview"
    property alias page: pageLoader.item
    property alias globalState: g
    property alias eventState: e
    property int mCompleted: 0
    function setProbeIndex(index) { probeSwipe.currentIndex=index }
    QtObject {
        id: mGlobalId
        property QtObject item: QtObject {
            id: g
            property int menuSettingsPageIndex: 6
            property int menuSettingsSubPageItemSetup: 0
            property int uartDebugEnabled: 0
            property int mediaImageEnabled: 0
            property bool modelCarSelection: false
            property int menuBarItemIndex: 0
            property int language: 1
            property string rtcDate: "2026-01-01"
            property string launcherVersion: "Safe Qt fixture"
            function getRtcTime() { return "12:00" }
            function getAmPm() { return "" }
            property int consumptionUnit: 0
            property int metricSystem: 1
            property int temperatureUnit: 1
            property int pressureUnit: 0
            property int followUnit: 1
            property int speedUnitOverride: 0
            property int tempUnitOverride: 0
            property var mFuelUnit: ["L/100km", "km/L", "MPG"]
            property var factoryCalls: []
            property int factoryRouteCreations: 0
            property var factoryStates: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
            property int swcHome: 16777232
            property int swcBack: 16777216
            property int swcUp: 16777235
            property int swcDown: 16777237
            property int swcLeft: 16777234
            property int swcRight: 16777236
            property int swcModes: 16777264
            property int swcEnter: 16777220
            property int swcPrintScr: 16777225
            function isRTL() { return false }
            function setFactory(index) {
                factoryCalls=factoryCalls.concat([index])
                var states=factoryStates.slice()
                states[index]=index===7?(states[index]+1)%5:!states[index]
                factoryStates=states
            }
        }
    }
    QtObject {
        id: mEventHandleId
        property QtObject item: QtObject {
            id: e
            property var calls: []
            property var queryCalls: []
            property var shellQueries: []
            property var adbCalls: []
            function systemInquire() { queryCalls=queryCalls.concat(["systemInquire"]) }
            function shellCmdInquire() { shellQueries=shellQueries.concat(["shellCmdInquire"]) }
            function adb(value) { adbCalls=adbCalls.concat([value]) }
            function setUnit2(type, value) { calls=calls.concat([[type,value]]) }
            function followVehicleUnits() {
                calls=calls.concat([["follow"]])
                g.speedUnitOverride=0; g.tempUnitOverride=0
                g.metricSystem=1; g.temperatureUnit=1
            }
        }
    }
    QtObject {
        id: mTranslationId
        property QtObject item: QtObject {
            property var mFactoryItems: FACTORY_TITLES
            property var mFactoryItemsState: g.factoryStates
            property string mBack: "Back"
            property string mSystemLangSetup: "Language"
            property var mSystemLanguages: ["Fixture", "English"]
            property string mSystemDateTime: "Date and time"
            property string mSystemUnits: "Units"
            property string mSystemGeneric: "Display"
            property string mDayBrightness: "Brightness"
            property string mSpeedWarn: "Speed warning"
            property string mSystemVersion: "Version"
            property string mSystemFactory: "Factory"
            property var mSystemSetupUnits: ["Fuel economy", "Speed and distance", "Temperature", "Tyre pressure"]
            function getSystemUnit(index) {
                return [g.mFuelUnit[g.consumptionUnit], g.metricSystem?"km/h":"MPH",
                        g.temperatureUnit?"Celsius":"Fahrenheit", ["kPa","bar","kg/cm2","psi"][g.pressureUnit]][index]
            }
        }
    }
    Item {
        id: keyBridge
        objectName: "key-bridge"
        anchors.fill: parent
        focus: true
        Rectangle { anchors.fill: parent; color: "#101317"; z: -1 }
        Keys.onPressed: { if(pageLoader.item) pageLoader.item.key(event.key,1); event.accepted=true }
        Keys.onReleased: { if(pageLoader.item) pageLoader.item.key(event.key,0); event.accepted=true }
        Loader { id: pageLoader; anchors.centerIn: parent; source: pageUrl }
        Text { x: 40; y: 30; color: "white"; font.pixelSize: 28; text: previewTitle }
        Text { x: 40; anchors.bottom: parent.bottom; anchors.bottomMargin: 24; color: "#aeb8c5"; font.pixelSize: 20
               text: "Captured UI components; safe context stubs; no vehicle connection." }
    }
}
""".replace("FACTORY_TITLES", json.dumps(titles)))
    engine.load(QtCore.QUrl.fromLocalFile(str(harness)))
    roots = engine.rootObjects()
    require(roots, result['messages'])
    window = roots[0]
    bridge = window.findChild(QtCore.QObject, "key-bridge")
    checks = []
    renders = []
    def advance():
        loop = QtCore.QEventLoop()
        QtCore.QTimer.singleShot(0, loop.quit)
        loop.exec_()
    def verify(name, condition):
        checks.append(dict(name=name, passed=bool(condition)))
        print("CHECK " + name, flush=True)
        require(condition, name)
    def value(obj, name):
        entry = obj.property(name)
        return entry.toVariant() if isinstance(entry, QtQml.QJSValue) else entry
    def press(key, release=True):
        bridge.forceActiveFocus()
        # Queue keyboard events so Qt compiler callbacks can acquire the Python GIL.
        app.postEvent(window, QtGui.QKeyEvent(QtCore.QEvent.KeyPress, key, QtCore.Qt.NoModifier))
        advance()
        if release:
            app.postEvent(window, QtGui.QKeyEvent(QtCore.QEvent.KeyRelease, key, QtCore.Qt.NoModifier))
            advance()
    def release(key):
        app.postEvent(window, QtGui.QKeyEvent(QtCore.QEvent.KeyRelease, key, QtCore.Qt.NoModifier))
        advance()
    def select_page(index):
        window.setProperty("pageUrl", QtCore.QUrl.fromLocalFile(pages[index]["copy"]).toString())
        advance()
        page = window.property("page")
        verify("page instantiated: " + pages[index]["source"], page is not None)
        count = (20,6,16)[index]
        candidates = [obj for obj in page.findChildren(QtCore.QObject)
                      if obj.metaObject().className().startswith("SwipeView") and obj.property("count") == count]
        if not candidates:
            result.update(passed=False, runtime_tree=[dict(type=obj.metaObject().className(),
                          count=obj.property("count"), currentIndex=obj.property("currentIndex"))
                          for obj in page.findChildren(QtCore.QObject) if obj.property("count") is not None])
            print(json.dumps(result), flush=True)
        swipe = candidates[0]
        verify("initial selection is first row", value(swipe,"currentIndex") == 0)
        rows = QtQml.QQmlListReference(swipe, b"contentChildren", engine)
        verify("actual row count " + str(count), rows.isValid() and rows.count() == count)
        return page, swipe, [rows.at(i) for i in range(rows.count())]
    global_state = window.property("globalState")
    event_state = window.property("eventState")
    if result["phase"] == "patched-settings-redirects":
        for url in ["qrc:/Trucks/menu/system/MenuSystem" + name + ".qml" for name in ("Language", "DateTime", "Generic", "Version")]:
            prepared = QtQml.QQmlComponent(engine, QtCore.QUrl(url))
            require(prepared.status() == QtQml.QQmlComponent.Ready, "Safe route marker compile failed")
        for path in (fixture/"RouteUnits.qml", fixture/"RouteFactory.qml"):
            prepared = QtQml.QQmlComponent(engine, QtCore.QUrl.fromLocalFile(str(path)))
            require(prepared.status() == QtQml.QQmlComponent.Ready, "External route marker compile failed")
        global_state.setProperty("menuSettingsPageIndex", 0)
        window.setProperty("pageUrl", "qrc:/Trucks/menu/system/MenuSystemSettings.qml")
        advance()
        page = window.property("page")
        verify("captured settings component instantiated", page is not None)
        urls = value(page, "mSystemSettingsItems")
        verify("patched unit URL evaluates", urls[2] == "file:/etc/vnU.qml")
        verify("patched factory URL evaluates", urls[5] == "file:/etc/vnF.qml")
        verify("factory route absent before selection", page.findChild(QtCore.QObject, "route-factory") is None
               and value(global_state, "factoryRouteCreations") == 0)
        swipe = next(obj for obj in page.findChildren(QtCore.QObject) if obj.metaObject().className().startswith("SwipeView"))
        engine.rootContext().setContextProperty("probeSwipe", swipe)
        route_lifecycle = []
        for index, marker_name, requested in ((2,"route-units","file:///etc/vnU.qml"),
                                               (5,"route-factory","file:///etc/vnF.qml"),
                                               (6,"route-factory",None),
                                               (5,"route-factory","file:///etc/vnF.qml")):
            QtCore.QMetaObject.invokeMethod(window, "setProbeIndex", QtCore.Qt.QueuedConnection, QtCore.Q_ARG("QVariant", index))
            loop = QtCore.QEventLoop()
            completed = QtCore.QTimer()
            completed.setInterval(10)
            completed.timeout.connect(lambda: loop.quit() if (page.findChild(QtCore.QObject, marker_name) is not None) == (requested is not None) else None)
            completed.start()
            QtCore.QTimer.singleShot(1000, loop.quit)
            loop.exec_()
            completed.stop()
            if requested is None:
                verify("factory route removed on Back selection", page.findChild(QtCore.QObject, marker_name) is None)
            else:
                verify("nested loader requested " + requested, requested in intercepted)
                verify("nested loader created " + marker_name, page.findChild(QtCore.QObject, marker_name) is not None)
            route_lifecycle.append(dict(index=index, factory_instances=value(global_state,"factoryRouteCreations")))
        verify("factory route recreated on reselection", value(global_state,"factoryRouteCreations") == 2)
        metadata = json.loads(next((ROOT/"analysis/capture-04/qml-cache").glob("*MenuSystemSettings.qml.json")).read_text())
        binding = next(entry for entry in metadata["functions"] if entry["name"] == "expression for mSystemSettingsItems")
        loader_fixture = json.loads((ROOT/"evidence/fixtures/capture-04/system-settings-loaders.json").read_text())
        redirect_indices = {row["index"] for row in loader_fixture["strings"]}
        redirect_uses = [entry for entry in binding["bytecode"] if entry.get("args",{}).get("stringId") in redirect_indices]
        verify("loader string indices match source array bytecode", len(redirect_uses) == 2 and
               {entry["args"]["stringId"] for entry in redirect_uses} == redirect_indices)
        result["source_array_bytecode"] = dict(function_index=binding["index"], source_line=binding["location"]["line"],
                                              code_sha256=binding["code_sha256"],
                                              redirect_uses=redirect_uses)
        errors = [message for message in result["messages"] if "TypeError" in message or "ReferenceError" in message]
        result.update(passed=all(entry["passed"] for entry in checks) and not errors and not denied,
                      redirect_checks=checks, evaluated_source_array=urls, qml_errors=errors,
                      factory_route_lifecycle=route_lifecycle,
                      cache_callbacks=callbacks, intercepted_urls=intercepted, denied_urls=denied,
                      native_writes=False,
                      proof_scope="Patched MenuSystemSettings source array and nested marker loaders. No dashboard or native vehicle plugin.")
        window.setProperty("visible", False)
        print(json.dumps(result), flush=True)
        return 0 if result["passed"] else 1
    page, swipe, rows = select_page(0)
    QtTest.QTest.qWait(80)
    result["startup_query_observations"] = {"first_factory_count": len(value(event_state,"queryCalls"))}
    verify("factory startup query occurs once", value(event_state,"queryCalls") == ["systemInquire"])
    verify("factory titles and Back", [value(row,"mTitle") for row in rows] == titles + ["Back"])
    title_layouts = []
    for row in rows:
        label = value(row,"mTitle")
        text_items = [obj for obj in row.findChildren(QtCore.QObject)
                      if obj.property("text") == label and obj.property("contentWidth") is not None]
        title_layouts.append(dict(title=label, data=value(row,"mData"),
                                  widths=[dict(width=obj.property("width"), content_width=obj.property("contentWidth")) for obj in text_items]))
    verify("factory title labels fit actual text bounds", all(entry["widths"] and all(item["width"] >= item["content_width"]-0.5 for item in entry["widths"]) for entry in title_layouts))
    result["factory_title_layouts"] = title_layouts
    press(QtCore.Qt.Key_Down, False)
    verify("Down press preserves index", value(swipe,"currentIndex") == 0)
    release(QtCore.Qt.Key_Down)
    verify("Down release advances", value(swipe,"currentIndex") == 1)
    press(QtCore.Qt.Key_Up)
    press(QtCore.Qt.Key_Up)
    verify("Up wraps to Back", value(swipe,"currentIndex") == 19)
    press(QtCore.Qt.Key_Down)
    verify("Down wraps to first", value(swipe,"currentIndex") == 0)
    press(QtCore.Qt.Key_Return, False)
    verify("Enter press has no setter call", value(global_state,"factoryCalls") == [] and value(page,"mPressed") == 1)
    release(QtCore.Qt.Key_Return)
    verify("Enter release calls factory setter", value(global_state,"factoryCalls") == [0] and value(page,"mPressed") == 0)
    for index in range(1,19):
        press(QtCore.Qt.Key_Down)
        press(QtCore.Qt.Key_Return)
    verify("all nineteen factory actions", value(global_state,"factoryCalls") == list(range(19)))
    press(QtCore.Qt.Key_Down)
    press(QtCore.Qt.Key_Return)
    verify("general Back returns to catalog", value(global_state,"menuSettingsSubPageItemSetup") == 0 and len(value(global_state,"factoryCalls")) == 19)
    global_state.setProperty("menuSettingsPageIndex", 6)
    page, swipe, rows = select_page(1)
    QtTest.QTest.qWait(80)
    result["startup_query_observations"]["after_units_count"] = len(value(event_state,"queryCalls"))
    result["startup_query_observations"]["unit_page_delta"] = len(value(event_state,"queryCalls"))-result["startup_query_observations"]["first_factory_count"]
    verify("units sends no startup query", value(event_state,"queryCalls") == ["systemInquire"])
    verify("unit titles Follow and Back", [value(row,"mTitle") for row in rows] == ["Fuel economy","Speed and distance","Temperature","Tyre pressure","Follow vehicle units","Back"])
    press(QtCore.Qt.Key_Down)
    press(QtCore.Qt.Key_Return)
    verify("speed manual override", value(global_state,"speedUnitOverride") == 1 and value(global_state,"metricSystem") == 0)
    verify("speed setter record only", value(event_state,"calls") == [[2,0]])
    press(QtCore.Qt.Key_Down)
    press(QtCore.Qt.Key_Return)
    verify("temperature manual override", value(global_state,"tempUnitOverride") == 1 and value(global_state,"temperatureUnit") == 0)
    verify("temperature setter record only", value(event_state,"calls") == [[2,0],[1,0]])
    verify("manual status text", "Manual" in value(rows[1],"mData") and "Manual" in value(rows[2],"mData"))
    press(QtCore.Qt.Key_Down)
    press(QtCore.Qt.Key_Down)
    press(QtCore.Qt.Key_Return)
    verify("Follow clears manual state", value(global_state,"speedUnitOverride") == 0 and value(global_state,"tempUnitOverride") == 0)
    verify("Follow records one call", value(event_state,"calls") == [[2,0],[1,0],["follow"]])
    verify("Follow status text", "Follow" in value(rows[1],"mData") and "Follow" in value(rows[2],"mData"))
    press(QtCore.Qt.Key_Down)
    press(QtCore.Qt.Key_Return)
    verify("units Back route", value(global_state,"menuSettingsPageIndex") == 0)
    catalog, menu, catalog_rows = select_page(2)
    QtTest.QTest.qWait(350)
    verify("catalog startup query preserves vendor schedule", value(event_state,"shellQueries") == ["shellCmdInquire"])
    verify("catalog startup leaves diagnostic settings unchanged", value(event_state,"adbCalls") == [] and
           value(global_state,"uartDebugEnabled") == 0 and value(global_state,"mediaImageEnabled") == 0 and
           value(global_state,"modelCarSelection") is False)
    expected_titles = ["General settings","Advanced settings","Fuel tank setup","Vehicle profile","Odometer setup",
                       "Service commands","ADB debugging: enable","ADB debugging: disable","Debug logging: off",
                       "Debug logging: warnings","Debug logging: UART receive","Debug logging: UART transmit",
                       "Debug logging: MCU","USB image preview: enable","Car model options","Back"]
    verify("catalog exposes all settings and tools", [value(row,"mTitle") for row in catalog_rows] == expected_titles)
    press(QtCore.Qt.Key_Up)
    verify("catalog Up wraps to Back", menu.property("currentIndex") == 15)
    press(QtCore.Qt.Key_Down)
    verify("catalog Down wraps to General", menu.property("currentIndex") == 0)
    press(QtCore.Qt.Key_Down,False)
    verify("catalog Down press preserves selection", menu.property("currentIndex") == 0)
    release(QtCore.Qt.Key_Down)
    verify("catalog Down release advances", menu.property("currentIndex") == 1)
    for row_index, expected_page in enumerate((5,1,3,4,2,6)):
        menu.setProperty("currentIndex", row_index)
        press(QtCore.Qt.Key_Return, False)
        verify("page opens only on release " + str(expected_page), value(global_state,"menuSettingsSubPageItemSetup") == 0)
        release(QtCore.Qt.Key_Return)
        verify("direct page route " + str(expected_page), value(global_state,"menuSettingsSubPageItemSetup") == expected_page)
        if expected_page == 5:
            child_views = [obj for obj in catalog.findChildren(QtCore.QObject)
                           if obj.metaObject().className().startswith("SwipeView") and obj.property("count") == 20]
            verify("general route loads the actual candidate page", len(child_views) == 1 and child_views[0].property("currentIndex") == 0)
        else:
            verify("service route loads a safe marker " + str(expected_page), catalog.findChild(QtCore.QObject,"vendor-page-"+str(expected_page)) is not None)
        press(QtCore.Qt.Key_Escape)
        expected_parent = 0
        verify("direct Back returns to catalog " + str(expected_page), value(global_state,"menuSettingsSubPageItemSetup") == expected_parent)
        if expected_parent:
            press(QtCore.Qt.Key_Escape)
        verify("return to the direct catalog " + str(expected_page), value(global_state,"menuSettingsSubPageItemSetup") == 0)
    menu.setProperty("currentIndex",1)
    press(QtCore.Qt.Key_Return)
    global_state.setProperty("menuSettingsSubPageItemSetup",3)
    press(QtCore.Qt.Key_Escape)
    verify("nested tank Back preserves Advanced parent", value(global_state,"menuSettingsSubPageItemSetup") == 1)
    press(QtCore.Qt.Key_Escape)
    verify("Advanced Back returns to catalog", value(global_state,"menuSettingsSubPageItemSetup") == 0)
    for row_index, argument in ((6,1),(7,0)):
        menu.setProperty("currentIndex",row_index)
        before = list(value(event_state,"adbCalls"))
        press(QtCore.Qt.Key_Return,False)
        verify("USB debug command waits for release " + str(argument), value(event_state,"adbCalls") == before)
        release(QtCore.Qt.Key_Return)
        verify("explicit USB debug command " + str(argument), value(event_state,"adbCalls") == before+[argument])
    for row_index, mode in enumerate((0,1,2,4,8),8):
        menu.setProperty("currentIndex",row_index)
        press(QtCore.Qt.Key_Return)
        verify("debug mode exact vendor value " + str(mode), value(global_state,"uartDebugEnabled") == mode)
        verify("debug selection feedback " + str(mode), value(catalog_rows[row_index],"mData") == "Selected")
    menu.setProperty("currentIndex",13)
    press(QtCore.Qt.Key_Return)
    verify("explicit image preview enable", value(global_state,"mediaImageEnabled") == 1)
    menu.setProperty("currentIndex",14)
    press(QtCore.Qt.Key_Return)
    verify("explicit model options toggle", value(global_state,"modelCarSelection") is True)
    def mode_event(state):
        QtCore.QMetaObject.invokeMethod(catalog,"key",QtCore.Qt.QueuedConnection,
            QtCore.Q_ARG("QVariant",value(global_state,"swcModes")),QtCore.Q_ARG("QVariant",state))
        advance()
    for state in (1,2,2,2,0):
        mode_event(state)
    verify("mode hold activates once and consumes release", value(global_state,"modelCarSelection") is False and
           menu.property("currentIndex") == 14)
    menu.setProperty("currentIndex",0)
    for state in (1,2,2,0):
        mode_event(state)
    verify("mode entry reaches General without a release advance", value(global_state,"menuSettingsSubPageItemSetup") == 5 and
           any(obj.metaObject().className().startswith("SwipeView") and obj.property("count") == 20 and obj.property("currentIndex") == 0
               for obj in catalog.findChildren(QtCore.QObject)))
    press(QtCore.Qt.Key_Escape)
    menu.setProperty("currentIndex",15)
    press(QtCore.Qt.Key_Return)
    verify("catalog Back reaches System Settings", value(global_state,"menuSettingsPageIndex") == 0)
    result["factory_catalog_scope"] = "Actual catalog and General candidate. Other vendor pages use safe markers with recorded Back contracts. Diagnostic methods record arguments only."
    # Capture fixture previews with actual cached component geometry and safe state.
    for page_index, title in ((0,"General settings"),(1,"Unit settings"),(2,"Factory menu")):
        page, swipe, rows = select_page(page_index)
        window.setProperty("previewTitle", "Host Qt fixture preview - " + title)
        verify("preview row0 checked and released", value(rows[0],"mChecked") and not value(rows[0],"mClicked"))
        for height in (932,720):
            window.resize(1920,height)
            window.show()
            content = swipe.property("contentItem")
            for unused in range(40):
                QtTest.QTest.qWait(20)
                if not content.property("moving") and abs(content.property("contentY") - content.property("originY")) < 0.5:
                    break
            verify("preview selected row settled", abs(content.property("contentY") - content.property("originY")) < 0.5)
            image = window.grabWindow()
            render_method = "QQuickWindow.grabWindow"
            if image.isNull():
                grab = window.contentItem().grabToImage()
                if grab is not None:
                    loop = QtCore.QEventLoop()
                    grab.ready.connect(loop.quit)
                    QtCore.QTimer.singleShot(2000, loop.quit)
                    loop.exec_()
                    image = grab.image()
                    render_method = "QQuickItem.grabToImage"
            if image.isNull():
                result.update(passed=False, runtime_checks=checks,
                              render_gap="Window and content-item captures returned null on offscreen QPA.",
                              window_state=dict(visible=window.isVisible(),exposed=window.isExposed(),
                                                width=window.width(),height=window.height()))
                print(json.dumps(result), flush=True)
                return 1
            verify("preview background is opaque", image.pixelColor(0,0).alpha() == 255)
            target = fixture / ("preview-" + str(page_index) + "-1920x" + str(height) + ".png")
            verify("preview saved " + str(height), not image.isNull() and image.save(str(target)))
            renders.append(dict(path=str(target), method=render_method, sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
                                width=image.width(), height=image.height(),
                                selected_row_y=rows[0].mapToItem(swipe, QtCore.QPointF(0,0)).y(),
                                label="Host Qt fixture preview; captured UI and safe context stubs."))
    for page in pages:
        page["source_bytes_unchanged"] = hashlib.sha256(Path(page["source"]).read_bytes()).hexdigest() == page["sha256"]
    verify("page source bytes unchanged", all(page["source_bytes_unchanged"] for page in pages))
    result["message_classifications"] = {"cache_miss_debug": [value for value in result["messages"] if "from disk cache" in value and "No such file" in value],
                                         "host_runtime_permissions": [value for value in result["messages"] if "wrong permissions" in value],
                                         "qml_errors": [value for value in result["messages"] if "TypeError" in value or "ReferenceError" in value]}
    result.update(runtime_checks=checks, renders=renders, cache_callbacks=callbacks, fixture_model="Ford index1",
                  intercepted_urls=intercepted, denied_urls=denied,
                  factory_calls=value(global_state,"factoryCalls"), event_calls=value(event_state,"calls"),
                  startup_queries=value(event_state,"queryCalls"),
                  passed=all(entry["passed"] for entry in checks) and not denied and not result["message_classifications"]["qml_errors"],
                  native_writes=False,
                  limitation="Qt fixture runtime and key routes verified. Safe methods record calls only; vehicle behavior remains unverified.")
    window.setProperty("visible",False)
    print(json.dumps(result), flush=True)
    return 0 if result["passed"] else 1


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--child", choices=PHASES)
    parser.add_argument("--fixture")
    parser.add_argument("--candidate-dir", default=str(ROOT / "analysis/capture-04/ui-candidate-trip-units-v1"))
    args = parser.parse_args()
    if args.child:
        return child(args.child, Path(args.fixture), args.candidate_dir)
    HOST.mkdir(parents=True, exist_ok=True)
    history = []
    if RESULT.exists():
        previous = json.loads(RESULT.read_text())
        history = previous.get("regression_history", [])
        failed = previous.get("settings_pages", {}).get("result", {})
        if failed.get("runtime_tree"):
            history.append(dict(finding="Factory opened on Back after Repeater population",
                                expected_initial_index=0, observed_tree=failed["runtime_tree"],
                                sources=failed.get("settings_compile", []),
                                evidence="Actual Qt5.14.2 object properties before source lifecycle correction."))
    runs = []
    phases = ["empty-source-control", "original-vendor-header", "original-adapted", "patched-adapted"]
    if args.candidate_dir:
        phases.extend(("patched-settings-adapted", "patched-settings-redirects"))
    for phase in phases:
        fixture = Path(tempfile.mkdtemp(prefix="loader-", dir=HOST))
        command = [sys.executable, str(Path(__file__).resolve()), "--child", phase, "--fixture", str(fixture)]
        if phase in ("patched-settings-adapted", "patched-settings-redirects"):
            command += ["--candidate-dir", args.candidate_dir]
        process = subprocess.run(command, capture_output=True, text=True, timeout=40)
        record = dict(phase=phase, command=command, exit_code=process.returncode,
                      stderr=process.stderr, stdout=process.stdout)
        try:
            record["result"] = json.loads(process.stdout.strip().splitlines()[-1])
            del record["stdout"]
        except (ValueError, IndexError):
            record["parse_failure"] = True
        record["stderr_classification"] = "native_crash" if process.returncode < 0 else ("python_error" if "Traceback" in process.stderr else "diagnostic")
        runs.append(record)
    success = all(r.get("result", {}).get("passed", False) for r in runs)
    guards = []
    for label, phase, expected_exit, expected_error in (
            ("unknown phase rejected", "unknown-phase", 2, "invalid choice: 'unknown-phase'"),
            ("fixture outside direct child rejected", "settings-pages", 1,
             "RuntimeError: QT_PROBE_GUARD: Fixture must resolve to a direct child of qt-host")):
        command = [sys.executable, "-O", str(Path(__file__).resolve()), "--child", phase, "--fixture", str(HOST)]
        rejected = subprocess.run(command, capture_output=True, text=True, timeout=10)
        guards.append(dict(name=label, command=command, exit_code=rejected.returncode,
                           expected_error=expected_error, optimized_python=True, stderr=rejected.stderr,
                           passed=rejected.returncode == expected_exit and expected_error in rejected.stderr))
    success = success and all(entry["passed"] for entry in guards)
    fixture = Path(tempfile.mkdtemp(prefix="compile-", dir=HOST))
    compile_command = [sys.executable, str(Path(__file__).resolve()), "--child", "candidate-compile", "--fixture", str(fixture)]
    process = subprocess.run(compile_command, capture_output=True, text=True, timeout=40)
    compile_record = dict(command=compile_command, exit_code=process.returncode, stderr=process.stderr,
                          stderr_classification="native_crash" if process.returncode < 0 else ("python_error" if "Traceback" in process.stderr else "diagnostic"))
    try:
        compile_record["result"] = json.loads(process.stdout.strip().splitlines()[-1])
    except (ValueError, IndexError):
        compile_record["stdout"] = process.stdout
    compile_success = compile_record.get("result", {}).get("passed", False)
    fixture = Path(tempfile.mkdtemp(prefix="settings-", dir=HOST))
    page_command = [sys.executable, str(Path(__file__).resolve()), "--child", "settings-pages", "--fixture", str(fixture)]
    try:
        process = subprocess.run(page_command, capture_output=True, text=True, timeout=50)
        page_record = dict(command=page_command, exit_code=process.returncode, stderr=process.stderr)
        try:
            page_record["result"] = json.loads(process.stdout.strip().splitlines()[-1])
        except (ValueError, IndexError):
            page_record["stdout"] = process.stdout
    except subprocess.TimeoutExpired as error:
        page_record = dict(command=page_command, exit_code=None, timed_out=True,
                           stdout=(error.stdout or b"").decode(errors="replace"),
                           stderr=(error.stderr or b"").decode(errors="replace"))
    page_success = page_record.get("result", {}).get("passed", False)
    result = dict(passed=success and compile_success and page_success, settings_pages=page_record, guard_checks=guards, routing_passed=success, compile_only=compile_record, command=[sys.executable, str(Path(__file__).resolve())] + (["--candidate-dir",args.candidate_dir] if args.candidate_dir else []), runs=runs,
                  limitations=["Only safe fixture QML and allowlisted interpreted UI cache data execute.",
                               "No ARM executable or captured native plugin loads.",
                               "Host compile hash adaptation, when needed, changes only an in-memory test header.",
                               "This probe tests cache geometry, bytecode, and loader routes. Target-fork cache acceptance remains unverified."])
    result["regression_history"] = history
    result["host_header_summary"] = dict(host_hashes=sorted({entry["result"]["host_compile_hash_hex"] for entry in runs if "result" in entry}),
                                         any_header_changed=any(entry.get("result", {}).get("in_memory_header_adaptation", False) for entry in runs))
    RESULT.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(dict(routing_passed=success, compile_passed=compile_success, settings_passed=page_success, artifact=str(RESULT))))
    return 0 if success and compile_success and page_success else 1


if __name__ == "__main__":
    sys.exit(main())
