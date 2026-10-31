import QtQuick 2.12
import QtQuick.Window 2.12
import "qrc:/common"
import "qrc:/Trucks/common"

// Owned dashboard shell. main.qml opens this file in place of the compiled Trucks/Dashboard.qml (cache 023).
// Phase 1 copies the compiled unit exactly: each binding and each function body follows the cache 023 bytecode.
// The "fn N" notes name the compiled function index (analysis/capture-04/qml-cache/023-Trucks_Dashboard.qml.json).
// The compiled children stay compiled and load by the same qrc URLs. The compiled imports "../common" and "./common"
// are the qrc:/common and qrc:/Trucks/common directories, in the same order.
// Compiled children resolve names through this context: ShellCmdList and FactoryShellCmd write mCompleted.
// Keep every id, property, and key_* function name.
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

    // fn 2
    function key_left(state) {
        switch(state) {
        case 0:
            key_back(state)
            break
        case 1:
            break
        case 2:
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

    // fn 10 (enabled) and fn 11 (onStateChanged). SwcEvent sets key and then state for each wheel event.
    SwcEvent {
        enabled: mCompleted
        onStateChanged: {
            if(mGlobalId.item.notifyTop && mNotifyId.item.key(key, state))
                return
            if(mGlobalId.item.doorInfo && !state) {
                mGlobalId.item.doorInfoHide()
                return
            }
            if(mGlobalId.item.menuBarIndex) {
                return mMenuPageId.item.key(key, state)
            } else {
                switch(key) {
                case mGlobalId.item.swcBack:
                    return key_back(state)
                case mGlobalId.item.swcLeft:
                    return key_left(state)
                case mGlobalId.item.swcRight:
                    return key_right(state)
                case mGlobalId.item.swcUp:
                    return key_up(state)
                case mGlobalId.item.swcDown:
                    return key_down(state)
                case mGlobalId.item.swcEnter:
                    return key_enter(state)
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
