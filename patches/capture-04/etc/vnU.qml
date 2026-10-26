import QtQuick 2.12
import QtQuick.Controls 2.12
import "qrc:/Trucks/common"
import "qrc:/Trucks/menu/common"

ItemInfo {
    width: 600
    height: 510
    property int mPressed: 0
    property bool mSupported: supportedModel()
    Component.onCompleted: mSystemUnitId.currentIndex=0

    function supportedModel() {
        var model=Number(mTrucksModel)
        return model>=0 && model<=8 && model===Math.floor(model)
    }
    function unitData(index) {
        if(!supportedModel())
            return "Unit controls unavailable for this vehicle model"
        if(index===4)
            return mGlobalId.item.followUnit?"":"Unavailable for this vehicle model"
        var value=mTranslationId.item.getSystemUnit(index)
        if(index===1)
            return value+" · "+(mGlobalId.item.followUnit && !mGlobalId.item.speedUnitOverride?"Follow":"Manual")
        if(index===2)
            return value+" · "+(mGlobalId.item.followUnit && !mGlobalId.item.tempUnitOverride?"Follow":"Manual")
        return value
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
        mSystemUnitId.currentIndex=mSystemUnitId.currentIndex>0?
                    mSystemUnitId.currentIndex-1:mSystemUnitId.count-1
        return 1
    }
    function key_down(state) {
        if(state!==0)
            return 0
        mSystemUnitId.currentIndex=mSystemUnitId.currentIndex<mSystemUnitId.count-1?
                    mSystemUnitId.currentIndex+1:0
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
            return 1
        var index=mSystemUnitId.currentIndex
        if(index===mSystemUnitId.count-1)
            return key_back(state)
        if(!supportedModel())
            return 1
        switch(index){
        case 0:
            if(mGlobalId.item.consumptionUnit<2)
                mGlobalId.item.consumptionUnit++
            else
                mGlobalId.item.consumptionUnit=0
            break
        case 1:
            mGlobalId.item.speedUnitOverride=1
            mGlobalId.item.metricSystem=!mGlobalId.item.metricSystem
            if(mGlobalId.item.followUnit)
                mEventHandleId.item.setUnit2(2, mGlobalId.item.metricSystem)
            break
        case 2:
            mGlobalId.item.tempUnitOverride=1
            mGlobalId.item.temperatureUnit=!mGlobalId.item.temperatureUnit
            if(mGlobalId.item.followUnit)
                mEventHandleId.item.setUnit2(1, mGlobalId.item.temperatureUnit)
            break
        case 3:
            if(mGlobalId.item.pressureUnit<3)
                mGlobalId.item.pressureUnit++
            else
                mGlobalId.item.pressureUnit=0
            break
        case 4:
            if(mGlobalId.item.followUnit)
                mEventHandleId.item.followVehicleUnits()
            break
        }
        return 1
    }
    function key_modes(state) {
        if(state===0)
            return key_down(0)
        return state===2?key_enter(0):0
    }

    SwipeView {
        id: mSystemUnitId
        width: 600
        height: 510
        orientation: Qt.Vertical
        interactive: true
        currentIndex: 0
        clip: true
        Repeater {
            model: mSupported?5:1
            MenuSetupButton {
                width: mSystemUnitId.width
                mIndex: index
                mTitle: !mSupported?"Unit controls unavailable for this vehicle model":
                            index===4?"Follow vehicle units":mTranslationId.item.mSystemSetupUnits[index]
                mData: mSupported?unitData(index):""
                mChecked: mSystemUnitId.currentIndex===mIndex
                mClicked: mChecked && mPressed
                mNoChecked: 1
            }
        }
        MenuItemButton {
            width: mSystemUnitId.width
            mIndex: mSupported?5:1
            mTitle: mTranslationId.item.mBack
            mChecked: mSystemUnitId.currentIndex===mIndex
            mClicked: mChecked && mPressed
            mType: -3
            mNoCheck: 1
        }
    }
    Loader {
        x: 600
        source: mSupported && mSystemUnitId.currentIndex<4?
                    ["qrc:/Trucks/menu/system/unit/FuelConsumptionUnit.qml",
                     "qrc:/Trucks/menu/system/unit/TripUnit.qml",
                     "qrc:/Trucks/menu/system/unit/TemperatureUnit.qml",
                     "qrc:/Trucks/menu/system/unit/PressureUnit.qml"][mSystemUnitId.currentIndex]:""
    }
}
