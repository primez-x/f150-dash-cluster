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
# The release candidate Launcher (tools/usb-install/encrypt.sh CANDIDATE_SHA256).
CANDIDATE_SHA256 = "e5f223441e454e1c6707bec6f775eccdab4ab7760a874f0b16abe7bfc5db238c"
PHASES = ("empty-source-control", "original-vendor-header", "original-adapted", "patched-adapted",
          "patched-settings-adapted", "patched-settings-redirects", "candidate-compile", "settings-pages",
          "dashboard-differential", "dashboard-keys", "dashboard-layout", "original-notify-table", "patched-notify-table")
DASHBOARD_PHASES = ("dashboard-differential", "dashboard-keys", "dashboard-layout")
NOTIFY_PHASES = ("original-notify-table", "patched-notify-table")
# Translation (cache 012) and the string record that names the notification text table (string 3327, fn 392).
TRANSLATION_SPAN = (1170000, 332652)
NOTIFY_RECORD = 1487208
# The text tables that Translation loads by mRccPrefix + "/common/<name>" (fn 385-400).
TRANSLATION_TABLES = ("VehicleSetupTranslation", "SystemSetupTranslation", "ServiceTranslation", "FactoryTranslation",
                      "SeniorFactoryTranslation", "NotifyTranslation", "CenterInfoTranslation", "CommonTranslation",
                      "VehicleMeter", "VehicleModels", "FuelWaterMeter", "AlarmTable")


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
    # The cluster has these fonts in /usr/share/fonts; the design handoff carries the same files.
    for name in ("BMW.ttf", "KonexyPersonalUseRegular.ttf"):
        QtGui.QFontDatabase.addApplicationFont(str(ROOT / "handoff/claude-dashboard/assets/fonts" / name))
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
                (47188, 47208, 46, "file:/etc/vnG.qml"),
                (48140, 48160, 52, "file:/etc/vnD.qml")):
            encoded = value.encode("utf-16le")
            struct.pack_into("<I", reconstructed, length_start - MAIN_OFFSET, len(value))
            relative = payload_start - MAIN_OFFSET
            reconstructed[relative:relative + capacity] = encoded + bytes(capacity - len(encoded))
        require(unit == reconstructed, 'Candidate main differs beyond the three reviewed redirect records')
        # Translation (cache 012): the one notification table record, "/common/NotifyTranslation.qml" -> "vnN.qml".
        start, size = TRANSLATION_SPAN
        translation = bytearray(original[start:start + size])
        require(struct.unpack_from("<iiIIQ", translation, NOTIFY_RECORD - start) == (-1, 29, 0, 24, 24)
                and translation[NOTIFY_RECORD - start + 24:NOTIFY_RECORD - start + 84] == "/common/NotifyTranslation.qml".encode("utf-16le") + bytes(2),
                "Original notification table record mismatch")
        struct.pack_into("<i", translation, NOTIFY_RECORD - start + 4, 7)
        translation[NOTIFY_RECORD - start + 24:NOTIFY_RECORD - start + 84] = "vnN.qml".encode("utf-16le") + bytes(46)
        require(raw[start:start + size] == translation, "Candidate Translation differs beyond the notification table record")
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
            require(original_digest == CANDIDATE_SHA256, "Menu candidate identity mismatch")
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
    if phase in DASHBOARD_PHASES:
        # Compiled units that run unchanged under both shells, from the original Launcher: the compiled shell
        # Trucks/Dashboard.qml (cache 023), SwcEvent, Trip, TurnLightIndicator, and the GlowText and GlowImage parts.
        for path in ("Trucks/Dashboard.qml", "common/SwcEvent.qml", "Trucks/common/Trip.qml",
                     "Trucks/common/TurnLightIndicator.qml", "Trucks/common/text/GlowText.qml", "Trucks/common/text/GlowImage.qml"):
            metadata = next((ROOT / "analysis/capture-04/qml-cache").glob("*-" + path.replace("/", "_") + ".json"))
            decoded = json.loads(metadata.read_text())
            require(decoded["qrc_path"] == path, "Cache metadata mismatch: " + path)
            require(all(entry["type"] != 1 or entry["uri"].startswith("Qt") for entry in decoded["imports"]), "Unexpected module import: " + path)
            payload = original[decoded["file_offset"]:decoded["file_offset"] + decoded["unit_size"]]
            require(hashlib.sha256(payload).hexdigest() == decoded["sha256"], "Cache unit hash mismatch: " + path)
            require(payload[:8] == b"qv4cdata" and struct.unpack_from("<II", payload, 8) == (37, 331266), "Cache unit header mismatch: " + path)
            ui_units["qrc:/" + path] = payload
            files[path] = ""
        # Stand-ins for the children that the shells load by URL. Menu and Notify record each key they receive;
        # the menu stand-in closes on a Back release, as the compiled menu does. The Notify stand-in answers 0, as the
        # compiled Notify does: ItemInfo.key (cache 189) returns 0 for every key. A translucent fill shows each place.
        fill = 'Rectangle { anchors.fill: parent; color: "#3080c0"; opacity: 0.35; border.color: "#ffffff" }'
        files["Trucks/menu/MenuPage.qml"] = marker("stand-in-menu", "width: 1720; height: 511\n" + fill + "\n"
            "function key(code, state) { mGlobalId.item.note(['menu', code, state]); "
            "if(code===mGlobalId.item.swcBack && state===0) mGlobalId.item.menuBarIndex=0; return 1 }")
        files["Trucks/common/Notify.qml"] = marker("stand-in-notify", "width: 640; height: 90\n" + fill + "\n"
            "function key(code, state) { mGlobalId.item.note(['notify', code, state]); return 0 }")
        for name, size in (("common/DoorInfo", "520; height: 300"), ("common/MaintentNotify", "820; height: 110"),
                           ("common/ShellInfoNotify", "900; height: 140"), ("common/Dragging", "700; height: 120"),
                           ("common/update/UpdateMcu", "760; height: 160")):
            files["Trucks/" + name + ".qml"] = marker("stand-in-" + name.split("/")[-1], "width: " + size + "\n" + fill)
        # The stock layouts that the compiled shell loads.
        for number in range(1, 7):
            files["Trucks/ui" + str(number) + "/Dashboard.qml"] = marker("stock-ui" + str(number),
                "width: " + str(1880 + number) + "; height: " + str(700 + number) + "\n" + fill)
        if phase == "dashboard-layout":
            # The icons that vnL loads from the Launcher resources.
            for name in ("oilTemp", "water"):
                alias = "Trucks/images/common/icon/" + name + ".png"
                (fixture / alias).parent.mkdir(parents=True, exist_ok=True)
                (fixture / alias).write_bytes((ROOT / "recovered-resources/latest-Launcher" / alias).read_bytes())
                files[alias] = None
        # Turn arrow images: the compiled TurnLightIndicator names each image without the file suffix.
        for name in ("tsico_left_n", "tsico_left_h", "tsico_right_n", "tsico_right_h"):
            image = (ROOT / "recovered-resources/latest-Launcher/Trucks/images/common/turnlight" / (name + ".png")).read_bytes()
            for alias in ("Trucks/images/common/turnlight/" + name, "Trucks/images/common/turnlight/" + name + ".png"):
                (fixture / alias).parent.mkdir(parents=True, exist_ok=True)
                (fixture / alias).write_bytes(image)
                files[alias] = None
        result["compiled_units"] = {url: hashlib.sha256(payload).hexdigest() for url, payload in ui_units.items()}
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
                "file:///etc/vnV.qml": fixture / "ExternalVehicle.qml",
                "file:///etc/vnD.qml": fixture / "ExternalDashboard.qml"}
    external["file:///etc/vnG.qml"].write_text(marker("external-global", props))
    external["file:///etc/vnV.qml"].write_text(marker("external-vehicle"))
    external["file:///etc/vnD.qml"].write_text(marker("external-dashboard"))
    # URL prefixes that map to a directory (the installed /etc/images of the layout phase).
    prefixes = {}
    # A component opened from /etc makes the engine read /etc/qmldir for the implicit directory import.
    external["file:///etc/qmldir"] = fixture / "isolated-etc-qmldir"
    external["file:///etc/qmldir"].write_text("")
    if phase == "patched-settings-redirects":
        external["file:///etc/vnM.qml"] = fixture / "RouteMenu.qml"
        external["file:///etc/vnM.qml"].write_text('import QtQuick 2.12\nItem { objectName: "route-menu"; property var keys: []; '
                                                   'function key(code,state) { keys=keys.concat([[code,state]]); return 1 } }')
        result["safe_directory_probe_mapping"] = {"file:///etc/qmldir": str(external["file:///etc/qmldir"])}
    if phase in NOTIFY_PHASES:
        # The compiled Translation (cache 012) from the Launcher under test, and the stock text tables at the URLs that
        # the cluster forms: Global mRccPrefix "file:///etc/" + "/common/<name>.qml". The candidate reads vnN instead.
        start, size = TRANSLATION_SPAN
        decoded = json.loads(next((ROOT / "analysis/capture-04/qml-cache").glob("012-*.json")).read_text(encoding="utf-8"))
        require(decoded["qrc_path"] == "common/Translation.qml" and (decoded["file_offset"], decoded["unit_size"]) == (start, size),
                "Translation cache metadata mismatch")
        require(hashlib.sha256(original[start:start + size]).hexdigest() == decoded["sha256"], "Translation cache unit hash mismatch")
        ui_units["qrc:/common/Translation.qml"] = raw[start:start + size]
        files["common/Translation.qml"] = ""
        (fixture / "etc-common").mkdir()
        for name in TRANSLATION_TABLES:
            copy = fixture / "etc-common" / (name + ".qml")
            copy.write_bytes((ROOT / "installed/capture-04/rootfs/etc/common" / (name + ".qml")).read_bytes())
            external["file:///etc//common/" + name + ".qml"] = copy
        # The cluster has no qmldir in /etc/common; the implicit directory import reads the empty fixture file.
        external["file:///etc//common/qmldir"] = external["file:///etc/qmldir"]
        if phase == "patched-notify-table":
            (fixture / "etc").mkdir()
            external["file:///etc/vnN.qml"] = fixture / "etc/vnN.qml"
            external["file:///etc/vnN.qml"].write_bytes((ROOT / "patches/capture-04/etc/vnN.qml").read_bytes())
    if phase in DASHBOARD_PHASES:
        # The owned shell and the layout file under the URLs that main.qml and vnD open, in an isolated directory.
        # dashboard-layout runs the real vnL with the images that vnL reads from /etc/images (mRccPrefix); the other
        # dashboard phases run the layout stand-in.
        (fixture / "etc").mkdir()
        external["file:///etc/vnD.qml"] = fixture / "etc/vnD.qml"
        external["file:///etc/vnD.qml"].write_bytes((ROOT / "patches/capture-04/etc/vnD.qml").read_bytes())
        external["file:///etc/vnL.qml"] = fixture / "etc/vnL.qml"
        external["file:///etc/vnL.qml"].write_bytes((ROOT / "patches/capture-04/etc/vnL.qml").read_bytes()
                                                     if phase == "dashboard-layout" else LAYOUT_STAND_IN.encode("utf-8"))
        if phase == "dashboard-layout":
            prefixes["file:///etc/images/"] = ROOT / "handoff/claude-dashboard/assets/installed"
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
            for prefix, folder in prefixes.items():
                if value.startswith(prefix):
                    target = (folder / value[len(prefix):]).resolve()
                    if target.is_relative_to(folder.resolve()):
                        return QtCore.QUrl.fromLocalFile(str(target))
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
        if phase in ("settings-pages", "patched-settings-redirects") + DASHBOARD_PHASES + NOTIFY_PHASES:
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
    if phase in DASHBOARD_PHASES:
        engine.rootContext().setContextProperty("mTrucksModel", 1)
        if phase == "dashboard-differential":
            return dashboard_differential(fixture, result, engine, callbacks, intercepted, denied, ui_units)
        return dashboard_keys(fixture, result, engine, callbacks, intercepted, denied, ui_units,
                              real_layout=phase == "dashboard-layout")
    if phase in NOTIFY_PHASES:
        engine.rootContext().setContextProperty("mTrucksModel", 1)
        # The Launcher sets mRegion from its REGION argument: /etc/qtenv.sh passes REGION from /etc/model (2).
        engine.rootContext().setContextProperty("mRegion", "2")
        return notify_table(fixture, result, engine, callbacks, intercepted, denied)
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
    expected = ({"embedded-global", "embedded-vehicle", "dashboard-stub"} if phase.startswith("original")
                else {"external-global", "external-vehicle", "external-dashboard"})
    result["expected_markers"] = sorted(expected)
    if phase == "empty-source-control":
        expected = set()
    result["expected_markers"] = sorted(expected)
    actual_pair = set(markers) & {"embedded-global", "embedded-vehicle", "external-global", "external-vehicle",
                                  "dashboard-stub", "external-dashboard"}
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


def capture(window):
    from PyQt5 import QtCore
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
    for name, alias in (("vnM.qml", "Menu.qml"), ("vnS.qml", "Grid.qml")):
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
            property int dashboardBeforeTow: -1
            property int towDashboard: 1
            property int mediaImageEnabled: 0
            property int screenGridEnabled: 0
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
    # - Factory: an inquiry missing or repeated; a press or highlight acts; a row with no effect sends; a compiled page does
    #   not open, stays open after its Back, or leaves menuSettingsSubPageItemSetup set; a nested compiled page closes early;
    #   Back hold leaves a compiled page value behind; a debug level outside the vendor list; the grid leaves the menu open.
    titles_general = titles
    menu_url = QtCore.QUrl.fromLocalFile(pages[0]["copy"]).toString()
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
    global_state.setProperty("menuBarIndex", 1)
    menu = load_menu()
    tap("Down")
    swc("Left", 1)
    swc("Left", 2)
    verify("menu Left hold closes the menu (the truck wheel has no Back key)", value(global_state, "menuBarIndex") == 0)
    swc("Left", 0)
    verify("menu release after the Left hold is swallowed", value(global_state, "menuBarIndex") == 0 and m("mCursor") == 1)
    # System: hosted Factory, Version, Language, Date and time, Units, Display.
    global_state.setProperty("menuBarIndex", 1)
    menu = load_menu()
    mark = len(log())
    open_path("System")
    verify("menu System rows", titles() == ["Language", "Date and time", "Units", "Display", "Version", "Factory"])
    tap("Down", 5)
    verify("menu Version and Factory highlight sends nothing", calls_since(mark) == [])
    mark = len(log())
    tap("Enter")
    verify("menu Factory is a native page with one shell inquiry", m("mPath") == ["home", "system", "factory"] and
           calls_since(mark) == [["shellCmdInquire"]] and value(global_state, "menuSettingsPageIndex") == 0)
    verify("menu Factory rows", titles() == ["General settings", "Advanced settings", "Fuel tank setup", "Vehicle profile",
                                             "Odometer setup", "Service commands", "ADB debugging: enable",
                                             "ADB debugging: disable", "Debug logging", "USB image preview", "Screen grid",
                                             "Car model options"])
    verify("menu Factory entry leaves the tools unchanged", value(event_state, "adbCalls") == [] and
           value(global_state, "uartDebugEnabled") == 0 and value(global_state, "mediaImageEnabled") == 0 and
           value(global_state, "modelCarSelection") is False)
    # General settings: a native page with the 19 vendor rows.
    no_effect = [6, 10, 11, 12, 13, 16, 17]
    mark = len(log())
    tap("Enter")
    verify("menu General settings runs one system inquiry", m("mPath")[-1] == "general" and calls_since(mark) == [["systemInquire"]])
    verify("menu General settings rows", titles() == titles_general)
    verify("menu General rows with no effect show the reason", all(rows()[i]["kind"] == "unavailable" and
           rows()[i]["value"] == "No effect in this firmware" for i in no_effect) and values()[0] == "Off" and values()[7] == "200")
    for index in range(19):
        before = list(value(global_state, "factoryCalls"))
        swc("Enter", 1)
        verify("menu General press sends nothing " + str(index), value(global_state, "factoryCalls") == before)
        swc("Enter", 0)
        tap("Down")
    verify("menu General sends the vendor setter for rows with an effect",
           value(global_state, "factoryCalls") == [i for i in range(19) if i not in no_effect])
    verify("menu General rows follow the setting", values()[0] == "On" and rows()[0]["current"] == 1 and values()[7] == "210")
    tap("Back")
    verify("menu General Back returns to the Factory row", m("mPath")[-1] == "factory" and m("mCursor") == 0)
    # Compiled Factory pages: the stubs keep the compiled Back contract (1 for Odometer, Fuel tank, Vehicle profile).
    for title, page_value in (("Advanced settings", 1), ("Fuel tank setup", 3), ("Vehicle profile", 4),
                              ("Odometer setup", 2), ("Service commands", 6)):
        focus(title)
        cursor = m("mCursor")
        swc("Enter", 1)
        verify("menu Factory page opens only on release " + str(page_value), value(global_state, "menuSettingsSubPageItemSetup") == 0)
        swc("Enter", 0)
        verify("menu Factory hosts the compiled page " + str(page_value),
               m("mPath")[-1] == "fsub" + str(page_value) and value(global_state, "menuSettingsSubPageItemSetup") == page_value and
               value(global_state, "menuSettingsPageIndex") == 1 and
               menu_state["page"].findChild(QtCore.QObject, "vendor-page-" + str(page_value)) is not None)
        tap("Back")
        verify("menu compiled page Back returns to the Factory row " + str(page_value),
               m("mPath")[-1] == "factory" and m("mCursor") == cursor and value(global_state, "menuSettingsSubPageItemSetup") == 0 and
               value(global_state, "menuSettingsPageIndex") == 0)
    focus("Advanced settings")
    tap("Enter")
    global_state.setProperty("menuSettingsSubPageItemSetup", 3)
    advance()
    verify("menu Advanced settings can open Fuel tank setup", m("mPath")[-1] == "fsub1" and
           menu_state["page"].findChild(QtCore.QObject, "vendor-page-3") is not None)
    tap("Back")
    verify("menu nested Fuel tank Back returns to Advanced settings", m("mPath")[-1] == "fsub1" and
           value(global_state, "menuSettingsSubPageItemSetup") == 1)
    tap("Back")
    verify("menu Advanced settings Back returns to Factory", m("mPath")[-1] == "factory" and value(global_state, "menuSettingsSubPageItemSetup") == 0)
    focus("Fuel tank setup")
    tap("Enter")
    swc("Back", 1)
    swc("Back", 2)
    verify("menu Back hold in a compiled page closes the menu and the page", value(global_state, "menuBarIndex") == 0 and
           m("mPath")[-1] == "factory" and value(global_state, "menuSettingsSubPageItemSetup") == 0)
    swc("Back", 0)
    global_state.setProperty("menuBarIndex", 1)
    for title, argument in (("ADB debugging: enable", 1), ("ADB debugging: disable", 0)):
        focus(title)
        before = list(value(event_state, "adbCalls"))
        swc("Enter", 1)
        verify("menu ADB command waits for release " + str(argument), value(event_state, "adbCalls") == before)
        swc("Enter", 0)
        verify("menu ADB command " + str(argument), value(event_state, "adbCalls") == before + [argument])
    focus("Debug logging")
    verify("menu Debug logging shows the level", row("Debug logging")["value"] == "Off")
    tap("Enter")
    tap("Down", 2)
    verify("menu Debug logging edit", m("mEditText") == "‹ UART receive ›" and value(global_state, "uartDebugEnabled") == 0)
    tap("Enter")
    verify("menu Debug logging sets the vendor value", value(global_state, "uartDebugEnabled") == 2 and
           row("Debug logging")["value"] == "UART receive")
    tap("Enter")
    tap("Down", 3)
    tap("Enter")
    verify("menu Debug logging wraps to Off", value(global_state, "uartDebugEnabled") == 0)
    focus("USB image preview")
    tap("Enter")
    verify("menu USB image preview on", value(global_state, "mediaImageEnabled") == 1 and row("USB image preview")["current"] == 1)
    tap("Enter")
    verify("menu USB image preview off", value(global_state, "mediaImageEnabled") == 0)
    focus("Car model options")
    for state in (1, 2, 2, 0):
        swc("Modes", state)
    verify("menu Modes hold toggles Car model options once", value(global_state, "modelCarSelection") is True and
           m("mCursor") == titles().index("Car model options"))
    tap("Enter")
    verify("menu Car model options off", value(global_state, "modelCarSelection") is False)
    focus("Screen grid")
    swc("Enter", 1)
    verify("menu Screen grid waits for release", value(global_state, "screenGridEnabled") == 0)
    swc("Enter", 0)
    verify("menu Screen grid shows the grid and closes the menu", value(global_state, "screenGridEnabled") == 1 and
           value(global_state, "menuBarIndex") == 0)
    global_state.setProperty("screenGridEnabled", 0)
    global_state.setProperty("menuBarIndex", 1)
    tap("Back")
    verify("menu Factory Back returns to the Factory row", m("mPath") == ["home", "system"] and m("mCursor") == 5)
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
    verify("menu display rows", titles() == ["Dashboard layout", "Day brightness", "Night brightness", "Speed warning",
                                             "Speed warning at"] and values()[:4] == ["Daily", "50%", "0%", "Off"])
    verify("menu layout row is two segments", row("Dashboard layout")["seg"] == ["Daily", "Towing"] and
           row("Dashboard layout")["current"] == 0)
    tap("Enter")
    verify("menu layout OK selects Towing", value(global_state, "dashboard") == 1 and not m("mEditing") and
           row("Dashboard layout")["value"] == "Towing" and row("Dashboard layout")["current"] == 1)
    tap("Enter")
    verify("menu layout OK selects Daily", value(global_state, "dashboard") == 0 and row("Dashboard layout")["current"] == 0)
    global_state.setProperty("dashboard", 1)
    global_state.setProperty("dashboardBeforeTow", 0)
    verify("menu layout notes the Tow/Haul choice", row("Dashboard layout")["value"] == "Towing · Tow/Haul" and
           row("Dashboard layout")["note"] == "Tow/Haul")
    tap("Enter")
    verify("menu layout choice while towing selects Daily", value(global_state, "dashboard") == 0 and
           row("Dashboard layout")["value"] == "Daily")
    global_state.setProperty("dashboardBeforeTow", -1)
    global_state.setProperty("dashboard", 0)
    verify("menu sends no vehicle command for a layout", sends(mark) == [])
    focus("Day brightness")
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
        # Wait past the longest menu motion (280 ms page enter) so the preview shows the settled frame.
        QtTest.QTest.qWait(400)
        image, render_method = capture(window)
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
    # Motion (design/round-41 tokens): the focus highlight slides to the next row, and a page that opens fades in.
    def find_item(item, name):
        for child in item.childItems():
            if child.objectName() == name and child.isVisible():
                return child
            found = find_item(child, name)
            if found is not None:
                return found
        return None
    page_item = sip.cast(menu_state["page"], QtQuick.QQuickItem)
    highlight, menu_view = find_item(page_item, "focusHighlight"), find_item(page_item, "menuView")
    require(m("mCursor") < len(rows())-1 and rows()[m("mCursor")]["kind"] == "page", "motion check needs a page row with a row below")
    start_y = highlight.property("y")
    tap("Down")
    verify("menu focus highlight slides, not jumps", highlight.property("y") < start_y+68-1)
    verify("menu focus highlight settles on the next row", wait_until(lambda: abs(highlight.property("y")-(start_y+68)) < 0.5, 1000))
    tap("Up")
    wait_until(lambda: abs(highlight.property("y")-start_y) < 0.5, 1000)
    tap("Enter")
    verify("menu page fades in, not jumps", menu_view.property("enterOpacity") < 1)
    verify("menu page settles", wait_until(lambda: menu_view.property("enterOpacity") == 1 and menu_view.property("enterX") == 0, 1000))
    tap("Back")
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
    tap("Back")
    open_path("Display")
    global_state.setProperty("dashboard", 1)
    global_state.setProperty("dashboardBeforeTow", 0)
    texts = item_texts(sip.cast(menu_state["page"], QtQuick.QQuickItem))
    verify("menu view shows the layout segments and the Tow/Haul note", {"Dashboard layout", "Daily", "Towing", "Tow/Haul"} <= texts)
    preview("layout-segments", "vnM locked view; Display with the Daily and Towing segments while Tow/Haul holds Towing.")
    global_state.setProperty("dashboardBeforeTow", -1)
    global_state.setProperty("dashboard", 0)
    tap("Back")
    open_path("Factory", "General settings")
    texts = item_texts(sip.cast(menu_state["page"], QtQuick.QQuickItem))
    verify("menu view moves the oldest column off at the fourth level", {"Factory", "General settings"} <= texts and
           "Settings" not in texts and "No effect in this firmware" in texts)
    preview("general", "vnM locked view; System > Factory > General settings.")
    tap("Back")
    preview("factory", "vnM locked view; System > Factory.")
    # Screen grid (vnS): the page fills the window and shows the size, the frame legend, and point labels.
    window.resize(1920, 720)
    window.setProperty("pageUrl", QtCore.QUrl.fromLocalFile(pages[1]["copy"]).toString())
    advance()
    grid = window.property("page")
    verify("grid fills the window", grid is not None and grid.property("width") == 1920 and grid.property("height") == 720)
    texts = item_texts(sip.cast(grid, QtQuick.QQuickItem))
    verify("grid shows the screen size and the frame legend", "Screen 1920 × 720 px · center 960,360" in texts
           and {"white 0", "red 10", "purple 70"} <= texts)
    verify("grid labels points every 200 x 100 px", {"200,100", "1600,600"} <= texts and "1800,100" not in texts)
    QtTest.QTest.qWait(150)
    image, render_method = capture(window)
    target = fixture / "preview-screen-grid.png"
    verify("grid preview saved", not image.isNull() and image.save(str(target)))
    renders.append(dict(path=str(target), method=render_method, sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
                        width=image.width(), height=image.height(), label="vnS screen grid at 1920 x 720."))
    window.setProperty("pageUrl", "")
    advance()
    result["menu_scope"] = ("vnM engine on host Qt with safe stubs. G-force and the compiled Factory pages use stubs with the "
                            "compiled Back contract. Native calls record arguments only.")
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


def tree_differences(left, right, path="shell", found=None):
    # Paths of the first differing item fields in two describe() trees.
    found = [] if found is None else found
    for key in sorted(set(left) | set(right)):
        if key == "children" or len(found) >= 5:
            continue
        if left.get(key) != right.get(key):
            found.append(dict(path=path + "." + key, compiled=left.get(key), owned=right.get(key)))
    pairs = list(zip(left.get("children", []), right.get("children", [])))
    if len(left.get("children", [])) != len(right.get("children", [])) and len(found) < 5:
        found.append(dict(path=path + ".children", compiled=len(left["children"]), owned=len(right["children"])))
    for index, (a, b) in enumerate(pairs):
        tree_differences(a, b, path + "/" + str(index) + ":" + a["type"], found)
    return found


SHELL_HARNESS = r"""import QtQuick 2.12
import QtQuick.Window 2.12
Window {
    width: 1920; height: 932; visible: true; color: "#000000"
    property string pageUrl: ""
    property alias page: pageLoader.item
    property string trace: ""
    property string tree: ""
    property var hookedLoader: null
    property var hookedItem: null
    QtObject {
        id: mGlobalId
        property QtObject item: GLOBAL_ITEM
    }
    QtObject {
        id: mTranslationId
        property QtObject item: QtObject {
            property string mTotal: "ODO"
            property string mTripA: "TRIP A"
            property string mTripB: "TRIP B"
            property string mFontType: "BMW Type Global"
            property string mNotifyTextItem: ""
        }
    }
    // The native event handler of main.qml: the stub records each reset with the time since the last press and counts
    // the overspeed inquiries of the layout.
    QtObject {
        id: mEventHandleId
        property QtObject item: QtObject {
            property int overspeedInquiries: 0
            function resetTrip(trip) { g.note(["resetTrip", trip, Date.now()-g.pressAt]) }
            function overspeedInquire() { overspeedInquiries++ }
        }
    }
    // A dark ground, so the white trip text shows in the previews.
    Rectangle { anchors.fill: parent; color: "#101317" }
    Loader { id: pageLoader; width: 1920; height: 932; source: pageUrl }

    // The probe queues these calls: a load from Python would hold the GIL that the type loader thread needs.
    function open(url) { pageUrl = url }
    function reset() {
        g.dashboard=0; g.vehicleModel=1; g.splashEnd=1; g.menuBarIndex=0; g.doorInfo=0; g.notifyTop=0; g.notifyText=0
        g.notifyDuration=0; g.shellInfoDuration=0; g.mcuUpdateTop=0; g.mainTentShow=0; g.tpmsInfoEnabled=1; g.tripType=1
        g.drivingInfoIndex=0; g.leftInfoIndex=0; g.rightInfoIndex=0; g.swcKey=0; g.swcState=0; g.swcChanged=0
        g.turnLeftLight=0; g.turnRightLight=0; g.calls=[]; g.holds=[]
        var layout=layoutLoader()
        if(layout)
            layout.active=true
        hookLayout()
    }
    function set(name, value) { g[name]=value }
    function clear() { g.calls=[]; g.holds=[] }
    // One wheel event, as VehicleEvent swcDeliver sets the event.
    function deliver(key, state) {
        if(state===1)
            g.pressAt=Date.now()
        g.swcKey=key; g.swcState=state; g.swcChanged=!g.swcChanged
    }
    function loaders() {
        var out=[]
        for(var i=0; i<page.children.length; i++) {
            var c=page.children[i]
            if(c.active!==undefined)
                out.push([String(c.source), !!c.active, c.item?c.item.objectName:""])
        }
        return out
    }
    // The Loader of the layout: /etc/vnL.qml in vnD, Trucks/uiN/Dashboard.qml in the compiled shell.
    function layoutLoader() {
        if(!page)
            return null
        for(var i=0; i<page.children.length; i++) {
            var c=page.children[i]
            if(c.active!==undefined && /vnL\.qml$|\/Trucks\/ui/.test(String(c.source)))
                return c
        }
        return null
    }
    function layoutActive(on) { layoutLoader().active=on }
    // Clears the layout URLs of vnD (the Loader drops the layout component), then sets the URLs back.
    property var savedUrls: null
    function layoutUrls(clear) {
        if(clear) {
            savedUrls=page.mDashboard
            page.mDashboard=["", ""]
        } else {
            page.mDashboard=savedUrls
        }
    }
    // Records the layout signals: each new layout item of the Loader, each tripHold value, and each tripFlash.
    function hookLayout() {
        var loader=layoutLoader()
        if(loader && loader!==hookedLoader) {
            hookedLoader=loader
            loader.loaded.connect(function() {
                g.layoutLoads++
                hookItem(loader.item)
            })
        }
        if(loader)
            hookItem(loader.item)
    }
    function hookItem(item) {
        if(!item || item===hookedItem)
            return
        hookedItem=item
        if(item.tripFlash!==undefined)
            item.tripFlash.connect(function() { g.note(["flashTrip", item.tow]) })
        if(item.tripHold!==undefined)
            item.tripHoldChanged.connect(function() { g.holdTrace("layout", item.tripHold) })
    }
    function keyState() {
        var item=layoutLoader().item
        trace=JSON.stringify({menuBarIndex: g.menuBarIndex, dashboard: g.dashboard, drivingInfoIndex: g.drivingInfoIndex,
                              leftInfoIndex: g.leftInfoIndex, rightInfoIndex: g.rightInfoIndex, doorInfo: g.doorInfo,
                              notifyDuration: g.notifyDuration, calls: g.calls, holds: g.holds, tripHold: page.tripHold,
                              layoutLoads: g.layoutLoads, overspeed: mEventHandleId.item.overspeedInquiries,
                              layout: item?(item.objectName || "vnL"):"", layoutTow: item && item.tow!==undefined?item.tow:null,
                              layoutPages: item && item.pages!==undefined?item.pages:null,
                              layoutHold: item && item.tripHold!==undefined?item.tripHold:null})
    }
    // Single wheel events across the Global states that change the routes. Each event starts from fixed Global values.
    // SwcEvent acts only on a state change, so a key 0 event in state 9 first moves SwcEvent off the next state.
    // Each key starts from each info index 0-6, so the script reaches every wrap and every step of the info pages.
    // Global keeps dashboard at 0 or 1 (onDashboardChanged), so the script runs the two layouts.
    function runScript() {
        var keys=[g.swcBack, g.swcLeft, g.swcRight, g.swcUp, g.swcDown, g.swcEnter, g.swcModes]
        var states=[1, 2, 3, 0]
        var out=[]
        for(var dash=0; dash<2; dash++)
        for(var menu=0; menu<2; menu++)
        for(var notify=0; notify<2; notify++)
        for(var door=0; door<2; door++)
        for(var tpms=0; tpms<2; tpms++)
        for(var start=0; start<7; start++)
        for(var k=0; k<keys.length; k++)
        for(var s=0; s<states.length; s++) {
            for(var pass=0; pass<2; pass++) {
                g.menuBarIndex=menu; g.dashboard=dash; g.notifyTop=notify; g.doorInfo=door; g.tpmsInfoEnabled=tpms
                g.drivingInfoIndex=start; g.leftInfoIndex=start%3; g.rightInfoIndex=start%3; g.calls=[]
                if(pass===0)
                    deliver(0, 9)
            }
            deliver(keys[k], states[s])
            out.push([dash, menu, notify, door, tpms, start, keys[k], states[s], g.menuBarIndex, g.dashboard,
                      g.drivingInfoIndex, g.leftInfoIndex, g.rightInfoIndex, g.doorInfo, g.calls, loaders()])
        }
        trace=JSON.stringify(out)
    }
    // Loader state and geometry for each Global dashboard value (0-5, so a stale value too) and vehicle model.
    function sweep() {
        var out=[]
        for(var model=0; model<2; model++)
        for(var dash=0; dash<6; dash++) {
            g.vehicleModel=model; g.dashboard=dash
            out.push([model, dash, describe(page, 3).children])
        }
        g.vehicleModel=1; g.dashboard=0
        trace=JSON.stringify(out)
    }
    function overlays(menu) {
        g.menuBarIndex=menu; g.doorInfo=1; g.notifyTop=1; g.mainTentShow=1; g.shellInfoDuration=1; g.mcuUpdateTop=1
        g.notifyText=1246; g.notifyDuration=100000; g.turnLeftLight=1; g.turnRightLight=1
    }
    function describe(item, depth) {
        var a=item.anchors
        var row={type: String(item).replace(/\(0x[0-9a-f]+.*$/, "").replace(/_QMLTYPE_[0-9]+$/, "").replace(/_QML_[0-9]+$/, ""),
                 name: item.objectName, x: item.x, y: item.y, width: item.width, height: item.height, z: item.z,
                 visible: item.visible, opacity: item.opacity, scale: item.scale, enabled: item.enabled,
                 margins: a?[a.leftMargin, a.rightMargin, a.topMargin, a.bottomMargin, a.horizontalCenterOffset]:null,
                 text: item.text!==undefined?String(item.text):null,
                 source: item.source!==undefined?String(item.source).replace(/\(0x[0-9a-f]+\)/, ""):null,
                 active: item.active!==undefined?item.active:null, children: []}
        if(depth!==1)
            for(var i=0; i<item.children.length; i++)
                row.children.push(describe(item.children[i], depth?depth-1:0))
        return row
    }
    function snapshot() { tree=JSON.stringify(describe(page, 0)) }
}
"""
# The stub Global of the shell harness, one member per line. Key codes as in Global.qml.
SHELL_GLOBAL = """// Each Global value that the shells and the compiled children read.
property int dashboard: 0
property int vehicleModel: 1
property int splashEnd: 1
property int menuBarIndex: 0
property int doorInfo: 0
property int notifyTop: 0
property int notifyText: 0
property int notifyDuration: 0
property int shellInfoDuration: 0
property int mcuUpdateTop: 0
property int mainTentShow: 0
property int tpmsInfoEnabled: 1
property int tripType: 1
property int drivingInfoIndex: 0
property int leftInfoIndex: 0
property int rightInfoIndex: 0
property int swcKey: 0
property int swcState: 0
property int swcChanged: 0
property int swcBack: 3
property int swcUp: 19
property int swcDown: 20
property int swcLeft: 21
property int swcRight: 22
property int swcEnter: 23
property int swcModes: 26
property int swcSingleUp: 29
property int swcSingleDn: 30
property int turnLeftLight: 0
property int turnRightLight: 0
property int turnLeftLightEnabled: 1
property int turnRightLightEnabled: 1
property string tripUnit: "mi"
function getOdo(unit) { return "123456" }
function getTripA(unit) { return "234.5" }
function getTripB(unit) { return "17.8" }
// Test records: Global calls, the tripHold values of the layout with the time since the last press, and layout loads.
property var calls: []
function note(entry) { calls=calls.concat([entry]) }
function doorInfoHide() { note(["doorInfoHide"]); doorInfo=0 }
property double pressAt: 0
property var holds: []
function holdTrace(name, value) { holds=holds.concat([[name, Date.now()-pressAt, value]]) }
property int layoutLoads: 0
"""
# The layout stand-in with the vnL parent contract: root 1920 x 932, tow, pages, tripHold, flashTrip(), and ownsNotify.
# The pages are the vnL pages. flashTrip() emits tripFlash, as vnL does.
LAYOUT_STAND_IN = """import QtQuick 2.12
Item {
    objectName: "vnL-stand-in"
    width: 1920; height: 932
    Rectangle { anchors.fill: parent; color: "#3080c0"; opacity: 0.35; border.color: "#ffffff" }
    readonly property bool tow: mGlobalId.item.dashboard===1
    readonly property var pages: tow?["trailer", "tires", "engine", "level", "trip"]:["trip", "economy", "tires", "engine", "level"]
    property real tripHold: 0
    readonly property bool ownsNotify: true
    signal tripFlash()
    function flashTrip() { tripFlash() }
}
"""
# A layout without the optional members (no tow, pages, tripHold, or flashTrip).
LAYOUT_BARE = """import QtQuick 2.12
Item {
    objectName: "vnL-bare"
    width: 1920; height: 932
}
"""


def shell_harness(fixture, result, engine, ui_units, real_layout=False):
    # The harness that the dashboard phases use: the window, a stub Global, a stub event handler, and a Loader for
    # the shell under test. Returns the window and the shared helpers.
    from PyQt5 import QtCore, QtQml, QtQuick  # QtQuick types the root as QQuickWindow for capture()
    warnings = []
    def handler(kind, context, message):
        result["messages"].append(message)
        if kind not in (QtCore.QtDebugMsg, QtCore.QtInfoMsg) and "wrong permissions" not in message:
            warnings.append(message)
    QtCore.qInstallMessageHandler(handler)
    checks = []
    def verify(name, condition):
        checks.append(dict(name=name, passed=bool(condition)))
        print("CHECK " + name, flush=True)
        require(condition, name)
    precompiled = []
    stand_ins = ["qrc:/" + name for name in ("Trucks/menu/MenuPage.qml", "Trucks/common/Notify.qml", "Trucks/common/DoorInfo.qml",
                 "Trucks/common/MaintentNotify.qml", "Trucks/common/ShellInfoNotify.qml", "Trucks/common/Dragging.qml",
                 "Trucks/common/update/UpdateMcu.qml")] + ["qrc:/Trucks/ui" + str(n) + "/Dashboard.qml" for n in range(1, 7)]
    for url in list(ui_units) + stand_ins + ["file:///etc/vnD.qml", "file:///etc/vnL.qml"]:
        dependency = QtQml.QQmlComponent(engine, QtCore.QUrl(url))
        precompiled.append(dict(url=url, ready=dependency.status() == QtQml.QQmlComponent.Ready,
                                errors=[error.toString() for error in dependency.errors()]))
    result["precompiled"] = precompiled
    verify("vnD, vnL, the compiled units, and the stand-ins compile", all(entry["ready"] for entry in precompiled))
    members, base = SHELL_GLOBAL.splitlines(), "QtObject"
    if real_layout:
        # The stub Global of tests/qt-layout-preview.py: each Global name that vnL reads, with the Global.qml defaults and
        # sentinels. The shell members that the stub does not declare follow.
        spec = importlib.util.spec_from_file_location("qt_layout_preview", ROOT / "tests/qt-layout-preview.py")
        preview = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(preview)
        stub, missing, unused = preview.stub_global()
        (fixture / "StubGlobal.qml").write_text(stub)
        declared = set(re.findall(r"^\s*(?:property\s+\w+|function)\s+(\w+)", stub, re.M))
        members = [line for line in members if (re.match(r"(?:property\s+\w+|function)\s+(\w+)", line) or [None, None])[1]
                   not in declared]
        base = "StubGlobal"
        result["layout_stub_missing_global_names"] = missing
    harness = fixture / "ShellHarness.qml"
    harness.write_text(SHELL_HARNESS.replace("GLOBAL_ITEM", base + " {\n            id: g\n" +
                                             "".join("            " + line + "\n" for line in members) + "        }"))
    engine.load(QtCore.QUrl.fromLocalFile(str(harness)))
    roots = engine.rootObjects()
    require(roots, result["messages"])
    window = roots[0]
    window.show()
    def settle(ms=100):
        loop = QtCore.QEventLoop()
        QtCore.QTimer.singleShot(ms, loop.quit)
        loop.exec_()
    def call(name, *arguments, wait=100):
        QtCore.QMetaObject.invokeMethod(window, name, QtCore.Qt.QueuedConnection,
                                        *[QtCore.Q_ARG("QVariant", argument) for argument in arguments])
        settle(wait)
    def open_shell(label, url):
        call("open", "")
        call("reset")
        call("open", url)
        page = window.property("page")
        verify(label + " shell instantiated", page is not None and page.property("width") == 1920 and page.property("height") == 932)
        # SwcEvent drops keys until the SwcEvent start timer sets mCompleted (100 ms on an idle host).
        swc = [item for item in page.childItems() if item.property("swcChagned") is not None]
        for _ in range(100):
            if swc and swc[0].property("mCompleted") == 1:
                break
            settle(50)
        verify(label + " shell SwcEvent takes keys", len(swc) == 1 and swc[0].property("mCompleted") == 1)
        call("hookLayout")
        return page
    return dict(window=window, warnings=warnings, checks=checks, verify=verify, settle=settle, call=call, open_shell=open_shell)


def finish_shell(result, harness, callbacks, intercepted, denied, proof_scope):
    checks, warnings = harness["checks"], harness["warnings"]
    harness["call"]("open", "")
    result.update(runtime_checks=checks, cache_callbacks=sorted(set(callbacks)),
                  intercepted_urls=sorted(set(intercepted)), denied_urls=denied, qml_warnings=warnings,
                  passed=all(entry["passed"] for entry in checks) and not warnings and not denied,
                  native_writes=False, proof_scope=proof_scope)
    harness["window"].setProperty("visible", False)
    print(json.dumps(result), flush=True)
    return 0 if result["passed"] else 1


BACK, UP, DOWN, LEFT, RIGHT, ENTER, MODES = 3, 19, 20, 21, 22, 23, 26


def dashboard_differential(fixture, result, engine, callbacks, intercepted, denied, ui_units):
    # Differential test of the owned shell vnD against the compiled Trucks/Dashboard.qml (cache 023), where the old
    # shell still matches. Both shells run in one harness with one stub Global, the real compiled SwcEvent, Trip, and
    # TurnLightIndicator, and stand-ins for the children loaded by URL; vnD loads the vnL stand-in.
    # Failure modes, each with a check below:
    # - vnD does not compile or logs a QML warning;
    # - a wheel event reaches the menu differently or hides the door popup differently;
    # - Back or Modes, or any key on the menu or door route, changes a different Global value;
    # - a Modes hold steps the layout past 1 (the compiled shell steps 0-5; the two-layout set switches 0 and 1);
    # - Left or Right pages the layout the wrong way, or another dashboard key map event changes a value;
    # - vnD still asks the Notify banner (the compiled Notify answers 0 for every key, so the route took no key);
    # - a kept overlay Loader (door popup, menu, service reminder, MCU update) turns on under different Global values or
    #   sits at a different place or size;
    # - vnD keeps a stock overlay that vnL now draws (Trip and ODO texts, turn arrows, Notify, Dragging, ShellInfoNotify),
    #   or the layout does not fill 1920 x 932 at 0,0 for each Global dashboard value and vehicle model;
    # - the notifyDuration timeout no longer ends a notification.
    # The dashboard actions of Left, Right, and OK differ by design; dashboard-keys tests them in real time.
    harness = shell_harness(fixture, result, engine, ui_units)
    window, verify, call = harness["window"], harness["verify"], harness["call"]
    renders = []
    shells = {"compiled": "qrc:/Trucks/Dashboard.qml", "owned": "file:///etc/vnD.qml"}
    runs = {}
    for label, url in shells.items():
        harness["open_shell"](label, url)
        run = runs[label] = {}
        call("runScript", wait=200)
        run["trace"] = json.loads(window.property("trace"))
        call("reset")
        call("sweep")
        run["sweep"] = json.loads(window.property("trace"))
        call("reset")
        call("set", "notifyTop", 1, wait=0)
        call("set", "notifyDuration", 300, wait=700)
        call("keyState", wait=0)
        run["notify_timeout"] = json.loads(window.property("trace"))["notifyDuration"]
        for menu in (0, 1):
            call("reset")
            call("overlays", menu, wait=1500)
            call("snapshot")
            run["tree-menu-" + str(menu)] = json.loads(window.property("tree"))
            image, method = capture(window)
            target = fixture / ("preview-shell-" + label + "-menu-" + str(menu) + ".png")
            verify("shell preview saved: " + target.name, not image.isNull() and image.save(str(target)))
            renders.append(dict(path=str(target), method=method, sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
                                width=image.width(), height=image.height(),
                                label=label + " shell with every overlay on; menuBarIndex " + str(menu) + "."))
    compiled, owned = runs["compiled"], runs["owned"]
    verify("compiled shell came from the cache", "qrc:/Trucks/Dashboard.qml" in callbacks)
    verify("owned shell opened by file:///etc/vnD.qml and the layout by file:///etc/vnL.qml",
           "file:///etc/vnD.qml" in intercepted and "file:///etc/vnL.qml" in intercepted)
    rows_c, rows_o = compiled["trace"], owned["trace"]
    events = len(rows_c)
    verify("key script ran 6272 events in each shell", events == len(rows_o) == 32 * 7 * 7 * 4)
    # Row: dash, menu, notify, door, tpms, start, key, state | menuBarIndex, dashboard, drivingInfoIndex, leftInfoIndex,
    # rightInfoIndex, doorInfo | calls | Loaders.
    kept = ("/DoorInfo.qml", "/MenuPage.qml", "/MaintentNotify.qml", "/UpdateMcu.qml")
    def routes(row):
        return [entry for entry in row[14] if entry[0] != "notify"]
    def kept_loaders(row):
        return [entry for entry in row[15] if entry[0].endswith(kept)]
    pages = 5
    differences = []
    counts = dict(full=0, layout_switch=0, page=0, no_action=0)
    for index, (left, right) in enumerate(zip(rows_c, rows_o)):
        dash, menu, notify, door, tpms, start, key, state = left[:8]
        dashboard_route = not (door and state == 0) and not menu
        if left[:8] != right[:8] or routes(left) != routes(right) or routes(right) != right[14]:
            differences.append(dict(index=index, reason="event or route calls", compiled=left, owned=right))
        elif dashboard_route and key == MODES and state == 3:
            # Compiled: the next of six layouts. vnD: the other of the two layouts. Other values stay equal.
            counts["layout_switch"] += 1
            if (left[9] != dash + 1 or right[9] != 1 - dash or left[8:9] + left[10:14] != right[8:9] + right[10:14]
                    or kept_loaders(left) != kept_loaders(right)):
                differences.append(dict(index=index, reason="Modes layout switch", compiled=left, owned=right))
        elif not (dashboard_route and key in (LEFT, RIGHT, UP, DOWN, ENTER)):
            counts["full"] += 1
            if left[8:14] != right[8:14] or kept_loaders(left) != kept_loaders(right):
                differences.append(dict(index=index, reason="Global values or kept Loaders", compiled=left, owned=right))
        elif key in (LEFT, RIGHT) and state == 1 and not door:
            # vnD pages the five layout pages; an index outside the pages counts as page 0.
            counts["page"] += 1
            shown = start if start < pages else 0
            if right[8:14] != [menu, dash, (shown + (1 if key == RIGHT else -1)) % pages, start % 3, start % 3, door]:
                differences.append(dict(index=index, reason="page key", compiled=left, owned=right))
        else:
            counts["no_action"] += 1
            if right[8:14] != [menu, dash, start, start % 3, start % 3, door]:
                differences.append(dict(index=index, reason="no dashboard action", compiled=left, owned=right))
    result["key_trace"] = dict(events=events, identical=not differences, compared=counts, first_differences=differences[:5],
        menu_calls=sum(1 for row in rows_c for entry in row[14] if entry[0] == "menu"),
        compiled_notify_calls=sum(1 for row in rows_c for entry in row[14] if entry[0] == "notify"),
        owned_notify_calls=sum(1 for row in rows_o for entry in row[14] if entry[0] == "notify"),
        door_hides=sum(1 for row in rows_c for entry in row[14] if entry[0] == "doorInfoHide"),
        distinct_global_results=len({json.dumps(row[8:14]) for row in rows_c}))
    if differences:
        print("TRACE DIFFERENCES " + json.dumps(differences[:5]), flush=True)
    verify("routes identical for every event; Global values and kept Loaders identical off the dashboard key map; Modes "
           "switches between the two layouts; Left and Right page the layout; other dashboard key map events change nothing",
           not differences)
    trace = result["key_trace"]
    verify("key script reaches the menu, the door popup, the compiled Notify route, and each comparison; vnD never asks Notify",
           trace["menu_calls"] and trace["door_hides"] and trace["compiled_notify_calls"] and not trace["owned_notify_calls"]
           and all(counts.values()))
    # The owned layout Loader for each Global dashboard value (0-5) and vehicle model.
    geometry = []
    for model, dash, children in owned["sweep"]:
        layout = [child for child in children if child["active"] is not None and "/Trucks/" not in (child["source"] or "")
                  and (child["source"] or "").endswith("vnL.qml")]
        item = layout[0]["children"][0] if len(layout) == 1 and layout[0]["children"] else None
        geometry.append(dict(model=model, dashboard=dash, source=layout[0]["source"] if layout else None,
                             loader=[layout[0][k] for k in ("x", "y", "width", "height")] if layout else None,
                             item=[item[k] for k in ("x", "y", "width", "height")] if item else None))
    result["layout_geometry"] = geometry
    verify("the layout is file:///etc/vnL.qml at 0,0, 1920 x 932, for each dashboard value 0-5 and vehicle model",
           len(geometry) == 12 and all(entry["source"] == "file:///etc/vnL.qml" and entry["loader"] == [0, 0, 1920, 932]
                                       and entry["item"] == [0, 0, 1920, 932] for entry in geometry))
    # Stock overlays with every overlay on: the compiled shell shows each one (so the check sees them); vnD shows none.
    def walk(row):
        yield row
        for child in row["children"]:
            yield from walk(child)
    def stock_overlays(tree):
        found = set()
        for row in walk(tree):
            if row["name"] in ("stand-in-notify", "stand-in-ShellInfoNotify", "stand-in-Dragging"):
                found.add(row["name"])
            if row["type"] in ("Trip", "TurnLightIndicator"):
                found.add(row["type"])
            if row["visible"] and row["text"] in ("TRIP A", "234.5", "123456"):
                found.add("trip text " + row["text"])
        return sorted(found)
    expected_stock = ["Trip", "TurnLightIndicator", "stand-in-Dragging", "stand-in-ShellInfoNotify", "stand-in-notify",
                      "trip text 123456", "trip text 234.5", "trip text TRIP A"]
    result["stock_overlays"] = {label + "-menu-" + str(menu): stock_overlays(runs[label]["tree-menu-" + str(menu)])
                                for label in runs for menu in (0, 1)}
    verify("compiled shell shows each stock overlay", result["stock_overlays"]["compiled-menu-0"] == expected_stock)
    for menu in (0, 1):
        tree_c, tree_o = compiled["tree-menu-" + str(menu)], owned["tree-menu-" + str(menu)]
        verify("vnD shows no stock overlay, menuBarIndex " + str(menu), result["stock_overlays"]["owned-menu-" + str(menu)] == [])
        sources = sorted(child["source"] for child in tree_o["children"] if child["active"] is not None)
        verify("vnD Loaders are the layout and the kept overlays, menuBarIndex " + str(menu),
               sources == sorted(["file:///etc/vnL.qml"] + ["qrc:/Trucks" + name for name in
                                 ("/common/DoorInfo.qml", "/menu/MenuPage.qml", "/common/MaintentNotify.qml",
                                  "/common/update/UpdateMcu.qml")]))
        # The menu ScaleAnimator stops when the menu closes, so an inactive menu Loader keeps any scale; skip that value.
        rows_kept = {label: {child["source"]: dict(child, scale=child["scale"] if child["active"] else None)
                             for child in tree["children"] if (child["source"] or "").endswith(kept)}
                     for label, tree in (("compiled", tree_c), ("owned", tree_o))}
        found = []
        for source in sorted(rows_kept["compiled"]):
            found += tree_differences(rows_kept["compiled"][source], rows_kept["owned"].get(source, {}), source)
        result["kept_overlay_differences_menu_" + str(menu)] = found
        if found:
            print("KEPT OVERLAY DIFFERENCES " + json.dumps(found), flush=True)
        verify("kept overlays at the compiled place and size, menuBarIndex " + str(menu),
               len(rows_kept["compiled"]) == len(rows_kept["owned"]) == 4 and not found)
    verify("notifyDuration ends after the timeout in each shell", compiled["notify_timeout"] == owned["notify_timeout"] == 0)
    result["renders"] = renders
    return finish_shell(result, harness, callbacks, intercepted, denied,
                        "Compiled Dashboard (cache 023) and owned vnD in one harness with a stub Global, the real compiled "
                        "SwcEvent, Trip, TurnLightIndicator, GlowText, and GlowImage, stand-ins for the URL children, "
                        "and the vnL stand-in.")


def dashboard_keys(fixture, result, engine, callbacks, intercepted, denied, ui_units, real_layout=False):
    # Timed wheel key cases for the owned shell vnD, through the stub Global as VehicleEvent swcDeliver sets the keys.
    # dashboard-keys loads the vnL stand-in; dashboard-layout runs the same cases on the real /etc/vnL.qml.
    # Both have the vnL pages: Daily A (dashboard 0) trip, economy, tires, engine, level; Towing A (dashboard 1) trailer,
    # tires, engine, level, trip. The stub Global has no change handlers: Global.qml keeps dashboard at 0 or 1
    # (tests/tow-layout-replay.cjs), and a case here sets 2-5 to test the vnD index guard.
    # Failure modes, written before the cases; each case names the failure modes that the case checks:
    # F1  Left or Right pages the wrong way, does not wrap, or keeps a stale index outside the pages.
    # F2  A hold state or the release of Left or Right pages again.
    # F3  A short OK does not open the menu, opens the menu on the press, or the release also reaches the menu.
    # F4  An OK hold released between 250 ms and 1200 ms opens the menu or resets Trip A, or tripHold stays above 0.
    # F5  An OK hold on the trip page does not reset Trip A exactly once near 1200 ms, does not flash the trip card,
    #     opens the menu on the release, or tripHold does not stay 0 for 250 ms, reach 1, and fall back to 0.
    # F6  An OK hold on another page starts the Trip A hold.
    # F7  Up or Down changes a value.
    # F8  With the menu open or the door popup shown, a key takes the dashboard key map instead of the compiled route;
    #     with a notification shown, a key does not take the dashboard key map (the stock route never took a key).
    # F9  A layout switch (Tow/Haul, the menu, a Modes hold) makes a new layout item, keeps the old pages or tow state,
    #     or steps past layout 1; a stale dashboard value 2-5 shows no layout or the towing layout.
    # F10 A layout change or a missing layout item during a hold resets Trip A later; a layout without the optional
    #     members logs a warning or blocks the menu; any key logs a QML warning.
    # F11 The notifyDuration timeout does not end a notification.
    harness = shell_harness(fixture, result, engine, ui_units, real_layout)
    window, verify, call, settle = harness["window"], harness["verify"], harness["call"], harness["settle"]
    harness["open_shell"]("owned", "file:///etc/vnD.qml")
    verify("layout opened by file:///etc/vnL.qml", "file:///etc/vnL.qml" in intercepted)
    if real_layout:
        # vnL asks for the overspeed setting 50 ms after the load, as the stock AlarmPage did.
        call("keyState", wait=0)
        verify("vnL sends one overspeed inquiry through the parent event handler",
               json.loads(window.property("trace"))["overspeed"] == 1)
        renders = []
        for dash, name in ((0, "daily"), (1, "towing")):
            call("set", "dashboard", dash, wait=800)
            image, method = capture(window)
            target = fixture / ("preview-shell-vnL-" + name + ".png")
            verify("shell preview saved: " + target.name, not image.isNull() and image.save(str(target)))
            renders.append(dict(path=str(target), method=method, sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
                                label="vnD with the real vnL, dashboard " + str(dash) + ", stub Global sentinels."))
        result["renders"] = renders
    layout_file = fixture / "etc/vnL.qml"
    def run(setup, steps):
        call("reset", wait=300)
        for name, value in setup.items():
            call("set", name, value, wait=0)
        # Move SwcEvent off state 1, then clear the records of that event and of the setup.
        call("deliver", 0, 9, wait=50)
        call("clear", wait=0)
        samples, last = {}, 9
        for step in steps + [("wait", 400), ("sample", "end")]:
            if step[0] == "key":
                # SwcEvent acts only on a state change; a case that repeats a state tests nothing.
                require(step[2] != last, "key steps must change the state")
                last = step[2]
                call("deliver", step[1], step[2], wait=step[3])
            elif step[0] == "set":
                call("set", step[1], step[2], wait=step[3])
            elif step[0] == "layout":
                call("layoutActive", step[1], wait=step[2])
            elif step[0] == "bare":
                # Swap the layout file for one without the optional members and load the layout again. The Loader keeps
                # the layout component while the URL stays, so the URLs clear first; then the engine reads the file again.
                layout_file.write_text(LAYOUT_BARE)
                call("layoutUrls", True, wait=50)
                engine.clearComponentCache()
                call("layoutUrls", False, wait=300)
            elif step[0] == "wait":
                settle(step[1])
            else:
                call("keyState", wait=0)
                samples[step[1]] = json.loads(window.property("trace"))
        return samples
    def press(key, held, states=(1, 0), gap=40):
        # A press, optional hold states, and the release; "held" is the time from the press to the release.
        steps = [("key", key, states[0], gap if len(states) > 2 else held)]
        for state in states[1:-1]:
            steps.append(("key", key, state, (held - gap) // (len(states) - 2)))
        return steps + [("key", key, states[-1], 60)]
    def calls(sample, name):
        return [entry for entry in sample["calls"] if entry[0] == name]
    def hold_shape(sample):
        values = [entry[2] for entry in sample["holds"]]
        rising = [entry for entry in sample["holds"] if entry[2] > 0]
        return dict(changes=len(values), first_rise_ms=rising[0][1] if rising else None,
                    peak=max(values) if values else 0, last=values[-1] if values else None)
    def quiet(sample, menu=0):
        # No reset, no flash, no menu change, and no hold progress.
        return (not calls(sample, "resetTrip") and not calls(sample, "flashTrip") and sample["menuBarIndex"] == menu
                and not sample["holds"] and sample["tripHold"] == 0)
    def one_reset(sample):
        # The animation clock starts a new animation from the time of the last frame, so the rise may come up to one frame
        # (about 16 ms; more while vnL draws a banner on the host software renderer) before 250 ms.
        shape = hold_shape(sample)
        resets = calls(sample, "resetTrip")
        return (len(resets) == 1 and resets[0][1] == 0 and 1150 <= resets[0][2] <= 1700
                and len(calls(sample, "flashTrip")) == 1 and sample["menuBarIndex"] == 0
                and shape["first_rise_ms"] is not None and shape["first_rise_ms"] >= 225 and shape["peak"] >= 0.999
                and shape["last"] == 0 and sample["tripHold"] == 0 and sample["layoutHold"] == 0 and not calls(sample, "menu"))
    daily = ["trip", "economy", "tires", "engine", "level"]
    towing = ["trailer", "tires", "engine", "level", "trip"]
    def same_item(s, labels):
        return len({s[label]["layoutLoads"] for label in labels}) == 1
    cases = [
        ("page Right wraps from the last daily page", "F1", "4 -> 0 -> 1",
         dict(dashboard=0, drivingInfoIndex=4), press(RIGHT, 60) + [("sample", "a")] + press(RIGHT, 60),
         lambda s: s["a"]["drivingInfoIndex"] == 0 and s["end"]["drivingInfoIndex"] == 1),
        ("page Left wraps from the first tow page", "F1", "0 -> 4 -> 3",
         dict(dashboard=1, drivingInfoIndex=0), press(LEFT, 60) + [("sample", "a")] + press(LEFT, 60),
         lambda s: s["a"]["drivingInfoIndex"] == 4 and s["end"]["drivingInfoIndex"] == 3),
        ("stale index 6 on 5 daily pages, then Right", "F1", "6 counts as 0; Right -> 1",
         dict(dashboard=0, drivingInfoIndex=6), press(RIGHT, 60),
         lambda s: s["end"]["drivingInfoIndex"] == 1),
        ("stale index 6 on 5 daily pages, then Left", "F1", "6 counts as 0; Left -> 4",
         dict(dashboard=0, drivingInfoIndex=6), press(LEFT, 60),
         lambda s: s["end"]["drivingInfoIndex"] == 4),
        ("Right held through states 2 and 3, then released", "F2", "1 -> 2 on the press only",
         dict(dashboard=0, drivingInfoIndex=1), [("key", RIGHT, 1, 40), ("sample", "a"), ("key", RIGHT, 2, 300),
                                                 ("key", RIGHT, 3, 300), ("key", RIGHT, 0, 60)],
         lambda s: s["a"]["drivingInfoIndex"] == 2 and s["end"]["drivingInfoIndex"] == 2),
        ("Left held through states 2 and 3, then released", "F2", "3 -> 2 on the press only",
         dict(dashboard=1, drivingInfoIndex=3), [("key", LEFT, 1, 40), ("sample", "a"), ("key", LEFT, 2, 300),
                                                 ("key", LEFT, 3, 300), ("key", LEFT, 0, 60)],
         lambda s: s["a"]["drivingInfoIndex"] == 2 and s["end"]["drivingInfoIndex"] == 2),
        ("short OK (100 ms) on the economy page", "F3", "menu opens on the release; the menu gets no key",
         dict(dashboard=0, drivingInfoIndex=1), [("key", ENTER, 1, 100), ("sample", "a"), ("key", ENTER, 0, 60)],
         lambda s: s["a"]["menuBarIndex"] == 0 and s["end"]["menuBarIndex"] == 1 and not calls(s["end"], "menu")
         and not calls(s["end"], "resetTrip")),
        ("short OK (100 ms) on the trip page", "F3 F5", "menu opens; no reset; tripHold stays 0",
         dict(dashboard=0, drivingInfoIndex=0), [("key", ENTER, 1, 100), ("key", ENTER, 0, 60)],
         lambda s: s["end"]["menuBarIndex"] == 1 and not calls(s["end"], "menu") and not calls(s["end"], "resetTrip")
         and not calls(s["end"], "flashTrip") and hold_shape(s["end"])["peak"] < 0.05 and s["end"]["tripHold"] == 0),
        ("OK held 600 ms on the trip page, then released", "F4", "no menu, no reset; tripHold rises, then returns to 0",
         dict(dashboard=0, drivingInfoIndex=0), [("key", ENTER, 1, 150), ("sample", "early"), ("wait", 450),
                                                 ("sample", "mid"), ("key", ENTER, 0, 60)],
         lambda s: s["early"]["tripHold"] == 0 and 0.05 < s["mid"]["tripHold"] < 0.9 and s["mid"]["layoutHold"] == s["mid"]["tripHold"]
         and s["end"]["menuBarIndex"] == 0 and not calls(s["end"], "resetTrip") and not calls(s["end"], "flashTrip")
         and s["end"]["tripHold"] == 0 and s["end"]["layoutHold"] == 0),
        ("OK held 1300 ms on the daily trip page, with hold states", "F5", "one resetTrip(0), one flashTrip, no menu; tripHold 0 -> 1 -> 0",
         dict(dashboard=0, drivingInfoIndex=0), [("key", ENTER, 1, 150), ("sample", "early"), ("key", ENTER, 2, 550),
                                                 ("key", ENTER, 3, 600), ("key", ENTER, 0, 60)],
         lambda s: s["early"]["tripHold"] == 0 and one_reset(s["end"])),
        ("OK held 1300 ms on the tow trip page (page 5)", "F5", "one resetTrip(0), one flashTrip, no menu; tripHold 0 -> 1 -> 0",
         dict(dashboard=1, drivingInfoIndex=4), press(ENTER, 1300),
         lambda s: one_reset(s["end"]) and calls(s["end"], "flashTrip")[0][1] is True),
        ("OK held 1300 ms on the economy page", "F6", "nothing",
         dict(dashboard=0, drivingInfoIndex=1), press(ENTER, 1300, (1, 2, 3, 0)),
         lambda s: quiet(s["end"]) and s["end"]["drivingInfoIndex"] == 1),
        ("Up and Down through press, holds, and release", "F7", "no value changes",
         dict(dashboard=0, drivingInfoIndex=2, leftInfoIndex=1, rightInfoIndex=1),
         press(UP, 400, (1, 2, 3, 0)) + press(DOWN, 400, (1, 2, 3, 0)),
         lambda s: quiet(s["end"]) and not s["end"]["calls"] and [s["end"][k] for k in ("drivingInfoIndex", "leftInfoIndex", "rightInfoIndex")] == [2, 1, 1]),
        ("menu open: Left, Right, short OK, and a 1300 ms OK hold", "F8", "each event goes to the menu; no paging, no reset",
         dict(dashboard=0, drivingInfoIndex=0, menuBarIndex=1),
         press(LEFT, 60) + press(RIGHT, 60) + press(ENTER, 100) + press(ENTER, 1300),
         lambda s: [entry[1:] for entry in calls(s["end"], "menu")] == [[LEFT, 1], [LEFT, 0], [RIGHT, 1], [RIGHT, 0],
                                                                         [ENTER, 1], [ENTER, 0], [ENTER, 1], [ENTER, 0]]
         and len(s["end"]["calls"]) == 8 and quiet(s["end"], 1) and s["end"]["drivingInfoIndex"] == 0),
        ("notification shown: Right to the trip page, then a 1300 ms OK hold", "F8",
         "the dashboard key map acts: 4 -> 0, one resetTrip(0), one flashTrip",
         dict(dashboard=0, drivingInfoIndex=4, notifyTop=1, notifyText=1409, notifyDuration=100000),
         press(RIGHT, 60) + [("sample", "a")] + press(ENTER, 1300),
         lambda s: s["a"]["drivingInfoIndex"] == 0 and one_reset(s["end"]) and len(s["end"]["calls"]) == 2),
        ("door popup: Left", "F8", "press does nothing; the release closes the popup",
         dict(dashboard=0, drivingInfoIndex=0, doorInfo=1), [("key", LEFT, 1, 60), ("sample", "a"), ("key", LEFT, 0, 60)],
         lambda s: s["a"]["doorInfo"] == 1 and s["a"]["drivingInfoIndex"] == 0 and s["end"]["doorInfo"] == 0
         and s["end"]["calls"] == [["doorInfoHide"]] and s["end"]["drivingInfoIndex"] == 0 and s["end"]["menuBarIndex"] == 0),
        ("door popup: short OK, and a 1300 ms OK hold on the trip page", "F8",
         "the first release closes the popup; no menu, no reset; the second release also closes the popup; no hold",
         dict(dashboard=0, drivingInfoIndex=0, doorInfo=1), press(ENTER, 100) + [("sample", "a")] + [("set", "doorInfo", 1, 0)]
         + press(ENTER, 1300),
         lambda s: s["a"]["calls"] == [["doorInfoHide"]] and s["a"]["menuBarIndex"] == 0
         and s["end"]["calls"] == [["doorInfoHide"], ["doorInfoHide"]] and quiet(s["end"])),
        ("Tow/Haul on and off: dashboard 0 -> 1 -> 0, with Right while towing", "F9",
         "one layout item; tow and the pages follow; Right pages the tow pages 1 -> 2",
         dict(dashboard=0, drivingInfoIndex=1), [("sample", "start"), ("set", "dashboard", 1, 300), ("sample", "on")]
         + press(RIGHT, 60) + [("sample", "paged"), ("set", "dashboard", 0, 300)],
         lambda s: s["start"]["layoutTow"] is False and s["start"]["layoutPages"] == daily and s["on"]["layoutTow"] is True
         and s["on"]["layoutPages"] == towing and s["paged"]["drivingInfoIndex"] == 2 and s["end"]["layoutTow"] is False
         and s["end"]["layoutPages"] == daily and same_item(s, ("start", "on", "paged", "end")) and s["end"]["layout"] != ""),
        ("Modes long hold (state 3) twice from Towing", "F9", "1 -> 0 -> 1 (never 2); one layout item; no menu",
         dict(dashboard=1, drivingInfoIndex=0), [("sample", "start"), ("key", MODES, 1, 40), ("key", MODES, 3, 200),
                                                 ("sample", "a"), ("key", MODES, 1, 40), ("key", MODES, 3, 200)],
         lambda s: s["a"]["dashboard"] == 0 and s["a"]["layoutTow"] is False and s["end"]["dashboard"] == 1
         and s["end"]["layoutTow"] is True and same_item(s, ("start", "a", "end")) and s["end"]["menuBarIndex"] == 0),
        ("stale dashboard 2, 3, 4, and 5 after Towing", "F9", "each shows Daily A in the same layout item; Right pages",
         dict(dashboard=1, drivingInfoIndex=4), [("sample", "start")]
         + [step for value in (2, 3, 4, 5) for step in (("set", "dashboard", value, 200), ("sample", "d" + str(value)))]
         + press(RIGHT, 60),
         lambda s: s["start"]["layoutTow"] is True and all(s["d" + str(v)]["layoutTow"] is False and s["d" + str(v)]["layoutPages"] == daily
                                                          for v in (2, 3, 4, 5))
         and same_item(s, ("start", "d2", "d3", "d4", "d5", "end")) and s["end"]["drivingInfoIndex"] == 0 and s["end"]["layout"] != ""),
        ("layout change to the tow layout 600 ms into a trip hold", "F10", "no reset, no flash, no menu; both holds 0",
         dict(dashboard=0, drivingInfoIndex=0), [("key", ENTER, 1, 600), ("set", "dashboard", 1, 900), ("key", ENTER, 0, 60)],
         lambda s: s["end"]["layoutTow"] is True and not calls(s["end"], "resetTrip") and not calls(s["end"], "flashTrip")
         and s["end"]["menuBarIndex"] == 0 and s["end"]["tripHold"] == 0 and s["end"]["layoutHold"] == 0),
        ("no layout item: Left, Right, a 1300 ms OK hold, then a short OK", "F10",
         "no paging, no reset; the short OK still opens the menu",
         dict(dashboard=0, drivingInfoIndex=0), [("layout", False, 50)] + press(LEFT, 60) + press(RIGHT, 60)
         + press(ENTER, 1300) + [("sample", "a")] + press(ENTER, 100),
         lambda s: s["a"]["layout"] == "" and s["a"]["drivingInfoIndex"] == 0 and s["a"]["menuBarIndex"] == 0
         and not calls(s["end"], "resetTrip") and s["end"]["menuBarIndex"] == 1),
        ("notification for 300 ms", "F11", "notifyDuration returns to 0",
         dict(dashboard=0, notifyTop=1, notifyText=1409), [("set", "notifyDuration", 300, 0), ("sample", "a"), ("wait", 500)],
         lambda s: s["a"]["notifyDuration"] == 300 and s["end"]["notifyDuration"] == 0),
    ]
    if not real_layout:
        # Last: the swap leaves the bare layout in the component cache.
        cases.append(("layout without tow, pages, tripHold, or flashTrip: Left, Right, a 1300 ms OK hold, then a short OK",
                      "F10", "no paging, no reset, no warning; the short OK opens the menu",
                      dict(dashboard=0, drivingInfoIndex=0), [("bare",), ("sample", "a")] + press(LEFT, 60) + press(RIGHT, 60)
                      + press(ENTER, 1300) + [("sample", "b")] + press(ENTER, 100),
                      lambda s: s["a"]["layout"] == "vnL-bare" and s["a"]["layoutPages"] is None and s["b"]["drivingInfoIndex"] == 0
                      and s["b"]["menuBarIndex"] == 0 and not calls(s["end"], "resetTrip") and not calls(s["end"], "flashTrip")
                      and s["end"]["menuBarIndex"] == 1 and s["end"]["tripHold"] == 0))
    table = []
    for name, modes, expected, setup, steps, check in cases:
        samples = run(setup, steps)
        passed = bool(check(samples))
        end = samples["end"]
        table.append(dict(case=name, failure_modes=modes, expected=expected, passed=passed,
                          observed=dict(samples={label: {key: value for key, value in sample.items() if key != "holds"}
                                                 for label, sample in samples.items()},
                                        hold=hold_shape(end))))
        observed = json.dumps(table[-1]["observed"])
        print("CASE " + ("PASS " if passed else "FAIL ") + name + " " + (observed[:600] if passed else observed), flush=True)
    result["key_cases"] = table
    for entry in table:
        verify("key case: " + entry["case"], entry["passed"])
    if harness["warnings"]:
        print("QML WARNINGS " + json.dumps(harness["warnings"][:5]), flush=True)
    verify("no QML warnings during the key cases", not harness["warnings"])
    return finish_shell(result, harness, callbacks, intercepted, denied,
                        "Owned vnD with a stub Global, a stub event handler, the real compiled SwcEvent, and " +
                        ("the real /etc/vnL.qml with the stub Global of tests/qt-layout-preview.py." if real_layout else
                         "the vnL stand-in, then a layout without the optional members."))


NOTIFY_HARNESS = r"""import QtQuick 2.12
Item {
    width: 1920; height: 932
    property string pageUrl: ""
    property alias page: mTranslationId.item
    property string trace: ""
    QtObject {
        id: mGlobalId
        property QtObject item: QtObject {
            id: g
            // Each Global value that Translation and the stock text tables read, with the Global.qml defaults.
            // mRccPrefix is the Linux value of Global.qml. Language 1 is English.
            property string mRccPrefix: "file:///etc/"
            property int language: 1
            property int vehicleModel: 1
            property int metricSystem: 0
            property int notifyText: 0
            property int nofifyDpf: 55
            property int nofifyU16: 0
            property int modelCarSelection: 0
            property int screenFlipEnabled: 0
            property int fordSetupInfoChanged: 0
            property var fordSetupInfo: new Array(100).fill(0)
            property int trucksSetupInfoChanged: 0
            property var trucksSetupInfo: new Array(100).fill(0)
            property int bsmOn: 0
            property int bsmSensitivity: 0
            property int bsmBright: 0
            property int pcsOn: 0
            property int pcsSensitivity: 0
            property string fuelUnit: "MPG"
            property string tripUnit: "mi"
            property string outSideTempUnit: "F"
            property string tpmsPressureUnit: " psi"
            property int mainTentChanged: 0
            property int mainTentId: 0
            property int mainTentItem: 0
            property int mainTentCustomize1: 0
            property int mainTentCustomize2: 0
            property int frontTpmsDoorExchange: 0
            property int rearTpmsDoorExchange: 0
            property int fuelRefuelingPortPositon: 0
            property int tpmsInfoEnabled: 1
            property int reverseAlarmEnabled: 0
            property int tachoSpeedMax6000: 0
            property int subTankEnabled: 0
            property int mLc76VehicleSpeedMaxIndex: 0
            property int angleInfoEnabled: 0
            property int outSideTempInfoEnabled: 1
            property int ecoInfoEnabled: 0
            property int gearInfoEnabled: 0
            property int oilTempEnabled: 0
            property int dteEnabled: 0
            property int clockInfoEnabled: 1
            property int doorInfoEnabled: 1
            property int oilPressureInfoEnabled: 0
            property int chassisStateEnabled: 0
            property int dialogId: 0
            property int dashboard: 0
            property int benzAdBlueTextMileage: 0xFFFF
            property int menuPageIndex: 0
        }
    }
    // main.qml loads Translation in the Loader mTranslationId; the text tables read that id.
    Loader { id: mTranslationId; source: pageUrl }
    // The probe queues these calls: a load from Python would hold the GIL that the type loader thread needs.
    function open(url) { pageUrl = url }
    function banner(id) {
        g.notifyText=id
        var loader=null
        for(var i=0; i<page.data.length; i++) {
            var source=page.data[i].source!==undefined?String(page.data[i].source):""
            if(/(NotifyTranslation|vnN)\.qml$/.test(source))
                loader=page.data[i]
        }
        trace=JSON.stringify({text: page.mNotifyTextItem, count: page.mNotifyTextItemLength,
                              source: loader?String(loader.source):"", loaded: !!(loader && loader.item)})
    }
}
"""


def notify_table(fixture, result, engine, callbacks, intercepted, denied):
    # The compiled Translation (cache 012) loads the notification text table and forms the banner text
    # (mNotifyTextItem = mNotifyId.item.mNotifyItems[notifyText][language]). Failure modes, each with a check below:
    # - the candidate unit differs from the original beyond the one record (checked before this function, in child());
    # - the candidate loads the stock table, or a URL other than file:///etc/vnN.qml, or the original loads vnN;
    # - the table at /etc/vnN.qml does not load, or a load logs a warning (the install health check rolls back on
    #   any "/etc/vn" line);
    # - the banner text for id 1409 is not "TRACTION CONTROL OFF" (the stock table shows the id 1408 text there).
    from PyQt5 import QtCore
    warnings = []
    def handler(kind, context, message):
        result["messages"].append(message)
        if kind not in (QtCore.QtDebugMsg, QtCore.QtInfoMsg) and "wrong permissions" not in message:
            warnings.append(message)
    QtCore.qInstallMessageHandler(handler)
    checks = []
    def verify(name, condition):
        checks.append(dict(name=name, passed=bool(condition)))
        print("CHECK " + name, flush=True)
        require(condition, name)
    patched = result["phase"] == "patched-notify-table"
    harness = fixture / "NotifyHarness.qml"
    harness.write_text(NOTIFY_HARNESS)
    engine.load(QtCore.QUrl.fromLocalFile(str(harness)))
    roots = engine.rootObjects()
    require(roots, result["messages"])
    root = roots[0]
    def settle(ms):
        loop = QtCore.QEventLoop()
        QtCore.QTimer.singleShot(ms, loop.quit)
        loop.exec_()
    def call(name, *arguments, wait=100):
        QtCore.QMetaObject.invokeMethod(root, name, QtCore.Qt.QueuedConnection,
                                        *[QtCore.Q_ARG("QVariant", argument) for argument in arguments])
        settle(wait)
    call("open", "qrc:/common/Translation.qml", wait=500)
    verify("compiled Translation came from the cache", "qrc:/common/Translation.qml" in callbacks)
    banners = {}
    for number in (1407, 1408, 1409, 1410):
        call("banner", number, wait=50)
        banners[number] = json.loads(root.property("trace"))
    stock = "file:///etc//common/NotifyTranslation.qml"
    table = "file:///etc/vnN.qml" if patched else stock
    result["banner_text"] = {number: value["text"] for number, value in banners.items()}
    result["notify_loader"] = banners[1409]["source"]
    if warnings:
        print("QML WARNINGS " + json.dumps(warnings[:5]), flush=True)
    verify("the mNotifyId Loader opens " + table, banners[1409]["source"] == table and banners[1409]["loaded"])
    verify("the engine requested " + table + " and not the other table",
           table in intercepted and (stock if patched else "file:///etc/vnN.qml") not in intercepted)
    verify("the table has 1456 rows", banners[1409]["count"] == 1456)
    if patched:
        verify("banner 1409 shows TRACTION CONTROL OFF", banners[1409]["text"] == "TRACTION CONTROL OFF")
        verify("banners 1407, 1408, 1410 show the fixed text",
               [banners[n]["text"] for n in (1407, 1408, 1410)] == ["AdvanceTrac OFF", "AdvanceTrac ON", "TRACTION CONTROL ON"])
    else:
        verify("the stock table reproduces the slot defect: banner 1409 shows the 1408 text",
               banners[1409]["text"] == banners[1408]["text"] != "TRACTION CONTROL OFF")
    verify("no QML warnings", not warnings)
    result.update(runtime_checks=checks, cache_callbacks=sorted(set(callbacks)), intercepted_urls=sorted(set(intercepted)),
                  denied_urls=denied, qml_warnings=warnings, native_writes=False,
                  passed=all(entry["passed"] for entry in checks) and not warnings and not denied,
                  proof_scope="Compiled Translation (cache 012) from the Launcher under test, the stock text tables, and a stub "
                              "Global with the Linux mRccPrefix.")
    root.setProperty("pageUrl", "")
    print(json.dumps(result), flush=True)
    return 0 if result["passed"] else 1


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--child", choices=PHASES)
    parser.add_argument("--fixture")
    # Default: the release candidate that tools/build_usb_install.py packs for the USB drive.
    builder = importlib.util.spec_from_file_location("build_usb_install", ROOT / "tools/build_usb_install.py")
    release = importlib.util.module_from_spec(builder)
    builder.loader.exec_module(release)
    parser.add_argument("--candidate-dir", default=str(release.CANDIDATE))
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
    phases = ["empty-source-control", "original-vendor-header", "original-adapted", "patched-adapted", "dashboard-differential",
              "dashboard-keys", "dashboard-layout", "original-notify-table"]
    if args.candidate_dir:
        phases.extend(("patched-settings-adapted", "patched-settings-redirects", "patched-notify-table"))
    for phase in phases:
        fixture = Path(tempfile.mkdtemp(prefix="loader-", dir=HOST))
        command = [sys.executable, str(Path(__file__).resolve()), "--child", phase, "--fixture", str(fixture)]
        if phase in ("patched-settings-adapted", "patched-settings-redirects", "patched-notify-table"):
            command += ["--candidate-dir", args.candidate_dir]
        # The key phases wait in real time for each timed key case.
        process = subprocess.run(command, capture_output=True, text=True,
                                 timeout=150 if phase in ("dashboard-keys", "dashboard-layout") else 40)
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
