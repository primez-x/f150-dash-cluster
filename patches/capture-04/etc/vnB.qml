import QtQuick 2.12
import QtQuick.Controls 2.12
import "qrc:/Trucks/common"
import "qrc:/Trucks/menu/common"

ItemInfo {
    width: 820
    height: 510
    property int mPressed: 0
    Component.onCompleted: {
        mFactoryRows.currentIndex=0
        mPostActionTimerId.restart()
    }
    Timer {
        id: mPostActionTimerId
        interval: 50
        running: false
        repeat: false
        onTriggered: mEventHandleId.item.systemInquire()
    }

    function key_back(state) {
        if(state!==0)
            return 0
        mGlobalId.item.menuSettingsSubPageItemSetup=0
        return 1
    }
    function key_up(state) {
        if(state!==0)
            return 0
        mFactoryRows.currentIndex=mFactoryRows.currentIndex>0?
                    mFactoryRows.currentIndex-1:mFactoryRows.count-1
        return 1
    }
    function key_down(state) {
        if(state!==0)
            return 0
        mFactoryRows.currentIndex=mFactoryRows.currentIndex<mFactoryRows.count-1?
                    mFactoryRows.currentIndex+1:0
        return 1
    }
    function key_left(state) {
        return key_back(state)
    }
    function key_right(state) {
        return state===0?key_enter(state):0
    }
    function key_enter(state) {
        mPressed=state===1?1:0
        if(state!==0)
            return 0
        if(mFactoryRows.currentIndex===mFactoryRows.count-1)
            return key_back(state)
        mGlobalId.item.setFactory(mFactoryRows.currentIndex)
        return 1
    }
    function key_modes(state) {
        if(state===0)
            return key_down(0)
        return state===2?key_enter(0):0
    }

    SwipeView {
        id: mFactoryRows
        width: 820
        height: 510
        orientation: Qt.Vertical
        interactive: true
        currentIndex: 0
        clip: true
        Repeater {
            model: 19
            MenuSetupButton {
                width: mFactoryRows.width
                mIndex: index
                mTitle: mTranslationId.item.mFactoryItems[index]
                mData: index===7?
                           ["200", "210", "240", "260", "290"][mTranslationId.item.mFactoryItemsState[index]]:
                           (mTranslationId.item.mFactoryItemsState[index]?"ON":"OFF")
                mChecked: mFactoryRows.currentIndex===mIndex
                mClicked: mChecked && mPressed
                mNoChecked: 1
            }
        }
        MenuItemButton {
            width: mFactoryRows.width
            mIndex: 19
            mTitle: mTranslationId.item.mBack
            mChecked: mFactoryRows.currentIndex===mIndex
            mClicked: mChecked && mPressed
            mType: -3
            mNoCheck: 1
        }
    }
}
