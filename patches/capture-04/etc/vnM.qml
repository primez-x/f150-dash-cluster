import QtQuick 2.12
import "qrc:/Trucks/common"

// Settings menu. Replaces the compiled MenuItemsList and every page under the list: Vehicle, System, Service, and Factory.
// MenuPage hosts this file in a 1720x511 slot and calls key(keycode, state). MenuPage reads nothing else.
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
    property var mEditFields: []        // date editors: [year, month, day] or [year, month, day, hour, minute]
    property int mEditField: 0
    property int mArmedRow: -1          // action row that waits for the second OK
    property int mSentRow: -1           // action row that shows "Reset sent"
    readonly property string mPage: mPath[mPath.length-1]
    readonly property var mRows: pageRows(mPage, mArmedRow, mSentRow)
    readonly property var mFocusRow: mCursor<mRows.length?mRows[mCursor]:null
    readonly property string mHostedUrl: mPage==="gforce"?"qrc:/Trucks/menu/vehicle/MenuVehicleGForce.qml":
                                         mPage.indexOf("fsub")===0?mFactoryUrls[mGlobalId.item.menuSettingsSubPageItemSetup]||"":""
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
        "general": "General settings", "fsub1": "Advanced settings", "fsub2": "Odometer setup", "fsub3": "Fuel tank setup",
        "fsub4": "Vehicle profile", "fsub6": "Service commands", "service": "Service"
    })
    // Compiled Factory pages by menuSettingsSubPageItemSetup value. The pages move between each other with the same value.
    // Value 5 was the old General settings page. vnM owns General settings now.
    readonly property var mFactoryUrls: ["", "qrc:/Trucks/menu/system/factory/FactorySeniorSetting.qml",
        "qrc:/Trucks/menu/system/factory/FactoryOdoSetup.qml", "qrc:/Trucks/menu/system/factory/FactoryTankSetup.qml",
        "qrc:/Trucks/menu/system/factory/FactoryVehicleModel.qml", "", "qrc:/Trucks/menu/system/factory/FactoryShellCmd.qml"]
    property int mFactoryEntry: 0       // the Factory page value that opened the hosted Factory page
    // No compiled page or native code reads these General settings in this firmware (Global.setFactory cases).
    readonly property var mFactoryNoEffect: [6, 10, 11, 12, 13, 16, 17]
    readonly property var mDebugLevels: [0, 1, 2, 4, 8]
    readonly property var mDebugTexts: ["Off", "Warnings", "UART receive", "UART transmit", "MCU"]
    readonly property var mLayouts: [0, 1, 2, 3, 4, 5]

    Component.onCompleted: {
        mGlobalId.item.menuBarItemIndex=0
        mGlobalId.item.menuSettingsPageIndex=0
    }
    onMRowsChanged: {
        if(mCursor>=mRows.length)
            mCursor=Math.max(0, mRows.length-1)
    }
    // A hosted page returns to the parent page when the hosted page sets menuSettingsPageIndex to 0.
    // A compiled Factory page returns when the page sets menuSettingsSubPageItemSetup to 0. Odometer, Fuel tank, and
    // Vehicle profile set 1 (their old parent, Advanced settings). Value 1 also returns when one of them opened the page.
    Connections {
        target: mGlobalId.item
        onMenuSettingsPageIndexChanged: {
            if(mHostedUrl!=="" && mGlobalId.item.menuSettingsPageIndex===0)
                closePage()
        }
        onMenuSettingsSubPageItemSetupChanged: {
            var value=mGlobalId.item.menuSettingsSubPageItemSetup
            if(mPage.indexOf("fsub")===0 && (!mFactoryUrls[value] || (value===1 && mFactoryEntry>=2 && mFactoryEntry<=4)))
                closePage()
        }
    }
    // Hosted page (G-force or a compiled Factory page). The engine owns the Loader and forwards keys to the page.
    // A replacement view may move the Loader; x is the only view setting.
    Loader {
        id: mHostedLoader
        x: 450
        z: 1
        source: mHostedUrl
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

    // ----- Keys -----
    // States: 0 release, 1 press, 2 hold, 3 (3 s hold) ignored. Pages act on release.
    // Hold: Modes = Enter, Back = close the menu, other keys nothing. The next release of a held key is swallowed.
    // A new press ends the hold, so a hold without a release does not swallow the next tap.
    // Each key event writes one "viknav-key" line to the Launcher log: time (ms), key code, state, then the page path,
    // cursor, and edit or hosted state after the event. The lines show repeated, held, or missing events from the wheel.
    function key(code, state) {
        handleKey(code, state)
        console.log("viknav-key "+Date.now()+" "+code+" "+state+" "+mPath.join("/")+" "+mCursor+
                    (mEditing?" edit":"")+(mHostedUrl!==""?" hosted":""))
        return 1
    }
    function handleKey(code, state) {
        var g=mGlobalId.item
        var hosted=mHostedUrl!==""
        if(state===1) {
            mHeldKey=-1
            mPressed=!hosted
            if(hosted)
                forward(code, 1)
            return 1
        }
        if(state===2) {
            mPressed=false
            if(mHeldKey===code)
                return 1
            mHeldKey=code
            if(code===g.swcBack)
                closeMenu()
            else if(code===g.swcModes)
                hosted?forward(g.swcEnter, 0):release(g.swcEnter)
            else if(hosted)
                forward(code, 2)
            return 1
        }
        if(state!==0)
            return 1
        mPressed=false
        if(mHeldKey===code) {
            mHeldKey=-1
            return 1
        }
        hosted?forward(code, 0):release(code)
        return 1
    }
    function forward(code, state) {
        if(mHostedLoader.item)
            mHostedLoader.item.key(code, state)
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
        if(mEditing) {
            switch(action) {
            case "up": editStep(-1); break
            case "down": editStep(1); break
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
        var g=mGlobalId.item
        if(page.indexOf("fsub")===0) {
            mFactoryEntry=Number(page.slice(4))
            g.menuSettingsPageIndex=1
            g.menuSettingsSubPageItemSetup=mFactoryEntry
            return
        }
        switch(page) {
        case "vehicle": if(mF150) e.seniorF150_11_14_SetupInquire(); break
        case "service": e.maintenacneInquire(); break
        case "version": e.versionInquire(); break
        case "factory": e.shellCmdInquire(); break
        case "general": e.systemInquire(); break
        case "gforce": g.menuSettingsPageIndex=1; break
        }
    }
    function closePage() {
        if(mPath.length<=1) {
            closeMenu()
            return
        }
        dropState()
        var leaving=mPage
        var parentRow=mCursors[mCursors.length-1]
        mCursors=mCursors.slice(0, -1)
        mPath=mPath.slice(0, -1)
        mCursor=parentRow
        // The path changes first, so these writes do not close a second page.
        if(leaving.indexOf("fsub")===0) {
            mGlobalId.item.menuSettingsSubPageItemSetup=0
            mGlobalId.item.menuSettingsPageIndex=0
        }
    }
    function closeMenu() {
        dropState()
        if(mPage.indexOf("fsub")===0)
            closePage()
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
    // Row fields: kind (page, hosted, toggle, choice, number, date, action, command, select, info, unavailable), title, value,
    // and per kind: page, op, arg, options, texts, start, min, max, step, unit, color.
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
                rows[i].value="Press OK again to reset"
            else if(i===sentRow)
                rows[i].value="Reset sent"
        }
        return rows
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
                                   makeRow("hosted", "G-force", "", {"page": "gforce"})])
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
            var items=[]
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
        case "oil": if(yukon || (model===1 && vehicle===1)) e.resetOilLife(); break
        case "compass": if(yukon) e.setFordSetup(13, 14, 1); break
        }
    }

    // ----- System -----
    function clockText() {
        var g=mGlobalId.item
        return (g.getRtcTime()+" "+g.getAmPm()).trim()
    }
    function clockSummary() {
        return (mGlobalId.item.gpsAutoSetRtcEnabled?"GPS · ":"")+clockText()
    }
    // Dashboard layouts ui1-ui6 (Global.dashboard 0-5), the same set as the OK hold on the dashboard (Dashboard.key_right).
    // Global saves the choice. A choice while Tow/Haul shows the towing layout stays after Tow/Haul ends.
    function layoutRow() {
        var g=mGlobalId.item
        var texts=mLayouts.map(function(index) { return "Layout "+(index+1) })
        var current=mLayouts.indexOf(g.dashboard)
        return makeRow("choice", "Dashboard layout", (current>=0?texts[current]:"Value "+g.dashboard)+
                                                     (g.dashboardBeforeTow>=0 && g.dashboard===g.towDashboard?" · Towing":""),
                       {"op": "layout", "options": mLayouts, "texts": texts, "start": nearest(mLayouts, g.dashboard), "current": current})
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
    // Rows and actions: ported from the Factory catalog (vnF.qml). The five setup pages stay compiled pages.
    function factoryRows() {
        var g=mGlobalId.item
        var debug=g.uartDebugEnabled
        var level=mDebugLevels.indexOf(debug)
        return [makeRow("page", "General settings", "", {"page": "general"}),
                makeRow("hosted", "Advanced settings", "", {"page": "fsub1"}),
                makeRow("hosted", "Fuel tank setup", "", {"page": "fsub3"}),
                makeRow("hosted", "Vehicle profile", "", {"page": "fsub4"}),
                makeRow("hosted", "Odometer setup", "", {"page": "fsub2"}),
                makeRow("hosted", "Service commands", "", {"page": "fsub6"}),
                makeRow("command", "ADB debugging: enable", "", {"op": "adb", "arg": 1}),
                makeRow("command", "ADB debugging: disable", "", {"op": "adb", "arg": 0}),
                makeRow("choice", "Debug logging", level>=0?mDebugTexts[level]:"Value "+debug,
                        {"op": "debug", "options": mDebugLevels, "texts": mDebugTexts, "start": nearest(mDebugLevels, debug),
                         "current": level}),
                makeRow("toggle", "USB image preview", g.mediaImageEnabled?"On":"Off", {"op": "preview", "current": g.mediaImageEnabled?1:0}),
                makeRow("command", "Screen grid", "", {"op": "grid"}),
                makeRow("toggle", "Car model options", g.modelCarSelection?"On":"Off", {"op": "model", "current": g.modelCarSelection?1:0})]
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
        case "hosted":
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
            mEditFields=dateStart(row)
            mEditField=0
            mEditing=true
            break
        case "action":
            if(mArmedRow===mCursor) {
                disarm()
                row.op==="reset"?runReset(row.arg):serviceSend("reset", row.arg)
                mSentRow=mCursor
                mSentTimer.restart()
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
            break
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
        } else if(row.kind==="date") {
            var fields=mEditFields.slice()
            var range=fieldRange(fields, mEditField)
            var value=fields[mEditField]+step
            fields[mEditField]=value>range[1]?range[0]:value<range[0]?range[1]:value
            fields[2]=Math.min(fields[2], daysInMonth(fields[0], fields[1]))
            mEditFields=fields
        }
    }
    function editEnter() {
        var row=mFocusRow
        if(!row || (row.kind!=="choice" && row.kind!=="number" && row.kind!=="date")) {
            dropState()
            return
        }
        if(row.kind==="date") {
            if(mEditField<mEditFields.length-1) {
                mEditField++
                return
            }
            var fields=mEditFields
            dropState()
            if(row.op==="clock")
                mEventHandleId.item.setRtc(fields[0]+"-"+pad2(fields[1])+"-"+pad2(fields[2])+" "+pad2(fields[3])+":"+pad2(fields[4])+":00")
            else
                serviceSend("date", row.arg, fields[0]+"-"+fields[1]+"-"+fields[2])
            return
        }
        var value=mEditValue
        var changed=value!==mEditStart
        dropState()
        if(changed)
            commit(row, value)
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
        case "layout": g.dashboard=value; break
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
    function dateStart(row) {
        var g=mGlobalId.item
        var fields
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
            var range=fieldRange(fields, i)
            fields[i]=clamp(isNaN(fields[i])?range[0]:fields[i], range[0], range[1])
        }
        return fields
    }
    function fieldRange(fields, index) {
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
    function editText() {
        var row=mFocusRow
        if(!row)
            return ""
        if(row.kind==="choice")
            return "‹ "+row.texts[row.options.indexOf(mEditValue)]+" ›"
        if(row.kind==="number")
            return "‹ "+mEditValue+row.unit+" ›"
        if(row.kind!=="date")
            return ""
        var fields=mEditFields
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
        parts[mEditField]="‹"+parts[mEditField]+"›"
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
        readonly property color caution: "#ffb020"
        readonly property color hot: "#ff3b30"
        readonly property color ok: "#3ee07a"
        readonly property string family: "BMW Type Global"
        readonly property int hintHeight: 44
        readonly property var widths: [340, 470]
        readonly property int depth: mPath.length
        // At most three columns fit. A deeper page moves the oldest columns off the left side.
        readonly property int first: Math.max(0, depth-3)
        readonly property int lastX: columnX(depth-1)
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
            if(mEditing)
                return [["▲ ▼", "Change"], ["OK", "Save"], ["◀", "Cancel"]]
            if(mArmedRow>=0)
                return [["OK", "Reset"], ["◀", "Cancel"]]
            return [["▲ ▼", "Select"], ["OK", "Open or change"], ["◀", "Back"], ["Hold BACK", "Close menu"]]
        }

        // The panel covers the vendor menu art behind this page.
        Rectangle {
            anchors.fill: parent
            radius: 12
            color: "#0b0e12"
            opacity: 0.94
        }
        // A hosted page (G-force or a compiled Factory page) takes the place of the deepest column.
        Binding {
            target: mHostedLoader
            property: "x"
            value: mView.lastX
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
                // The narrow first column shows titles only. The values stay in the wider columns.
                readonly property bool compact: !last && level===mView.first
                readonly property int headHeight: 54
                readonly property int visibleRows: Math.floor((height-headHeight)/rowHeight)
                readonly property int firstRow: Math.max(0, Math.min(focusRow-visibleRows+2, rows.length-visibleRows))
                x: mView.columnX(level)
                width: last?menuRoot.width-x:mView.widths[Math.min(level-mView.first, mView.widths.length-1)]
                height: menuRoot.height-mView.hintHeight
                visible: level>=mView.first && !(last && mHostedUrl!=="")
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
                                    opacity: !mColumn.last && !onPath?0.45:1
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
                                            sourceComponent: mRow.armed?mArmedText:mRow.sent?mSentText:mRow.na?mReasonText:
                                                             (row.kind==="page" || row.kind==="hosted")?mOpenValue:
                                                             row.seg && (editing || row.current>=0)?mSegments:
                                                             row.kind==="toggle" && row.current>=0?mSwitch:
                                                             row.kind==="number" && row.unit==="%"?mMeter:mTextValue
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

        // Key hints under the menu. The hosted pages fill the full height and have their own rows.
        Row {
            visible: mHostedUrl===""
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
                text: editing?mEditText:row.value
                font.family: mView.family
                font.pixelSize: 28
                color: focused?"#ffffff":mView.sub
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
                color: mView.mute
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
                    color: focused?"#ffffff":mView.sub
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
                    color: mView.mute
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
                                    color: parent.on?(focused?"#05070a":"#ffffff"):mView.sub
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
                    color: focused?"#ffffff":mView.sub
                }
            }
        }
    }
}
