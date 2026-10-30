import QtQuick 2.12
import QtQuick.Controls 2.12
import "qrc:/Trucks/common"
import "qrc:/Trucks/menu/common"

ItemInfo {
    width: 820
    height: 510
    property int mPressed: 0
    property int mCompleted: 0
    property bool mModeHeld: false
    property int mEntryPage: 0
    property var mFactoryMenu: [
        {"title":"General settings", "page":5},
        {"title":"Advanced settings", "page":1},
        {"title":"Fuel tank setup", "page":3},
        {"title":"Vehicle profile", "page":4},
        {"title":"Odometer setup", "page":2},
        {"title":"Service commands", "page":6},
        {"title":"ADB debugging: enable", "action":"adb", "value":1},
        {"title":"ADB debugging: disable", "action":"adb", "value":0},
        {"title":"Debug logging: off", "action":"debug", "value":0},
        {"title":"Debug logging: warnings", "action":"debug", "value":1},
        {"title":"Debug logging: UART receive", "action":"debug", "value":2},
        {"title":"Debug logging: UART transmit", "action":"debug", "value":4},
        {"title":"Debug logging: MCU", "action":"debug", "value":8},
        {"title":"USB image preview: enable", "action":"preview"},
        {"title":"Screen grid", "action":"grid"},
        {"title":"Car model options", "action":"model"}
    ]
    property var mFactorySubPage: [
        "",
        "qrc:/Trucks/menu/system/factory/FactorySeniorSetting.qml",
        "qrc:/Trucks/menu/system/factory/FactoryOdoSetup.qml",
        "qrc:/Trucks/menu/system/factory/FactoryTankSetup.qml",
        "qrc:/Trucks/menu/system/factory/FactoryVehicleModel.qml",
        "file:/etc/vnB.qml",
        "qrc:/Trucks/menu/system/factory/FactoryShellCmd.qml"
    ]
    Component.onCompleted: {
        mGlobalId.item.menuSettingsSubPageItemSetup=0
        mFactoryEntries.currentIndex=0
        mPostTimerId.restart()
    }
    Component.onDestruction: mGlobalId.item.menuSettingsSubPageItemSetup=0
    Timer {
        id: mPostTimerId
        interval: 300
        running: false
        repeat: false
        onTriggered: {
            mCompleted=1
            mEventHandleId.item.shellCmdInquire()
        }
    }
    function entryData(index) {
        var entry=mFactoryMenu[index]
        if(entry.action==="debug")
            return mGlobalId.item.uartDebugEnabled===entry.value?"Selected":""
        if(entry.action==="preview")
            return mGlobalId.item.mediaImageEnabled?"ON":"OFF"
        if(entry.action==="model")
            return mGlobalId.item.modelCarSelection?"ON":"OFF"
        return ""
    }
    function activateEntry(index) {
        if(index<0 || index>=mFactoryMenu.length)
            return 0
        var entry=mFactoryMenu[index]
        if(entry.page) {
            mEntryPage=entry.page
            mGlobalId.item.menuSettingsSubPageItemSetup=entry.page
            return 1
        }
        switch(entry.action) {
        case "adb": mEventHandleId.item.adb(entry.value); break
        case "debug": mGlobalId.item.uartDebugEnabled=entry.value; break
        case "preview": mGlobalId.item.mediaImageEnabled=1; break
        case "model": mGlobalId.item.modelCarSelection=!mGlobalId.item.modelCarSelection; break
        case "grid":
            // The grid covers the whole screen. Close the menu, so the next key press returns to the dashboard.
            mGlobalId.item.screenGridEnabled=1
            mGlobalId.item.menuBarIndex=0
            break
        }
        return 1
    }
    function key_back(state) {
        if(state!==0)
            return 0
        mGlobalId.item.menuSettingsPageIndex=0
        return 1
    }
    function key_up(state) {
        if(state!==0)
            return 0
        mFactoryEntries.currentIndex=mFactoryEntries.currentIndex>0?
                    mFactoryEntries.currentIndex-1:mFactoryEntries.count-1
        return 1
    }
    function key_down(state) {
        if(state!==0)
            return 0
        mFactoryEntries.currentIndex=mFactoryEntries.currentIndex<mFactoryEntries.count-1?
                    mFactoryEntries.currentIndex+1:0
        return 1
    }
    function key_left(state) { return key_back(state) }
    function key_right(state) { return state===0?key_enter(state):0 }
    function key_enter(state) {
        mPressed=state===1?1:0
        if(state!==0)
            return 0
        return mFactoryEntries.currentIndex===mFactoryMenu.length?
                    key_back(state):activateEntry(mFactoryEntries.currentIndex)
    }
    function key_modes(state) {
        if(state===2) {
            mModeHeld=true
            return key_enter(0)
        }
        return state===0?key_down(0):0
    }
    function key(code, state) {
        if(code===mGlobalId.item.swcModes && mModeHeld) {
            if(state===0)
                mModeHeld=false
            return 1
        }
        if(mFactorySubPageId.active) {
            if(!mFactorySubPageId.item)
                return 1
            var page=mGlobalId.item.menuSettingsSubPageItemSetup
            var accepted=mFactorySubPageId.item.key(code, state)
            if(page===mEntryPage && page>=2 && page<=4 && mGlobalId.item.menuSettingsSubPageItemSetup===1)
                mGlobalId.item.menuSettingsSubPageItemSetup=0
            return accepted
        }
        switch(code) {
        case mGlobalId.item.swcHome: return key_home(state)
        case mGlobalId.item.swcBack: return key_back(state)
        case mGlobalId.item.swcUp: return key_up(state)
        case mGlobalId.item.swcDown: return key_down(state)
        case mGlobalId.item.swcLeft: return key_left(state)
        case mGlobalId.item.swcRight: return key_right(state)
        case mGlobalId.item.swcEnter: return key_enter(state)
        case mGlobalId.item.swcModes: return key_modes(state)
        }
        return 0
    }
    SwipeView {
        id: mFactoryEntries
        width: 820
        height: 510
        orientation: Qt.Vertical
        currentIndex: 0
        clip: true
        visible: !mFactorySubPageId.active
        Repeater {
            model: mFactoryMenu.length
            MenuSetupButton {
                width: mFactoryEntries.width
                mIndex: index
                mTitle: mFactoryMenu[index].title
                mData: entryData(index)
                mChecked: mFactoryEntries.currentIndex===mIndex
                mClicked: mChecked && mPressed
                mNoChecked: 1
            }
        }
        MenuItemButton {
            width: mFactoryEntries.width
            mIndex: mFactoryMenu.length
            mTitle: mTranslationId.item.mBack
            mChecked: mFactoryEntries.currentIndex===mIndex
            mClicked: mChecked && mPressed
            mType: -3
            mNoCheck: 1
        }
    }
    Loader {
        id: mFactorySubPageId
        active: mGlobalId.item.menuSettingsSubPageItemSetup>0
        source: mFactorySubPage[mGlobalId.item.menuSettingsSubPageItemSetup]
    }
}
