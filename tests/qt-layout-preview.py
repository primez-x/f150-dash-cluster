#!/usr/bin/env python3
"""Host preview of the locked dashboard layouts in patches/capture-04/etc/vnL.qml (Daily A and Towing A).

The runner loads vnL.qml with a stub Global (exposed as mGlobalId.item) on the PyQt5 5.14.2 host build, sets the raw
firmware values of every design/round-42/geometry scene, and saves one preview per scene. Each layout runs in a fresh
engine: the first evaluation with every Global sentinel, then the stale scene, then the other scenes, then the
behaviour checks. Checks:
- zero QML warnings or errors at any time;
- geometry: every design text node and the objectName-keyed boxes against the JSON node boxes (4 px);
- pixels: mean absolute difference on a 1/4 scale and the worst 64 x 64 tiles (report only);
- behaviour: card pages 0 to 4 and an index outside the pages, the tripHold ring, flashTrip, the dashboard switch,
  the sentinels, the banner sources, the trailer gain notify, the overspeed badge, and the warning light blink.
Output: analysis/capture-04/qt-host/layout-preview/<layout>-<scene>.png and report.json there. Exit 1 on a failure.

Run from Windows Git Bash:
  MSYS_NO_PATHCONV=1 wsl.exe -d Ubuntu --exec /mnt/c/f150-dash-cluster/tools/qt-host/venv/bin/python \\
      /mnt/c/f150-dash-cluster/tests/qt-layout-preview.py
"""
import argparse
import atexit
import ctypes
import json
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LAYOUT = ROOT / "patches/capture-04/etc/vnL.qml"
GLOBAL = ROOT / "patches/capture-04/etc/common/Global.qml"
GEOMETRY = ROOT / "design/round-42/geometry"
HOST = ROOT / "analysis/capture-04/qt-host"
OUT = HOST / "layout-preview"
LAYOUTS = ("daily-a", "tow-a")
SCENES = ("stale", "normal", "cruise", "busycruise", "economy", "hottrans", "lowfuel", "crawl", "backing", "turn",
          "page0", "page1", "page2", "page3", "page4")
REPRODUCE = ("MSYS_NO_PATHCONV=1 wsl.exe -d Ubuntu --exec /mnt/c/f150-dash-cluster/tools/qt-host/venv/bin/python "
             "/mnt/c/f150-dash-cluster/tests/qt-layout-preview.py")
TOLERANCE = 4.0
MPH = 0.62137
PSI_KPA = 6.894757293168
# Integer mPitch (degrees) cannot carry a grade of 1, -1, or 8 percent: the nearest pitch shows 2, -2, and 9.
EXPECTED_TEXT_DEVIATIONS = {"+1", "−1", "+8"}

# Global sentinel defaults the stub cannot copy from Global.qml (bindings to vendor tables or other components).
STUB_OVERRIDES = {
    "vehicleSpeedMax": "260",
    "tachoSpeedMax": "7000",
    "mRccPrefix": '"file:///etc/"',
    "notifyTop": "notifyDuration>0",
    "gpsFixedValid": '""',
    "gpsFixed": "0",
    "gpsAltitude": "0",
    "fuelPercentageValid": "fuelPercentageRaw>=0 && fuelPercentageRaw<=100",
}
STUB_FUNCTIONS = ("rtcTrusted", "getRtcTime", "getAmPm", "getOverSpeedWaningSpeed")


def require(condition, message):
    if not condition:
        raise RuntimeError("QT_PROBE_GUARD: " + message)


def global_names():
    """Property declarations (type, default) and function bodies of the real Global.qml."""
    text = GLOBAL.read_text(encoding="utf-8")
    props = {}
    for m in re.finditer(r"^\s*(?:readonly\s+)?property\s+(\w+)\s+(\w+)\s*(?::\s*(.*?))?\s*;?\s*(?://.*)?$", text, re.M):
        props.setdefault(m.group(2), (m.group(1), (m.group(3) or "").strip()))
    funcs = {}
    for m in re.finditer(r"^(\s*)function\s+(\w+)\s*\(", text, re.M):
        start, depth, i = m.start(), 0, text.index("{", m.end())
        while True:
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        funcs.setdefault(m.group(2), text[start:i + 1])
    return props, funcs


def used_names():
    return sorted(set(re.findall(r"\bg\.(\w+)", LAYOUT.read_text(encoding="utf-8"))))


LITERAL = re.compile(r'^(-?\d+(\.\d+)?|-?0x[0-9A-Fa-f]+|true|false|"[^"]*"|\[\])$')


def stub_global():
    props, funcs = global_names()
    names = used_names()
    missing = [n for n in names if n not in props and n not in funcs]
    lines = ["import QtQuick 2.12", "QtObject {", "    objectName: \"stub-global\""]
    extra = {"fuelPercentageRaw": ("int", "0"), "shellCmdShow": ("int", "0")}
    for name in sorted(set(names) | set(extra) | {"rtcTime", "rtc24h", "gpsClockRtcSet", "gpsClockMinYear",
                                                  "overSpeedWarningSpeed", "language"}):
        if name in funcs and name not in props:
            continue
        kind, value = props.get(name, extra.get(name, ("var", "undefined")))
        if name in STUB_OVERRIDES:
            value = STUB_OVERRIDES[name]
        elif not LITERAL.match(value):
            value = {"int": "0", "real": "0", "double": "0", "bool": "false", "string": '""', "var": "[]"}.get(kind, "0")
            if name in ("tripFactor",):
                value = "metricSystem?1:0.62137"
            if name in ("vehicleSpeedUnit",):
                value = 'metricSystem?"km/h":"MPH"'
            if name in ("lpkValid",):
                value = "lpk!==0x7FFF && lpk!==0x7FFE"
        lines.append("    property %s %s: %s" % (kind, name, value))
    lines.append("    function prefixInteger(num, n) { return (Array(n).join(0)+num).slice(-n) }")
    for name in STUB_FUNCTIONS:
        lines.append("    " + funcs[name].strip().replace("Funcs.prefixInteger(", "prefixInteger("))
    lines.append("}")
    return "\n".join(lines) + "\n", missing, names


HARNESS = r"""import QtQuick 2.12
import QtQuick.Window 2.12
Window {
    id: win
    width: 1920
    height: 932
    visible: true
    color: "#000000"
    QtObject { id: mGlobalId; property QtObject item: StubGlobal {} }
    QtObject {
        id: mTranslationId
        property QtObject item: QtObject {
            property string mNotifyTextItem: ""
            property string mFontType: "BMW Type Global"
        }
    }
    QtObject {
        id: mEventHandleId
        property QtObject item: QtObject {
            property int overspeedInquiries: 0
            function overspeedInquire() { overspeedInquiries++ }
        }
    }
    Loader {
        id: layoutLoader
        objectName: "layout-loader"
        x: 0
        y: 0
        width: 1920
        height: 932
        source: "LAYOUT_URL"
    }
    function setValue(name, value) { mGlobalId.item[name]=value }
    function setTranslation(text) { mTranslationId.item.mNotifyTextItem=text }
    function inquiries() { return mEventHandleId.item.overspeedInquiries }
}
"""


# ===== Scene state to raw firmware values (inverse of the vnL conversions) =====
def raw_state(layout, scene, state):
    tow = layout == "tow-a"
    temps = state.get("temps", {})

    def temp(value):
        return 0xFF if value is None else int(value)
    tires = state.get("tires", [35, 35, 35, 35])
    low = state.get("low", -1)
    alarms = [0] * 300
    for i in state.get("telltales", []):
        alarms[i] = 1
    boost = state.get("boost")
    gear = state.get("gear", "D")
    cruise = state.get("cruise", "off")
    values = {
        "metricSystem": 0, "temperatureUnit": 0, "consumptionUnit": 2, "pressureUnit": 3,
        "dashboard": 1 if tow else 0, "drivingInfoIndex": int(state.get("page", 0)),
        "vehicleSpeed": round(state.get("speed", 0) / MPH), "tachoSpeed": int(state.get("rpm", 0)),
        "fuelPercentageRaw": 0xFF if state.get("fuel") is None else int(state["fuel"]),
        "fuelPercentage": 0 if state.get("fuel") is None else int(state["fuel"]),
        "fuelPercentageSeen": True,
        "dte": 0xFFFF if state.get("range") is None else round(state["range"] / MPH),
        "gearBoxTemp": temp(temps.get("trans")), "waterTemp": temp(temps.get("coolant")),
        "oilTemp": temp(temps.get("oil")), "cylinderHeadTemp": temp(temps.get("cht")),
        "inletAirTemp": temp(state.get("iat")),
        "tpmsLFPressure": round(tires[0] * PSI_KPA), "tpmsRFPressure": round(tires[1] * PSI_KPA),
        "tpmsLRPressure": round(tires[2] * PSI_KPA), "tpmsRRPressure": round(tires[3] * PSI_KPA),
        "tpmsLFState": int(low == 0), "tpmsRFState": int(low == 1), "tpmsLRState": int(low == 2), "tpmsRRState": int(low == 3),
        "frontTpmsDoorExchange": 0, "rearTpmsDoorExchange": 0,
        "tripA": float(state.get("trip", "0")) / MPH, "odo": 48213 / MPH,
        "sinceResetTravelTime": 161,
        "sinceResetAvgFuel": 235.2156 / float(state.get("avg", "1")),
        "lpk": 235.2156 / float(state.get("mpgNow", 1)), "lpkUnitIndex": 0,
        "gpsFixedValid": "A", "gpsFixed": 0,
        "vacuumBoost": 0xFFFF if boost is None else round(abs(boost) * 10),
        "vacuumBoostDir": 0 if boost is None else int(boost < 0),
        "mPitch": round(math.degrees(math.atan(state.get("grade", 0) / 100))),
        "mRoll": int(state.get("roll", 0)), "angle": round(state.get("steer", 0) * 128 / 45),
        "mAltitude": state.get("altFt", 1840) / 3.28084, "outSideTemp": 20.0,
        "rtcDate": "2025-10-30", "rtcTime": "10:42", "rtc24h": 1, "gpsClockRtcSet": True,
        "gearString": gear + (str(state.get("gearNum", "")) if gear == "D" else ""),
        "trucksShiftGear": 0, "gearHasAwd": 1, "gearAwd": {"2H": 1, "4H": 2, "4L": 4}.get(state.get("drive", "2H"), 1),
        "oilPressureState": 0, "oilPressurePercentage": 0xFF if state.get("oilp") is None else int(state["oilp"]),
        "trucksTrailerDistance": round(state.get("trailerMi", 342) / MPH * 1000 + 3),
        "trucksTrailerGain": float(state.get("gain", 5.5)), "trucksTrailerBrakeState": 0, "trucksTrailerOutput": -1,
        "cruiseState": 0 if cruise == "off" else 1, "cruiseSpeedSet": int(cruise == "set"),
        "cruiseSetSpeedState": int(cruise == "set"), "cruiseSpeed": round(state.get("cruiseSet", 65) / MPH),
        "cruiseLimState": 0, "cruiseAccInterfaceState": 0, "cruiseLimSpeed": 0,
        "turnLeftLight": 0, "turnRightLight": 0,
        "overSpeedWarningEnabled": 0, "overSpeedWarningState": 0, "overSpeedWarningSpeed": 0,
        "notifyText": 0, "notifyDuration": 0, "nofifyDpf": 0,
        "alarmTable": alarms,
    }
    return values, state.get("heading", 0)


# ===== Child: one layout in one fresh engine =====
def child(layout):
    os.environ.update(QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", QML_DISABLE_DISK_CACHE="1")
    os.environ.pop("QSG_RENDER_LOOP", None)
    from PyQt5 import QtCore, QtGui, QtQml, QtQuick, sip

    messages = []

    def handler(kind, context, message):
        if kind in (QtCore.QtDebugMsg, QtCore.QtInfoMsg) or "wrong permissions" in message:
            return
        messages.append(message)
    QtCore.qInstallMessageHandler(handler)
    app = QtGui.QGuiApplication([])
    require(QtCore.qVersion() == "5.14.2", QtCore.qVersion())
    for name in ("BMW.ttf", "KonexyPersonalUseRegular.ttf"):
        require(QtGui.QFontDatabase.addApplicationFont(str(ROOT / "handoff/claude-dashboard/assets/fonts" / name)) >= 0,
                "font " + name)
    fixture = Path(tempfile.mkdtemp(prefix="layout-preview-", dir=HOST))
    atexit.register(shutil.rmtree, str(fixture), True)
    stub, missing, names = stub_global()
    (fixture / "StubGlobal.qml").write_bytes(stub.encode("utf-8"))
    (fixture / "Harness.qml").write_bytes(HARNESS.replace("LAYOUT_URL", QtCore.QUrl.fromLocalFile(str(LAYOUT)).toString()).encode("utf-8"))
    result = {"layout": layout, "missing_global_names": missing, "global_names": names, "scenes": {}, "checks": [],
              "warnings": messages, "intercepted": [], "denied": []}

    qrc_root = ROOT / "recovered-resources/latest-Launcher"
    etc_images = ROOT / "handoff/claude-dashboard/assets/installed"

    class Interceptor(QtQml.QQmlAbstractUrlInterceptor):
        def intercept(self, url, kind):
            value = url.toString()
            if value.startswith("qrc:/Trucks/images/"):
                result["intercepted"].append(value)
                return QtCore.QUrl.fromLocalFile(str(qrc_root / value[len("qrc:/"):]))
            if value.startswith("file:///etc/images/"):
                result["intercepted"].append(value)
                return QtCore.QUrl.fromLocalFile(str(etc_images / value[len("file:///etc/images/"):]))
            if url.scheme() in ("http", "https", "ftp") or value.startswith("file:///etc/"):
                result["denied"].append(value)
            return url
    interceptor = Interceptor()
    engine = QtQml.QQmlApplicationEngine()
    library = ctypes.CDLL(str(Path(QtCore.QLibraryInfo.location(QtCore.QLibraryInfo.LibrariesPath)) / "libQt5Qml.so.5"))
    set_interceptor = library._ZN10QQmlEngine17setUrlInterceptorEP26QQmlAbstractUrlInterceptor
    set_interceptor.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
    set_interceptor(ctypes.c_void_p(sip.unwrapinstance(engine)), ctypes.c_void_p(sip.unwrapinstance(interceptor)))
    engine.rootContext().setContextProperty("mTrucksModel", 1)

    def settle(ms):
        loop = QtCore.QEventLoop()
        QtCore.QTimer.singleShot(ms, loop.quit)
        loop.exec_()

    def check(name, ok, detail=""):
        result["checks"].append({"name": name, "passed": bool(ok), "detail": detail})

    # The stub starts with the Global sentinels; the dashboard follows the layout before the first evaluation.
    stub_defaults = stub
    if layout == "tow-a":
        (fixture / "StubGlobal.qml").write_bytes(stub_defaults.replace("property int dashboard: 0", "property int dashboard: 1").encode("utf-8"))
    engine.load(QtCore.QUrl.fromLocalFile(str(fixture / "Harness.qml")))
    require(engine.rootObjects(), "harness did not load: " + "; ".join(messages))
    window = engine.rootObjects()[0]
    loader = window.findChild(QtCore.QObject, "layout-loader")
    settle(300)
    item = loader.property("item")
    require(item is not None, "vnL did not load: " + "; ".join(messages))
    g = window.findChild(QtCore.QObject, "stub-global")

    def call(name, *args):
        QtCore.QMetaObject.invokeMethod(window, name, QtCore.Qt.DirectConnection,
                                        *[QtCore.Q_ARG("QVariant", a) for a in args])

    def set_value(name, value):
        call("setValue", name, value)

    def prop(name):
        value = item.property(name)
        return value.toVariant() if hasattr(value, "toVariant") else value

    def walk(node, opacity=1.0, out=None):
        out = [] if out is None else out
        for c in node.childItems():
            if not c.isVisible():
                continue
            o = opacity * c.opacity()
            out.append((c, o))
            walk(c, o, out)
        return out

    def scene_items():
        found = []
        for c, o in walk(window.contentItem()):
            r = c.mapRectToScene(QtCore.QRectF(0, 0, c.width(), c.height()))
            entry = {"cls": c.metaObject().className(), "name": c.objectName(), "opacity": round(o, 3),
                     "box": [round(r.x(), 1), round(r.y(), 1), round(r.width(), 1), round(r.height(), 1)]}
            if entry["cls"].startswith("QQuickText"):
                entry["text"] = c.property("text")
            found.append(entry)
        return found

    def capture(path=None):
        image = window.grabWindow()
        if image.isNull():
            grab = window.contentItem().grabToImage()
            loop = QtCore.QEventLoop()
            grab.ready.connect(loop.quit)
            QtCore.QTimer.singleShot(3000, loop.quit)
            loop.exec_()
            image = grab.image()
        require(not image.isNull(), "capture failed")
        if path:
            image.save(str(path))
        return image

    # ----- First evaluation with every Global sentinel -----
    sentinel_props = {"odoText": "--", "tripText": "--", "rangeText": "--", "avgText": "--", "nowText": "--",
                      "oatText": "--", "altText": "--", "boostText": "--", "dateText": "--", "timeText": "--:--",
                      "travelText": "--", "gradeText": "--", "rollText": "--", "trailerText": "0"}
    observed = {k: prop(k) for k in sentinel_props}
    check("sentinels: first evaluation shows -- for every invalid reading",
          all(observed[k] == v for k, v in sentinel_props.items()), observed)
    texts = [e["text"] for e in scene_items() if "text" in e and e["opacity"] > 0]
    bad = [t for t in texts if re.search(r"NaN|undefined|null|Infinity|65535|16777215|4095|255\b", str(t))]
    check("sentinels: no raw sentinel or NaN text on screen", not bad, bad)
    check("sentinels: zero warnings on the first evaluation", not messages, list(messages))
    capture(OUT / (layout + "-sentinels.png"))

    def apply(scene, extra=None):
        data = json.loads((GEOMETRY / ("%s-%s.json" % (layout, scene))).read_text(encoding="utf-8"))
        values, heading = raw_state(layout, scene, data["state"])
        heading = tape_heading(data, heading)
        values.update(extra or {})
        # The tape holds the bearing at 5 mph and under, so the bearing goes in at speed first.
        set_value("vehicleSpeed", 200)
        set_value("gpsFixedValid", "A")
        settle(20)
        set_value("gpsBearing", float(heading))
        settle(20)
        alarms = values.pop("alarmTable")
        for name, value in values.items():
            set_value(name, value)
        set_value("alarmTable", alarms)
        set_value("alarmChanged", 1 - int(g.property("alarmChanged") or 0))
        settle(1300)
        if prop("markOn"):
            for unused in range(40):
                if prop("csetOpacity") == 0:
                    break
                settle(100)
        return data

    # ----- Design scenes, stale first -----
    for scene in SCENES:
        data = apply(scene)
        path = OUT / ("%s-%s.png" % (layout, scene))
        image = capture(path)
        items = scene_items()
        geo = geometry(data, items)
        px = pixels(image, GEOMETRY / ("%s-%s.png" % (layout, scene)))
        result["scenes"][scene] = {"png": str(path.relative_to(ROOT)), "geometry": geo, "pixels": px,
                                   "warnings_so_far": len(messages)}

    # ----- Behaviour checks -----
    apply("normal")
    pages = prop("pages")
    shown = []
    for i in range(len(pages)):
        set_value("drivingInfoIndex", i)
        settle(450)
        shown.append(prop("cardShown"))
    check("card: pages 0 to 4 in order", shown == list(pages), shown)
    set_value("drivingInfoIndex", len(pages))
    settle(450)
    over = prop("cardShown")
    set_value("drivingInfoIndex", -1)
    settle(450)
    under = prop("cardShown")
    check("card: an index outside the pages shows pages[0]", over == pages[0] and under == pages[0], [over, under])
    trip = pages.index("trip")
    set_value("drivingInfoIndex", trip)
    settle(450)
    before = capture()
    item.setProperty("tripHold", 0.6)
    settle(100)
    during = capture(OUT / (layout + "-tripHold.png"))
    rings = [e["box"] for e in scene_items() if e["name"] == "trip.ring" and e["opacity"] > 0.01]
    box = QtCore.QRect(*[int(round(v)) for v in rings[0]]) if rings else QtCore.QRect(0, 0, 1, 1)
    diff = region_diff(before, during, box)
    item.setProperty("tripHold", 0)
    settle(100)
    after = region_diff(before, capture(), box)
    check("tripHold: the ring draws while held and clears at 0", diff > 0.2 and after < 0.05, [round(diff, 3), round(after, 3)])
    trip_values = [c for c, o in walk(window.contentItem()) if c.objectName() == "cell.value" and c.property("text") == prop("tripText")]
    QtCore.QMetaObject.invokeMethod(item, "flashTrip", QtCore.Qt.DirectConnection)
    settle(260)
    mid = [round(c.opacity(), 2) for c in trip_values]
    settle(1400)
    end = [round(c.opacity(), 2) for c in trip_values]
    check("flashTrip: the Trip A value blinks and returns to full opacity",
          trip_values and min(mid) < 0.9 and min(end) == 1.0, [mid, end])
    tow = layout == "tow-a"
    set_value("dashboard", 0 if tow else 1)
    settle(500)
    switched = (prop("tow"), prop("cardShown"))
    capture(OUT / (layout + "-switched.png"))
    set_value("dashboard", 1 if tow else 0)
    settle(500)
    back = (prop("tow"), prop("cardShown"))
    check("dashboard switch 0 <-> 1 keeps one card page and no warnings",
          switched[0] == (not tow) and back[0] == tow and back[1] in pages and not messages, [switched, back])
    # Banner sources: a derived warn wins over an adapter caution; otherwise the newest source shows.
    apply("normal")
    call("setTranslation", "Tow/Haul Mode Active")
    set_value("notifyText", 1247)
    set_value("notifyDuration", 5000)
    settle(400)
    adapter = prop("alertShown")
    capture(OUT / (layout + "-notify.png"))
    set_value("gearBoxTemp", 124)
    settle(400)
    warn_over = prop("alertShown")
    set_value("gearBoxTemp", 93)
    set_value("dte", 72)
    settle(400)
    caution_newest = prop("alertShown")
    set_value("notifyDuration", 5001)
    settle(400)
    notify_newest = prop("alertShown")
    check("banner: adapter notify text, warn over caution, newest caution wins",
          adapter[2] == "Tow/Haul Mode Active" and warn_over[2] == "TRANSMISSION HOT"
          and caution_newest[2] == "FUEL LOW" and notify_newest[2] == "Tow/Haul Mode Active",
          [adapter, warn_over, caution_newest, notify_newest])
    set_value("dte", 502)
    long_text = ("Light Electric Trailer Brake Check the trailer connector and the brake controller wiring before you "
                 "continue towing, then confirm the gain setting")
    call("setTranslation", long_text)
    set_value("notifyDuration", 6000)
    settle(400)
    capture(OUT / (layout + "-notify-long.png"))
    title = [c for c, o in walk(window.contentItem()) if c.property("text") == long_text]
    lines = title[0].property("lineCount") if title else 0
    check("banner: a long adapter text wraps on words to two lines", lines == 2, lines)
    call("setTranslation", "   ")
    set_value("notifyDuration", 6001)
    settle(500)
    check("banner: an empty adapter text shows no banner", prop("alertNow") is None, prop("alertNow"))
    set_value("notifyDuration", 0)
    settle(400)
    # Trailer brake gain notify 1246: Towing A jumps the card to the trailer page; Daily A shows the banner text.
    call("setTranslation", "Light Electric Trailer Brake 6.5")
    set_value("nofifyDpf", 65)
    set_value("notifyText", 1246)
    set_value("notifyDuration", 3000)
    settle(500)
    capture(OUT / (layout + "-gain.png"))
    if tow:
        check("gain 1246: Towing A shows the trailer page with gain 6.5 and no banner",
              prop("cardShown") == "trailer" and prop("gainText") == "6.5" and prop("alertNow") is None,
              [prop("cardShown"), prop("gainText"), prop("alertNow")])
    else:
        check("gain 1246: Daily A shows the gain in the banner text",
              (prop("alertShown") or [""] * 3)[2] == "Light Electric Trailer Brake 6.5", prop("alertShown"))
    set_value("notifyDuration", 0)
    settle(400)
    # Overspeed badge (unit 173): one inquiry 50 ms after the load; the badge shows and blinks while enabled and active.
    set_value("overSpeedWarningSpeed", 113)
    set_value("overSpeedWarningEnabled", 1)
    set_value("overSpeedWarningState", 1)
    settle(300)
    badge = [c for c, o in walk(window.contentItem()) if c.objectName() == "overspeed"]
    capture(OUT / (layout + "-overspeed.png"))
    texts = [e.get("text") for e in scene_items() if e.get("text")]
    check("overspeed: badge with the threshold and the unit", bool(badge) and "70" in texts and "MPH" in texts,
          [bool(badge), [t for t in texts if t in ("70", "MPH")]])
    set_value("overSpeedWarningState", 0)
    settle(200)
    res = QtCore.QMetaObject.invokeMethod(window, "inquiries", QtCore.Qt.DirectConnection, QtCore.Q_RETURN_ARG("QVariant"))
    check("overspeed: one overspeedInquire after the load", res == 1, res)
    # Cruise cancel (round 32 cancel32): red for 1 s, then a 0.8 s fade back to the cruise color (amber when not set).
    apply("cruise")
    require(prop("cruiseSet"), "the cruise scene has a set speed")
    set_value("cruiseSpeedSet", 0)
    greens = []
    for wait in (500, 900, 700):
        settle(wait)
        greens.append(QtGui.QColor(prop("cueShown")).green())
    capture(OUT / (layout + "-cancel.png"))
    check("cruise cancel: the cue holds red, fades, and ends amber", greens[0] <= 70 and 70 < greens[1] < 170 and greens[2] >= 170,
          greens)
    # Warning light blink: state 2 blinks at 300 ms.
    alarms = [0] * 300
    alarms[24] = 2
    set_value("alarmTable", alarms)
    set_value("alarmChanged", 1 - int(g.property("alarmChanged") or 0))
    settle(100)
    seen, frames = set(), []
    lamps = [e["box"] for e in scene_items() if e["name"] == "telltale.24"]
    lamp_box = QtCore.QRect(*[int(round(v)) for v in lamps[0]]) if lamps else QtCore.QRect(0, 0, 1, 1)
    for unused in range(16):
        lamp = [c for c, o in walk(window.contentItem()) if c.objectName() == "telltale.24"]
        if lamp:
            seen.add(round(lamp[0].opacity(), 1))
        frames.append(capture())
        settle(45)
    swing = max(region_diff(frames[0], f, lamp_box) for f in frames)
    check("warning light: state 2 blinks (opacity reaches 0 and 1, and the lamp pixels change)",
          lamps and {0.0, 1.0} <= seen and swing > 0.1, [sorted(seen), round(swing, 3)])
    result["warnings"] = list(messages)
    check("zero QML warnings over the whole run", not messages, list(messages)[:20])
    check("every Global name in vnL exists in Global.qml", not missing, missing)
    print("LAYOUT_PREVIEW_RESULT " + json.dumps(result), flush=True)
    window.setProperty("visible", False)
    return 0


def raw(image):
    ptr = image.constBits()
    ptr.setsize(image.byteCount())
    return bytes(ptr)


def region_diff(a, b, rect):
    """Fraction of pixels in rect that differ by more than 24 levels."""
    ca, cb = a.copy(rect).convertToFormat(4), b.copy(rect).convertToFormat(4)
    da, db = raw(ca), raw(cb)
    changed = sum(1 for i in range(0, len(da), 4) if abs(da[i] - db[i]) + abs(da[i + 1] - db[i + 1]) + abs(da[i + 2] - db[i + 2]) > 24)
    return changed / max(1, len(da) // 4)


def pixels(image, design_path):
    from PyQt5 import QtCore, QtGui
    design = QtGui.QImage(str(design_path))
    if design.isNull():
        return {"error": "no design png"}

    def small(img, w, h):
        s = img.convertToFormat(QtGui.QImage.Format_RGB32).scaled(w, h, QtCore.Qt.IgnoreAspectRatio, QtCore.Qt.SmoothTransformation)
        return raw(s)
    a, b = small(image, 480, 233), small(design, 480, 233)
    total = sum(abs(a[i] - b[i]) + abs(a[i + 1] - b[i + 1]) + abs(a[i + 2] - b[i + 2]) for i in range(0, len(a), 4))
    mean = total / (480 * 233 * 3)
    a8, b8 = small(image, 240, 117), small(design, 240, 117)
    tiles = []
    for ty in range(0, 117, 8):
        for tx in range(0, 240, 8):
            s, n = 0, 0
            for y in range(ty, min(117, ty + 8)):
                for x in range(tx, min(240, tx + 8)):
                    i = (y * 240 + x) * 4
                    s += abs(a8[i] - b8[i]) + abs(a8[i + 1] - b8[i + 1]) + abs(a8[i + 2] - b8[i + 2])
                    n += 3
            tiles.append((round(s / n, 2), [tx * 8, ty * 8, 64, 64]))
    tiles.sort(reverse=True)
    return {"mean_abs_diff_quarter_scale": round(mean, 3), "worst_tiles_64": [{"diff": d, "box": box} for d, box in tiles[:6]]}


CARDINALS = {"N": 0, "NE": 45, "E": 90, "SE": 135, "S": 180, "SW": 225, "W": 270, "NW": 315}
TAPE_PX_PER_DEG = 2.5


def inside(a, b, slack=0.5):
    """True when box a lies inside box b."""
    return (a[0] >= b[0] - slack and a[1] >= b[1] - slack
            and a[0] + a[2] <= b[0] + b[2] + slack and a[1] + a[3] <= b[1] + b[3] + slack)


def tape_groups(data):
    """Label node indexes of each heading tape layer, in document order."""
    groups, tape = [], None
    for i, n in enumerate(data["nodes"]):
        if n.get("cls") == "abs hdgtape":
            tape = n["box"]
            groups.append([])
        elif tape is not None and n["tag"] == "text" and inside(n["box"], tape):
            groups[-1].append(i)
        elif tape is not None and n["tag"] not in ("svg", "g", "path", "line", "polygon", "rect", "text"):
            tape = None
    return groups


def tape_heading(data, fallback):
    """Heading of the first tape layer, read from the label positions (the round 20 turn demo drives that layer)."""
    groups = tape_groups(data)
    x = y = 0.0
    for i in (groups[0] if groups else []):
        n = data["nodes"][i]
        deg = CARDINALS.get((n.get("text") or "").strip())
        if deg is None:
            continue
        h = math.radians(deg + (960 - (n["box"][0] + n["box"][2] / 2)) / TAPE_PX_PER_DEG)
        x, y = x + math.cos(h), y + math.sin(h)
    return round(math.degrees(math.atan2(y, x)) % 360, 1) if x or y else fallback


def design_texts(data):
    """Visible design text nodes. Labels of a second tape layer (the turn demo leaves the static layer) are skipped."""
    groups = tape_groups(data)
    skip = {i for grp in groups[1:] for i in grp}
    nodes = data["nodes"]
    texts = [n for n in nodes if (n.get("text") or "").strip()]
    out = []
    for i, n in enumerate(nodes):
        text = (n.get("text") or "").strip()
        style = n.get("style", {})
        if not text or i in skip or style.get("opacity") == "0" or style.get("visibility") == "hidden":
            continue
        # A text box is exact when the box holds only the text: an SVG text, or an inline element without nested text.
        # A block, a flex box, a box with nested text (a unit span), or a box-keyed element (padding) bounds the text.
        nested = any(m is not n and m["box"] != n["box"] and inside(m["box"], n["box"]) for m in texts)
        keyed = any(pred(n) for pred in BOX_KEYS.values())
        exact = n["tag"] == "text" or (not nested and not keyed and style.get("display") in ("inline", "inline-block"))
        out.append({"text": text, "box": n["box"], "cls": n.get("cls", ""), "tag": n["tag"], "exact": exact,
                    "align": style.get("text-align", "start"), "keyed": keyed})
    return out


def box_miss(node, q):
    """Deviation of a QML text box q from a design text node, by the rules in design_texts."""
    d = node["box"]
    if node["exact"]:
        dev = [abs(q[i] - d[i]) for i in range(4)]
        if node["tag"] == "text":
            dev[3] = 0          # SVG text boxes carry the font box, not the line box
        return max(dev)
    # Bounded text: inside the box, on the box vertical center, and on the aligned edge (keyed boxes: inside only).
    over = max(d[0] - q[0], d[1] - q[1], q[0] + q[2] - d[0] - d[2], q[1] + q[3] - d[1] - d[3], 0)
    dev = [over, abs((q[1] + q[3] / 2) - (d[1] + d[3] / 2))]
    if not node["keyed"]:
        if node["align"] in ("center", "-webkit-center"):
            dev.append(abs((q[0] + q[2] / 2) - (d[0] + d[2] / 2)))
        elif node["align"] in ("right", "end", "-webkit-right"):
            dev.append(abs((q[0] + q[2]) - (d[0] + d[2])))
        else:
            dev.append(abs(q[0] - d[0]))
    return max(dev)


# objectName keys against design node classes.
BOX_KEYS = {
    "speed": lambda n: n.get("cls") == "abs big speed",
    "hdgtape": lambda n: n.get("cls") == "abs hdgtape",
    "card": lambda n: "wide42" in (n.get("cls") or "") or "card sec sq" in (n.get("cls") or ""),
    "tempcard": lambda n: (n.get("cls") or "").startswith("abs card t25"),
    "dots": lambda n: n.get("cls") == "dots",
    "drv30": lambda n: (n.get("cls") or "").startswith("abs drv30"),
    "dchip": lambda n: (n.get("cls") or "").startswith("dchip"),
    "alert": lambda n: "alert4" in (n.get("cls") or ""),
    "sunit": lambda n: "sunit" in (n.get("cls") or ""),
    "zcol": lambda n: n.get("cls") == "zcol",
    "tread": lambda n: (n.get("cls") or "").startswith("abs tread"),
}


def on_screen(box):
    """The part of a box inside the 1920 x 932 screen (a card may run past the edge to hide the outer corners)."""
    x0, y0 = max(0, box[0]), max(0, box[1])
    x1, y1 = min(1920, box[0] + box[2]), min(932, box[1] + box[3])
    return [x0, y0, round(max(0, x1 - x0), 1), round(max(0, y1 - y0), 1)]


def geometry(data, items):
    texts = [e for e in items if "text" in e and e["opacity"] > 0.01 and e["text"]]
    misses, matched = [], 0
    for node in design_texts(data):
        if node["text"] in EXPECTED_TEXT_DEVIATIONS:
            continue
        cands = [e for e in texts if str(e["text"]).strip() == node["text"]]
        if not cands:
            misses.append({"text": node["text"], "design": node["box"], "reason": "no text item"})
            continue
        best = min(cands, key=lambda e: box_miss(node, e["box"]))
        if box_miss(node, best["box"]) > TOLERANCE:
            misses.append({"text": node["text"], "design": node["box"], "qml": best["box"],
                           "rule": "exact" if node["exact"] else "bounded"})
        else:
            matched += 1
    for key, pred in BOX_KEYS.items():
        nodes = [n for n in data["nodes"] if pred(n) and n.get("style", {}).get("opacity") != "0"]
        boxes = [dict(e, box=on_screen(e["box"])) for e in items if e["name"] == key and e["opacity"] > 0.01]
        for node in nodes:
            if not boxes:
                misses.append({"key": key, "design": node["box"], "reason": "no item"})
                continue
            best = min(boxes, key=lambda e: sum(abs(e["box"][i] - node["box"][i]) for i in range(4)))
            if max(abs(best["box"][i] - node["box"][i]) for i in range(4)) > TOLERANCE:
                misses.append({"key": key, "design": node["box"], "qml": best["box"]})
            else:
                matched += 1
    for node in data["nodes"]:
        m = re.search(r"/alarm/(\d+)\.png", node.get("src", "") or "")
        if node["tag"] != "img" or not m:
            continue
        boxes = [e for e in items if e["name"] == "telltale." + m.group(1)]
        if not boxes or max(abs(boxes[0]["box"][i] - node["box"][i]) for i in range(4)) > TOLERANCE:
            misses.append({"key": "telltale." + m.group(1), "design": node["box"], "qml": boxes[0]["box"] if boxes else None})
        else:
            matched += 1
    return {"matched": matched, "mismatches": misses}


def parent(only):
    OUT.mkdir(parents=True, exist_ok=True)
    report = {"command": REPRODUCE, "layouts": {}, "passed": True}
    for layout in only or LAYOUTS:
        proc = subprocess.run([sys.executable, __file__, "--child", layout], capture_output=True, text=True, timeout=1200)
        line = [l for l in proc.stdout.splitlines() if l.startswith("LAYOUT_PREVIEW_RESULT ")]
        if not line:
            report["layouts"][layout] = {"error": proc.stderr[-4000:], "returncode": proc.returncode}
            report["passed"] = False
            print("%s: FAIL (no result, exit %d)" % (layout, proc.returncode))
            print("    " + (proc.stderr.strip().splitlines() or [""])[-1])
            continue
        res = json.loads(line[0][len("LAYOUT_PREVIEW_RESULT "):])
        report["layouts"][layout] = res
        geo_fail = {s: v["geometry"]["mismatches"] for s, v in res["scenes"].items() if v["geometry"]["mismatches"]}
        failed = [c for c in res["checks"] if not c["passed"]]
        res["passed"] = not geo_fail and not failed and not res["warnings"] and not res["missing_global_names"] and not res["denied"]
        report["passed"] = report["passed"] and res["passed"]
        print("%s: %s" % (layout, "PASS" if res["passed"] else "FAIL"))
        print("  warnings: %d" % len(res["warnings"]))
        for w in res["warnings"][:10]:
            print("    " + w)
        for c in res["checks"]:
            print("  %s %s" % ("ok  " if c["passed"] else "FAIL", c["name"]) + ("" if c["passed"] else "  " + json.dumps(c["detail"])[:300]))
        for scene, v in res["scenes"].items():
            g = v["geometry"]
            print("  %-11s geometry %3d ok %2d off  pixels %.2f" % (scene, g["matched"], len(g["mismatches"]),
                                                                    v["pixels"].get("mean_abs_diff_quarter_scale", -1)))
            for m in g["mismatches"][:8]:
                print("      " + json.dumps(m, ensure_ascii=True))
    (OUT / "report.json").write_bytes(json.dumps(report, indent=1).encode("utf-8"))
    print("report: " + str((OUT / "report.json").relative_to(ROOT)))
    print("reproduce: " + REPRODUCE)
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--child")
    ap.add_argument("--only", nargs="*")
    args = ap.parse_args()
    if args.child:
        require(args.child in LAYOUTS, "layout")
        sys.exit(child(args.child))
    sys.exit(parent(args.only))
