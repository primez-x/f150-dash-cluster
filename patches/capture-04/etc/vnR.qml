import QtQuick 2.12
import QtQuick.Controls 2.12
import "qrc:/Trucks/common"
import "qrc:/Trucks/menu/common"

// Vehicle > Reset. The rows, keys, and commands follow the captured MenuVehicleResetSettings page.
// One change: the captured page removes Oil Life for every Ford. The 2011-2014 F150 keeps the row,
// and resetOilLife sends the Ford setup command that the vendor uses on Vehicle > Assist row 59.
ItemInfo {
    id: rectangle
    width: 820
    height: 510
    property int mPressed: 0
    property int mCompleted: 0
    readonly property int mModel: Number(mTrucksModel)
    readonly property int mVehicle: mGlobalId.item.vehicleModel
    readonly property var mRows: resetRows(mModel, mVehicle)

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
    function rowTitle(row) {
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
    function runRow(row) {
        var e=mEventHandleId.item
        var yukon=mModel===8
        switch(row){
        case "tripA": e.resetTrip(0); break
        case "tripB": e.resetTrip(1); break
        case "since": e.resetSinceReset(); break
        case "tpms": e.tpmsReset(); break
        case "factory":
            if(mModel===1 && mVehicle===1)
                e.setFordSetup(14, 18, 1)
            else if(yukon)
                e.setFordSetup(13, 11, 1)
            break
        case "key": if(yukon) e.setFordSetup(13, 8, 1); break
        case "tpmsLearn": if(yukon) e.setFordSetup(13, 9, 1); break
        case "oil": if(yukon || (mModel===1 && mVehicle===1)) e.resetOilLife(); break
        case "compass": if(yukon) e.setFordSetup(13, 14, 1); break
        }
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
        mVehicleSettingsId.currentIndex=mVehicleSettingsId.currentIndex>0?
                    mVehicleSettingsId.currentIndex-1:mVehicleSettingsId.count-1
        return 1
    }
    function key_down(state) {
        if(state!==0)
            return 0
        mVehicleSettingsId.currentIndex=mVehicleSettingsId.currentIndex<mVehicleSettingsId.count-1?
                    mVehicleSettingsId.currentIndex+1:0
        return 1
    }
    function key_left(state) {
        return state===0?key_back(state):0
    }
    function key_right(state) {
        return state===0?key_enter(state):0
    }
    function key_enter(state) {
        mPressed=state===1?1:0
        if(state!==0)
            return 1
        var index=mVehicleSettingsId.currentIndex
        if(index===mVehicleSettingsId.count-1)
            return key_back(state)
        runRow(mRows[index])
        return 1
    }
    function key_modes(state) {
        if(state===0)
            return key_down(state)
        return state===2?key_enter(0):0
    }

    Rectangle {
        width: 1
        height: rectangle.width
        color: "gray"
        anchors.right: parent.right
        anchors.rightMargin: 0
        opacity: 0.5
    }
    SwipeView {
        id: mVehicleSettingsId
        width: 820
        height: 510
        currentIndex: 0
        orientation: Qt.Vertical
        interactive: true
        Repeater {
            model: mRows
            MenuItemButton {
                width: mVehicleSettingsId.width
                mIndex: index
                mTitle: rowTitle(modelData)
                mChecked: mVehicleSettingsId.currentIndex===mIndex
                mClicked: mPressed && mChecked
                mType: -3
                mNoCheck: 1
            }
        }
        MenuItemButton {
            width: mVehicleSettingsId.width
            mIndex: 100
            mTitle: mTranslationId.item.mBack
            mChecked: mVehicleSettingsId.currentIndex===mVehicleSettingsId.count-1
            mClicked: mPressed && mChecked
            mType: -3
            mNoCheck: 1
        }
        Component.onCompleted: {
            contentItem.preferredHighlightBegin=1
            contentItem.preferredHighlightEnd=0.1
            mCompleted=1
            currentIndex=0
        }
    }
}
