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
    # The cluster has this font in /usr/share/fonts; the design handoff carries the same file.
    QtGui.QFontDatabase.addApplicationFont(str(ROOT / "handoff/claude-dashboard/assets/fonts/BMW.ttf"))
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
                   "MenuItemSelectButton.qml", "GlowImage.qml", "GlowText.qml"]
        if phase == "patched-settings-redirects":
            require(original_digest == "3aee8242a8cb167069750bb721f34b5ab66e48cf634fe7c3fcb81b75abd49d8a", "Menu candidate identity mismatch")
            allowed.remove("MenuItemSelectButton.qml")
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
            # MenuPage (cache 024): the original unit plus the one reviewed Loader redirect must equal the candidate unit.
            start, size = 3998016, 8652
            menu_unit = bytearray(original[start:start+size])
            for length_start, payload_start, capacity, value in ((4002516, 4002536, 72, "file:/etc/vnM.qml"),):
                encoded = value.encode("utf-16le")
                struct.pack_into("<I", menu_unit, length_start-start, len(value))
                relative = payload_start-start
                menu_unit[relative:relative+capacity] = encoded + bytes(capacity-len(encoded))
            require(raw[start:start+size] == menu_unit, "MenuPage unit differs beyond the reviewed redirect")
            ui_units["qrc:/Trucks/menu/MenuPage.qml"] = bytes(menu_unit)
            files["Trucks/menu/MenuPage.qml"] = ""
            # Safe stand-in for the compiled trip overlay that MenuPage declares.
            files["Trucks/common/Trip.qml"] = marker("safe-Trip", "property int mIndex: 0")
            # MenuPage imports these directories; each needs one file to exist in the fixture resources.
            files["Trucks/menu/vehicle/SafeVehicle.qml"] = marker("safe-vehicle-directory")
            files["Trucks/common/text/SafeText.qml"] = marker("safe-text-directory")
            result["menu_unit_reconstruction_validated"] = True
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
        # The compiled G-force page needs PitchInfo/RollInfo units outside the allowlist. The stub keeps the
        # compiled Back contract (key_back release sets menuSettingsPageIndex=0) and records each forwarded key.
        files["Trucks/menu/vehicle/MenuVehicleGForce.qml"] = ('import QtQuick 2.12\nItem { objectName: "gforce-stub"; property var keys: []; '
            'function key(code,state) { keys=keys.concat([[code,state]]); if(state===0 && (code===mGlobalId.item.swcBack || code===mGlobalId.item.swcLeft)) '
            '{ mGlobalId.item.menuSettingsPageIndex=0; return 1 } return 0 } }')
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
        external["file:///etc/vnF.qml"] = fixture / "Catalog.qml"
        external["file:///etc/qmldir"] = fixture / "isolated-etc-qmldir"
        external["file:///etc/qmldir"].write_text("")
    if phase == "patched-settings-redirects":
        external["file:///etc/vnM.qml"] = fixture / "RouteMenu.qml"
        external["file:///etc/vnM.qml"].write_text('import QtQuick 2.12\nItem { objectName: "route-menu"; property var keys: []; '
                                                   'function key(code,state) { keys=keys.concat([[code,state]]); return 1 } }')
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
    from PyQt5 import QtCore, QtGui, QtQml, QtQuick, QtTest, sip
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
    for name, alias in (("vnB.qml", "Factory.qml"), ("vnF.qml", "Catalog.qml"), ("vnM.qml", "Menu.qml")):
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
            property int vehicleModel: 1
            property var fordSetupInfo: []
            property bool fordSetupKnown: false
            // Store a JS array, as Global does, so in-place element writes persist.
            function assign(name, values) { g[name]=values.slice() }
            property int fordSetupInfoChanged: 0
            // Global.qml f150_11_14_param_id (linux branch).
            function f150_11_14_param_id(index) {
                return ({2:2, 5:5, 6:6, 13:11, 50:0, 51:0, 52:1, 56:3, 57:4, 58:7, 59:8, 60:9, 61:10,
                         62:12, 63:13, 64:14, 65:15, 66:16, 70:17})[index]
            }
            property int menuBarIndex: 1
            property int dashboard: 0
            property int tripType: 0
            property int gpsAutoSetRtcEnabled: 1
            property int rtc24h: 1
            property string rtcTime: "12:00"
            property int lightBrightness: 125
            property int darkBrightness: 0
            function getBrightnessLevel(dark) { return Math.floor(Math.floor(dark?darkBrightness:lightBrightness)/25) }
            property int overSpeedWarningEnabled: 0
            property int overSpeedWarningSpeed: 0
            property real tripFactor: metricSystem?1:0.62137
            property string tripUnit: metricSystem?"km":"mi"
            property string vehicleSpeedUnit: metricSystem?"km/h":"MPH"
            function getOverSpeedWaningSpeed(unit) {
                return (overSpeedWarningSpeed===0?"---":(overSpeedWarningSpeed*tripFactor).toFixed(0))+(!unit?"":" "+vehicleSpeedUnit)
            }
            property string pluginsVersion: "plugins@fixture"
            property string mcuVersion: "mcu@fixture"
            property var mTpmsUnit: [" kPa", " bar", " kg/cm2", " psi"]
            // Maintenance state and text helpers copied from Global.qml.
            property int mainTentChanged: 0
            property int mainTentCustomize1: 0
            property int mainTentCustomize2: 0
            property var mainTentState: [0, 1, 2, 0, 4, 5, 0, 0, 0, 0]
            property var mainTentMileage: [16777215, 16777215, 16777215, 16777215, 16777215, 16777215, 16777215, 16777215, 16777215, 16777215]
            property var mainTentReminder: [16777215, 16777215, 16777215, 16777215, 16777215, 16777215, 16777215, 16777215, 16777215, 16777215]
            property var mainTentYear: [255, 255, 255, 255, 255, 255, 255, 255, 255, 255]
            property var mainTentMonth: [255, 255, 255, 255, 255, 255, 255, 255, 255, 255]
            property var mainTentDay: [255, 255, 255, 255, 255, 255, 255, 255, 255, 255]
            function getMaintentStateColor(id) {
                var color
                switch(mainTentState[id]) {
                case 1: case 4: color="orange"; break
                case 2: case 5: color="red"; break
                default: color="white"
                }
                return mainTentChanged?color:color
            }
            function getMaintentMileage(id) {
                var mileage=(mainTentMileage[id]===0xFFFFFF?"----":(mainTentMileage[id]*tripFactor).toFixed(0))+" "+tripUnit
                return mainTentChanged?mileage:mileage
            }
            function getMaintentDate(id) {
                var year=(mainTentYear[id]===0xFF || mainTentYear[id]<=0)?"----":(mainTentYear[id]+2000)
                var month=(mainTentMonth[id]<1||mainTentMonth[id]>12)?"--":(mainTentMonth[id])
                var day=(mainTentDay[id]<1||mainTentDay[id]>31)?"--":(mainTentDay[id])
                var date=metricSystem?(year+"/"+month+"/"+day):(month+"/"+day+"/"+year)
                return mainTentChanged?date:date
            }
            function getMaintentReminder(id) {
                var reminder=(mainTentReminder[id]===0xFFFFFF?"----":(mainTentReminder[id]*tripFactor).toFixed(0))+" "+tripUnit
                return mainTentChanged?reminder:reminder
            }
            property var mFuelUnit: ["L/100km", "km/L", "MPG"]
            property var factoryCalls: []
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
            // Every native call in order, for exact send checks.
            property var log: []
            function note(entry) { log=log.concat([entry]) }
            function systemInquire() { queryCalls=queryCalls.concat(["systemInquire"]); note(["systemInquire"]) }
            function shellCmdInquire() { shellQueries=shellQueries.concat(["shellCmdInquire"]); note(["shellCmdInquire"]) }
            function adb(value) { adbCalls=adbCalls.concat([value]); note(["adb",value]) }
            function setUnit2(type, value) { calls=calls.concat([[type,value]]); note(["unit2",type,value]) }
            property var resetCalls: []
            function resetTrip(trip) { resetCalls=resetCalls.concat([["trip",trip]]); note(["trip",trip]) }
            function resetSinceReset() { resetCalls=resetCalls.concat([["since"]]); note(["since"]) }
            function tpmsReset() { resetCalls=resetCalls.concat([["tpms"]]); note(["tpms"]) }
            function setFordSetup(vehicle, id, data) { resetCalls=resetCalls.concat([["ford",vehicle,id,data]]); note(["ford",vehicle,id,data]) }
            function resetOilLife() { resetCalls=resetCalls.concat([["oil"]]); note(["oil"]) }
            function followVehicleUnits() {
                calls=calls.concat([["follow"]]); note(["follow"])
                g.speedUnitOverride=0; g.tempUnitOverride=0
                g.metricSystem=1; g.temperatureUnit=1
            }
            function seniorF150_11_14_SetupInquire() { note(["fordInquire"]) }
            function maintenacneInquire() { note(["serviceInquire"]) }
            function versionInquire() { note(["versionInquire"]) }
            function setRtc(rtc) { note(["setRtc",rtc]) }
            function setBright(dark, bright) {
                note(["setBright",dark,bright])
                if(dark) g.darkBrightness=Math.floor(bright/25)*25
                else g.lightBrightness=Math.floor(bright/25)*25
            }
            function setOverSpeedWarningEnabled(on) { note(["warnEnabled",on]) }
            function setOverSpeedWarningSpeed(speed) { note(["warnSpeed",speed]) }
            function setMaintentCustomId(id, item) { note(["svcItem",id,item]) }
            function setMaintentMileage(id, mileage) { note(["svcMileage",id,mileage]) }
            function setMaintentDate(id, date) { note(["svcDate",id,date]) }
            function setMaintentReset(id) { note(["svcReset",id]) }
        }
    }
    QtObject {
        id: mTranslationId
        property QtObject item: QtObject {
            property var mFactoryItems: FACTORY_TITLES
            property var mFactoryItemsState: g.factoryStates
            property string mBack: "Back"
            property string mSystemLangSetup: "Language"
            property var mSystemLanguages: ["Chinese", "English", "Japanese", "Traditional Chinese", "Russian", "Arabic",
                                            "Spanish", "German", "Turkish", "Korean", "French", "Italian", "Portuguese", "Hindi"]
            property var mSystemLangPickUp: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
            property var mServiceDefaultItems: ["Oil & Oil filter", "Front brake", "Inspection", "Brake fluid", "Rear brake",
                                                "Filter", "Individual 1", "Individual 2"]
            property var mServiceIndividual1Items: ["Individual 1"].concat(SERVICE_CUSTOM)
            property var mServiceIndividual2Items: ["Individual 2"].concat(SERVICE_CUSTOM)
            property string mSystemDateTime: "Date and time"
            property string mSystemUnits: "Units"
            property string mSystemGeneric: "Display"
            property string mDayBrightness: "Brightness"
            property string mSpeedWarn: "Speed warning"
            property string mSystemVersion: "Version"
            property string mSystemFactory: "Factory"
            property var mSystemSetupUnits: ["Fuel economy", "Speed and distance", "Temperature", "Tyre pressure"]
            property var reset: ["Fixture", "Reset"]
            property string mResetTripInfo: "Reset trip info"
            property var mResetTpms: ["Fixture", "Reset TPMS"]
            property var mResetFactory: ["Fixture", "Factory reset"]
            property var mResetKey: ["Fixture", "Learn key"]
            property string mCalibrateCompass: "Calibrate compass"
            function getVehicleSettingsItem(index) { return index===59?"Oil Life":"Item "+index }
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
""".replace("FACTORY_TITLES", json.dumps(titles)).replace("SERVICE_CUSTOM", json.dumps(
        ["Air filter element", "spark plug", "Wiper", "Tire", "Battery", "Antifreeze", "Throttle", "Shock Absorber",
         "Air conditioning filter element", "Clutch"])))
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
    def capture():
        image = window.grabWindow()
        if not image.isNull():
            return image, "QQuickWindow.grabWindow"
        grab = window.contentItem().grabToImage()
        if grab is not None:
            loop = QtCore.QEventLoop()
            grab.ready.connect(loop.quit)
            QtCore.QTimer.singleShot(2000, loop.quit)
            loop.exec_()
            image = grab.image()
        return image, "QQuickItem.grabToImage"
    def select_page(index):
        window.setProperty("pageUrl", QtCore.QUrl.fromLocalFile(pages[index]["copy"]).toString())
        advance()
        page = window.property("page")
        verify("page instantiated: " + pages[index]["source"], page is not None)
        count = (20,16)[index]
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
        prepared = QtQml.QQmlComponent(engine, QtCore.QUrl.fromLocalFile(str(fixture/"RouteMenu.qml")))
        require(prepared.status() == QtQml.QQmlComponent.Ready, "External route marker compile failed")
        verify("menu route absent before MenuPage loads", "file:///etc/vnM.qml" not in intercepted)
        global_state.setProperty("menuBarIndex", 1)
        window.setProperty("pageUrl", "qrc:/Trucks/menu/MenuPage.qml")
        advance()
        page = window.property("page")
        verify("captured MenuPage component instantiated", page is not None)
        loaders = [obj for obj in page.findChildren(QtCore.QObject) if obj.metaObject().className() == "QQuickLoader"]
        sources = [obj.property("source") for obj in loaders]
        # The URL interceptor maps file:///etc/vnM.qml to the fixture marker, so the Loader holds the mapped URL.
        verify("patched MenuPage Loader source evaluates to file:/etc/vnM.qml",
               QtCore.QUrl.fromLocalFile(str(fixture/"RouteMenu.qml")) in sources and
               intercepted.count("file:///etc/vnM.qml") >= 1 and "qrc:/Trucks/menu/MenuItemsList.qml" not in intercepted)
        loop = QtCore.QEventLoop()
        completed = QtCore.QTimer()
        completed.setInterval(10)
        completed.timeout.connect(lambda: loop.quit() if page.findChild(QtCore.QObject, "route-menu") is not None else None)
        completed.start()
        QtCore.QTimer.singleShot(1000, loop.quit)
        loop.exec_()
        completed.stop()
        route = page.findChild(QtCore.QObject, "route-menu")
        verify("nested loader requested file:///etc/vnM.qml", "file:///etc/vnM.qml" in intercepted)
        verify("nested loader created route-menu", route is not None)
        verify("compiled MenuItemsList never requested", not any("MenuItemsList" in url for url in intercepted + callbacks))
        QtCore.QMetaObject.invokeMethod(page, "key", QtCore.Qt.QueuedConnection,
            QtCore.Q_ARG("QVariant", value(global_state, "swcDown")), QtCore.Q_ARG("QVariant", 0))
        advance()
        verify("MenuPage forwards keys to vnM", value(route, "keys") == [[value(global_state, "swcDown"), 0]])
        metadata = json.loads(next((ROOT/"analysis/capture-04/qml-cache").glob("024-*MenuPage.qml.json")).read_text())
        loader = next(entry for entry in metadata["objects"] if entry.get("id") == "mMenuListId")
        binding = next(entry for entry in loader["bindings"] if entry["property"] == "source")
        record = metadata["strings"][binding["string_index"]]
        verify("MenuPage source binding uses the redirected string record",
               binding["type"] == "String" and binding["string_index"] == 41 and record["file_offset"] == 4002512 and
               record["value"] == "qrc:/Trucks/menu/MenuItemsList.qml")
        result["menu_loader_binding"] = dict(object_index=loader["index"], string_index=binding["string_index"],
                                             record_file_offset=record["file_offset"], original=record["value"],
                                             replacement="file:/etc/vnM.qml")
        errors = [message for message in result["messages"] if "TypeError" in message or "ReferenceError" in message]
        result.update(passed=all(entry["passed"] for entry in checks) and not errors and not denied,
                      redirect_checks=checks, evaluated_loader_sources=[url.toString() for url in sources], qml_errors=errors,
                      cache_callbacks=callbacks, intercepted_urls=intercepted, denied_urls=denied,
                      native_writes=False,
                      proof_scope="Patched MenuPage Loader and a nested marker for vnM. No dashboard or native vehicle plugin.")
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
    no_effect = [6, 10, 11, 12, 13, 16, 17]
    verify("factory actions skip rows with no effect", value(global_state,"factoryCalls") == [i for i in range(19) if i not in no_effect])
    verify("rows with no effect show the reason", all(value(rows[i],"mData") == "No effect in this firmware" for i in no_effect)
           and value(rows[0],"mData") in ("ON","OFF"))
    press(QtCore.Qt.Key_Down)
    press(QtCore.Qt.Key_Return)
    verify("general Back returns to catalog", value(global_state,"menuSettingsSubPageItemSetup") == 0 and len(value(global_state,"factoryCalls")) == 12)
    catalog, menu, catalog_rows = select_page(1)
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
    # Settings menu engine (vnM). Failure modes, each with a check below:
    # - Keys: action on press; no wrap; Left/Right/Modes mapped wrong; Back skips or stays at the top; Back hold leaves the menu open;
    #   a release after a hold acts again; repeated hold events act twice; a held key eats the next real tap; state 3 acts.
    # - Pages: re-entry resumes an old cursor or edit; Back loses the parent row; an inquiry runs on highlight or twice per entry.
    # - Ford: plausible values or sends before truck data; oil life sends >100 or <10, sends while editing or on cancel;
    #   camera sends Fault (2); off-list lamp value sticks or sends without a change; read-back missing, early, or repeated.
    # - Actions: one OK sends; an armed row survives another key, the 5 s timeout, or leaving the page; wrong Reset command.
    # - Clock: set row editable while GPS sets the clock; Feb day accepted past the month end; unpadded string; cancel sends.
    # - Display, Units, Service: wrong commit value; unit side effects; no-data text; wrong custom name; reset without confirm.
    # - Hosted pages: keys not forwarded; no return on menuSettingsPageIndex 0; a Modes hold leaves the hosted guard stuck.
    menu_url = QtCore.QUrl.fromLocalFile(pages[2]["copy"]).toString()
    menu_state = {}
    def load_menu():
        window.setProperty("pageUrl", "")
        advance()
        window.setProperty("pageUrl", menu_url)
        advance()
        menu_state["page"] = window.property("page")
        return menu_state["page"]
    def swc(name, state):
        QtCore.QMetaObject.invokeMethod(menu_state["page"], "key", QtCore.Qt.QueuedConnection,
            QtCore.Q_ARG("QVariant", value(global_state, "swc" + name)), QtCore.Q_ARG("QVariant", state))
        advance()
    def tap(name, count=1):
        for unused in range(count):
            swc(name, 1)
            swc(name, 0)
    def m(name):
        return value(menu_state["page"], name)
    def rows():
        return m("mRows")
    def titles():
        return [row["title"] for row in rows()]
    def values():
        return [row["value"] for row in rows()]
    def row(title):
        return next(entry for entry in rows() if entry["title"] == title)
    def focus(title):
        index = titles().index(title)
        for unused in range(len(rows())):
            if m("mCursor") == index:
                return
            tap("Down")
        require(m("mCursor") == index, "menu focus failed: " + title)
    def open_path(*names):
        for name in names:
            focus(name)
            tap("Enter")
    def log():
        return value(event_state, "log")
    def calls_since(mark):
        return log()[mark:]
    def sends(mark):
        return [entry for entry in calls_since(mark) if not str(entry[0]).endswith("Inquire")]
    def inquiries(mark, name):
        return [entry for entry in calls_since(mark) if entry[0] == name]
    def hosted_catalog():
        return [obj for obj in menu_state["page"].findChildren(QtCore.QObject)
                if obj.metaObject().className().startswith("SwipeView") and obj.property("count") == 16]
    def wait_until(predicate, limit_ms):
        # QML Timers follow the animation clock, which can lag real time in the offscreen harness. Poll up to a bound.
        start = time.monotonic()
        while not predicate() and (time.monotonic() - start) * 1000 < limit_ms:
            QtTest.QTest.qWait(20)
        return predicate()
    def assign(name, array):
        QtCore.QMetaObject.invokeMethod(global_state, "assign", QtCore.Qt.DirectConnection,
                                        QtCore.Q_ARG("QVariant", name), QtCore.Q_ARG("QVariant", array))
    swc_code = {name: value(global_state, "swc" + name) for name in ("Back", "Down", "Enter", "Modes")}
    global_state.setProperty("vehicleModel", 1)
    global_state.setProperty("menuBarIndex", 1)
    global_state.setProperty("menuBarItemIndex", 1)
    global_state.setProperty("menuSettingsPageIndex", 3)
    global_state.setProperty("menuSettingsSubPageItemSetup", 0)
    menu = load_menu()
    verify("menu instantiated", menu is not None)
    verify("menu open resets the list indexes", value(global_state, "menuBarItemIndex") == 0 and value(global_state, "menuSettingsPageIndex") == 0)
    verify("menu root fits the MenuPage slot", menu.property("width") == 1720 and menu.property("height") == 511)
    verify("menu top rows", titles() == ["Vehicle", "System", "Service"] and m("mPath") == ["home"] and m("mCursor") == 0)
    mark = len(log())
    swc("Down", 1)
    verify("menu Down press keeps the cursor and shows the press", m("mCursor") == 0 and m("mPressed"))
    swc("Down", 0)
    verify("menu Down release moves the cursor", m("mCursor") == 1 and not m("mPressed"))
    tap("Down", 2)
    verify("menu Down wraps to the first row", m("mCursor") == 0)
    tap("Up")
    verify("menu Up wraps to the last row", m("mCursor") == 2)
    tap("Modes")
    verify("menu Modes release moves down", m("mCursor") == 0)
    verify("menu highlight sends nothing", calls_since(mark) == [])
    tap("Right")
    verify("menu Right opens Vehicle at row 0", m("mPath") == ["home", "vehicle"] and m("mCursor") == 0)
    verify("menu Vehicle rows", titles() == ["Lighting", "Locks", "Driver assist", "Remote start", "Reset", "G-force"])
    verify("menu Vehicle entry runs one setup inquiry", calls_since(mark) == [["fordInquire"]])
    tap("Down", 2)
    tap("Left")
    verify("menu Left returns to the parent row", m("mPath") == ["home"] and m("mCursor") == 0)
    tap("Enter")
    verify("menu re-entry starts at row 0", m("mPath") == ["home", "vehicle"] and m("mCursor") == 0)
    verify("menu each Vehicle entry runs one inquiry", inquiries(mark, "fordInquire") == [["fordInquire"]] * 2)
    open_path("Locks")
    tap("Back")
    verify("menu Back keeps the parent row and sends no inquiry", m("mPath") == ["home", "vehicle"] and m("mCursor") == 1 and
           len(calls_since(mark)) == 2)
    # Ford rows before and after truck data.
    mark = len(log())
    open_path("Driver assist")
    verify("menu assist rows", titles() == ["Trailer brake mode", "Trailer sway control", "Range calculation",
                                            "Easy entry and exit", "Oil life start value", "Off-road camera"])
    verify("menu Ford rows wait for truck data", all(entry["value"] == "Waiting for truck" for entry in rows()))
    for unused in range(6):
        tap("Enter")
        tap("Down")
    verify("menu Ford rows send nothing before data", calls_since(mark) == [] and not m("mEditing"))
    info = [0] * 85
    info[2], info[5], info[6], info[58] = 50, 3, 1, 1
    info[51], info[52], info[56], info[57], info[59], info[70] = 0, 1, 1, 0, 95, 2
    info[63], info[64], info[84] = 0, 1, 1
    assign("fordSetupInfo", info)
    global_state.setProperty("fordSetupKnown", True)
    global_state.setProperty("fordSetupInfoChanged", 1)
    advance()
    verify("menu Ford values after data", values() == ["Electric", "On", "Towing", "Off", "95%", "Fault"])
    focus("Trailer sway control")
    tap("Enter")
    verify("menu toggle sends the other value", calls_since(mark) == [["ford", 14, 1, 0]] and row("Trailer sway control")["value"] == "Off")
    QtTest.QTest.qWait(300)
    verify("menu no read-back before 500 ms", calls_since(mark) == [["ford", 14, 1, 0]])
    verify("menu one read-back after a Ford send", wait_until(lambda: len(calls_since(mark)) >= 2, 4000) and
           calls_since(mark) == [["ford", 14, 1, 0], ["fordInquire"]])
    QtTest.QTest.qWait(600)
    verify("menu read-back runs once", len(calls_since(mark)) == 2)
    mark = len(log())
    focus("Oil life start value")
    tap("Enter")
    verify("menu oil life edit starts at the rounded value", m("mEditing") and m("mEditValue") == 100)
    tap("Down")
    verify("menu oil life edit stops at 100", m("mEditValue") == 100)
    tap("Up", 12)
    verify("menu oil life edit stops at 10", m("mEditValue") == 10)
    tap("Modes")
    verify("menu Modes release is the next value in an edit", m("mEditValue") == 20)
    verify("menu nothing sent while editing", sends(mark) == [])
    tap("Enter")
    verify("menu oil life commits once", sends(mark) == [["ford", 14, 8, 20]] and not m("mEditing") and
           row("Oil life start value")["value"] == "20%")
    tap("Enter")
    tap("Down")
    tap("Left")
    verify("menu Left cancels an edit and stays on the page", sends(mark) == [["ford", 14, 8, 20]] and not m("mEditing") and
           m("mPath")[-1] == "assist" and row("Oil life start value")["value"] == "20%")
    tap("Enter")
    tap("Down")
    tap("Back")
    verify("menu Back cancels an edit and stays on the page", sends(mark) == [["ford", 14, 8, 20]] and not m("mEditing") and
           m("mPath")[-1] == "assist")
    tap("Enter")
    tap("Down")
    tap("Right")
    verify("menu Right commits an edit", sends(mark) == [["ford", 14, 8, 20], ["ford", 14, 8, 30]])
    for raw, start in ((3, 10), (250, 100)):
        info[59] = raw
        assign("fordSetupInfo", info)
        global_state.setProperty("fordSetupInfoChanged", value(global_state, "fordSetupInfoChanged") + 1)
        advance()
        tap("Enter")
        verify("menu oil life edit start clamps " + str(raw), m("mEditValue") == start)
        tap("Back")
    verify("menu oil life never sends outside 10..100", all(10 <= entry[3] <= 100 for entry in sends(mark) if entry[2] == 8))
    wait_until(lambda: calls_since(mark)[-1] == ["fordInquire"], 4000)
    mark = len(log())
    focus("Off-road camera")
    tap("Enter", 3)
    verify("menu camera never sends Fault", sends(mark) == [["ford", 14, 17, 0], ["ford", 14, 17, 1], ["ford", 14, 17, 0]])
    wait_until(lambda: inquiries(mark, "fordInquire"), 4000)
    QtTest.QTest.qWait(600)
    verify("menu one read-back after several sends", inquiries(mark, "fordInquire") == [["fordInquire"]])
    mark = len(log())
    tap("Back")
    open_path("Lighting")
    verify("menu lamp off-list value shows seconds", values() == ["50 s"])
    tap("Enter")
    verify("menu lamp edit starts at the nearest step", m("mEditValue") == 60)
    tap("Enter")
    verify("menu unchanged commit sends nothing", sends(mark) == [] and not m("mEditing"))
    tap("Enter")
    tap("Down")
    tap("Enter")
    verify("menu lamp commit sends the chosen step", sends(mark) == [["ford", 14, 2, 90]] and values() == ["90 s"])
    tap("Enter")
    tap("Up", 5)
    tap("Enter")
    verify("menu lamp Off", sends(mark)[-1] == ["ford", 14, 2, 0] and values() == ["Off"])
    tap("Back")
    open_path("Locks")
    verify("menu lock values", titles() == ["Auto lock", "Auto unlock", "Remote unlock"] and values() == ["Value 3", "On", "Two stage"])
    tap("Enter")
    verify("menu generic toggle sends 0 from an unknown value", sends(mark)[-1] == ["ford", 14, 5, 0] and values()[0] == "Off")
    tap("Back")
    open_path("Remote start")
    verify("menu remote start rows", titles() == ["Front defrost", "Rear defrost", "Passenger seat", "Climate", "Run time",
                                                  "Silent start", "Windshield wiper"])
    focus("Run time")
    verify("menu run time label", row("Run time")["value"] == "5 min")
    tap("Enter")
    tap("Down")
    tap("Enter")
    verify("menu run time commit", sends(mark)[-1] == ["ford", 14, 14, 2] and row("Run time")["value"] == "10 min")
    focus("Climate")
    tap("Enter")
    verify("menu climate toggle", sends(mark)[-1] == ["ford", 14, 13, 1] and row("Climate")["value"] == "Automatic")
    tap("Back")
    # Reset: press-twice confirm with the captured Reset page commands.
    open_path("Reset")
    verify("menu reset rows follow the captured Reset page", titles() == ["Reset TripA", "Reset TripB", "Reset trip info", "Reset TPMS", "Factory reset", "Oil Life"])
    mark = len(log())
    tap("Enter")
    verify("menu one OK arms and sends nothing", sends(mark) == [] and m("mArmedRow") == 0 and
           rows()[0]["value"] == "Press OK again to reset")
    tap("Enter")
    verify("menu second OK sends the Reset command", sends(mark) == [["trip", 0]] and m("mArmedRow") == -1 and
           rows()[0]["value"] == "Reset sent")
    QtTest.QTest.qWait(1000)
    verify("menu Reset sent stays for at least 1 s", rows()[0]["value"] == "Reset sent")
    verify("menu Reset sent clears after 2 s", wait_until(lambda: rows()[0]["value"] == "", 6000))
    tap("Enter")
    tap("Down")
    verify("menu another key disarms and still moves", m("mArmedRow") == -1 and m("mCursor") == 1 and sends(mark) == [["trip", 0]])
    tap("Enter")
    QtTest.QTest.qWait(3500)
    verify("menu armed row holds for at least 3.5 s", m("mArmedRow") == 1)
    verify("menu arm times out after 5 s", wait_until(lambda: m("mArmedRow") == -1, 10000) and rows()[1]["value"] == "")
    tap("Enter")
    verify("menu OK after the timeout arms again", m("mArmedRow") == 1 and sends(mark) == [["trip", 0]])
    tap("Enter")
    for unused in range(4):
        tap("Down")
        tap("Enter")
        tap("Enter")
    verify("menu reset commands match the captured Reset page", sends(mark) == [["trip", 0], ["trip", 1], ["since"], ["tpms"], ["ford", 14, 18, 1], ["oil"]])
    tap("Enter")
    tap("Back")
    open_path("Reset")
    verify("menu leaving drops the armed row", m("mArmedRow") == -1 and m("mCursor") == 0 and len(sends(mark)) == 6)
    tap("Back")
    for vehicle, expected in ((0, ["Reset TripA", "Reset TripB", "Reset trip info", "Reset TPMS"]),
                              (2, ["Reset TripA", "Reset TripB", "Reset trip info", "Reset TPMS", "Factory reset", "Learn key",
                                   "Reset TPMS", "Calibrate compass"])):
        global_state.setProperty("vehicleModel", vehicle)
        tap("Back")
        mark = len(log())
        tap("Enter")
        verify("menu other profile sends no F150 inquiry " + str(vehicle), calls_since(mark) == [])
        verify("menu other profile Ford pages unavailable " + str(vehicle),
               [(entry["kind"], entry["value"]) for entry in rows()[:4]] == [("unavailable", "Not set up for this vehicle profile")] * 4)
        tap("Enter")
        verify("menu unavailable row does nothing " + str(vehicle), m("mPath") == ["home", "vehicle"] and calls_since(mark) == [])
        open_path("Reset")
        verify("menu reset rows for Ford vehicle model " + str(vehicle), titles() == expected)
        tap("Back")
    global_state.setProperty("vehicleModel", 1)
    # Hosted G-force.
    open_path("G-force")
    stub = menu.findChild(QtCore.QObject, "gforce-stub")
    verify("menu G-force hosted on entry", stub is not None and value(global_state, "menuSettingsPageIndex") == 1 and
           m("mPath") == ["home", "vehicle", "gforce"])
    tap("Down")
    verify("menu keys forward to the hosted page", value(stub, "keys") == [[swc_code["Down"], 1], [swc_code["Down"], 0]])
    tap("Back")
    QtTest.QTest.qWait(20)
    verify("menu hosted Back returns to the G-force row", m("mPath") == ["home", "vehicle"] and m("mCursor") == 5 and
           menu.findChild(QtCore.QObject, "gforce-stub") is None)
    tap("Enter")
    stub = menu.findChild(QtCore.QObject, "gforce-stub")
    swc("Back", 1)
    swc("Back", 2)
    verify("menu Back hold closes the menu from a hosted page", value(global_state, "menuBarIndex") == 0)
    swc("Back", 0)
    verify("menu release after the Back hold is swallowed", m("mPath")[-1] == "gforce" and
           [swc_code["Back"], 0] not in value(stub, "keys"))
    # Holds, swallowed releases, and state 3.
    global_state.setProperty("menuBarIndex", 1)
    menu = load_menu()
    verify("menu reopen starts at the top", m("mPath") == ["home"] and m("mCursor") == 0 and
           value(global_state, "menuSettingsPageIndex") == 0)
    swc("Modes", 1)
    swc("Modes", 2)
    swc("Modes", 2)
    swc("Modes", 2)
    verify("menu Modes hold opens the focus row once", m("mPath") == ["home", "vehicle"] and m("mCursor") == 0)
    swc("Modes", 0)
    verify("menu release after the Modes hold is swallowed", m("mCursor") == 0)
    swc("Modes", 1)
    swc("Modes", 2)
    verify("menu second Modes hold opens Lighting", m("mPath") == ["home", "vehicle", "lighting"])
    tap("Back")
    tap("Modes")
    verify("menu a held key does not eat the next tap", m("mPath") == ["home", "vehicle"] and m("mCursor") == 1)
    swc("Enter", 1)
    swc("Enter", 2)
    swc("Enter", 0)
    verify("menu Enter hold does nothing and the release is swallowed", m("mPath") == ["home", "vehicle"] and m("mCursor") == 1)
    swc("Down", 1)
    swc("Down", 2)
    swc("Down", 0)
    verify("menu Down hold does nothing", m("mCursor") == 1)
    swc("Down", 3)
    swc("Enter", 3)
    swc("Back", 3)
    verify("menu state 3 is ignored", m("mPath") == ["home", "vehicle"] and m("mCursor") == 1)
    tap("Back")
    tap("Back")
    verify("menu Back at the top closes the menu", value(global_state, "menuBarIndex") == 0)
    # System: hosted Factory, Version, Language, Date and time, Units, Display.
    global_state.setProperty("menuBarIndex", 1)
    menu = load_menu()
    mark = len(log())
    open_path("System")
    verify("menu System rows", titles() == ["Language", "Date and time", "Units", "Display", "Version", "Factory"])
    tap("Down", 5)
    verify("menu Version and Factory highlight sends nothing", calls_since(mark) == [])
    tap("Enter")
    catalog_views = hosted_catalog()
    verify("menu Factory hosts the owned catalog", len(catalog_views) == 1 and value(global_state, "menuSettingsPageIndex") == 1)
    tap("Down")
    verify("menu keys forward to Factory", catalog_views[0].property("currentIndex") == 1)
    tap("Up")
    swc("Modes", 1)
    swc("Modes", 2)
    verify("menu Modes hold enters the Factory row", value(global_state, "menuSettingsSubPageItemSetup") == 5)
    swc("Modes", 0)
    tap("Back")
    verify("menu Factory sub page Back", value(global_state, "menuSettingsSubPageItemSetup") == 0)
    tap("Modes")
    verify("menu Factory Modes tap still moves after a hold", hosted_catalog()[0].property("currentIndex") == 1)
    tap("Back")
    QtTest.QTest.qWait(20)
    verify("menu Factory Back returns to the Factory row", m("mPath") == ["home", "system"] and m("mCursor") == 5 and not hosted_catalog())
    mark = len(log())
    focus("Version")
    tap("Enter")
    verify("menu Version rows", titles() == ["App", "Plugins", "Protocol"] and
           values() == ["Safe Qt fixture", "plugins@fixture", "mcu@fixture"])
    verify("menu Version entry runs one inquiry", calls_since(mark) == [["versionInquire"]])
    tap("Enter")
    verify("menu info rows do nothing", m("mPath")[-1] == "version" and calls_since(mark) == [["versionInquire"]])
    tap("Back")
    focus("Language")
    verify("menu Language row shows the current language", row("Language")["value"] == "English")
    tap("Enter")
    verify("menu language rows follow the region list", titles() == ["Chinese", "English", "Japanese", "Traditional Chinese",
           "Russian", "Arabic", "Spanish", "German", "Turkish", "Korean", "French", "Italian", "Portuguese"] and
           rows()[1]["value"] == "Selected" and m("mCursor") == 0)
    tap("Down", 2)
    tap("Enter")
    verify("menu Enter sets the language", value(global_state, "language") == 2 and rows()[2]["value"] == "Selected")
    tap("Up")
    tap("Enter")
    verify("menu language restored", value(global_state, "language") == 1)
    tap("Back")
    mark = len(log())
    open_path("Date and time")
    verify("menu clock rows", titles() == ["GPS sets the clock", "Set date and time", "Time format"])
    verify("menu set row unavailable while GPS sets the clock",
           (row("Set date and time")["kind"], row("Set date and time")["value"]) == ("unavailable", "Off while GPS sets the clock"))
    focus("Set date and time")
    tap("Enter")
    verify("menu unavailable clock row does nothing", not m("mEditing") and sends(mark) == [])
    focus("GPS sets the clock")
    verify("menu GPS clock On", row("GPS sets the clock")["value"] == "On")
    tap("Enter")
    verify("menu GPS clock toggle", value(global_state, "gpsAutoSetRtcEnabled") == 0 and row("GPS sets the clock")["value"] == "Off"
           and row("Set date and time")["kind"] == "date")
    global_state.setProperty("rtcDate", "2028-01-31")
    global_state.setProperty("rtcTime", "07:05")
    focus("Set date and time")
    tap("Enter")
    verify("menu clock editor starts from the clock", m("mEditing") and m("mEditFields") == [2028, 1, 31, 7, 5] and m("mEditField") == 0)
    tap("Enter")
    tap("Down")
    verify("menu Feb 2028 clamps the day to 29", m("mEditFields") == [2028, 2, 29, 7, 5] and m("mEditField") == 1)
    tap("Enter")
    tap("Down")
    verify("menu day wraps after Feb 29", m("mEditFields")[2] == 1)
    tap("Up")
    verify("menu day wraps back to Feb 29", m("mEditFields")[2] == 29)
    tap("Back")
    verify("menu Back cancels the clock edit", not m("mEditing") and sends(mark) == [])
    global_state.setProperty("rtcDate", "2027-01-30")
    tap("Enter")
    verify("menu clock re-edit starts fresh", m("mEditFields") == [2027, 1, 30, 7, 5] and m("mEditField") == 0)
    tap("Enter")
    tap("Down")
    verify("menu Feb 2027 clamps the day to 28", m("mEditFields")[2] == 28)
    tap("Enter", 3)
    verify("menu clock sends nothing before the last field", sends(mark) == [] and m("mEditField") == 4)
    tap("Enter")
    verify("menu clock commits a padded string once", sends(mark) == [["setRtc", "2027-02-28 07:05:00"]] and not m("mEditing"))
    global_state.setProperty("rtcDate", "2020-05-05")
    tap("Enter")
    verify("menu clock year starts inside 2024..2099", m("mEditFields")[0] == 2024)
    tap("Up")
    verify("menu clock year wraps to 2099", m("mEditFields")[0] == 2099)
    tap("Left")
    focus("Time format")
    verify("menu time format 24 h", row("Time format")["value"] == "24 h")
    tap("Enter")
    verify("menu time format toggle", value(global_state, "rtc24h") == 0 and row("Time format")["value"] == "12 h" and
           sends(mark)[-1] == ["unit2", 5, 0])
    tap("Back")
    for name, flag in (("metricSystem", 1), ("temperatureUnit", 1), ("speedUnitOverride", 0), ("tempUnitOverride", 0),
                       ("followUnit", 1), ("consumptionUnit", 0), ("pressureUnit", 0)):
        global_state.setProperty(name, flag)
    mark = len(log())
    open_path("Units")
    verify("menu unit titles keep the Units page rows", titles() == ["Fuel economy", "Speed and distance", "Temperature", "Tyre pressure",
                                                       "Follow vehicle units"])
    focus("Speed and distance")
    tap("Enter")
    verify("menu speed manual override", value(global_state, "speedUnitOverride") == 1 and value(global_state, "metricSystem") == 0
           and sends(mark) == [["unit2", 2, 0]])
    focus("Temperature")
    tap("Enter")
    verify("menu temperature manual override", value(global_state, "tempUnitOverride") == 1 and value(global_state, "temperatureUnit") == 0
           and sends(mark) == [["unit2", 2, 0], ["unit2", 1, 0]])
    verify("menu manual status text", "Manual" in row("Speed and distance")["value"] and "Manual" in row("Temperature")["value"])
    focus("Follow vehicle units")
    tap("Enter")
    verify("menu Follow clears manual state", value(global_state, "speedUnitOverride") == 0 and
           value(global_state, "tempUnitOverride") == 0 and sends(mark)[-1] == ["follow"])
    verify("menu Follow status text", "Follow" in row("Speed and distance")["value"] and "Follow" in row("Temperature")["value"])
    focus("Fuel economy")
    tap("Enter")
    tap("Down")
    verify("menu fuel economy edit is local", value(global_state, "consumptionUnit") == 0)
    tap("Enter")
    verify("menu fuel economy commit", value(global_state, "consumptionUnit") == 1 and row("Fuel economy")["value"] == "km/L")
    focus("Tyre pressure")
    tap("Enter")
    tap("Up")
    tap("Enter")
    verify("menu tyre pressure choice wraps", value(global_state, "pressureUnit") == 3 and len(sends(mark)) == 3)
    tap("Back")
    mark = len(log())
    open_path("Display")
    verify("menu display rows", titles() == ["Day brightness", "Night brightness", "Speed warning", "Speed warning at"] and
           values()[:3] == ["50%", "0%", "Off"])
    tap("Enter")
    verify("menu day brightness edit starts at the level", m("mEditValue") == 50)
    tap("Down")
    tap("Enter")
    verify("menu day brightness commit", sends(mark) == [["setBright", 0, 150]] and row("Day brightness")["value"] == "60%")
    focus("Night brightness")
    tap("Enter")
    tap("Up")
    verify("menu night brightness starts at 10", m("mEditValue") == 10)
    tap("Enter")
    tap("Enter")
    tap("Down")
    tap("Enter")
    verify("menu night brightness commit", sends(mark) == [["setBright", 0, 150], ["setBright", 1, 50]])
    verify("menu speed warning value unavailable while off",
           (row("Speed warning at")["kind"], row("Speed warning at")["value"]) == ("unavailable", "Turn on the speed warning first"))
    focus("Speed warning at")
    tap("Enter")
    verify("menu unavailable speed row does nothing", not m("mEditing") and len(sends(mark)) == 2)
    focus("Speed warning")
    tap("Enter")
    verify("menu speed warning toggle", value(global_state, "overSpeedWarningEnabled") == 1 and sends(mark)[-1] == ["warnEnabled", 1])
    focus("Speed warning at")
    tap("Enter")
    tap("Up")
    verify("menu speed warning edit starts at 20", m("mEditValue") == 20)
    tap("Down")
    tap("Enter")
    verify("menu speed warning commit", sends(mark)[-1] == ["warnSpeed", 25])
    global_state.setProperty("overSpeedWarningSpeed", 199)
    tap("Enter")
    tap("Down")
    verify("menu speed warning stops at 200", m("mEditValue") == 200)
    tap("Back")
    tap("Back")
    tap("Back")
    # Service.
    global_state.setProperty("mainTentCustomize1", 2)
    mark = len(log())
    open_path("Service")
    verify("menu Service entry runs one inquiry", calls_since(mark) == [["serviceInquire"]])
    verify("menu service titles", titles() == ["Oil & Oil filter", "Front brake", "Inspection", "Brake fluid", "Rear brake",
                                               "Filter", "spark plug", "Individual 2"])
    verify("menu service no-data text", all(entry == "No data from adapter" for entry in values()))
    verify("menu service colours", [entry["color"] for entry in rows()] ==
           ["white", "orange", "red", "white", "orange", "red", "white", "white"])
    for name, data in (("mainTentReminder", 1000), ("mainTentMileage", 8000), ("mainTentYear", 27), ("mainTentMonth", 3), ("mainTentDay", 15)):
        array = value(global_state, name)
        array[0] = data
        assign(name, array)
    global_state.setProperty("mainTentChanged", 1)
    advance()
    verify("menu service reminder text", values()[0] == "1000 km")
    open_path("Oil & Oil filter")
    verify("menu service item rows", titles() == ["Next service date", "Service interval", "Reset"] and
           values() == ["2027/3/15", "8000 km", ""])
    tap("Enter")
    verify("menu service date starts from the stored date", m("mEditFields") == [2027, 3, 15])
    tap("Enter")
    tap("Down")
    tap("Enter")
    verify("menu service date waits for the last field", sends(mark) == [])
    tap("Enter")
    verify("menu service date commit", sends(mark) == [["svcDate", 0, "2027-4-15"]])
    QtTest.QTest.qWait(300)
    verify("menu no service read-back before 500 ms", inquiries(mark, "serviceInquire") == [["serviceInquire"]])
    verify("menu one service read-back", wait_until(lambda: len(inquiries(mark, "serviceInquire")) >= 2, 4000) and
           inquiries(mark, "serviceInquire") == [["serviceInquire"]] * 2)
    focus("Service interval")
    tap("Enter")
    verify("menu interval edit starts from the stored interval", m("mEditValue") == 8000)
    tap("Down")
    tap("Enter")
    verify("menu interval commit", sends(mark)[-1] == ["svcMileage", 0, 8500])
    focus("Reset")
    tap("Enter")
    verify("menu service reset arms", m("mArmedRow") == 2 and sends(mark)[-1] == ["svcMileage", 0, 8500])
    tap("Enter")
    verify("menu service reset sends", sends(mark)[-1] == ["svcReset", 0])
    wait_until(lambda: len(inquiries(mark, "serviceInquire")) >= 3, 4000)
    QtTest.QTest.qWait(600)
    verify("menu service read-back once per burst", len(inquiries(mark, "serviceInquire")) == 3)
    tap("Back")
    focus("Rear brake")
    tap("Enter")
    focus("Next service date")
    tap("Enter")
    today = time.localtime()
    verify("menu service date without data starts today", m("mEditFields") == [max(2024, today.tm_year), today.tm_mon, today.tm_mday])
    tap("Back")
    tap("Back")
    open_path("spark plug")
    verify("menu custom rows", titles() == ["Item", "Next service date", "Service interval", "Reset"] and values()[0] == "spark plug")
    tap("Enter")
    tap("Down")
    tap("Enter")
    verify("menu custom item commit", value(global_state, "mainTentCustomize1") == 3 and sends(mark)[-1] == ["svcItem", 6, 3] and
           values()[0] == "Wiper")
    focus("Service interval")
    tap("Enter")
    tap("Up")
    verify("menu interval without data starts at 0", m("mEditValue") == 0)
    tap("Down")
    tap("Enter")
    verify("menu custom interval commit", sends(mark)[-1] == ["svcMileage", 6, 500])
    tap("Back")
    verify("menu custom name in the service list", titles()[6] == "Wiper")
    # Locked view (round 21 layout A, values B, confirm A): the open path stays on screen as columns.
    global_state.setProperty("menuBarIndex", 1)
    menu = load_menu()
    open_path("Vehicle", "Driver assist")
    focus("Oil life start value")
    tap("Enter")
    # Repeater rows are visual children only, so walk the item tree.
    def item_texts(item):
        found = set()
        for child in item.childItems():
            if child.isVisible() and child.property("text") is not None:
                found.add(child.property("text"))
            found |= item_texts(child)
        return found
    texts = item_texts(sip.cast(menu_state["page"], QtQuick.QQuickItem))
    verify("menu view shows a column for each open page", {"Settings", "Vehicle", "Driver assist"} <= texts)
    verify("menu view keeps the parent rows on screen", {"System", "Lighting", "Remote start"} <= texts)
    verify("menu view shows the edit value with the meter", "‹ 100% ›" in texts)
    verify("menu view shows segment labels", {"Electric", "Electric over hydraulic", "Normal", "Towing"} <= texts)
    verify("menu view shows edit key hints", {"Save", "Cancel"} <= texts and "Close menu" not in texts)
    window.setProperty("previewTitle", "Host Qt fixture preview - settings menu")
    window.resize(1920, 932)
    window.show()
    def preview(name, label):
        QtTest.QTest.qWait(150)
        image, render_method = capture()
        target = fixture / ("preview-menu-" + name + ".png")
        verify("menu preview saved: " + name, not image.isNull() and image.save(str(target)))
        renders.append(dict(path=str(target), method=render_method, sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
                            width=image.width(), height=image.height(), label=label))
    preview("assist-edit", "vnM locked view; Driver assist with an oil life edit.")
    tap("Back")
    texts = item_texts(sip.cast(menu_state["page"], QtQuick.QQuickItem))
    verify("menu view shows browse key hints", {"Select", "Open or change", "Back", "Close menu"} <= texts)
    preview("assist", "vnM locked view; Driver assist.")
    tap("Back")
    tap("Back")
    preview("home", "vnM locked view; Settings home.")
    open_path("Vehicle", "Reset")
    tap("Enter")
    texts = item_texts(sip.cast(menu_state["page"], QtQuick.QQuickItem))
    verify("menu view shows the armed reset row", "Press OK again to reset" in texts and "Reset" in texts)
    preview("reset-armed", "vnM locked view; Reset with Trip A armed.")
    tap("Back")
    tap("Back")
    open_path("System", "Units")
    texts = item_texts(sip.cast(menu_state["page"], QtQuick.QQuickItem))
    verify("menu view shows unit segments and the follow note", {"km/h", "mph", "°C", "°F", "Follow"} <= texts)
    preview("units", "vnM locked view; System > Units.")
    window.setProperty("pageUrl", "")
    advance()
    result["menu_scope"] = ("vnM engine on host Qt with safe stubs. G-force uses a stub with the compiled Back contract; "
                            "Factory hosts the owned vnF copy. Native calls record arguments only.")
    # Capture fixture previews with actual cached component geometry and safe state.
    for page_index, title in ((0,"General settings"),(1,"Factory menu")):
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
            image, render_method = capture()
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
    parser.add_argument("--candidate-dir", default=str(ROOT / "analysis/capture-04/ui-candidate-menu-v1"))
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
        process = subprocess.run(page_command, capture_output=True, text=True, timeout=150)
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
