import QtQuick 2.12
import QtQuick.Window 2.12
import QtQml 2.14
import "qrc:/common"
import "qrc:/Trucks/common"

// Owned dashboard shell. main.qml opens this file in place of the compiled Trucks/Dashboard.qml (cache 023).
// Phase 1 copied the compiled unit exactly: each binding and each function body follows the cache 023 bytecode.
// The "fn N" notes name the compiled function index (analysis/capture-04/qml-cache/023-Trucks_Dashboard.qml.json).
// Phase 2 adds the wheel key map for the dashboard (key_card, key_ok, and the Trip A hold below). The notification,
// door popup, and menu routes keep the compiled order and the compiled calls.
// The compiled children stay compiled and load by the same qrc URLs. The compiled imports "../common" and "./common"
// are the qrc:/common and qrc:/Trucks/common directories, in the same order.
// Compiled children resolve names through this context: ShellCmdList and FactoryShellCmd write mCompleted.
// Keep every id and property name. No other unit calls the key_* functions; the key map left fn 2 (key_left) without
// a caller, so the file drops fn 2. Modes still reaches key_enter and key_right (fn 6 state 3).
Item {
    id: mRootId
    width: 1920
    height: 932

    // fn 0
    function key_back(state) {
        switch(state) {
        case 0:
            mGlobalId.item.menuBarIndex=!mGlobalId.item.menuBarIndex
            break
        case 1:
            break
        case 2:
            mGlobalId.item.menuBarIndex=!mGlobalId.item.menuBarIndex
            break
        }
    }

    // fn 1
    function key_right(state) {
        switch(state) {
        case 0:
            break
        case 1:
            break
        case 2:
        case 3:
            if(mGlobalId.item.dashboard<5)
                mGlobalId.item.dashboard++
            else
                mGlobalId.item.dashboard=0
            break
        }
    }

    // fn 3. The second "case 5" is in the compiled unit; the first "case 5" always matches first.
    function key_up(state) {
        switch(state) {
        case 0:
            switch(mGlobalId.item.dashboard) {
            case 0:
                mGlobalId.item.rightInfoIndex=!mGlobalId.item.rightInfoIndex
                break
            case 1:
                if(mGlobalId.item.drivingInfoIndex>0)
                    mGlobalId.item.drivingInfoIndex--
                else
                    mGlobalId.item.drivingInfoIndex=mGlobalId.item.tpmsInfoEnabled?6:5
                break
            case 2:
            case 3:
            case 4:
            case 5:
                if(mGlobalId.item.leftInfoIndex>0)
                    mGlobalId.item.leftInfoIndex--
                else
                    mGlobalId.item.leftInfoIndex=1
                break
            case 5:
                break
            }
            break
        case 1:
            break
        case 2:
            break
        }
    }

    // fn 4
    function key_down(state) {
        switch(state) {
        case 0:
            switch(mGlobalId.item.dashboard) {
            case 0:
                mGlobalId.item.rightInfoIndex=!mGlobalId.item.rightInfoIndex
                break
            case 1:
                if(mGlobalId.item.tpmsInfoEnabled?mGlobalId.item.drivingInfoIndex<6:mGlobalId.item.drivingInfoIndex<5)
                    mGlobalId.item.drivingInfoIndex++
                else
                    mGlobalId.item.drivingInfoIndex=0
                break
            case 2:
            case 3:
            case 4:
            case 5:
                if(mGlobalId.item.leftInfoIndex<1)
                    mGlobalId.item.leftInfoIndex++
                else
                    mGlobalId.item.leftInfoIndex=0
                break
            case 5:
                break
            }
            break
        case 1:
            break
        case 2:
            break
        }
    }

    // fn 5
    function key_enter(state) {
        switch(state) {
        case 0:
            break
        case 1:
            break
        case 2:
            key_right(state)
            break
        case 3:
            key_right(state)
            break
        }
    }

    // fn 6
    function key_modes(state) {
        switch(state) {
        case 0:
            switch(mGlobalId.item.dashboard) {
            case 0:
                mGlobalId.item.rightInfoIndex=!mGlobalId.item.rightInfoIndex
                break
            case 1:
                if(mGlobalId.item.tpmsInfoEnabled?mGlobalId.item.drivingInfoIndex<6:mGlobalId.item.drivingInfoIndex<5)
                    mGlobalId.item.drivingInfoIndex++
                else
                    mGlobalId.item.drivingInfoIndex=0
                break
            case 2:
            case 3:
            case 4:
            case 5:
                if(mGlobalId.item.leftInfoIndex<1)
                    mGlobalId.item.leftInfoIndex++
                else
                    mGlobalId.item.leftInfoIndex=0
                break
            case 5:
                break
            }
            break
        case 1:
            break
        case 2:
            key_back(state)
            break
        case 3:
            key_enter(state)
            break
        }
    }

    // fn 7, with the nested function fn 8
    function key_printScr(state) {
        switch(state) {
        case 0:
            mRootId.grabToImage(function(result) {
                result.saveToFile("capture.png")
            })
            break
        case 1:
            break
        case 2:
            break
        }
        return 0
    }

    // Wheel key map on the dashboard. States: 1 press, 2 and 3 hold, 0 release.
    // - Left and Right page the card on the press. A layout with a "pages" array pages through the array;
    //   a stock layout runs the compiled Up (previous) and Down (next) info switch.
    // - OK released within mOkShortMs opens the menu, as the compiled Left release does.
    // - OK held on the trip page fills tripHold from mOkShortMs to mOkResetMs, then resets Trip A.
    // - Up and Down do nothing. Back and Modes keep the compiled functions.
    // Presses do nothing while the door popup shows; the release closes the popup, as before.
    readonly property int mOkShortMs: 250
    readonly property int mOkResetMs: 1200
    property real tripHold: 0           // Trip A hold progress, 0 to 1
    property bool mOkDown: false        // an OK press that the dashboard tracks
    property var mOkHoldItem: null      // the layout item of the Trip A hold

    // The card pages of the layout, or null for a stock layout or no layout.
    function layoutPages() {
        var item=mDashboardId.item
        var pages=item?item.pages:undefined
        return pages && pages.length>0?pages:null
    }
    // The shown card: drivingInfoIndex, or 0 when a stock layout left an index outside the pages.
    function pageIndex(pages) {
        var index=mGlobalId.item.drivingInfoIndex
        return index>=0 && index<pages.length?index:0
    }
    function isTripPage() {
        var pages=layoutPages()
        return pages!==null && pages[pageIndex(pages)]==="trip"
    }
    // Left (step -1) and Right (step 1). Global stores drivingInfoIndex on each change.
    function key_card(step, state) {
        if(state!==1 || mGlobalId.item.doorInfo || !mDashboardId.item)
            return
        var pages=layoutPages()
        if(pages)
            mGlobalId.item.drivingInfoIndex=(pageIndex(pages)+step+pages.length)%pages.length
        else if(step<0)
            key_up(0)
        else
            key_down(0)
    }
    function key_ok(state) {
        switch(state) {
        case 1:
            okCancel()
            if(mGlobalId.item.doorInfo)
                break
            mOkDown=true
            mOkShortTimerId.restart()
            if(isTripPage()) {
                mOkHoldItem=mDashboardId.item
                mTripHoldId.restart()
            }
            break
        case 0:
            var open=mOkDown && mOkShortTimerId.running
            okCancel()
            if(open)
                key_back(0)
            break
        }
    }
    // Ends the tracked OK press: no menu and no reset for this press.
    function okCancel() {
        mOkDown=false
        mOkHoldItem=null
        mOkShortTimerId.stop()
        if(mTripHoldId.running)
            mTripHoldId.stop()
        if(tripHold>0)
            mTripHoldDropId.restart()
    }
    // The last step of mTripHoldId, at mOkResetMs. Menu > Vehicle > Reset > Reset TripA makes the same call (vnM runReset).
    function tripHoldDone() {
        var item=mDashboardId.item
        var g=mGlobalId.item
        if(mOkDown && item && item===mOkHoldItem && isTripPage() && !g.menuBarIndex && !g.notifyTop && !g.doorInfo) {
            var e=mEventHandleId.item
            if(e)
                e.resetTrip(0)
            if(typeof item.flashTrip==="function")
                item.flashTrip()
        }
        // The animation group ends after this step, so only the press state and the drop change here.
        mOkDown=false
        mOkHoldItem=null
        mOkShortTimerId.stop()
        mTripHoldDropId.restart()
    }
    Timer {
        id: mOkShortTimerId
        interval: mOkShortMs
    }
    SequentialAnimation {
        id: mTripHoldId
        PauseAnimation { duration: mOkShortMs }
        NumberAnimation { target: mRootId; property: "tripHold"; from: 0; to: 1; duration: mOkResetMs-mOkShortMs }
        ScriptAction { script: tripHoldDone() }
    }
    NumberAnimation {
        id: mTripHoldDropId
        target: mRootId
        property: "tripHold"
        to: 0
        duration: 200
    }
    // A layout with a tripHold property shows the hold progress. mDashboardId sets mTripHoldTarget on each layout change:
    // a binding that tests the layout for tripHold would depend on the value that this Binding writes (a binding loop).
    // The target is null for a layout without tripHold, because a target without the property logs a warning.
    property QtObject mTripHoldTarget: null
    Binding {
        target: mTripHoldTarget
        property: "tripHold"
        value: mRootId.tripHold
        when: mTripHoldTarget!==null
        restoreMode: Binding.RestoreBindingOrValue
    }

    // fn 10 (enabled) and fn 11 (onStateChanged). SwcEvent sets key and then state for each wheel event.
    // The notification, door popup, and menu routes are as compiled; each one also ends a tracked OK press.
    SwcEvent {
        enabled: mCompleted
        onStateChanged: {
            if(mGlobalId.item.notifyTop && mNotifyId.item.key(key, state))
                return okCancel()
            if(mGlobalId.item.doorInfo && !state) {
                okCancel()
                mGlobalId.item.doorInfoHide()
                return
            }
            if(mGlobalId.item.menuBarIndex) {
                okCancel()
                return mMenuPageId.item.key(key, state)
            } else {
                if(key!==mGlobalId.item.swcEnter)
                    okCancel()
                switch(key) {
                case mGlobalId.item.swcBack:
                    return key_back(state)
                case mGlobalId.item.swcLeft:
                    return key_card(-1, state)
                case mGlobalId.item.swcRight:
                    return key_card(1, state)
                case mGlobalId.item.swcEnter:
                    return key_ok(state)
                case mGlobalId.item.swcModes:
                    return key_modes(state)
                }
            }
        }
    }

    // fn 9
    property var mDashboard: ["qrc:/Trucks/ui1/Dashboard.qml", "qrc:/Trucks/ui2/Dashboard.qml", "qrc:/Trucks/ui3/Dashboard.qml",
                              "qrc:/Trucks/ui4/Dashboard.qml", "qrc:/Trucks/ui5/Dashboard.qml", "qrc:/Trucks/ui6/Dashboard.qml"]

    Loader {
        id: mDashboardId
        source: mDashboard[mGlobalId.item.dashboard]                                    // fn 12
        anchors.left: parent.left                                                        // fn 13
        anchors.leftMargin: mGlobalId.item.vehicleModel===1?8:-3                         // fn 14
        anchors.bottom: parent.bottom                                                    // fn 15
        anchors.bottomMargin: mGlobalId.item.vehicleModel===1?(mGlobalId.item.dashboard===1?20:0):15   // fn 16
        // A layout change ends a tracked OK press and the Trip A hold, and moves the tripHold Binding.
        onItemChanged: {
            okCancel()
            mTripHoldTarget=item && "tripHold" in item?item:null
        }
    }

    Loader {
        id: mDoorId
        anchors.bottom: parent.bottom                                                    // fn 18
        anchors.bottomMargin: 170
        anchors.horizontalCenter: parent.horizontalCenter                                // fn 19
        source: "qrc:/Trucks/common/DoorInfo.qml"
        active: mGlobalId.item.doorInfo && !mGlobalId.item.menuBarIndex                  // fn 17
    }

    Loader {
        id: mMenuPageId
        transformOrigin: Item.Top                                                        // fn 20
        anchors.top: parent.top                                                          // fn 22
        anchors.topMargin: 220
        anchors.horizontalCenter: parent.horizontalCenter                                // fn 23
        source: "qrc:/Trucks/menu/MenuPage.qml"
        active: mGlobalId.item.menuBarIndex                                              // fn 21
        scale: 0.85
        ScaleAnimator {
            target: mMenuPageId                                                          // fn 24
            running: mMenuPageId.active                                                  // fn 25
            from: 0.85
            to: 1
            duration: 100
        }
    }

    Loader {
        id: mNotifyId
        anchors.top: parent.top                                                          // fn 27
        anchors.topMargin: 40
        anchors.horizontalCenter: parent.horizontalCenter                                // fn 28
        source: "qrc:/Trucks/common/Notify.qml"
        active: mGlobalId.item.notifyTop                                                 // fn 26
        Behavior on anchors.topMargin {
            NumberAnimation { duration: 100 }
        }
        Timer {
            id: mNotifyTimeId
            interval: mGlobalId.item.notifyDuration                                      // fn 29
            running: mGlobalId.item.notifyDuration>0                                     // fn 30
            onTriggered: mGlobalId.item.notifyDuration=0                                 // fn 31
        }
    }

    Loader {
        id: mMaintentId
        x: 550
        anchors.top: parent.top                                                          // fn 34
        anchors.topMargin: mGlobalId.item.mainTentShow?5:-100                            // fn 35
        source: "qrc:/Trucks/common/MaintentNotify.qml"
        active: mGlobalId.item.mainTentShow                                              // fn 32
        visible: mGlobalId.item.splashEnd                                                // fn 33
        Behavior on anchors.topMargin {
            SpringAnimation { duration: 200; spring: 10; damping: 0.3 }
        }
    }

    Loader {
        anchors.top: parent.top                                                          // fn 37
        anchors.topMargin: 120
        anchors.horizontalCenter: parent.horizontalCenter                                // fn 38
        source: "qrc:/Trucks/common/ShellInfoNotify.qml"
        active: mGlobalId.item.shellInfoDuration                                         // fn 36
    }

    Loader {
        id: mDraggingId
        anchors.bottom: parent.bottom                                                    // fn 40
        anchors.bottomMargin: 170
        anchors.horizontalCenter: parent.horizontalCenter                                // fn 41
        source: "qrc:/Trucks/common/Dragging.qml"
        active: mGlobalId.item.notifyText===1246 && !mGlobalId.item.menuBarIndex && mGlobalId.item.notifyDuration>0   // fn 39
    }

    Loader {
        id: mMcuUpdateId
        anchors.top: parent.top                                                          // fn 43
        anchors.topMargin: 40
        anchors.horizontalCenter: parent.horizontalCenter                                // fn 44
        source: "qrc:/Trucks/common/update/UpdateMcu.qml"
        active: mGlobalId.item.mcuUpdateTop                                              // fn 42
        Behavior on anchors.topMargin {
            NumberAnimation { duration: 100 }
        }
    }

    Loader {
        id: mOdoId
        anchors.right: parent.right                                                      // fn 47
        anchors.rightMargin: 580
        anchors.bottom: parent.bottom                                                    // fn 48
        anchors.bottomMargin: 141
        source: "qrc:/Trucks/common/Trip.qml"
        visible: Number(mTrucksModel)===0?false:true                                     // fn 45
        onLoaded: mOdoId.item.mIndex=0                                                   // fn 46
    }

    Trip {
        id: mTripId
        anchors.left: parent.left                                                        // fn 51
        anchors.leftMargin: 580
        anchors.bottom: parent.bottom                                                    // fn 52
        anchors.bottomMargin: 141
        mIndex: mGlobalId.item.tripType                                                  // fn 49
        visible: Number(mTrucksModel)===0?false:true                                     // fn 50
    }

    TurnLightIndicator {
        anchors.left: parent.left                                                        // fn 53
        anchors.leftMargin: 554
        anchors.top: parent.top                                                          // fn 54
        anchors.topMargin: 82
    }

    TurnLightIndicator {
        mIndex: 1
        anchors.right: parent.right                                                      // fn 55
        anchors.rightMargin: 554
        anchors.top: parent.top                                                          // fn 56
        anchors.topMargin: 82
    }

    Timer {
        id: mPostActionTimerId
        interval: 2200
        running: mGlobalId.item.splashEnd                                                // fn 57
        onTriggered: mCompleted=1                                                        // fn 58
    }

    property int mCompleted: 0
    Component.onCompleted: {                                                             // fn 59
        console.log("[Dashboard Starting...]")
        mPostActionTimerId.restart()
    }
}
