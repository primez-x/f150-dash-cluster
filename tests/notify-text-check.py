"""Load the notification text table with Qt 5.14.2 and check the English text that the banner shows.

The cluster reads /etc/common/NotifyTranslation.qml. The banner shows mNotifyItems[id][language]; English is language 1.
The original phase must reproduce the known slot defect (id 1409 shows the id 1408 text). The patched phase must pass.
"""
import json
from pathlib import Path
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCES = {"original": ROOT / "installed/capture-04/rootfs/etc/common/NotifyTranslation.qml",
           "patched": ROOT / "patches/capture-04/etc/common/NotifyTranslation.qml"}
RESULTS = ROOT / "analysis/capture-04"
COUNT = 1456
ENGLISH = 1
# Text the patched table must show. Values with a gain number use nofifyDpf 55 (5.5).
EXPECTED = {
    1243: "Adjustable Pedals Unavailable: Cruise Engaged",
    1244: "Adjustable Pedals Unavailable: Vehicle in Reverse",
    1245: "Extended Idle Shutdown Complete",
    1246: "Light Electric Trailer Brake 5.5",
    1274: "Slow to 5 km/h for 4WD Low",
    1276: "Vehicle in 4WD Low",
    1278: "TRAILER DISCONNECTED",
    1308: "Train Left Rear Tire",
    1352: "Locking Differential Disabled",
    1407: "AdvanceTrac OFF",
    1408: "AdvanceTrac ON",
    1409: "TRACTION CONTROL OFF",
    1410: "TRACTION CONTROL ON",
}
WRAPPER = """import QtQuick 2.12
Item {
    QtObject { id: stub; property int nofifyDpf: 55; property int nofifyU16: 0; property int language: 1 }
    Item { id: mGlobalId; property var item: stub }
    Loader { id: mNotifyId; objectName: "table"; source: %s }
}
"""


def run(phase):
    from PyQt5 import QtCore, QtGui, QtQml
    messages = []
    QtCore.qInstallMessageHandler(lambda kind, context, text: messages.append(text))
    app = QtGui.QGuiApplication([])
    with tempfile.TemporaryDirectory() as folder:
        wrapper = Path(folder) / "wrapper.qml"
        wrapper.write_bytes((WRAPPER % json.dumps(SOURCES[phase].resolve().as_uri())).encode())
        engine = QtQml.QQmlEngine()
        component = QtQml.QQmlComponent(engine, QtCore.QUrl.fromLocalFile(str(wrapper)))
        root = component.create()
        if root is None:
            raise RuntimeError("wrapper failed: " + "; ".join(e.toString() for e in component.errors()))
        app.processEvents()
        table = root.findChild(QtCore.QObject, "table").property("item")
        items = table.property("mNotifyItems").toVariant()
        slots = [i for i in range(len(items)) if items[i] != table.property("mNotify%d" % i).toVariant()]
        english = {i: items[i][ENGLISH] for i in EXPECTED}
        wrong = {i: english[i] for i, text in EXPECTED.items() if english[i] != text}
        dummy = [i for i in range(1216, len(items)) if "dummy" in str(items[i][ENGLISH])]
        root.deleteLater()
        app.processEvents()
    return {"phase": phase, "count": len(items), "slot_mismatches": slots, "wrong_text": wrong,
            "ford_rows_with_dummy": dummy, "warnings": messages}


def main():
    phase = sys.argv[1] if len(sys.argv) > 1 else "patched"
    if phase not in SOURCES:
        raise SystemExit("Use original or patched")
    result = run(phase)
    if phase == "original":
        result["passed"] = result["slot_mismatches"] == [1409] and not result["warnings"]
    else:
        result["passed"] = (result["count"] == COUNT and not result["slot_mismatches"] and not result["wrong_text"]
                            and not result["ford_rows_with_dummy"] and not result["warnings"])
    (RESULTS / ("notify-text-check-%s.json" % phase)).write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({k: result[k] for k in ("phase", "count", "slot_mismatches", "passed")} | {"warnings": len(result["warnings"])}))
    raise SystemExit(0 if result["passed"] else 1)


if __name__ == "__main__":
    main()
