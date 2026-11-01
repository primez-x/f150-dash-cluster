import QtQuick 2.12
import "qrc:/Trucks/common"

// Settings menu. Replaces the compiled MenuItemsList and every page under the list: Vehicle, System, Service, and Factory,
// with G-force and the Factory setup pages (stock MenuVehicleGForce, FactoryOdoSetup, FactoryTankSetup, FactoryVehicleModel,
// and FactoryShellCmd; cache 100, 084, 080, 082, 079). MenuPage hosts this file in a 1720x511 slot and calls
// key(keycode, state). MenuPage reads nothing else.
// Two blocks: the engine (state, rows, keys, native calls) and the view. The view reads engine properties only.
// Fixes: vehicle.md #1-#9, system.md #1, #3-#8, #10, #14, #15, shell-service.md S1-S9, K2 (analysis/capture-04/menu-audit).
ItemInfo {
    id: menuRoot
    width: 1720
    height: 511

    // ===== Engine =====
    property var mPath: ["home"]        // open pages, top level first
    property var mCursors: []           // parent row for each open level, for Back
    property int mCursor: 0
    property bool mPressed: false
    property int mHeldKey: -1           // a held key; the next release of the key is swallowed
    property bool mEditing: false
    property var mEditValue: 0
    property var mEditStart: 0
    property var mEditFields: []        // field editors: date [year, month, day(, hour, minute)] or digits [d0, d1, ...]
    property int mEditField: 0
    property int mArmedRow: -1          // action row that waits for the second OK
    property int mSentRow: -1           // action row that shows the sent text
    property var mShellCmds: []         // service command file names, read once when Service commands opens
    readonly property string mPage: mPath[mPath.length-1]
    readonly property var mRows: pageRows(mPage, mArmedRow, mSentRow)
    readonly property var mFocusRow: mCursor<mRows.length?mRows[mCursor]:null
    readonly property string mPathText: mPath.map(pageTitle).join(" › ")
    readonly property string mEditText: mEditing?editText():""
    readonly property bool mF150: Number(mTrucksModel)===1 && mGlobalId.item.vehicleModel===1

    // Ford setup rows for the 2011-2014 F150 (truck model 1, vehicle model 1). The key is the fordSetupInfo index.
    readonly property var mFordPages: ({
        "lighting": [2], "locks": [5, 6, 58], "assist": [51, 52, 56, 57, 59, 70], "remote": [60, 61, 62, 63, 64, 65, 66]
    })
    readonly property var mFord: ({
        2: {"title": "Headlamp delay", "kind": "choice", "options": [0, 10, 20, 30, 60, 90, 120, 180], "unit": "s"},
        5: {"title": "Auto lock", "kind": "toggle"},
        6: {"title": "Auto unlock", "kind": "toggle"},
        58: {"title": "Remote unlock", "kind": "toggle", "labels": ["One stage", "Two stage"]},
        51: {"title": "Trailer brake mode", "kind": "toggle", "labels": ["Electric", "Electric over hydraulic"]},
        52: {"title": "Trailer sway control", "kind": "toggle"},
        56: {"title": "Range calculation", "kind": "toggle", "labels": ["Normal", "Towing"]},
        57: {"title": "Easy entry and exit", "kind": "toggle"},
        59: {"title": "Oil life start value", "kind": "number", "min": 10, "max": 100, "step": 10, "unit": "%"},
        // The camera toggle sends 0 or 1 only. Value 2 is the camera fault state from the truck.
        70: {"title": "Off-road camera", "kind": "toggle", "labels": ["Disabled", "Enabled", "Fault"]},
        60: {"title": "Front defrost", "kind": "toggle"},
        61: {"title": "Rear defrost", "kind": "toggle"},
        62: {"title": "Passenger seat", "kind": "toggle"},
        63: {"title": "Climate", "kind": "toggle", "labels": ["Last setting", "Automatic"]},
        64: {"title": "Run time", "kind": "choice", "options": [0, 1, 2, 3], "labels": ["Off", "5 min", "10 min", "15 min"]},
        65: {"title": "Silent start", "kind": "toggle"},
        66: {"title": "Windshield wiper", "kind": "toggle"}
    })
    readonly property var mTitles: ({
        "home": "Settings", "vehicle": "Vehicle", "lighting": "Lighting", "locks": "Locks", "assist": "Driver assist",
        "remote": "Remote start", "reset": "Reset", "gforce": "G-force", "system": "System", "language": "Language",
        "datetime": "Date and time", "units": "Units", "display": "Display", "version": "Version", "factory": "Factory",
        "general": "General settings", "odometer": "Odometer setup", "tank": "Fuel tank setup", "profile": "Vehicle profile",
        "commands": "Service commands", "service": "Service"
    })
    // No compiled page or native code reads these General settings in this firmware (Global.setFactory cases).
    readonly property var mFactoryNoEffect: [6, 10, 11, 12, 13, 16, 17]
    readonly property var mDebugLevels: [0, 1, 2, 4, 8]
    readonly property var mDebugTexts: ["Off", "Warnings", "UART receive", "UART transmit", "MCU"]

    Component.onCompleted: {
        mGlobalId.item.menuBarItemIndex=0
    }
    onMRowsChanged: {
        if(mCursor>=mRows.length)
            mCursor=Math.max(0, mRows.length-1)
    }
    // MenuPage unloads this file when the menu closes. A calibration that is still on would keep the gyro offsets
    // following the truck (VehicleEvent onPitchRollNotify) until the next menu open, so the close ends the calibration.
    Component.onDestruction: {
        if(mGlobalId.item.mGyroCalibration)
            mGlobalId.item.mGyroCalibration=0
    }
    Timer {
        id: mArmTimer
        interval: 5000
        onTriggered: mArmedRow=-1
    }
    Timer {
        id: mSentTimer
        interval: 2000
        onTriggered: mSentRow=-1
    }
    // One read-back inquiry 500 ms after the last user set. The inquiry is the same one the stock page sends on load.
    Timer {
        id: mFordReadBack
        interval: 500
        onTriggered: mEventHandleId.item.seniorF150_11_14_SetupInquire()
    }
    Timer {
        id: mServiceReadBack
        interval: 500
        onTriggered: mEventHandleId.item.maintenacneInquire()
    }
    // Gyro calibration: the same 1200 ms window as the stock G-force page. VehicleEvent stores the offsets while the
    // flag is on; the flag clears 1200 ms after any write of 1.
    Timer {
        interval: 1200
        running: !!mGlobalId.item.mGyroCalibration
        onTriggered: mGlobalId.item.mGyroCalibration=0
    }

    // ----- Keys -----
    // States: 0 release, 1 press, 2 hold, 3 (3 s hold) ignored. Up, Down, Enter, and Right act on press, so a step does
    // not wait for the release; the release of these keys does nothing. Back, Left, and Modes act on release, because a
    // hold of these keys has a different action.
    // Hold: Modes = Enter, Back = close the menu, other keys nothing. The next release of a held key is swallowed.
    // A new press ends the hold, so a hold without a release does not swallow the next tap.
    // Each key event writes one "viknav-key" line to the Launcher log: time (ms), key code, state, then the page path,
    // cursor, and edit state after the event. The lines show repeated, held, or missing events from the wheel.
    function key(code, state) {
        handleKey(code, state)
        console.log("viknav-key "+Date.now()+" "+code+" "+state+" "+mPath.join("/")+" "+mCursor+(mEditing?" edit":""))
        return 1
    }
    function handleKey(code, state) {
        var g=mGlobalId.item
        var onPress=code===g.swcUp || code===g.swcDown || code===g.swcEnter || code===g.swcRight
        if(state===1) {
            mHeldKey=-1
            mPressed=true
            if(onPress) {
                // The release (and a hold) of this key is swallowed.
                mHeldKey=code
                release(code)
            }
            return 1
        }
        if(state===2) {
            mPressed=false
            if(mHeldKey===code)
                return 1
            mHeldKey=code
            // The truck wheel has no Back key, so a Left hold also closes the menu.
            if(code===g.swcBack || code===g.swcLeft)
                closeMenu()
            else if(code===g.swcModes)
                release(g.swcEnter)
            return 1
        }
        if(state!==0)
            return 1
        mPressed=false
        if(mHeldKey===code) {
            mHeldKey=-1
            return 1
        }
        if(!onPress)
            release(code)
        return 1
    }
    function release(code) {
        var g=mGlobalId.item
        var action=code===g.swcUp?"up":
                   (code===g.swcDown || code===g.swcModes)?"down":
                   (code===g.swcBack || code===g.swcLeft)?"back":
                   (code===g.swcEnter || code===g.swcRight)?"enter":""
        if(action==="")
            return
        if(mArmedRow>=0 && action!=="enter")
            disarm()
        // In an editor the keys follow the up and down chevrons: Up raises the value, the field, or goes to the next
        // option; Down (and Modes) lowers the value or goes to the previous option.
        if(mEditing) {
            switch(action) {
            case "up": editStep(1); break
            case "down": editStep(-1); break
            case "back": dropState(); break
            case "enter": editEnter(); break
            }
            return
        }
        switch(action) {
        case "up": move(-1); break
        case "down": move(1); break
        case "back": closePage(); break
        case "enter": activate(); break
        }
    }
    function move(step) {
        var count=mRows.length
        if(count>0)
            mCursor=(mCursor+step+count)%count
    }

    // ----- Pages -----
    function openPage(page) {
        dropState()
        mCursors=mCursors.concat([mCursor])
        mPath=mPath.concat([page])
        mCursor=0
        var e=mEventHandleId.item
        switch(page) {
        case "vehicle": if(mF150) e.seniorF150_11_14_SetupInquire(); break
        case "service": e.maintenacneInquire(); break
        case "version": e.versionInquire(); break
        case "factory": e.shellCmdInquire(); break
        case "general": e.systemInquire(); break
        case "commands":
            // The stock page reads the local and USB command files once, when the page loads.
            var names=[]
            var count=Number(e.getSehllCmdCount())
            for(var i=0; i<count; i++)
                names.push(e.getSehllCmdName(i))
            mShellCmds=names
            break
        }
    }
    function closePage() {
        if(mPath.length<=1) {
            closeMenu()
            return
        }
        dropState()
        var parentRow=mCursors[mCursors.length-1]
        mCursors=mCursors.slice(0, -1)
        mPath=mPath.slice(0, -1)
        mCursor=parentRow
    }
    function closeMenu() {
        dropState()
        mGlobalId.item.menuBarIndex=0
    }
    function dropState() {
        mEditing=false
        mEditFields=[]
        mEditField=0
        disarm()
        mSentRow=-1
        mSentTimer.stop()
    }
    function disarm() {
        mArmedRow=-1
        mArmTimer.stop()
    }
    function pageTitle(page) {
        if(page.indexOf("svc")===0)
            return serviceName(Number(page.slice(3)))
        return mTitles[page]
    }

    // ----- Rows -----
    // Row fields: kind (page, toggle, choice, number, date, digits, action, command, select, info, unavailable), title, value,
    // and per kind: page, op, arg, options, texts, start, min, max, step, unit, color, verb and done (action: the word of the
    // second OK and the text after the send; default Reset and "Reset sent"; an empty done shows no text).
    // View fields: current (index of the value in seg or options, -1 when the value is outside), seg (labels for a segment
    // control; a toggle without seg is a switch), note (a short state next to the control).
    function makeRow(kind, title, value, extra) {
        var row={"kind": kind, "title": title, "value": value===undefined?"":String(value)}
        for(var name in extra)
            row[name]=extra[name]
        return row
    }
    function unavailableRow(title, reason) {
        return makeRow("unavailable", title, reason, {})
    }
    function pageRows(page, armedRow, sentRow) {
        var g=mGlobalId.item
        // The truck data arrays change in place. A read of the change flags makes this binding refresh.
        g.fordSetupInfoChanged
        g.mainTentChanged
        var rows=buildRows(page)
        for(var i=0; i<rows.length; i++) {
            if(i===armedRow)
                rows[i].value="Press OK again to "+actionVerb(rows[i]).toLowerCase()
            else if(i===sentRow)
                rows[i].value=rows[i].done!==undefined?rows[i].done:"Reset sent"
        }
        return rows
    }
    function actionVerb(row) {
        return row && row.verb?row.verb:"Reset"
    }
    function buildRows(page) {
        var g=mGlobalId.item
        var t=mTranslationId.item
        switch(page) {
        case "home":
            var home=[makeRow("page", "Vehicle", "", {"page": "vehicle"}), makeRow("page", "System", "", {"page": "system"})]
            if(Number(mTrucksModel)!==0)
                home.push(makeRow("page", "Service", "", {"page": "service"}))
            return home
        case "vehicle":
            var vehicle=[["lighting", "Lighting"], ["locks", "Locks"], ["assist", "Driver assist"], ["remote", "Remote start"]].map(function(entry) {
                return mF150?makeRow("page", entry[1], "", {"page": entry[0]}):
                             unavailableRow(entry[1], "Not set up for this vehicle profile")
            })
            return vehicle.concat([makeRow("page", "Reset", "", {"page": "reset"}),
                                   makeRow("page", "G-force", "", {"page": "gforce"})])
        case "gforce":
            return gforceRows()
        case "lighting":
        case "locks":
        case "assist":
        case "remote":
            return mFordPages[page].map(fordRow)
        case "reset":
            return resetRows(Number(mTrucksModel), g.vehicleModel).map(function(name) {
                return makeRow("action", resetTitle(name), "", {"op": "reset", "arg": name})
            })
        case "system":
            return [makeRow("page", "Language", t.mSystemLanguages[g.language], {"page": "language"}),
                    makeRow("page", "Date and time", clockSummary(), {"page": "datetime"}),
                    makeRow("page", "Units", "", {"page": "units"}),
                    makeRow("page", "Display", "", {"page": "display"}),
                    makeRow("page", "Version", "", {"page": "version"}),
                    makeRow("page", "Factory", "", {"page": "factory"})]
        case "factory":
            return factoryRows()
        case "general":
            return generalRows()
        case "odometer":
            return [makeRow("digits", "Odometer", g.getOdo(1), {"op": "odo"})]
        case "tank":
            return [makeRow("digits", "Main and sub tank", tankText(), {"op": "tank"})]
        case "profile":
            return profileRows()
        case "commands":
            if(mShellCmds.length===0)
                return [unavailableRow("Service commands", "No command files on the cluster or a USB drive")]
            return mShellCmds.map(function(name) {
                return makeRow("action", name, "", {"op": "shell", "arg": name, "verb": "Run", "done": "Command sent"})
            })
        case "language":
            return t.mSystemLangPickUp.map(function(code) {
                return makeRow("select", t.mSystemLanguages[code], code===g.language?"Selected":"", {"op": "language", "arg": code})
            })
        case "datetime":
            return [makeRow("toggle", "GPS sets the clock", g.gpsAutoSetRtcEnabled?"On":"Off", {"op": "gps", "current": g.gpsAutoSetRtcEnabled?1:0}),
                    g.gpsAutoSetRtcEnabled?unavailableRow("Set date and time", "Off while GPS sets the clock"):
                                           makeRow("date", "Set date and time", clockText(), {"op": "clock"}),
                    makeRow("toggle", "Time format", g.rtc24h?"24 h":"12 h", {"op": "format", "seg": ["12 h", "24 h"], "current": g.rtc24h?1:0})]
        case "units":
            return unitRows()
        case "display":
            var warning=g.overSpeedWarningEnabled
            var speed=Number(g.getOverSpeedWaningSpeed(0))
            return [layoutRow(), brightnessRow("Day brightness", 0), brightnessRow("Night brightness", 1),
                    makeRow("toggle", "Speed warning", warning?"On":"Off", {"op": "warn", "current": warning?1:0}),
                    warning?makeRow("number", "Speed warning at", g.getOverSpeedWaningSpeed(1),
                                    {"op": "warnSpeed", "min": 20, "max": 200, "step": 5, "unit": " "+g.vehicleSpeedUnit,
                                     "start": clamp(Math.round((isNaN(speed)?0:speed)/5)*5, 20, 200)}):
                           unavailableRow("Speed warning at", "Turn on the speed warning first")]
        case "version":
            return [makeRow("info", "App", g.launcherVersion, {}), makeRow("info", "Plugins", g.pluginsVersion, {}),
                    makeRow("info", "Protocol", g.mcuVersion, {})]
        case "service":
            // The truck oil life comes first: the service reminders below are the adapter's own counters, and their
            // Reset does not reset the truck oil life. Reset oil life sends the same command as Vehicle > Reset.
            var items=mF150?[oilLifeRow(), makeRow("action", "Reset oil life", "", {"op": "reset", "arg": "oil"})]:[]
            for(var id=0; id<8; id++)
                items.push(makeRow("page", serviceName(id), g.mainTentReminder[id]===0xFFFFFF?"No data from adapter":g.getMaintentReminder(id),
                                   {"page": "svc"+id, "color": g.getMaintentStateColor(id)}))
            return items
        }
        if(page.indexOf("svc")===0)
            return serviceRows(Number(page.slice(3)))
        return []
    }

    // ----- Vehicle -----
    function fordText(spec, raw) {
        if(spec.unit==="s")
            return raw===0?"Off":raw+" s"
        if(spec.unit==="%")
            return raw+"%"
        if(spec.labels)
            return spec.labels[raw]!==undefined?spec.labels[raw]:"Value "+raw
        return raw===0?"Off":raw===1?"On":"Value "+raw
    }
    function fordRow(id) {
        var g=mGlobalId.item
        var spec=mFord[id]
        if(!g.fordSetupKnown)
            return unavailableRow(spec.title, "Waiting for truck")
        var raw=Number(g.fordSetupInfo[id])
        var extra={"op": "ford", "arg": id}
        if(spec.kind==="toggle") {
            extra.current=raw===0 || raw===1?raw:-1
            if(spec.labels)
                extra.seg=spec.labels.slice(0, 2)
        } else if(spec.kind==="choice") {
            extra.options=spec.options
            extra.texts=spec.options.map(function(option) { return fordText(spec, option) })
            extra.start=nearest(spec.options, raw)
            extra.current=spec.options.indexOf(raw)
            if(spec.options.length<=4)
                extra.seg=extra.texts
        } else if(spec.kind==="number") {
            extra.min=spec.min
            extra.max=spec.max
            extra.step=spec.step
            extra.unit=spec.unit
            extra.start=clamp(Math.round(raw/spec.step)*spec.step, spec.min, spec.max)
        }
        return makeRow(spec.kind, spec.title, fordText(spec, raw), extra)
    }
    // Same write as the stock pages: local value, change flag, then the Ford setup frame. One read-back follows.
    function fordSend(id, value) {
        var g=mGlobalId.item
        g.fordSetupInfo[id]=value
        g.fordSetupInfoChanged=!g.fordSetupInfoChanged
        mEventHandleId.item.setFordSetup(14, g.f150_11_14_param_id(id), value)
        mFordReadBack.restart()
    }
    // Reset rows, titles, profile rules, and commands: ported unchanged from vnR.qml.
    function resetRows(model, vehicle) {
        var removed
        switch(model){
        case 1: // ford f150
            removed=vehicle===0?["factory", "key", "tpmsLearn", "compass", "oil"]:
                    vehicle===1?["key", "tpmsLearn", "compass"]:["oil"]
            break
        case 8: // yukon
            removed=["tpms"]
            break
        case 7: // everest
            removed=["factory", "key", "compass", "tpmsLearn"]
            break
        default:
            removed=["oil", "factory", "key", "tpmsLearn", "compass"]
        }
        return ["tripA", "tripB", "since", "tpms", "factory", "key", "tpmsLearn", "oil", "compass"].filter(function(row) {
            return removed.indexOf(row)<0
        })
    }
    function resetTitle(row) {
        var t=mTranslationId.item
        var language=mGlobalId.item.language
        switch(row){
        case "tripA": return t.reset[language]+" TripA"
        case "tripB": return t.reset[language]+" TripB"
        case "since": return t.mResetTripInfo
        case "tpms": return t.mResetTpms[language]
        case "factory": return t.mResetFactory[language]
        case "key": return t.mResetKey[language]
        case "tpmsLearn": return t.mResetTpms[language]
        case "oil": return t.getVehicleSettingsItem(59)
        case "compass": return t.mCalibrateCompass
        }
        return ""
    }
    function runReset(row) {
        var e=mEventHandleId.item
        var model=Number(mTrucksModel)
        var vehicle=mGlobalId.item.vehicleModel
        var yukon=model===8
        switch(row){
        case "tripA": e.resetTrip(0); break
        case "tripB": e.resetTrip(1); break
        case "since": e.resetSinceReset(); break
        case "tpms": e.tpmsReset(); break
        case "factory":
            if(model===1 && vehicle===1)
                e.setFordSetup(14, 18, 1)
            else if(yukon)
                e.setFordSetup(13, 11, 1)
            break
        case "key": if(yukon) e.setFordSetup(13, 8, 1); break
        case "tpmsLearn": if(yukon) e.setFordSetup(13, 9, 1); break
        case "oil":
            if(yukon || (model===1 && vehicle===1)) {
                e.resetOilLife()
                // resetOilLife writes fordSetupInfo[59] in place: refresh the rows, then read the Ford setup back.
                mGlobalId.item.fordSetupInfoChanged=!mGlobalId.item.fordSetupInfoChanged
                if(model===1)
                    mFordReadBack.restart()
            }
            break
        case "compass": if(yukon) e.setFordSetup(13, 14, 1); break
        }
    }
    // G-force: the pitch and roll text of the stock gauges (Global getPitchString and getRollString, "--°" before the
    // first sensor frame). The rows follow each sensor change. The values hold still while the calibration runs.
    function gforceRows() {
        var g=mGlobalId.item
        return [makeRow("info", "Pitch", g.getPitchString(), {}), makeRow("info", "Roll", g.getRollString(), {}),
                makeRow("action", "Calibrate", g.mGyroCalibration?"Calibrating":"", {"op": "gyro", "verb": "Calibrate", "done": ""})]
    }

    // ----- System -----
    function clockText() {
        var g=mGlobalId.item
        return (g.getRtcTime()+" "+g.getAmPm()).trim()
    }
    function clockSummary() {
        return (mGlobalId.item.gpsAutoSetRtcEnabled?"GPS · ":"")+clockText()
    }
    // The two layouts of /etc/vnL.qml (Global.dashboard 0 Daily A, 1 Towing A), the same switch as a Modes hold on the
    // dashboard (vnD key_right). Global saves the choice. The note shows while Tow/Haul holds the towing layout; a choice
    // while towing stays after Tow/Haul ends.
    function layoutRow() {
        var g=mGlobalId.item
        var towing=g.dashboard===1
        var auto=towing && g.dashboardBeforeTow>=0
        return makeRow("toggle", "Dashboard layout", (towing?"Towing":"Daily")+(auto?" · Tow/Haul":""),
                       {"op": "layout", "seg": ["Daily", "Towing"], "current": towing?1:0, "note": auto?"Tow/Haul":undefined})
    }
    function brightnessRow(title, dark) {
        var level=mGlobalId.item.getBrightnessLevel(dark)
        return makeRow("number", title, level*10+"%", {"op": "bright", "arg": dark, "min": 10, "max": 100, "step": 10, "unit": "%",
                                                       "start": clamp(level*10, 10, 100)})
    }
    // Units rows, values, and actions: ported from vnU.qml. Fuel economy and Tyre pressure use the choice editor.
    function unitsSupported() {
        var model=Number(mTrucksModel)
        return model>=0 && model<=8 && model===Math.floor(model)
    }
    function unitData(index) {
        var g=mGlobalId.item
        var value=mTranslationId.item.getSystemUnit(index)
        if(index===1)
            return value+" · "+(g.followUnit && !g.speedUnitOverride?"Follow":"Manual")
        if(index===2)
            return value+" · "+(g.followUnit && !g.tempUnitOverride?"Follow":"Manual")
        return value
    }
    function unitRows() {
        var g=mGlobalId.item
        var titles=mTranslationId.item.mSystemSetupUnits
        if(!unitsSupported())
            return [unavailableRow("Units", "Unit controls unavailable for this vehicle model")]
        var trim=function(text) { return String(text).trim() }
        var fuel=g.mFuelUnit.map(trim)
        var pressure=g.mTpmsUnit.map(trim)
        var follow=function(override) { return g.followUnit && !override?"Follow":"Manual" }
        return [makeRow("choice", titles[0], unitData(0), {"op": "unit", "arg": 0, "options": [0, 1, 2],
                        "texts": fuel, "seg": fuel, "start": g.consumptionUnit, "current": g.consumptionUnit}),
                makeRow("toggle", titles[1], unitData(1), {"op": "unit", "arg": 1, "seg": ["km/h", "mph"],
                        "current": g.metricSystem?0:1, "note": follow(g.speedUnitOverride)}),
                makeRow("toggle", titles[2], unitData(2), {"op": "unit", "arg": 2, "seg": ["°C", "°F"],
                        "current": g.temperatureUnit?0:1, "note": follow(g.tempUnitOverride)}),
                makeRow("choice", titles[3], unitData(3), {"op": "unit", "arg": 3, "options": [0, 1, 2, 3],
                        "texts": pressure, "seg": pressure, "start": g.pressureUnit, "current": g.pressureUnit}),
                g.followUnit?makeRow("command", "Follow vehicle units", "", {"op": "follow"}):
                             unavailableRow("Follow vehicle units", "Unavailable for this vehicle model")]
    }

    // ----- Factory -----
    // Rows and actions: ported from the Factory catalog (vnF.qml). The stock Advanced settings page (cache 083) sets
    // only the odometer, the fuel tanks, and the vehicle profile, the same calls as their own pages, so the menu has no
    // Advanced settings row.
    function factoryRows() {
        var g=mGlobalId.item
        var debug=g.uartDebugEnabled
        var level=mDebugLevels.indexOf(debug)
        return [makeRow("page", "General settings", "", {"page": "general"}),
                makeRow("page", "Fuel tank setup", tankText(), {"page": "tank"}),
                makeRow("page", "Vehicle profile", mTranslationId.item.mVehicleModel, {"page": "profile"}),
                makeRow("page", "Odometer setup", g.getOdo(1), {"page": "odometer"}),
                makeRow("page", "Service commands", "", {"page": "commands"}),
                makeRow("command", "ADB debugging: enable", "", {"op": "adb", "arg": 1}),
                makeRow("command", "ADB debugging: disable", "", {"op": "adb", "arg": 0}),
                makeRow("choice", "Debug logging", level>=0?mDebugTexts[level]:"Value "+debug,
                        {"op": "debug", "options": mDebugLevels, "texts": mDebugTexts, "start": nearest(mDebugLevels, debug),
                         "current": level}),
                makeRow("toggle", "USB image preview", g.mediaImageEnabled?"On":"Off", {"op": "preview", "current": g.mediaImageEnabled?1:0}),
                makeRow("command", "Screen grid", "", {"op": "grid"}),
                makeRow("toggle", "Car model options", g.modelCarSelection?"On":"Off", {"op": "model", "current": g.modelCarSelection?1:0})]
    }
    function tankText() {
        var g=mGlobalId.item
        return g.getTank(0, 1)+" · "+g.getTank(1, 1)
    }
    // Vehicle profile (stock FactoryVehicleModel). The stock page lists 11 rows; the Ford table names 3 profiles, so the
    // menu lists the defined profiles only.
    function profileRows() {
        var t=mTranslationId.item
        var rows=[]
        t.mVehicleModelPickUp.forEach(function(index) {
            if(t.mVehicleModels[index]!==undefined)
                rows.push(makeRow("select", t.mVehicleModels[index], index===mGlobalId.item.vehicleModel?"Selected":"",
                                  {"op": "profile", "arg": index}))
        })
        return rows
    }
    // Same order as the stock page: the profile first, then the device profile index that the new profile binds
    // (Translation mVehicleModelIndex). The stock Advanced settings page sends no index of -1; an undefined index is not sent.
    function selectProfile(index) {
        mGlobalId.item.vehicleModel=index
        var device=mTranslationId.item.mVehicleModelIndex
        if(device!==undefined && Number(device)!==-1)
            mEventHandleId.item.setVehicleModel(device)
    }
    // Rows: ported from the General settings page (vnB.qml). OK sends Global.setFactory(index), which flips the setting.
    // Row 7 steps through five speed scale values.
    function generalRows() {
        var t=mTranslationId.item
        var states=t.mFactoryItemsState
        var rows=[]
        for(var i=0; i<19; i++) {
            var title=t.mFactoryItems[i]
            if(mFactoryNoEffect.indexOf(i)>=0)
                rows.push(unavailableRow(title, "No effect in this firmware"))
            else if(i===7)
                rows.push(makeRow("toggle", title, ["200", "210", "240", "260", "290"][states[i]], {"op": "factory", "arg": i}))
            else
                rows.push(makeRow("toggle", title, states[i]?"On":"Off", {"op": "factory", "arg": i, "current": states[i]?1:0}))
        }
        return rows
    }

    // ----- Service -----
    // The truck oil life percent (JLY 0x1A, the trailer info frame). The trailer brake state of the same frame stays -1
    // until the first frame, so the row can tell no data from 0%.
    function oilLifeRow() {
        var g=mGlobalId.item
        return makeRow("info", "Oil life", g.trucksTrailerBrakeState<0?"No data from truck":g.trucksOilLifePercentage+"%", {})
    }
    function serviceName(id) {
        var t=mTranslationId.item
        var g=mGlobalId.item
        if(id<6)
            return t.mServiceDefaultItems[id]
        return id===6?t.mServiceIndividual1Items[g.mainTentCustomize1]:t.mServiceIndividual2Items[g.mainTentCustomize2]
    }
    function serviceDateKnown(id) {
        var g=mGlobalId.item
        var year=g.mainTentYear[id], month=g.mainTentMonth[id], day=g.mainTentDay[id]
        return year!==0xFF && year>0 && month>=1 && month<=12 && day>=1 && day<=31
    }
    function serviceRows(id) {
        var g=mGlobalId.item
        var rows=[]
        if(id>=6) {
            var names=id===6?mTranslationId.item.mServiceIndividual1Items:mTranslationId.item.mServiceIndividual2Items
            var options=[]
            for(var i=0; i<names.length; i++)
                options.push(i)
            var custom=id===6?g.mainTentCustomize1:g.mainTentCustomize2
            rows.push(makeRow("choice", "Item", names[custom], {"op": "svcItem", "arg": id, "options": options,
                                                                 "texts": names, "start": custom}))
        }
        var mileage=g.mainTentMileage[id]
        rows.push(makeRow("date", "Next service date", serviceDateKnown(id)?g.getMaintentDate(id):"No data from adapter",
                          {"op": "svcDate", "arg": id}))
        rows.push(makeRow("number", "Service interval", mileage===0xFFFFFF?"No data from adapter":g.getMaintentMileage(id),
                          {"op": "svcInterval", "arg": id, "min": 0, "max": 99500, "step": 500, "unit": " "+g.tripUnit,
                           "start": mileage===0xFFFFFF?0:clamp(Math.round(mileage*g.tripFactor/500)*500, 0, 99500)}))
        rows.push(makeRow("action", "Reset", "", {"op": "svcReset", "arg": id}))
        return rows
    }

    // ----- Enter and edits -----
    function activate() {
        var row=mFocusRow
        if(!row)
            return
        var g=mGlobalId.item
        switch(row.kind) {
        case "page":
            openPage(row.page)
            break
        case "toggle":
            toggle(row)
            break
        case "choice":
        case "number":
            mEditValue=row.start
            mEditStart=row.start
            mEditing=true
            break
        case "date":
        case "digits":
            mEditFields=fieldStart(row)
            mEditStart=mEditFields
            mEditField=0
            mEditing=true
            break
        case "action":
            if(mArmedRow===mCursor) {
                disarm()
                runAction(row)
                if(row.done!=="") {
                    mSentRow=mCursor
                    mSentTimer.restart()
                }
            } else {
                mSentRow=-1
                mArmedRow=mCursor
                mArmTimer.restart()
            }
            break
        case "command":
            if(row.op==="follow" && g.followUnit)
                mEventHandleId.item.followVehicleUnits()
            else if(row.op==="adb")
                mEventHandleId.item.adb(row.arg)
            else if(row.op==="grid") {
                // The grid covers the whole screen. The menu closes, so the next key press returns to the dashboard.
                g.screenGridEnabled=1
                closeMenu()
            }
            break
        case "select":
            if(row.op==="language")
                g.language=row.arg
            else if(row.op==="profile")
                selectProfile(row.arg)
            break
        }
    }
    // The second OK of an action row.
    function runAction(row) {
        switch(row.op) {
        case "reset": runReset(row.arg); break
        case "svcReset": serviceSend("reset", row.arg); break
        // Stock FactoryShellCmd: one OK ran the file; the menu asks for a second OK first.
        case "shell": mEventHandleId.item.setShellCmdFile(row.arg); break
        // Stock G-force: the flag only; the Timer above clears the flag after 1200 ms.
        case "gyro": mGlobalId.item.mGyroCalibration=1; break
        }
    }
    function toggle(row) {
        var g=mGlobalId.item
        var e=mEventHandleId.item
        switch(row.op) {
        case "ford":
            fordSend(row.arg, Number(g.fordSetupInfo[row.arg])===0?1:0)
            break
        case "unit":
            if(row.arg===1) {
                g.speedUnitOverride=1
                g.metricSystem=!g.metricSystem
                if(g.followUnit)
                    e.setUnit2(2, g.metricSystem)
            } else {
                g.tempUnitOverride=1
                g.temperatureUnit=!g.temperatureUnit
                if(g.followUnit)
                    e.setUnit2(1, g.temperatureUnit)
            }
            break
        case "gps":
            g.gpsAutoSetRtcEnabled=g.gpsAutoSetRtcEnabled?0:1
            break
        case "format":
            g.rtc24h=g.rtc24h?0:1
            if(g.followUnit)
                e.setUnit2(5, g.rtc24h)
            break
        case "warn":
            g.overSpeedWarningEnabled=g.overSpeedWarningEnabled?0:1
            e.setOverSpeedWarningEnabled(g.overSpeedWarningEnabled)
            break
        case "factory": g.setFactory(row.arg); break
        case "preview": g.mediaImageEnabled=g.mediaImageEnabled?0:1; break
        case "model": g.modelCarSelection=!g.modelCarSelection; break
        case "layout": g.dashboard=g.dashboard===1?0:1; break
        }
    }
    function editStep(step) {
        var row=mFocusRow
        if(!row)
            return
        if(row.kind==="choice") {
            var count=row.options.length
            var index=row.options.indexOf(mEditValue)
            mEditValue=row.options[(index+step+count)%count]
        } else if(row.kind==="number") {
            mEditValue=clamp(mEditValue+step*row.step, row.min, row.max)
        } else if(mEditFields.length>0) {
            var fields=mEditFields.slice()
            var range=fieldRange(row, fields, mEditField)
            var value=fields[mEditField]+step
            fields[mEditField]=value>range[1]?range[0]:value<range[0]?range[1]:value
            if(row.kind==="date")
                fields[2]=Math.min(fields[2], daysInMonth(fields[0], fields[1]))
            mEditFields=fields
        }
    }
    function editEnter() {
        var row=mFocusRow
        if(!row || (row.kind!=="choice" && row.kind!=="number" && row.kind!=="date" && row.kind!=="digits")) {
            dropState()
            return
        }
        if(mEditFields.length>0) {
            if(mEditField<mEditFields.length-1) {
                mEditField++
                return
            }
            var fields=mEditFields
            var start=mEditStart
            dropState()
            commitFields(row, fields, start)
            return
        }
        var value=mEditValue
        var changed=value!==mEditStart
        dropState()
        if(changed)
            commit(row, value)
    }
    // The last OK of a field editor. A digit editor sends only a changed value; the stock page sent every Set, and a
    // re-send of the same odometer in miles can move the stored kilometres by the rounding.
    function commitFields(row, fields, start) {
        var e=mEventHandleId.item
        switch(row.op) {
        case "clock":
            e.setRtc(fields[0]+"-"+pad2(fields[1])+"-"+pad2(fields[2])+" "+pad2(fields[3])+":"+pad2(fields[4])+":00")
            break
        case "svcDate":
            serviceSend("date", row.arg, fields[0]+"-"+fields[1]+"-"+fields[2])
            break
        case "odo":
            if(fields.join("")!==start.join(""))
                e.setOdo(Number(fields.join("")))
            break
        case "tank":
            // The stock Set sends both tanks together, the main tank first.
            if(fields.join("")!==start.join("")) {
                e.setFuelTank(0, Number(fields.slice(0, 3).join("")))
                e.setFuelTank(1, Number(fields.slice(3).join("")))
            }
            break
        }
    }
    function commit(row, value) {
        var g=mGlobalId.item
        switch(row.op) {
        case "ford": fordSend(row.arg, value); break
        case "unit":
            if(row.arg===0)
                g.consumptionUnit=value
            else
                g.pressureUnit=value
            break
        case "bright": mEventHandleId.item.setBright(row.arg, value/10*25); break
        case "warnSpeed": mEventHandleId.item.setOverSpeedWarningSpeed(value); break
        case "svcInterval": serviceSend("mileage", row.arg, value); break
        case "svcItem": serviceSend("item", row.arg, value); break
        case "debug": g.uartDebugEnabled=value; break
        }
    }
    // Maintenance sends. One read-back inquiry follows the last send.
    function serviceSend(kind, id, value) {
        var g=mGlobalId.item
        var e=mEventHandleId.item
        switch(kind) {
        case "date": e.setMaintentDate(id, value); break
        case "mileage": e.setMaintentMileage(id, value); break
        case "reset": e.setMaintentReset(id); break
        case "item":
            if(id===6)
                g.mainTentCustomize1=value
            else
                g.mainTentCustomize2=value
            e.setMaintentCustomId(id, value)
            break
        }
        mServiceReadBack.restart()
    }
    // Start values of a field editor. The digits come from the same Global helpers as the stock pages; the stock digit
    // property is an int, so a fraction from the helper drops to the whole digit.
    function fieldStart(row) {
        var g=mGlobalId.item
        var fields
        if(row.op==="odo" || row.op==="tank") {
            fields=[]
            for(var digit=0; digit<6; digit++) {
                var raw=Math.floor(Number(row.op==="odo"?g.getOdoNum(digit):g.getTankNum(digit<3?0:1, digit%3)))
                fields.push(clamp(isNaN(raw)?0:raw, 0, 9))
            }
            return fields
        }
        if(row.op==="clock") {
            var date=String(g.rtcDate).split("-").map(Number)
            var time=String(g.rtcTime).split(":").map(Number)
            fields=[date[0], date[1], date[2], time[0], time[1]]
        } else if(serviceDateKnown(row.arg)) {
            fields=[g.mainTentYear[row.arg]+2000, g.mainTentMonth[row.arg], g.mainTentDay[row.arg]]
        } else {
            var today=new Date()
            fields=[today.getFullYear(), today.getMonth()+1, today.getDate()]
        }
        for(var i=0; i<fields.length; i++) {
            var range=fieldRange(row, fields, i)
            fields[i]=clamp(isNaN(fields[i])?range[0]:fields[i], range[0], range[1])
        }
        return fields
    }
    function fieldRange(row, fields, index) {
        if(row.kind==="digits")
            return [0, 9]
        switch(index) {
        case 0: return [2024, 2099]
        case 1: return [1, 12]
        case 2: return [1, daysInMonth(fields[0], fields[1])]
        case 3: return [0, 23]
        }
        return [0, 59]
    }
    function daysInMonth(year, month) {
        return new Date(year, month, 0).getDate()
    }
    // The edited value. Up and Down change the value, so the view shows an up and down mark next to the value, not
    // left and right arrows. mark(text) wraps the field that Up and Down change; without mark the text is plain.
    function editText(mark) {
        var row=mFocusRow
        if(!row)
            return ""
        if(row.kind==="choice")
            return row.texts[row.options.indexOf(mEditValue)]
        if(row.kind==="number")
            return mEditValue+row.unit
        var fields=mEditFields
        if(row.kind==="digits") {
            var digits=fields.map(String)
            if(mark)
                digits[mEditField]=mark(digits[mEditField])
            if(row.op==="tank")
                return "Main "+digits.slice(0, 3).join("")+" · Sub "+digits.slice(3).join("")+" "+mGlobalId.item.tankUnit
            return digits.join("")+" "+mGlobalId.item.tripUnit
        }
        if(row.kind!=="date")
            return ""
        var parts=[String(fields[0]), pad2(fields[1]), pad2(fields[2])]
        var suffix=""
        if(fields.length>3) {
            var hour=fields[3]
            if(!mGlobalId.item.rtc24h) {
                suffix=hour<12?" AM":" PM"
                hour=hour%12===0?12:hour%12
            }
            parts.push(row.op==="clock" && !mGlobalId.item.rtc24h?String(hour):pad2(hour), pad2(fields[4]))
        }
        if(mark)
            parts[mEditField]=mark(parts[mEditField])
        var text=parts[0]+"-"+parts[1]+"-"+parts[2]
        return parts.length>3?text+"  "+parts[3]+":"+parts[4]+suffix:text
    }
    function nearest(options, value) {
        var best=options[0]
        for(var i=1; i<options.length; i++) {
            if(Math.abs(options[i]-value)<Math.abs(best-value))
                best=options[i]
        }
        return best
    }
    function clamp(value, low, high) {
        return Math.max(low, Math.min(high, value))
    }
    function pad2(value) {
        return value<10?"0"+value:String(value)
    }

    // ===== View =====
    // Locked design (design/round-21): layout A (columns), values B (controls), confirm A (press twice).
    // Parent pages stay on screen as columns; the deepest column has the focus. The view reads engine properties only.
    Item {
        id: mView
        objectName: "menuView"
        anchors.fill: parent
        readonly property bool tow: mGlobalId.item.dashboardBeforeTow>=0
        readonly property color accent: tow?"#5ad1c0":"#8fd3ff"
        readonly property color accentDim: tow?"#2e5ad1c0":"#2e8fd3ff"
        readonly property color accentPress: tow?"#4d5ad1c0":"#4d8fd3ff"
        readonly property color sub: "#7d8792"
        readonly property color mute: "#4d5661"
        readonly property color line: "#1f262e"
        readonly property color quiet: "#9aa4af"
        // Values stay readable without the focus: about 12:1 on the panel (sub is about 5:1, mute about 2.6:1).
        readonly property color bright: "#c9d1d9"
        readonly property color caution: "#ffb020"
        readonly property color hot: "#ff3b30"
        readonly property color ok: "#3ee07a"
        readonly property string family: "BMW Type Global"
        readonly property int hintHeight: 44
        readonly property var widths: [340, 470]
        readonly property int depth: mPath.length
        // At most three columns fit. A deeper page moves the oldest columns off the left side.
        readonly property int first: Math.max(0, depth-3)
        function columnX(level) {
            var x=0
            for(var i=first; i<level; i++)
                x+=widths[Math.min(i-first, widths.length-1)]
            return x
        }
        // Motion (design/round-41 tokens: 120, 200, and 280 ms, Easing.OutCubic). Only position, opacity, scale, and colour animate.
        // A page that opens slides in 40 px from the right and fades in over 280 ms. A page that closes leaves at once.
        property real enterX: 0
        property real enterOpacity: 1
        property int shownDepth: 1
        Component.onCompleted: shownDepth=depth
        onDepthChanged: {
            if(depth>shownDepth)
                mEnter.restart()
            shownDepth=depth
        }
        ParallelAnimation {
            id: mEnter
            NumberAnimation { target: mView; property: "enterX"; from: 40; to: 0; duration: 280; easing.type: Easing.OutCubic }
            NumberAnimation { target: mView; property: "enterOpacity"; from: 0; to: 1; duration: 280; easing.type: Easing.OutCubic }
        }
        function hints() {
            // A field editor moves to the next field until the last one.
            if(mEditing)
                return [["▲ ▼", "Change"], ["OK", mEditField<mEditFields.length-1?"Next":"Save"], ["◀", "Cancel"]]
            if(mArmedRow>=0)
                return [["OK", actionVerb(mFocusRow)], ["◀", "Cancel"]]
            return [["▲ ▼", "Select"], ["OK", "Open or change"], ["◀", "Back"], ["Hold ◀", "Close menu"]]
        }

        // The panel covers the vendor menu art behind this page.
        Rectangle {
            anchors.fill: parent
            radius: 12
            color: "#0b0e12"
            opacity: 0.94
        }

        Repeater {
            model: mView.depth
            Item {
                id: mColumn
                readonly property int level: index
                readonly property bool last: level===mView.depth-1
                readonly property var rows: last?mRows:pageRows(mPath[level], -1, -1)
                // Back shortens mCursors before mPath, so a parent column can briefly have no saved row.
                readonly property int focusRow: last?mCursor:(mCursors[level]!==undefined?mCursors[level]:0)
                readonly property int rowHeight: last?68:60
                // Parent columns show titles and the open chevrons only, so the titles do not elide. The values stay in the
                // focused column.
                readonly property bool compact: !last
                readonly property int headHeight: 54
                readonly property int visibleRows: Math.floor((height-headHeight)/rowHeight)
                readonly property int firstRow: Math.max(0, Math.min(focusRow-visibleRows+2, rows.length-visibleRows))
                x: mView.columnX(level)
                width: last?menuRoot.width-x:mView.widths[Math.min(level-mView.first, mView.widths.length-1)]
                height: menuRoot.height-mView.hintHeight
                visible: level>=mView.first
                opacity: last?mView.enterOpacity:1
                transform: Translate { x: mColumn.last?mView.enterX:0 }

                Rectangle {
                    anchors.right: parent.right
                    y: 18
                    width: 1
                    height: parent.height-18
                    color: mView.line
                    visible: !mColumn.last
                }
                Text {
                    x: 50
                    y: 22
                    text: pageTitle(mPath[mColumn.level])
                    font.family: mView.family
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                    font.letterSpacing: 4
                    font.capitalization: Font.AllUppercase
                    color: mView.mute
                }
                Item {
                    x: 22
                    y: mColumn.headHeight
                    width: parent.width-44
                    height: parent.height-mColumn.headHeight
                    clip: true
                    Item {
                        y: -mColumn.firstRow*mColumn.rowHeight
                        width: parent.width
                        height: mColumn.rows.length*mColumn.rowHeight
                        Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        // Focus: one highlight slides from row to row. The armed row turns the highlight amber.
                        Rectangle {
                            objectName: "focusHighlight"
                            readonly property bool armed: mArmedRow>=0 && mArmedRow===mCursor
                            visible: mColumn.last && mColumn.rows.length>0
                            y: mColumn.focusRow*mColumn.rowHeight+3
                            width: parent.width
                            height: mColumn.rowHeight-6
                            radius: 12
                            color: armed?"#29ffb020":mPressed?mView.accentPress:mView.accentDim
                            Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            Rectangle {
                                y: 11
                                width: 5
                                height: parent.height-22
                                radius: 3
                                color: parent.armed?mView.caution:mView.accent
                            }
                        }
                        Column {
                            width: parent.width
                            // A count model keeps each row while values change, so the controls animate in place.
                            Repeater {
                                model: mColumn.rows.length
                                Item {
                                    id: mRow
                                    readonly property var row: mColumn.rows[index]
                                    readonly property bool focused: mColumn.last && index===mCursor
                                    readonly property bool onPath: !mColumn.last && index===mColumn.focusRow
                                    readonly property bool armed: mColumn.last && index===mArmedRow
                                    readonly property bool sent: mColumn.last && index===mSentRow
                                    readonly property bool na: row.kind==="unavailable"
                                    readonly property bool editing: focused && mEditing
                                    width: parent.width
                                    height: mColumn.rowHeight
                                    opacity: !mColumn.last && !onPath?0.6:1
                                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                                    // Parent columns mark the open row; the focus highlight marks the focused row.
                                    Rectangle {
                                        visible: mRow.onPath
                                        y: 22
                                        width: 3
                                        height: parent.height-2*y
                                        radius: 3
                                        color: mView.accent
                                        opacity: 0.6
                                    }
                                    Text {
                                        x: 28
                                        width: mValue.x-x-16
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: mRow.row.title
                                        elide: Text.ElideRight
                                        font.family: mView.family
                                        font.pixelSize: mColumn.last?30:28
                                        color: mRow.na?mView.mute:(mRow.focused || mRow.armed)?"#ffffff":mRow.onPath?mView.accent:
                                               mRow.row.color==="red"?mView.hot:mRow.row.color==="orange"?mView.caution:mView.quiet
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                    }
                                    Row {
                                        id: mValue
                                        anchors.right: parent.right
                                        anchors.rightMargin: 28
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 12
                                        Loader {
                                            anchors.verticalCenter: parent.verticalCenter
                                            readonly property var row: mRow.row
                                            readonly property bool focused: mRow.focused
                                            readonly property bool editing: mRow.editing
                                            readonly property bool compact: mColumn.compact
                                            visible: !compact || row.kind==="page"
                                            sourceComponent: mRow.armed?mArmedText:mRow.sent?mSentText:mRow.na?mReasonText:
                                                             row.kind==="page"?mOpenValue:
                                                             row.seg && (editing || row.current>=0)?mSegments:
                                                             row.kind==="toggle" && row.current>=0?mSwitch:
                                                             row.kind==="number" && row.unit==="%"?mMeter:mTextValue
                                        }
                                        // While the row edits, Up and Down change the value: an up and a down chevron.
                                        Item {
                                            objectName: "editChevrons"
                                            visible: mRow.editing
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 16
                                            height: 34
                                            Repeater {
                                                model: [-45, 135]
                                                // Chevron: two strokes of a square turned to point up, then down.
                                                Item {
                                                    x: 1
                                                    y: index===0?4:16
                                                    width: 12
                                                    height: 12
                                                    rotation: modelData
                                                    Rectangle { width: parent.width; height: 3; color: mView.accent }
                                                    Rectangle { anchors.right: parent.right; width: 3; height: parent.height; color: mView.accent }
                                                }
                                            }
                                        }
                                    }
                                    // Confirm A: the bar runs down over the 5 s the row stays armed.
                                    Rectangle {
                                        visible: mRow.armed
                                        x: 28
                                        width: parent.width-56
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 8
                                        height: 4
                                        radius: 2
                                        color: "#33ffb020"
                                        Rectangle {
                                            width: parent.width
                                            height: parent.height
                                            radius: 2
                                            color: mView.caution
                                            transform: Scale { id: mArmScale; origin.x: 0 }
                                            NumberAnimation {
                                                target: mArmScale
                                                property: "xScale"
                                                running: mRow.armed
                                                from: 1
                                                to: 0
                                                duration: 5000
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Key hints under the menu.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            spacing: 44
            Repeater {
                model: mView.hints()
                Row {
                    spacing: 8
                    Text {
                        text: modelData[0]
                        font.family: mView.family
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                        color: mView.sub
                    }
                    Text {
                        text: modelData[1]
                        font.family: mView.family
                        font.pixelSize: 20
                        font.letterSpacing: 1
                        color: mView.mute
                    }
                }
            }
        }

        // ----- Value controls -----
        // Each control reads row, focused, and editing from the Loader that holds the control.
        Component {
            id: mTextValue
            Text {
                readonly property var row: parent.row
                readonly property bool focused: parent.focused
                readonly property bool editing: parent.editing
                readonly property bool fields: editing && mEditFields.length>0
                // The date field or digit that Up and Down change takes the accent colour and an underline.
                text: fields?editText(function(part) { return "<u><font color=\""+mView.accent+"\">"+part+"</font></u>" }):
                             editing?mEditText:row.value
                textFormat: fields?Text.StyledText:Text.PlainText
                font.family: mView.family
                font.pixelSize: 28
                color: focused?"#ffffff":mView.bright
            }
        }
        Component {
            id: mReasonText
            Text {
                readonly property var row: parent.row
                readonly property bool focused: parent.focused
                readonly property bool editing: parent.editing
                text: row.value
                font.family: mView.family
                font.pixelSize: 22
                color: mView.sub
            }
        }
        Component {
            id: mArmedText
            Text {
                readonly property var row: parent.row
                readonly property bool focused: parent.focused
                readonly property bool editing: parent.editing
                text: row.value
                font.family: mView.family
                font.pixelSize: 24
                color: mView.caution
            }
        }
        Component {
            id: mSentText
            Text {
                readonly property var row: parent.row
                readonly property bool focused: parent.focused
                readonly property bool editing: parent.editing
                text: row.value
                font.family: mView.family
                font.pixelSize: 24
                color: mView.ok
            }
        }
        Component {
            id: mOpenValue
            Row {
                readonly property var row: parent.row
                readonly property bool focused: parent.focused
                readonly property bool editing: parent.editing
                readonly property bool compact: parent.compact
                spacing: 14
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: text!=="" && !compact
                    text: row.value
                    font.family: mView.family
                    font.pixelSize: 28
                    color: focused?"#ffffff":mView.bright
                }
                // Chevron: two strokes of a square turned 45 degrees.
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    height: 14
                    rotation: 45
                    opacity: 0.7
                    Rectangle { width: parent.width; height: 3; color: focused?"#ffffff":mView.sub }
                    Rectangle { anchors.right: parent.right; width: 3; height: parent.height; color: focused?"#ffffff":mView.sub }
                }
            }
        }
        Component {
            id: mSwitch
            Rectangle {
                readonly property var row: parent.row
                readonly property bool focused: parent.focused
                readonly property bool editing: parent.editing
                readonly property bool on: row.current===1
                width: 66
                height: 34
                radius: 17
                color: on?mView.accent:"#2a3138"
                Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Rectangle {
                    x: parent.on?36:4
                    y: 4
                    width: 26
                    height: 26
                    radius: 13
                    color: parent.on?"#ffffff":"#6b7480"
                    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }
            }
        }
        Component {
            id: mSegments
            Row {
                readonly property var row: parent.row
                readonly property bool focused: parent.focused
                readonly property bool editing: parent.editing
                readonly property int selected: editing?row.options.indexOf(mEditValue):row.current
                spacing: 12
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.note!==undefined
                    text: row.note!==undefined?row.note:""
                    font.family: mView.family
                    font.pixelSize: 22
                    color: mView.sub
                }
                Rectangle {
                    width: mSegmentRow.width+8
                    height: mSegmentRow.height+8
                    radius: 10
                    color: "#161b21"
                    border.width: editing?2:0
                    border.color: mView.accent
                    // One pill slides to the selected segment while the value changes.
                    Rectangle {
                        readonly property Item target: selected>=0 && mSegmentRepeater.count>selected?mSegmentRepeater.itemAt(selected):null
                        visible: target!==null
                        x: 4+(target?target.x:0)
                        y: 4
                        width: target?target.width:0
                        height: target?target.height:0
                        radius: 7
                        color: focused?mView.accent:"#2f3740"
                        Behavior on x { enabled: editing; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Behavior on width { enabled: editing; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    }
                    Row {
                        id: mSegmentRow
                        x: 4
                        y: 4
                        spacing: 4
                        Repeater {
                            id: mSegmentRepeater
                            model: row.seg
                            Item {
                                readonly property bool on: index===selected
                                width: mSegmentText.width+28
                                height: mSegmentText.height+10
                                Text {
                                    id: mSegmentText
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.family: mView.family
                                    font.pixelSize: 22
                                    color: parent.on?(focused?"#05070a":"#ffffff"):mView.quiet
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }
                            }
                        }
                    }
                }
            }
        }
        Component {
            id: mMeter
            Row {
                readonly property var row: parent.row
                readonly property bool focused: parent.focused
                readonly property bool editing: parent.editing
                readonly property real percent: Math.max(0, Math.min(100, editing?mEditValue:parseFloat(row.value)))
                spacing: 20
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 230
                    height: 8
                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: "#222a33"
                    }
                    // The fill scales from the left edge; the knob moves. Both follow each edit step.
                    Rectangle {
                        width: parent.width
                        height: parent.height
                        radius: 4
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: "transparent" }
                            GradientStop { position: 1; color: mView.accent }
                        }
                        transform: Scale {
                            origin.x: 0
                            xScale: isNaN(percent)?0:percent/100
                            Behavior on xScale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }
                    }
                    Rectangle {
                        visible: !isNaN(percent)
                        x: parent.width*percent/100-10
                        y: -6
                        width: 20
                        height: 20
                        radius: 10
                        color: "#ffffff"
                        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: editing?mEditText:row.value
                    font.family: mView.family
                    font.pixelSize: 28
                    color: focused?"#ffffff":mView.bright
                }
            }
        }
    }
}
