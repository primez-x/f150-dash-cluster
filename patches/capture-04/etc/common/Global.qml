/****************************************************************************
**
** Copyright (C) 2023 ShenZhen SNTron Technology Co., Ltd.
** Contact: http://www.sntron.cn
**
** This file is part of the Global of the QML.
**
****************************************************************************/
import QtQuick 2.12
import QtQuick.LocalStorage 2.12
import QtQuick.Window 2.12
import "qrc:/functions.js" as Funcs

Item {

    ////////////////////////////////
    // common mGlobalId.item.splashEnd
    ////////////////////////////////
    property int autoRun: 0
    property int map: 0
    property int language: Number(mLanguage)
    //property int menuInfoIndex: doorInfo?1:0
    property int showLayout: 0

    property int splashBoot: 0
    property int splashIndex: 0
    property int splashEnd: !Number(mSplashPlay)

    property int region: 2          // 0: worldwide without chiness, 1: chiness, 2: worldwide

    property int rtc24h: 1
    property int vehicleColor: 0

    property int rightHand: 0
    property int backlight: 0
    property var mFollowUnit:    //单位设置：1为MCU记忆，0为仪表记忆
    [
        1,      // ram
        1,      // ford
        1,      // padap
        1,      // patrol
        1,      // landcruiser
        1,      // lc76
        1,      // silverado
        1,      // everest
        1,      // yukon
        1,      // gmc
    ]
    property int followUnit: mFollowUnit[Number(mTrucksModel)]
    property int speedUnitOverride: 0
    property int tempUnitOverride: 0
    property int activited: 1

    onSpeedUnitOverrideChanged: {
        Funcs.setProperty("speedUnitOverride", speedUnitOverride)
    }
    onTempUnitOverrideChanged: {
        Funcs.setProperty("tempUnitOverride", tempUnitOverride)
    }

    onLanguageChanged: {
        Funcs.setProperty("language", language)
    }
    onMetricSystemChanged: {
        console.log("Global: onMetricSystemChanged metricSystem:"+metricSystem)
        Funcs.setProperty("metricSystem", metricSystem)
    }
    onVehicleColorChanged: {
        Funcs.setProperty("vehicleColor", vehicleColor)
    }
    onRtc24hChanged: {
        Funcs.setProperty("rtc24h", rtc24h)
    }

    function isRTL(){
        return language==5?1:0
    }

    property var mVehicleEventUartNum:
    [
        0,      // NONE
        3,      // T113-Core
        2,      // T507-Core
    ]
    property int mVehicleEventVendor: 1     // 0: none, 1: jly, 2: dsxw, 3: tesla
    property int mVehicleEventUart: mVehicleEventUartNum[Number(mPlatform)]
    property int mVehicleEventUartBaud: 115200
    property string launcherVersion: "RAM@20240401 r26971"
    property string pluginsVersion: "plugins@2023"
    property string linkEventVersion: "plugins@2023"
    property string btVersion: "bt@2023"
    property string hwVersion: "T507-Core_V1.0"

    //////////////////////////////////
    // Gyro mGlobalId.item.mGyroCalibration
    //////////////////////////////////
    property int gyroDevice: 0
    property int mGyroCalibration: 0
    property int mPitch: 0xFFFF
    property int mRoll: 0xFFFF
    property int mYaw: 0xFFFF

    property int mPitchOffset: 0
    property int mRollOffst: 0

    property int gX: 0
    property int gY: 0
    property int gZ: 0
    property int gXoffset: 0
    property int gYoffset: 0
    property int gZoffset: 0

    onMPitchOffsetChanged: {
        if(mCompleted)
            Funcs.setProperty("mPitchOffset", mPitchOffset)
    }
    onMRollOffstChanged: {
        if(mCompleted)
            Funcs.setProperty("mRollOffst", mRollOffst)
    }
    onGXoffsetChanged: {
        if(mCompleted)
            Funcs.setProperty("gXoffset", gXoffset)
    }
    onGYoffsetChanged: {
        if(mCompleted)
            Funcs.setProperty("gYoffset", gYoffset)
    }
    onGZoffsetChanged: {
        if(mCompleted)
            Funcs.setProperty("gZoffset", gZoffset)
    }

    function getPitchString(){
        return (mPitch==0xFFFF?"--":mPitch)+"°"
    }
    function getRollString(){
        return (mRoll==0xFFFF?"--":mRoll)+"°"
    }
    // 0~30, 80間距, 80/30=2.666 factor
    // 30~90, 48間距, 48/60=0.8 factor
    function getGforceX(){
        var positive=gX>0?1:0
        if(Math.abs(gX)>30){
            if(positive)
                return (gX-30*0.8)+80
            else
                return (30+gX*0.8)-80
        }else
            return gX*2.666
    }
    function getGforceY(){
        var positive=gY>0?1:0
        if(Math.abs(gY)>30){
            if(positive)
                return (gY-30*0.8)+80
            else
                return (30+gY*0.8)-80
        }else
            return gY*2.666
    }
    function getGforceZ(){
        return gZ //gZ>9?9:gZ
    }

    ////////////////////////////////
    // Pressure/altitude mGlobalId.item.getPressure
    ////////////////////////////////
    property real mAltitude: 0xFFFF
    property real mhPa: 0xFFFF

    function getAltitude(unit){
        return (gpsFixed?gpsAltitude.toFixed(1):
               (mAltitude==0xFFFF?"--.-":mAltitude.toFixed(1)))+(unit?" m":"")
        //return (mAltitude==0xFFFF?"--.-":mAltitude.toFixed(1))+(unit?" m":"")
    }
    function getPressure(unit){
        return (mhPa==0xFFFF?"---.-":(mhPa/10).toFixed(1))+(unit?" kPa":"")
    }

    ////////////////////////////////
    // GPS/GNSS mGlobalId.item.gpsBearing
    ////////////////////////////////
    property int gpsAutoSetRtcEnabled;  // 使用GPS自動設置時間日期
    property string gpsFixedValid;      // A=有效定位，V=无效定位
    property double gpsFixed;           // 1=没有定位，2=2D定位，3=3D定位
    property int gpsInView;
    property int gpsInUsed;
    property double gpsLatitude;        // 纬度ddmm.mmmm（度分)(S為負)
    property double gpsLongitude;       // 经度dddmm.mmmm（度分
    property double gpsAltitude;        // 海拔高度（-9999.9~99999.9）
    property double gpsBearing: 0       // 000.0~359.9度
    property double gpsAccuracy;        // PDOP位置精度因子（0.5~99.9, 一般卫星分布越好时，PDOP值越小，一般小于3为比较理想状态
    property double gpsSNR;             // 信噪比（00－99）dbHz  50算信号比较好
    property int timeZone: gpsLongitude?lon2timezone():0//lon2timezone()
    onGpsAutoSetRtcEnabledChanged: {
        Funcs.setProperty("gpsAutoSetRtcEnabled", gpsAutoSetRtcEnabled)
    }

    function getGpsBearing(){
        var temp;
        if(gpsBearing>315)
            temp=gpsBearing-360;
        else
            temp=gpsBearing
        //console.log("getGpsBearing()="+temp)
        return temp
    }

    property var mCompassDir:
    [
        "N",        // 0~45
        "NE",       // 45~90
        "E",        // 90~135
        "SE",       // 135~180
        "S",        // 180~225
        "SW",       // 225~270
        "W",        // 270~315
        "NW",       // 315~360
    ]
    function getCompassDir(){
        if(gpsBearing>=337.5 && gpsBearing<22.5)
            return mCompassDir[0]
        else if(gpsBearing>=22.5 && gpsBearing<67.5)
            return mCompassDir[1]
        else if(gpsBearing>=67.5 && gpsBearing<112.5)
            return mCompassDir[2]
        else if(gpsBearing>=112.5 && gpsBearing<157.5)
            return mCompassDir[3]
        else if(gpsBearing>=157.5 && gpsBearing<202.5)
            return mCompassDir[4]
        else if(gpsBearing>=202.5 && gpsBearing<247.5)
            return mCompassDir[5]
        else if(gpsBearing>=247.5 && gpsBearing<292.5)
            return mCompassDir[6]
        else if(gpsBearing>=292.5 && gpsBearing<332.5)
            return mCompassDir[7]
        else
            return mCompassDir[0]
    }

    function lon2timezone(){
        //var timeZone ;
        var shangValue=Number(gpsLongitude/15);
        var yushuValue=Math.abs(gpsLongitude%15);
        if (yushuValue<=7.5) {
            timeZone=shangValue;
        } else {
            timeZone=shangValue+(gpsLongitude>0?1:-1);
        }
        //console.log("[timeZone: "+timeZone+"]");
        //return timeZone
    }
  // for prado
    property int modelCarSelection:0
    onModelCarSelectionChanged: {
        if(mCompleted)
        Funcs.setProperty("modelCarSelection", modelCarSelection)
    }

    ////////////////////////////////
    // factory mGlobalId.item.metricSystem
    ////////////////////////////////
    property int frontTpmsDoorExchange: 0
    property int rearTpmsDoorExchange: 0
    property int angleInfoEnabled: 0
    property int sinceStartInfoEnabled: 1
    property int sinceResetInfoEnabled: 1
    property int sinceRefuelingInfoEnabled: 1
    property int clockInfoEnabled: 1
    property int doorInfoEnabled: 1
    property int outSideTempInfoEnabled: 1
    property int ecoInfoEnabled: 0
    property int tpmsInfoEnabled: 1
    property int oilPressureInfoEnabled: 0
    property int cruiseInfoEnabled: 0
    property int attentionAssistInfoEnabled: 0
    property int mediaInfoEnabled: 0
    property int gforceInfoEnabled: 0
    property int vehicleSpeed320: 0
    property int reverseAlarmEnabled: 0
    property int tachoSpeedMax6000: 0
    property int fuelType: 0
    property int metricSystem: 0
    property int fuelRefuelingPortPositon: 0    // 0: left, 1: right
    property int subTankEnabled: 0
    property int gearInfoEnabled: 0
    property int oilTempEnabled: 0
    property int dteEnabled: 0
    property int chassisStateEnabled: 0
    property int screenFlipEnabled: 0

    function setFactory(index){
        console.log("[setFactory index:"+index+"]")
        // 更新了CenterInfo 列表，必須把 drivingInfoIndex 設置在Trip/ODO頁面上，否則溢位
        mGlobalId.item.drivingInfoIndex=0
        switch(index){
        case 0:
            frontTpmsDoorExchange=!frontTpmsDoorExchange
            Funcs.setProperty("frontTpmsDoorExchange", frontTpmsDoorExchange)
            break
        case 1:
            rearTpmsDoorExchange=!rearTpmsDoorExchange
            Funcs.setProperty("rearTpmsDoorExchange", rearTpmsDoorExchange)
            break
        case 2:
            fuelRefuelingPortPositon=!fuelRefuelingPortPositon
            Funcs.setProperty("fuelRefuelingPortPositon", fuelRefuelingPortPositon)
            mEventHandleId.item.setFuelFillerRightSide(fuelRefuelingPortPositon)
            break
        case 3:
            tpmsInfoEnabled=!tpmsInfoEnabled
            Funcs.setProperty("tpmsInfoEnabled", tpmsInfoEnabled)
            break
        case 4:
            reverseAlarmEnabled=!reverseAlarmEnabled
            mEventHandleId.item.setReverseAlarm(reverseAlarmEnabled)
            //Funcs.setProperty("reverseAlarmEnabled", reverseAlarmEnabled)
            break;
        case 5:
            tachoSpeedMax6000=!tachoSpeedMax6000
            //mEventHandleId.item.setReverseAlarm(reverseAlarmEnabled)
            Funcs.setProperty("tachoSpeedMax6000", tachoSpeedMax6000)
            break;
        case 6:
            subTankEnabled=!subTankEnabled
            Funcs.setProperty("subTankEnabled", subTankEnabled)
            break;
        case 7:
            if(mGlobalId.item.mLc76VehicleSpeedMaxIndex<4)
                mGlobalId.item.mLc76VehicleSpeedMaxIndex++
            else
                mGlobalId.item.mLc76VehicleSpeedMaxIndex=0
            Funcs.setProperty("mLc76VehicleSpeedMaxIndex", mLc76VehicleSpeedMaxIndex)
            break
        case 8:
            angleInfoEnabled=!angleInfoEnabled
            Funcs.setProperty("angleInfoEnabled", angleInfoEnabled)
            break
        case 9:
            outSideTempInfoEnabled=!outSideTempInfoEnabled
            Funcs.setProperty("outSideTempInfoEnabled", outSideTempInfoEnabled)
            break
        case 10:
            ecoInfoEnabled=!ecoInfoEnabled
            Funcs.setProperty("ecoInfoEnabled", ecoInfoEnabled)
            break
        case 11:
            gearInfoEnabled=!gearInfoEnabled
            Funcs.setProperty("gearInfoEnabled", gearInfoEnabled)
            break;
        case 12:
            oilTempEnabled=!oilTempEnabled
            Funcs.setProperty("oilTempEnabled", oilTempEnabled)
            break;
        case 13:
            dteEnabled=!dteEnabled
            Funcs.setProperty("dteEnabled", dteEnabled)
            break
        case 14:
            clockInfoEnabled=!clockInfoEnabled
            Funcs.setProperty("clockInfoEnabled", clockInfoEnabled)
            break
        case 15:
            doorInfoEnabled=!doorInfoEnabled
            Funcs.setProperty("doorInfoEnabled", doorInfoEnabled)
            break
        case 16:
            oilPressureInfoEnabled=!oilPressureInfoEnabled
            Funcs.setProperty("oilPressureInfoEnabled", oilPressureInfoEnabled)
            break
        case 17:
            chassisStateEnabled=!chassisStateEnabled
            Funcs.setProperty("chassisStateEnabled", chassisStateEnabled)
            break
        case 18:
            screenFlipEnabled=!screenFlipEnabled
            Funcs.setProperty("screenFlipEnabled", screenFlipEnabled)
            break
//        case 3:
//            sinceStartInfoEnabled=!sinceStartInfoEnabled
//            Funcs.setProperty("sinceStartInfoEnabled", sinceStartInfoEnabled)
//            break
//        case 4:
//            sinceResetInfoEnabled=!sinceResetInfoEnabled
//            Funcs.setProperty("sinceResetInfoEnabled", sinceResetInfoEnabled)
//            break
//        case 5:
//            sinceRefuelingInfoEnabled=!sinceRefuelingInfoEnabled
//            Funcs.setProperty("sinceRefuelingInfoEnabled", sinceRefuelingInfoEnabled)
//            break
//        case 12:
//            cruiseInfoEnabled=!cruiseInfoEnabled
//            Funcs.setProperty("cruiseInfoEnabled", cruiseInfoEnabled)
//            break
//        case 13:
//            attentionAssistInfoEnabled=!attentionAssistInfoEnabled
//            Funcs.setProperty("attentionAssistInfoEnabled", attentionAssistInfoEnabled)
//            break
//        case 14:
//            gforceInfoEnabled=!gforceInfoEnabled
//            Funcs.setProperty("gforceInfoEnabled", gforceInfoEnabled)
//            break
//        case 15:
//            vehicleSpeed320=!vehicleSpeed320
//            Funcs.setProperty("vehicleSpeed320", vehicleSpeed320)
//            break
//        case 5:
//            mTachoSpeedMax=!mTachoSpeedMax
//            //mEventHandleId.item.setReverseAlarm(reverseAlarmEnabled)
//            Funcs.setProperty("mTachoSpeedMax", mTachoSpeedMax)
//            break;
//        case 16:
//            fuelType=!fuelType
//            Funcs.setProperty("fuelType", fuelType)
//            break;
//        case 17:
//            metricSystem=!metricSystem
//            Funcs.setProperty("metricSystem", metricSystem)
//            break

        }
    }

    /////////////////////////////
    // protocol uart debug mGlobalId.item.btVersion
    /////////////////////////////
    property string mcuUartData;
    property int mcuUartDataCnt: 0
    property string armUartData;
    property int armUartDataCnt: 0
    property int uartDebugEnabled: 0

    onUartDebugEnabledChanged: {
        if(mCompleted)
            Funcs.setProperty("uartDebugEnabled", uartDebugEnabled)
    }
    //////////////////////////////////
    // Bt mGlobalId.item.btConnected
    //////////////////////////////////
    property int btConnected: 0
    //////////////////////////////////
    // PHONELINK mGlobalId.item.cP_KEY_REQUESTUI_MAP
    //////////////////////////////////
    property var mLinkEventUartNum:
    [
        0,      // NONE
        1,      // T113-Core
        1,      // T507-Core
    ]
    property var mLinkMfiBusNum:
    [
        0,      // NONE
        1,      // T113-Core
        3,      // T507-Core
    ]
    property int mLinkEventUart: mLinkEventUartNum[Number(mPlatform)]
    property int mLinkMfiBus: mLinkMfiBusNum[Number(mPlatform)]
    property int cP_KEY_REQUESTUI_CURRENT: 2000
    property int cP_KEY_REQUESTUI_MAP: 2001
    property int cP_KEY_REQUESTUI_MUSIC: 2002
    property int cP_KEY_REQUESTUI_NOWPLAYING: 2003
    property int cP_KEY_REQUESTUI_PHONECALL: 2004

    property int linkKeyPlay: 1
    property int linkKeyPause: 2
    property int linkKeyPlayPause: 3
    property int linkKeyNext: 4
    property int linkKeyPrev: 5
    property int linkKeyLeft: 7
    property int linkKeyRight: 9
    property int linkKeyUp: 10
    property int linkKeyDown: 11
    property int linkKeyEnter: 13
    property int linkKeyHome: 14
    property int linkKeyBack: 15
    property int linkKeyHangup: 16
    property int linkKeyAnswer: 17
    property int linkKeySpeech: 18
    property int linkKeyLeftTurn: 19
    property int linkKeyRightTurn: 20

    property int linkKeyMap: 50

//    KEY_MEDIA_PLAY = 1,
//    KEY_MEDIA_PAUSE = 2,
//    KEY_MEDIA_PLAY_PAUSE = 3,
//    KEY_MEDIA_NEXT = 4,
//    KEY_MEDIA_PREVIOUS = 5,
//    KEY_SOFT_LEFT = 6,
//    KEY_DPAD_LEFT = 7,
//    KEY_SOFT_RIGHT = 8,
//    KEY_DPAD_RIGHT = 9,
//    KEY_DPAD_UP = 10,
//    KEY_DPAD_DOWN = 11,
//    KEY_ENTER = 12,
//    KEY_DPAD_CENTER = 13,
//    KEY_HOME = 14,
//    KEY_BACK = 15,
//    KEY_ENDCALL = 16,
//    KEY_CALL = 17,
//    KEY_ASR = 18,
//    KEY_LEFT_TRUN = 19,
//    KEY_RIGNT_TRUN = 20,

    property int linkEnabled: 0
    property int linkUsed: 1
    property int linkVendor: 0
    property int linkMode: 0
    property int linkWired: 0 //EventHandle.PHONELINK_WIRED_AOA

    property int phonelink: 0
    property int linkWidth: Screen.desktopAvailableWidth
    property int linkHeight: Screen.desktopAvailableHeight
    property int linkSession: 0
    property int linkUnActivited: 0
    property string p2pState;
    property int linkScrWidth: 1080
    property int linkScrHeight: 2160
    property int linkMirror: 0
    property int linkRotation: 90
    property string linkLabel: "CarHome"
    property string linkName: mSSID

    property int mLinkSessionLast: 0
    property int mLinkSession: linkSession
    onMLinkSessionChanged: {
        if(linkSession==4){
            map=1
        }else{
            map=0
        }
    }
    property int linkCpMusicOn: 0
    property int linkCpTurnByTurn: 0
    property int linkCpPhoneCall: 0

    property int linkWiredCarPlay: 0
    property int linkWiredAuto: 0
    property int linkWiredQuickTime: 0
    property int linkWiredAoa: 1
    property int linkRndisConnected: 0

    ////////////////////////////////
    // menu mGlobalId.item.mPostInfoFocusTimerId
    ////////////////////////////////
    property int menuBarIndex: 0
    property int menuBarItemIndex: 0

    property int menuPageIndex: 0
    property int menuPageItemIndex: 0

    property int menuSubPageIndex: 0
    property int menuSubPageItemIndex: 0

    property int menuSettingsPageIndex: 0
    property int menuSettingsPageItemIndex: 0

    property int menuSettingsSubPageItemIndex: 0
    property int menuSettingsSubPageItemSetup: 0

    property int infoFocus: 0
    property int infoFocusIndex: 1 // 0: left, 1: center, 2: right

    function info_focus_timer_refresh(){
        mPostInfoFocusTimerId.restart()
    }

    Timer{
        id: mPostInfoFocusTimerId
        interval: 100
        running: false
        onTriggered: {
            infoFocus=1
            mPostFocusTimerId.restart()
        }
    }

    Timer{
        id: mPostFocusTimerId
        interval: 3000
        running: false
        onTriggered: {
            infoFocus=0
            infoFocusIndex=1
        }
    }
    ////////////////////////////////
    // 【0x00】建立/断开连接
    ////////////////////////////////
    property int startEnd: 0
    ////////////////////////////////
    // 【0x02】常规故障表 alarmInfoNotify
    ////////////////////////////////
    property int alarmMax: 300
    property var alarmTable: []
    property int alarmChanged: 0
    onAlarmChangedChanged: {
        // 示宽灯(大灯)
        ill=Math.floor(alarmTable[12])
    }
    function getAlarm(id){
        return alarmChanged?alarmTable[id]:alarmTable[id]
    }

    Timer{
        id: mAlarmTableTimerId
        interval: 2000
        repeat: true
        running: autoRun
        onTriggered: {
            for(var i=0;i<alarmMax;i++){
                alarmTable[i]=Funcs.getRndInteger(0, 2)
            }
            mGlobalId.item.alarmChanged=!mGlobalId.item.alarmChanged
        }
    }

    ////////////////////////////////
    // 【0x03】弹窗提醒 warning/dialog Notify
    // mGlobalId.item.notifyInfoHide
    ////////////////////////////////
    property int notifyTop: (acc && splashEnd) &&
                            (shellCmdShow ||
                             dialogShow ||
                             notifyShow )
    property int notifyText: 0
    property int notifyIcon: 0
    property int notifyDuration: 0
    property int notifyShow: notifyDuration>0
    property int nofifyDpf: 0
    property int nofifyU16: 0

    function notifyInfoHide(){
        notifyDuration=0
    }

    Timer{
        interval: 2000
        running: autoRun
        repeat: true
        onTriggered: {
            notifyText=Funcs.getRndInteger(1, 300)
            notifyIcon=notifyText
        }
    }

    ////////////////////////////////
    // 【0x83】新弹窗提醒 warning/dialog Notify
    // mGlobalId.item.dialogIcon
    ////////////////////////////////
    property int dialogTotal: 0
    property int dialogListId: 0
    property int dialogColor: 0
    property int dialogId: 0
    property int dialogIcon: 0
    property int dialogDuration: 0
    property int dialogParam: 0
    property int dialogShow: dialogDuration>0

    function dialogInfoHide(){
        dialogDuration=0
    }
    function getDialogColor(){
        switch(dialogColor){
        case 0:
            return "white"
        case 1:
            return "orange"
        case 2:
            return "red"
        case 3:
            return "green"
        case 4:
            return "grey"
        }
    }
    // mGlobalId.item.getDialogListTotal
    function getDialogListTotal(){
        var total=mEventHandleId.item.getDialog2ListTotal()
        return total
    }
    // 0: total, 1: currentId, 2: color, 3: id, 4: icon, 5: param
    function getDialogListInfo(index, item){
        var info=mEventHandleId.item.getDialog2ListInfo(index).split("#")
        return Number(info[item])
    }
    function getDialogListColorState(state){
        switch(state){
        case 0:
            return "white"
        case 1:
            return "orange"
        case 2:
            return "red"
        case 3:
            return "green"
        case 4:
            return "grey"
        }
    }
    function getDialogListColor(index){
        return getDialogListColorState(getDialogListInfo(index, 2))
    }
    function getDialogListText(index){
        return getDialogListInfo(index, 3)
    }
    function getDialogListIcon(index){
        return getDialogListInfo(index, 4)
    }

    ////////////////////////////////
    // 【0x04】实时车速&发动机转速 speedInfoNotify
    // mGlobalId.item.vehicleSpeed
    ////////////////////////////////
    property int vehicleSpeed: 0
    property int vehicleSpeedDelta: 0
    property int vehicleSpeedMax: mVehicleSpeedMax[Number(mTrucksModel)]//260//metricSystem?200:120//vehicleSpeed320?330:260
    property int vehicleSpeedDuration: vehicleSpeedDelta>30?100:180
    property string vehicleSpeedUnit: metricSystem?"km/h":"MPH"
    property int tachoSpeed: 0
    property int tachoSpeedDelta: 0
    property int tachoSpeedMax: mTachoSpeedMax[Number(mTrucksModel)]//tachoSpeedMax6000?6000:7000
    property int tachoSpeedDuration: Math.abs(tachoSpeedDelta)>1500?300:800//100:180

    // Number(mTrucksModel)
    property int mLc76VehicleSpeedMaxIndex: 0
    onMLc76VehicleSpeedMaxIndexChanged: {
        Funcs.setProperty("mLc76VehicleSpeedMaxIndex", mLc76VehicleSpeedMaxIndex)
    }
    property var mLc76VehicleSpeedList:
    [
        200, //metricSystem?200:120,
        210, //metricSystem?210:130,
        240, //metricSystem?240:150,
        260, //metricSystem?260:160,
        290, //metricSystem?290:180,
    ]
    property int mSilveradoVehicleSpeedMaxIndex: 2
    onMSilveradoVehicleSpeedMaxIndexChanged: {
        Funcs.setProperty("mSilveradoVehicleSpeedMaxIndex", mSilveradoVehicleSpeedMaxIndex)
    }
    property var mSilveradoVehicleSpeedList:
    [
        240,//metricSystem?180:110,
        240,//metricSystem?200:120,
        240,//metricSystem?220:140,
    ]
    property int mSilveradoTachoSpeedMaxIndex: 1
    onMSilveradoTachoSpeedMaxIndexChanged: {
        Funcs.setProperty("mSilveradoTachoSpeedMaxIndex", mSilveradoTachoSpeedMaxIndex)
    }
    property var mSilveradoTachoSpeedList:
    [
        5000,
        6000,
        7000,
    ]
    property var mTachoSpeedMax:
    [
        tachoSpeedMax6000?6000:7000,    // ram
        tachoSpeedMax6000?6000:7000,    // ford
        tachoSpeedMax6000?6000:7000,    // prado
        tachoSpeedMax6000?6000:7000,    // patorl
        tachoSpeedMax6000?6000:7000,    // landcruiser
        tachoSpeedMax6000?6000:7000,                         // lc76
        mSilveradoTachoSpeedList[mSilveradoTachoSpeedMaxIndex],
        tachoSpeedMax6000?6000:7000,    // everest
        7000,    // yukon
        tachoSpeedMax6000?6000:7000,    // gmc
    ]
    property var mVehicleSpeedMax:
    [
        200,//metricSystem?200:120,                   //        200,    // ram
        200,//metricSystem?200:120,                                      //        200,    // ford
        260,//metricSystem?260:160,                                      //        260,    // prado
        260,//metricSystem?260:160,                                       //        260,    // patorl
        260,//metricSystem?260:160,                                      //        260,    // landcruiser
        mLc76VehicleSpeedList[mLc76VehicleSpeedMaxIndex],                                      //        210,    // lc76
        mSilveradoVehicleSpeedList[mSilveradoVehicleSpeedMaxIndex],
        200,    // everest
        200,    // yukon
        240
    ]
//    Behavior on vehicleSpeed{
////        SpringAnimation{
////            damping: 0.1
////            spring: 1
////        }
//        NumberAnimation{
//            duration: vehicleSpeedDuration
//        }
//    }
//    Behavior on tachoSpeed{
//        NumberAnimation{
//            duration: tachoSpeedDuration
//        }
//    }
    function getVehicleSpeed(){
        //console.log("[getVehicleSpeed:"+vehicleSpeed+"]")
        return (vehicleSpeed>vehicleSpeedMax)?
               (vehicleSpeedMax*tripFactor).toFixed(0):
               (vehicleSpeed*tripFactor).toFixed(0)
    }
    function getVehicleSpeedLevel(level){
        if(vehicleSpeedMax>260){
            if(getVehicleSpeed()<=200)
                return (getVehicleSpeed()*level)/260
            else{
                var temp=((getVehicleSpeed()-200)*level/260)/2
                return 180+temp
            }
        }else{
            return (getVehicleSpeed()*level)/vehicleSpeedMax
        }
    }
    function getTachoSpeed(){
        return tachoSpeed>tachoSpeedMax?tachoSpeedMax:tachoSpeed
    }
    function getTachoSpeedLevel(level){
        return (getTachoSpeed()*level)/tachoSpeedMax
    }

    Timer{
        id: vehicleSpeedTimerId
        interval: 200
        running: autoRun
        repeat: true
        onTriggered: {
            var temp;
            temp=Number(Funcs.getRndInteger(20, vehicleSpeedMax))
            vehicleSpeedDelta=Math.abs(vehicleSpeed-temp)
            vehicleSpeed=temp
            temp=Number(Funcs.getRndInteger(600, 7800))
            tachoSpeedDelta=Math.abs(tachoSpeed-temp)
            tachoSpeed=temp
        }
    }
    ////////////////////////////////
    // 【0x05】系统设置
    // mGlobalId.item.vehicleModel
    ////////////////////////////////
    property int lineTracking: 0
    property int reverseAlarm: 0
    property int vehicleModel: 0 //Number(mTrucksModel)
    onVehicleModelChanged: {
        Funcs.setProperty("vehicleModel", vehicleModel)
    }

    function getMcuVehicleModelIndex(vender, model){
        switch(vender){
        case 0: // benz
            switch(vehicleModel){
            case 0:
                return 19   //VT
            case 1:
                return 30    //C180
            case 2:
                return 32   //S600
            case 3:
                return 34    //老款C系
            case 4:
                return 35   //老款E系
            case 5:
                return 36   //GLA
            case 6:
                return 42   //BJ
            case 7:
                return 43    //GLE
            case 8:
                return 44   //BENZ_G
            case 9:
                return 49   //S320L
            case 10:
                return 47   //R500
            }
            break;
        case 1: // bmw
            break;
        case 2: // mini
            return model
        }
    }

    ////////////////////////////////
    // 【0x06】油量信息 fuelInfoNotify
    // common mGlobalId.item.isDteVisible
    ////////////////////////////////
    property int consumptionUnit: 0
    property int dte: 0xFFFF         // 续航里程
    property int fuelPercentage: 0
    property int fuelFillerPosition: 0  // 0: left, 1: right,  應用工廠設置決定
    property int fuelLevel: 0     // 0: white, 1: yellow, 2: red
    property var mFuelUnit:
    [
        "l/100km",
        "km/l",
        "MPG",
    ]
    property string fuelUnit: mFuelUnit[consumptionUnit]//consumptionUnit?"L/100km":"MPG"
    //property real fuelFactor: consumptionUnit?1:0.425143706
    property int mainTank: 0
    property int subTank: 0
    property int mainTankPercentage: 0
    property int subTankPercentage: 0
    property int mainTankState: 0
    property int subTankState: 0
    property string tankUnit: "L" //metricSystem?"L":"GAL"
    property real tankUnitFactor: 1 //metricSystem?1:0.264172052358

//    function getFuelConsumption(value){
//        return (consumptionUnit?value:(235.22/value)).toFixed(1)
//    }
    function getFuelConsumption(value){
        switch(consumptionUnit){
        case 0: // L/100km
            return (value).toFixed(1)
        case 1: // km/l
            return !value?0.0:(100/value).toFixed(1)
        case 2: // MPG
            return !value?0.0:(235.2156/value).toFixed(1)
        }
        //return (consumptionUnit?value:(235.2156/value)).toFixed(1)
    }

    onConsumptionUnitChanged: {
        Funcs.setProperty("consumptionUnit", consumptionUnit)
    }

    function getTank(sub, unit){
        if(sub){
            return (subTank*tankUnitFactor).toFixed(0)+" "+tankUnit
        }else{
            return (mainTank*tankUnitFactor).toFixed(0)+" "+tankUnit
        }
    }
    function getTankNum(sub, index){
        var temp=!sub?(mainTank*tankUnitFactor).toFixed(0):(subTank*tankUnitFactor).toFixed(0)
        switch(index){
        case 0:
            return temp/100
        case 1:
            return temp%100/10
        case 2:
            return temp%10
        }
    }

    function isDteVisible(){
        return dte!=0xFFFE
    }
    function getDte(unit){
        return mGlobalId.item.metricSystem?(dte==0xFFFF?"---":(dte*tripFactor).toFixed(0))+(unit?(" "+tripUnit):""):
                                           (dte==0xFFFF?"---":(dte*tripFactor).toFixed(0))+(unit?(" "+tripUnit):"")
    }
    function getFuelPercentage(){
        return fuelPercentage+"%"
    }
    property var mFuelStateColor:
    [
        "white",
        "orange",
        "red",
    ]
    function getFuelStateColor(){
        return mFuelStateColor[fuelLevel]
    }
    Timer{
        id: mainfuelPercentageTimerId
        interval: 500
        running: autoRun
        repeat: true
        onTriggered: {
            odo=Funcs.getRndInteger(99, 19999)
            tripA=Funcs.getRndInteger(99.9, 999.9)
            mainTankPercentage=Funcs.getRndInteger(0, 100)
            dte=Funcs.getRndInteger(10, 900)
            if(mainTankPercentage<20)
                fuelLevel=2
            else if(mainTankPercentage<50)
                fuelLevel=1
            else
                fuelLevel=0
        }
    }
    Timer{
        id: subfuelPercentageTimerId
        interval: 500
        running: autoRun
        repeat: true
        onTriggered: {
            odo=Funcs.getRndInteger(99, 19999)
            tripA=Funcs.getRndInteger(99.9, 999.9)
            subTankPercentage=Funcs.getRndInteger(0, 100)
            dte=Funcs.getRndInteger(10, 900)
            if(subTankPercentage<20)
                fuelLevel=2
            else if(subTankPercentage<50)
                fuelLevel=1
            else
                fuelLevel=0
        }
    }
    Timer{
        id: fuelPercentageTimerId
        interval: 500
        running: autoRun
        repeat: true
        onTriggered: {
            odo=Funcs.getRndInteger(99, 19999)
            tripA=Funcs.getRndInteger(99.9, 999.9)
            fuelPercentage=Funcs.getRndInteger(0, 100)
            dte=Funcs.getRndInteger(10, 900)
            if(fuelPercentage<20)
                fuelLevel=2
            else if(fuelPercentage<50)
                fuelLevel=1
            else
                fuelLevel=0
        }
    }
    ////////////////////////////////
    // 【0x07】界面 ID & 弹窗 ID dashboardInfoNotify
    ////////////////////////////////
    property int dashboard: 0
    property int dashboardCounts: 3
    property int dashboardNum: 3
    property int drivingInfoIndex: 0
    property int drivingInfoIndexCounts: 0
    property int drivingInfoIndexLast: 0
    property int leftInfoIndex: 0
    property int leftInfoIndexCounts: 0
    property int rightInfoIndex: 0
    property int rightInfoIndexCounts: 0
    // gauge info
    property int upGaugeIndex: 0
    property int downGaugeIndex: 0

    property int rightInfoTachoSpeedGear: 0     // 0: TachoSpeed Info, 1: Gear/DriveMode info

    Timer{
        id: mInfoTimerId
        interval: 2000
        running: autoRun
        repeat: true
        onTriggered: {
            drivingInfoIndex=Funcs.getRndInteger(0, 3)
            leftInfoIndex=Funcs.getRndInteger(0, 3)
            rightInfoIndex=Funcs.getRndInteger(0, 3)
        }
    }

    // 只要上面數據有改變就儲存
    onDashboardChanged: {
        Funcs.setProperty("dashboard", dashboard)
    }
    onDrivingInfoIndexChanged: {
        Funcs.setProperty("drivingInfoIndex", drivingInfoIndex)
    }
    onLeftInfoIndexChanged: {
        Funcs.setProperty("leftInfoIndex", leftInfoIndex)
    }
    onRightInfoIndexChanged: {
        Funcs.setProperty("rightInfoIndex", rightInfoIndex)
    }
    onUpGaugeIndexChanged: {
        if(upGaugeIndex>3)
            upGaugeIndex=0
        Funcs.setProperty("upGaugeIndex", upGaugeIndex)
    }
    onDownGaugeIndexChanged: {
        if(downGaugeIndex>3)
            downGaugeIndex=0
        Funcs.setProperty("downGaugeIndex", downGaugeIndex)
    }
    Timer{
        id: mDashboardTimerId
        interval: 4000
        running: autoRun
        repeat: true
        onTriggered: {
            // if(dashboard<4)
            //     dashboard++
            // else
            //     dashboard=0
            //mGlobalId.item.vehicleColor=-1
            vehicleColor=Funcs.getRndInteger(0, 6)
            //map=Funcs.getRndInteger(0, 1)
            //console.log("[vehicleColor:"+vehicleColor+"]")
        }
    }
    ////////////////////////////////
    // 【0x08】里程信息
    // tripInfoNotify mGlobalId.item.tripType
    ////////////////////////////////
    property double odo: 0xFFFFFF
    property real tripA: 0xFFFFFF
    property real tripB: 0xFFFFFF
    property int tripType: 1      // 0: odo, 1: tripA, 2: tripB
    property string tripUnit: metricSystem?"km":"mi"
    property real tripFactor: metricSystem?1:0.62137
    onTripTypeChanged: {
        Funcs.setProperty("tripType", tripType)
    }
    function getOdo(unit){
        return (odo==0xFFFFFF?"------":
               (odo*tripFactor).toFixed(0))+
               (unit?" "+tripUnit:"")
    }
    function getTripA(unit){
        return (tripA==0xFFFFFF?"---.-":
               (tripA*tripFactor).toFixed(1))+
               (unit?" "+tripUnit:"")
    }
    function getTripB(unit){
        return (tripB==0xFFFFFF?"---.-":
               (tripB*tripFactor).toFixed(1))+
               (unit?" "+tripUnit:"")
    }
    function getOdoNum(index){
        var temp=(odo*tripFactor).toFixed(0)
        switch(index){
        case 0:
            return odo==0xFFFFFF?0:temp/100000
        case 1:
            return odo==0xFFFFFF?0:temp%100000/10000
        case 2:
            return odo==0xFFFFFF?0:temp%100000%10000/1000
        case 3:
            return odo==0xFFFFFF?0:temp%100000%10000%1000/100
        case 4:
            return odo==0xFFFFFF?0:temp%100000%10000%1000%100/10
        case 5:
            return odo==0xFFFFFF?0:temp%10
        }
    }

    ////////////////////////////////
    // 【0x0A】胎压 tpmsInfoNotify
    // mGlobalId.item.getTpmsPressure
    ////////////////////////////////
    property int pressureUnit: 0 // 0: kPa, 1: bar , 2: kg/cm2, 3: psi
    property var mTpmsUnit:
    [
        " kPa",
        " bar",
        " kg/cm2",
        " psi",
    ]
    property int tpmsLFState: 0
    property int tpmsLFPressure: 0xFFF
    property string tpmsLFString: tpmsLFPressure==0xFFF?"---":(pressureUnit?tpms_pressure(tpmsLFPressure):tpms_pressure(tpmsLFPressure))
    property int tpmsRFState: 0
    property int tpmsRFPressure: 0xFFF
    property string tpmsRFString: tpmsRFPressure==0xFFF?"---":(pressureUnit?tpms_pressure(tpmsRFPressure):tpms_pressure(tpmsRFPressure))
    property int tpmsLRState: 0
    property int tpmsLRPressure: 0xFFF
    property string tpmsLRString: tpmsLRPressure==0xFFF?"---":(pressureUnit?tpms_pressure(tpmsLRPressure):tpms_pressure(tpmsLRPressure))
    property int tpmsRRState: 0
    property int tpmsRRPressure: 0xFFF
    property string tpmsRRString: tpmsRRPressure==0xFFF?"---":(pressureUnit?tpms_pressure(tpmsRRPressure):tpms_pressure(tpmsRRPressure))
    property int tpmsRearState: 0
    property int tpmsRearPressure: 0xFFF
    property string tpmsRearString: tpmsRearPressure==0xFFF?"---":(pressureUnit?tpms_pressure(tpmsRearPressure):tpms_pressure(tpmsRearPressure))

    property int tpmsPressureUnitIndex: 0  // 0: kPa, 1: bar、 2, kg/cm2、3: PSI
    property string tpmsPressureUnit: mTpmsUnit[pressureUnit]

    onPressureUnitChanged: {
        Funcs.setProperty("pressureUnit", pressureUnit)
    }

    function tpms_pressure(value){
        if(value===0xFFF)
            return "---"
        switch(pressureUnit){
        case 0: // kPa
            return value
        case 1: // bar
            return (value/100).toFixed(1)
        case 2: // kg/cm2
            return (value/98.0665).toFixed(1)
        case 3: // PSI
            return (value/6.894757293168).toFixed(1)
        }
    }
    function getTpmsPressure(index){
        switch(index){
        case 0: // lf
            return tpms_pressure(frontTpmsDoorExchange?tpmsRFPressure:tpmsLFPressure)
        case 1: // rf
            return tpms_pressure(frontTpmsDoorExchange?tpmsLFPressure:tpmsRFPressure)
        case 2: // lr
            return tpms_pressure(rearTpmsDoorExchange?tpmsRRPressure:tpmsLRPressure)
        case 3: // rr
            return tpms_pressure(rearTpmsDoorExchange?tpmsLRPressure:tpmsRRPressure)
        case 4: // rear
            return tpms_pressure(tpmsRearPressure)//(rearTpmsDoorExchange?tpmsLRPressure:tpmsRRPressure)
        }
    }
    function getTpmsState(index){
        switch(index){
        case 0: // lf
            return frontTpmsDoorExchange?tpmsRFState:tpmsLFState
        case 1: // rf
            return frontTpmsDoorExchange?tpmsLFState:tpmsRFState
        case 2: // lr
            return frontTpmsDoorExchange?tpmsRRState:tpmsLRState
        case 3: // rr
            return frontTpmsDoorExchange?tpmsLRState:tpmsRRState
        case 4: // rear
            return tpmsRearState//frontTpmsDoorExchange?tpmsLRState:tpmsRRState

        }
    }

    ////////////////////////////////
    // 【0x0B】车门 doorInfoNotify
    // mGlobalId.item.getDoorState()
    ////////////////////////////////
    property int doorInfo: doorLeftFront|doorRightFront|doorLeftRear|doorRightRear|doorHood|doorTrunk|radarEnabled
    property int doorLeftFront: 0
    property int doorRightFront: 0
    property int doorLeftRear: 0
    property int doorRightRear: 0
    property int doorHood: 0
    property int doorTrunk: 0

    function doorInfoHide(){
        // 不可以doorInfo=0, 因為這樣會失去跟車門的相關性
        //if(radarEnabled){
            doorLeftFront=0
            doorRightFront=0
            doorLeftRear=0
            doorRightRear=0
            doorHood=0
            doorTrunk=0
        //}
        //mGlobalId.item.notifyText=0
        //mGlobalId.item.notifyDuration=0
    }

    function getDoorState(index){
        switch(index){
        case 0: // lf
            return frontTpmsDoorExchange?doorRightFront:doorLeftFront
        case 1: // rf
            return frontTpmsDoorExchange?doorLeftFront:doorRightFront
        case 2: // lr
            return rearTpmsDoorExchange?doorRightRear:doorLeftRear
        case 3: // rr
            return rearTpmsDoorExchange?doorLeftRear:doorRightRear
        case 4: // hood
            return doorHood
        case 5: // hood
            return doorTrunk
        }
    }

    ////////////////////////////////
    // 【0x0C】重置后 sinceReset/Refueling/start InfoNotify
    // mGlobalId.item.sinceResetAvgSpeed
    ////////////////////////////////
    property real sinceResetAvgFuel: 0xFFFF
    property int sinceResetAvgSpeed: 0xFFFF
    property int sinceResetTravelTime: 0xFFFF
    property int sinceResetTravelMileage: 0xFFFF

    function getSinceResetAvgFuel(){
        return (sinceResetAvgFuel===0xFFFF?"--.-":getFuelConsumption(sinceResetAvgFuel))
               //(sinceResetAvgFuel/fuelFactor).toFixed(1))
    }
    function getSinceResetAvgSpeed(){
        return (sinceResetAvgSpeed===0xFFFF?"---":
               (sinceResetAvgSpeed*tripFactor).toFixed(0))
    }
    function getSinceResetTravelTime(){
        return sinceResetTravelTime===0xFFFF?"--:--":
               (Math.floor(sinceResetTravelTime/60)+":"+
               Math.floor(sinceResetTravelTime%60))
    }
    function getSinceResetTravelMileage(){
        return (sinceResetTravelMileage===0xFFFF?"---":
               (sinceResetTravelMileage*tripFactor).toFixed(0))
    }
    ////////////////////////////////
    // 【0x0D】加油后
    // mGlobalId.item.getSinceRefuelingDte
    ////////////////////////////////
    property int sinceRefuelingDte: 0xFFFF
    property real sinceRefuelingAvgFuel: 0xFFFF
    property int sinceRefuelingAvgSpeed: 0xFFFF

    function getSinceRefuelingDte(){
        return (sinceRefuelingDte===0xFFFF?"---":
               (sinceRefuelingDte*tripFactor).toFixed(0))
    }
    function getSinceRefuelingAvgFuel(){
        return (sinceRefuelingAvgFuel===0xFFFF?"--.-":getFuelConsumption(sinceRefuelingAvgFuel))
               //(sinceRefuelingAvgFuel/fuelFactor).toFixed(1))
    }
    function getSinceRefuelingAvgSpeed(){
        return (sinceRefuelingAvgSpeed===0xFFFF?"---":
               (sinceRefuelingAvgSpeed*tripFactor).toFixed(0))
    }
    ////////////////////////////////
    // 【0x0E】启动后
    // mGlobalId.item.sinceStartAvgSpeed
    ////////////////////////////////
    property real sinceStartAvgFuel: 0xFFFF
    property int sinceStartAvgSpeed: 0xFFFF
    property int sinceStartTravelTime: 0xFFFF
    property int sinceStartTravelMileage: 0xFFFF

    function getSinceStartAvgFuel(){
        return (sinceStartAvgFuel===0xFFFF?"--.-":getFuelConsumption(sinceStartAvgFuel))
               //(sinceStartAvgFuel/fuelFactor).toFixed(1))
    }
    function getSinceStartAvgSpeed(){
        return (sinceStartAvgSpeed===0xFFFF?"---":
               (sinceStartAvgSpeed*tripFactor).toFixed(0))
    }
    function getSinceStartTravelTime(){
        return sinceStartTravelTime===0xFFFF?"--:--":
               (Math.floor(sinceStartTravelTime/60)+":"+
               Math.floor(sinceStartTravelTime%60))
    }
    function getSinceStartTravelMileage(){
        return (sinceStartTravelMileage===0xFFFF?"---":
               (sinceStartTravelMileage*tripFactor).toFixed(0))
    }
    ////////////////////////////////
    // 【0x0F】ECO 节能信息 ecoInfoNotify mGlobalId.item.ecoValue
    ////////////////////////////////
    property int ecoEnabled: 0
    property int ecoState: 0
    property int ecoValue: 0

    Timer{
        running: autoRun
        interval: 500
        repeat: true
        onTriggered: {
            ecoValue=Funcs.getRndInteger(0, 5)
        }
    }

    ////////////////////////////////
    // 【0x11】瞬时油耗 lpkInfoNotify
    // mGlobalId.item.getLpkData
    ////////////////////////////////
    property var mLpkUnit:
    [
        "L/100km",
        "L/h",
    ]
    property int lpkUnitIndex: 0
    property string lpkUnit: mFuelUnit[consumptionUnit]//consumptionUnit?mLpkUnit[lpkUnitIndex]:"MPG"
    property real lpk: 0x7FFF             // 瞬时油耗
    Behavior on lpk{
        NumberAnimation{
            duration: 300
        }
    }
    function isLpkVisible(){
        return lpk!=0x7FFE
    }
    function getLpkData(){
        return lpk>100?0:getFuelConsumption(lpk)
    }
    function getLPK(unit){
        return (lpk==0x7FFF?"--.-":getFuelConsumption(lpk))+(unit?(" "+lpkUnit):"")
                //consumptionUnit?lpk.toFixed(1):(lpk/fuelFactor).toFixed(1))+
               // (unit?(" "+lpkUnit):"")
    }
    ////////////////////////////////
    // 【0x12】智能怠速 idleInfoNotify
    ////////////////////////////////
    property int idleTimeMode: 0
    property int idleUseTime: 0
    property int idleStartSavingsFuel: 0xFFFF
    property real idleResetSavingsFuel: 0xFFFF
    property int idleStartTotalTime;
    property int idleResetTotalTime;

    function getIdleUseTime(){
        return Math.floor(idleUseTime/60)+":"+Math.floor(idleUseTime%60)
    }
    function getIdleStartSavingFuel(){
        return (idleStartSavingsFuel==0xFFFF?"----":
               consumptionUnit===2?(idleStartSavingsFuel/3785.411784).toFixed(2):idleStartSavingsFuel)+
               (consumptionUnit===2?"gal":"ml")
    }
    function getIdleResetSavingsFuel(){
        return (idleResetSavingsFuel==0xFFFF?"----":
               consumptionUnit===2?(idleResetSavingsFuel/3.785411784).toFixed(1):idleResetSavingsFuel)+
               (consumptionUnit===2?"gal":"L")
    }
    function getIdleStartTotalTime(){
        return Funcs.second2String(idleStartTotalTime)
    }
    function getIdleResetTotalTime(){
        return Funcs.second2String(idleResetTotalTime)
    }
    ////////////////////////////////
    // 【0x13】定速巡航 cruiseInfoNotify
    // mGlobalId.item.cruiseDownHillSpeedState
    ////////////////////////////////
    property int cruiseState: 0
    property int cruiseSpeedSet: 0
    property int cruiseSpeedUnit: 0
    property int cruiseLimState: 0  // 默認LIM狀態
    property int cruiseDownHillSpeedState: 0
    property int cruiseSetSpeedState: 0
    property int cruiseSpeed: 0
    property int cruiseAccFollowDistacnce: 0
    property int cruiseAccFrontCarState: 0
    property int cruiseAccDistacnceColor: 0
    property int cruiseAccState: 0
    property int cruiseAccInterfaceState: 0
    property int cruiseLimSpeed: 0

    Behavior on cruiseSpeed{
        NumberAnimation{
            duration: 200
        }
    }
    Behavior on cruiseLimSpeed{
        NumberAnimation{
            duration: 200
        }
    }
    function setCruiseLimSpeed(type, step){
        cruiseLimState=0
        cruiseState=0
        cruiseAccState=0
        switch(type){
        case 0: // lim
            if(cruiseLimSpeed+step<vehicleSpeedMax && cruiseLimSpeed+step>0){
                cruiseLimSpeed+=step
                cruiseLimState=1
            }else{
                cruiseLimSpeed=0
                cruiseLimState=0
            }
            break;
        case 1: // cruise
            if(cruiseSpeed+step<vehicleSpeedMax && cruiseSpeed+step>0){
                cruiseSpeed+=step
                cruiseState=1
                cruiseSetSpeedState=1
            }else{
                cruiseSpeed=0
                cruiseState=0
                cruiseSetSpeedState=0
            }
            break
        case 2: // cruise
            cruiseAccInterfaceState=!cruiseAccInterfaceState
            break
        }
    }
    function getCruiseLimSpeed(){
        return (cruiseLimState)?
               (!cruiseLimSpeed?"---":(cruiseLimSpeed*tripFactor).toFixed(0)):
               (!cruiseSetSpeedState?"---":(cruiseSpeed*tripFactor).toFixed(0))
    }
    function getCruiseLimSpeedNumber(){
        var speed;
        if(metricSystem){
            if(cruiseLimState){
                speed=cruiseLimSpeed
            }else{
                speed=cruiseSpeed
            }
            if(vehicleSpeed320 && speed>200){
                return ((speed-200)*0.5)+200
            }else
                return cruiseLimState?cruiseLimSpeed:cruiseSpeed
        }else{
            if(cruiseLimState){
                speed=(cruiseLimSpeed*tripFactor).toFixed(0)
            }else{
                speed=(cruiseSpeed*tripFactor).toFixed(0)
            }
            if(speed>100){
                if(vehicleSpeed320 && speed>120){
                    return ((speed-120)*0.5)+220
                }else
                    return (speed-100)+200
            }else
                return speed*2
        }
    }
    function getCruiseLimSpeedColor(){
        return cruiseLimState?(cruiseLimSpeed>0?"#2dde10":"#9f9f9f"):
               (cruiseSetSpeedState?(cruiseSpeed>0?"#2dde10":"#9f9f9f"):"#9f9f9f")
    }

    ////////////////////////////////
    // 【0x14】车型设置
    ////////////////////////////////

    ////////////////////////////////
    // 【0x15】水温 waterInfoNotify
    // mGlobalId.item.getWaterTemp
    ////////////////////////////////
    property int waterTemp: 0xFF
    property int waterTempPercentage: 0
    property int waterLevel: 0
    // mGlobalId.item.getWaterTemp
    function isWaterTempVisible(){
        return waterTemp!=0xFE
    }
    function getWaterTemp(unit){
        return (waterTemp===0xFF || waterTemp===0xFE?"---":
               (waterTemp===0xFC?"E":temperatureUnit?waterTemp:c2f(waterTemp, 0)))+
               (unit?" "+outSideTempUnit:"")
    }
    function getWaterTempColor(){
        return waterLevel===2?"red":waterLevel===1?"orange":"white"
    }

    Timer{
        interval: 500
        running: autoRun
        repeat: true
        onTriggered: {
            waterTempPercentage=Funcs.getRndInteger(0, 100)
            waterTemp=waterTempPercentage*1.2
            if(waterTempPercentage<70)
                waterLevel=0
            else
                waterLevel=2
        }
    }
    ////////////////////////////////
    // 【0x17】警告音播报
    ////////////////////////////////

    ////////////////////////////////
    // 【0x18】仪表背光 brightInfoNotify
    // mGlobalId.item.lightBrightness
    ////////////////////////////////
    property int brightness: 0
    property int brightnessMin: 110
    property int brightnessMax: 250
    property int brightMode: 0 //  0: light, 1, dark,
    property int brightSetMode: 0  // 0: light, 1: dark, 2: auto
    property int lightBrightness: 200
    property int darkBrightness: 40
    property int ill: 0            // widthLamp 連動
    property color fontColor: ill?"#dcdcdc":"white"
    Behavior on lightBrightness{
        NumberAnimation{
            duration: 50
        }
    }
    Behavior on darkBrightness{
        NumberAnimation{
            duration: 50
        }
    }

    // mTranslationId.item.mBrightnessMin
    // mTranslationId.item.mBrightnessMax
    function getBrightnessLevel(dark){
        var brightness=Math.floor(dark?darkBrightness:lightBrightness)
        var level=Math.floor(brightness/25) // 0~10, 10 level, 250 Max
        return level
    }
    // 10~100% 不要有低於10%的
    function setBrightness(dark, up){
        var level=getBrightnessLevel(dark)
        if(up){
            if(level<10)
                level++
            else
                level=1
        }else{
            if(level>1)
                level--
            else
                level=10
        }
        var bright=Math.floor((level)*10*250/100)
        return bright
    }
    ////////////////////////////////
    // 【0x20】方向盘按键 swcInfoNotify
    ////////////////////////////////
    property int swcKey: 0
    property int swcState: 0
    property int swcStep: 0         // 滚轮时为步进值
    property int swcChanged: 0
    onSwcChangedChanged: {
        switch(swcKey){
        case swcNext:
            switch(swcState){
            case 0: //release
                mLinkEventId.item.key(linkKeyRight, 0)
                break;
            case 1: // pressed
                break;
            case 2: // hold
                break;
            }
            break;
        case swcPrev:
            switch(swcState){
            case 0: //release
                mLinkEventId.item.key(linkKeyLeft, 0)
                break;
            case 1: // pressed
                break;
            case 2: // hold
                break;
            }
            break;
        case swcMode:
            switch(swcState){
            case 0: //release
                mLinkEventId.item.key(linkKeyHome, 0)
                break;
            case 1: // pressed
                break;
            case 2: // hold
                mLinkEventId.item.key(linkKeyBack, 0)
                break;
            }
            break;
        case swcNavi:
            switch(swcState){
            case 0: //release
                if(!map)
                    map=1
                break;
            case 1: // pressed
                break;
            case 2: // hold
                mLinkEventId.item.key(linkKeyMap, 0)
                break;
            }
            break;
        case swcSpeech:
            switch(swcState){
            case 0: //release
                mLinkEventId.item.key(linkKeySpeech, 0)
                break;
            case 1: // pressed
                break;
            case 2: // hold
                break;
            }
            break;
        case swcStyle:
            switch(swcState){
            case 0: //release
                if(dashboard<dashboardNum-1)
                    dashboard++
                else
                    dashboard=0
                break;
            case 1: // pressed
                break;
            case 2: // hold
                break;
            }
            break;
        }
    }
    property int swcNone: 0
    property int swcMode: 1
    property int swcHome: 2
    property int swcBack: 3
    property int swcNext: 4
    property int swcPrev: 5
    property int swcVolup: 6
    property int swcVoldn: 7
    property int swcMute: 8
    property int swcPlayPause: 9
    property int swcAnswer: 10
    property int swcReject: 11
    property int swcPower: 12
    property int swcNavi: 13
    property int swcBacklight: 14
    property int swcSpeech: 15
    property int swcTrip: 16
    property int swcDash: 17
    property int swcTerrain: 18
    property int swcUp: 19
    property int swcDown: 20
    property int swcLeft: 21
    property int swcRight: 22
    property int swcEnter: 23
    property int swcStyle: 24
    property int swcFuncs: 25
    property int swcModes: 26
    property int swcBrightUp: 27
    property int swcBrightDn: 28
    property int swcSingleUp: 29
    property int swcSingleDn: 30
    ////////////////////////////////
    // 【0x22】雷达信息 radarInfoNotify
    // mGlobalId.item.getRearRadarInfo
    ////////////////////////////////
    property int radarEnabled: 0
    onRadarEnabledChanged: {
        mRadarTimerId.restart()
    }
    // 如果雷達沒有數據，800ms後關閉彈窗
    Timer{
        id: mRadarTimerId
        interval: 1000
        running: mGlobalId.item.radarEnabled
        onTriggered: {
            mGlobalId.item.radarEnabled=0
            //console.log("xxxxxxxxxxx")
        }
    }

    property int radarFrontInfo: 0

    property int radarFrontLeft: 0x3F
    property int radarFrontLeftMiddle: 0x3F
    property int radarFrontCenter: 0x3F
    property int radarFrontRightMiddle: 0x3F
    property int radarFrontRight: 0x3F

    property int radarFrontLeftLevel: 0
    property int radarFrontLeftMiddleLevel: 0
    property int radarFrontCenterLevel: 0
    property int radarFrontRightMiddleLevel: 0
    property int radarFrontRightLevel: 0

    property int radarRearLeft: 0x3F
    property int radarRearLeftMiddle:0x3F
    property int radarRearCenter: 0x3F
    property int radarRearRightMiddle: 0x3F
    property int radarRearRight: 0x3F

    property int radarRearLeftLevel: 0
    property int radarRearLeftMiddleLevel: 0
    property int radarRearCenterLevel: 0
    property int radarRearRightMiddleLevel: 0
    property int radarRearRightLevel: 0

    function getFrontRadarInfo(position){
        switch(position){
        case 0: // FL
            return radarFrontLeft
        case 1: // FLM
            return radarFrontLeftMiddle
        case 2: // FC
            return radarFrontCenter
        case 3: // FRM
            return radarFrontRightMiddle
        case 4: // FR
            return radarFrontRight
        }
    }
    function getRearRadarInfo(position){
        switch(position){
        case 0: // RL
            return radarRearLeft
        case 1: // RLM
            return radarRearLeftMiddle
        case 2: // RC
            return radarRearCenter
        case 3: // RRM
            return radarRearRightMiddle
        case 4: // RR
            return radarRearRight
        }
    }

    ////////////////////////////////
    // 【0x26】轨迹线 trackInfoNotify
    // mGlobalId.item.getAngle
    ////////////////////////////////
    property int angle: 0
    Behavior on angle{
        NumberAnimation{
            duration: 300
        }
    }
    function getAngle(){
        return (angle*45)/128
    }
    function getAngle1(){
        return (angle*40)/128
    }

    ////////////////////////////////
    // 【0x30】版本信息 versionNotify
    ////////////////////////////////
    property string mcuVersion: "mcu@0000"
    ////////////////////////////////
    // 【0x32】时间显示 rtcInfoNotify
    // mGlobalId.item.rtcTime
    ////////////////////////////////
    property var dateTime: [2020, 1, 10, 12, 00]
    property string rtcTime: "00:00"
    property string rtcDate: "2020-01-10"

    function getRtcTime(){
        var hour;
        var temp=rtcTime.split(":")
        hour=Number(temp[0])
        var min=Number(temp[1])
        if(!rtc24h){
            if(hour>12){
                hour=hour-12
            }
               if(hour===0)
                   hour=12
        }

        return hour+":"+Funcs.prefixInteger(min, 2)
    }

    function getAmPm(){
        var hour;
        if(!rtc24h){
            var temp=rtcTime.split(":")
            hour=Number(temp[0])
            if(hour>=12)
                return "PM"
            else
                return "AM"
        }
        return ""
    }

    ////////////////////////////////
    // 【0x33】档位状态 gearInfoNotify
    // mGlobalId.item.getGearAwd
    ////////////////////////////////
    property string gearString: "P"
    property int gear: 0
    property int gearState: 0
    property int gearNubmer: 0
    // for Trucks(Pickup/Jeep)
//        GEAR_4WD_NONE = 0,
//        GEAR_4WD_2H = 1,
//        GEAR_4WD_4H = 2,
//        GEAR_4WD_N = 3,
//        GEAR_4WD_4L = 4,
//        GEAR_4WD_4HLC = 5,
//        GEAR_4WD_4LLC = 6,
//        GEAR_4WD_AUTO = 7,
    property int gearAwd: 0
    property int gearHasAwd: 0
    property int gearAwdFlicker: 0

    function getGearAwdVisisble(){
        return gearHasAwd
    }
    function getGearAwd(){
        return gearAwd
    }
    function getGearAwdFlicker(){
        return gearAwdFlicker // 0:常亮, 1:闪烁每300ms
    }

    property var mGearTest:
    [
        " ",
        "P",
        "R",
        "N",
        "D",
        "D1",
        "M2",
        "S3",
    ]
    Timer{
        interval: 500
        running: autoRun
        repeat: true
        onTriggered: {
            gear=Funcs.getRndInteger(0, 5)
            gearNubmer=Funcs.getRndInteger(0, 4)
            angle=Funcs.getRndInteger(-30, 30)

            if(mGlobalId.item.gear<mGearTest.length-1)
                mGlobalId.item.gear++
            else
                mGlobalId.item.gear=0
            mGlobalId.item.gearString=mGlobalId.item.mGearTest[mGlobalId.item.gear]
            //mGlobalId.item.benzCBopianNumber=mGlobalId.item.gear>3?1:0
        }
    }
    ////////////////////////////////
    // 【0x34】ACC 钥匙状态 accInfoNotify
    ////////////////////////////////
    property int acc: Number(mSplashPlay)?0:1
    ////////////////////////////////
    // 【0x35】转向灯状态 turnLightInfoNotify
    // mGlobalId.item.turnLeftLight
    ////////////////////////////////
    property int turnRightLightEnabled: 0
    property int turnLeftLightEnabled: 0
    property int turnRightLight: 0
    property int turnLeftLight: 0

    Timer{
        id: mTurnLightTimerId
        interval: 300
        running: autoRun
        repeat: true
        onTriggered: {
            turnRightLight=Funcs.getRndInteger(0, 1)
            turnLeftLight=Funcs.getRndInteger(0, 1)
        }
    }
    ////////////////////////////////
    // 【0x36】保养信息 maintentInfoNotify
    // mGlobalId.item.mainTentId
    ////////////////////////////////
    property int mainTentChanged: 0
    onMainTentChangedChanged: {
        //console.log("mGlobal mainTentChanged: "+mainTentChanged)
    }
    property int mainTentId: 0
    property var mainTentState: [ 0, 0 ,0 ,0, 0, 0, 0, 0, 0, 0 ]
    property int mainTentItem: 0
    property string mainTentMsg: "下次保养，请在xxxkm后进行"
    property var mainTentMileage:
    [
        0xFFFFFF,
        0xFFFFFF,
        0xFFFFFF,
        0xFFFFFF,
        0xFFFFFF,
        0xFFFFFF,
        0xFFFFFF,
        0xFFFFFF,
        0xFFFFFF,
        0xFFFFFF,
    ]
    property var mainTentReminder:
    [
        0xFFFFFF,
        0xFFFFFF,
        0xFFFFFF,
        0xFFFFFF,
        0xFFFFFF,
        0xFFFFFF,
        0xFFFFFF,
        0xFFFFFF,
        0xFFFFFF,
        0xFFFFFF,
    ]
    property var mainTentYear:
    [
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
    ]
    property var mainTentMonth:
    [
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
    ]
    property var mainTentDay:
    [
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
    ]
    property int mainTentDuration: 0
    property int mainTentItemIndex: 0
    property int mainTentPage: 0
    property int mainTentShow: mainTentDuration>0
    property int mainTentCustomize1: 0
    property int mainTentCustomize2: 0
    onMainTentCustomize1Changed: {
        Funcs.setProperty("mainTentCustomize1", mainTentCustomize1)
    }
    onMainTentCustomize2Changed: {
        Funcs.setProperty("mainTentCustomize2", mainTentCustomize2)
    }
    // mGlobalId.item.ldaRightLaneState
    function maintentInfoHide(){
        mainTentDuration=0
    }
    // mGlobalId.item.getMaintentStateColor(id)
    function getMaintentState(id){
        var state=mainTentState[id]
        return mainTentChanged?state:state
    }
    function getMaintentStateColor(id){
        var color;
        switch(mainTentState[id])
        {
        case 1:     // apporach mileage
        case 4:     // apporach date
            color="orange"
            break
        case 2:     // expire mileage
        case 5:     // expire date
            color="red"
            break
        default:
            color="white"
        }
        return mainTentChanged?color:color
    }
    // mGlobalId.item.getMaintentReminder(id)
    function getMaintentMileage(id){
        //console.log("[getMaintentMileage id:"+id)
        var mileage=(mainTentMileage[id]===0xFFFFFF?"----":
                    (mainTentMileage[id]*tripFactor).toFixed(0))+" "+tripUnit
        return mainTentChanged?mileage:mileage
    }
    function getMaintentDate(id){
        var year=(mainTentYear[id]===0xFF || mainTentYear[id]<=0)?"----":(mainTentYear[id]+2000)
        var month=(mainTentMonth[id]<1||mainTentMonth[id]>12)?"--":(mainTentMonth[id])
        var day=(mainTentDay[id]<1||mainTentDay[id]>31)?"--":(mainTentDay[id])
        var date=metricSystem?(year+"/"+month+"/"+day):(month+"/"+day+"/"+year)
        return mainTentChanged?date:date
    }
    function getMaintentReminder(id){
        var reminder=(mainTentReminder[id]===0xFFFFFF?"----":
                     (mainTentReminder[id]*tripFactor).toFixed(0))+" "+tripUnit
        return mainTentChanged?reminder:reminder
    }
    function getMaintentMileageNum(id, index){
        var temp=(mainTentMileage[id]*tripFactor).toFixed(0)
//        console.log("[getMaintentMileageNum id:"+id+"]")
//        console.log("[getMaintentMileageNum temp:"+temp+"]")
        switch(index){
        case 0:
            return mainTentMileage[id]===0xFFFFFF?0:temp/10000
        case 1:
            return mainTentMileage[id]===0xFFFFFF?0:temp%10000/1000
        case 2:
            return mainTentMileage[id]===0xFFFFFF?0:temp%10000%1000/100
        case 3:
            return mainTentMileage[id]===0xFFFFFF?0:temp%10000%1000%100/10
        case 4:
            return mainTentMileage[id]===0xFFFFFF?0:temp%10
        }
    }

    ////////////////////////////////
    // 【0x37】超速预警 overSpeedWarningNotify
    // mGlobalId.item.getOverSpeedWaningSpeed
    ////////////////////////////////
    property int overSpeedWarningEnabled: 0
    property int overSpeedWarningState: 0
    property int overSpeedWarningSpeed: 0
    onOverSpeedWarningEnabledChanged: {
        Funcs.setProperty("overSpeedWarningEnabled", overSpeedWarningEnabled)
    }
    function getOverSpeedNum(index){
        var temp=(overSpeedWarningSpeed*tripFactor).toFixed(0)
        switch(index){
        case 0:
            return temp/100
        case 1:
            return temp%100/10
        case 2:
            return temp%10
        }
    }
    function getOverSpeedWaningSpeed(unit){
        return (overSpeedWarningSpeed===0?"---":(overSpeedWarningSpeed*tripFactor).toFixed(0))+
               (!unit?"":" "+vehicleSpeedUnit)
    }

    ////////////////////////////////
    // 【0x38】其他资讯 vehicleInfoNotify
    ////////////////////////////////
    property int temperatureUnit: 1  // 0: "℉", 1: "℃"
    property int oilPressurePercentage: 0
    property string oilPressureUnit: "kPa"
    property real batterVoltage: 0xFF
    property int gearBoxTemp: 0xFF
    property int gearBoxTempPercentage: 0xFF
    property real outSideTemp: 0xFE
    property real inSideTemp: 0
    property string outSideTempUnit: temperatureUnit?"℃":"℉"
    property int oilTempPercentage: 0
    property int oilTemp: 0xFF
    property int diffOilTemp: 0xFF

    onTemperatureUnitChanged: {
        Funcs.setProperty("temperatureUnit", temperatureUnit)
    }
    ///////////////////////////////
    // get Oil function
    // mGlobalId.item.getOilTemp
    ///////////////////////////////
    function isOilPressureVisible(){
        return oilPressurePercentage!=0xFF
    }
    function getPressurePercentage(){
        return oilPressurePercentage+"%"
    }
    function isBatteryVoltageVisible(){
        return batterVoltage!=0xFE
    }
    function getBatteryVoltage(){
        return (batterVoltage===0xFF?"--.-":batterVoltage.toFixed(1))+" v"
    }
    function getBatteryVoltageColor(){
        if(batterVoltage>16 || batterVoltage<11.9 || batterVoltage===0xFF)
            return "red"
        else
            return "white"
    }
    function isGearBoxTempPercentageVisible(){
        return gearBoxTempPercentage!=0xFF
    }

    function getGearBoxTemp(unit){
        return (gearBoxTemp===0xFF?"--.-":temperatureUnit?gearBoxTemp:c2f(gearBoxTemp, 0))+
               (unit?" "+outSideTempUnit:"")
    }
    function isOutSideTempVisible(){
        return outSideTemp!=0xFF
    }
    function getOutSideTemp(unit){
        return (outSideTemp===0xFE || outSideTemp===0xFF?"---":
               (outSideTemp===0xFC?"E":(outSideTemp>0?"":"")+
               (temperatureUnit?outSideTemp.toFixed(0):c2f(outSideTemp, 0))))+
               (unit?" "+outSideTempUnit:"")
    }
    function getOutSideTempColor(){
        return "white"
    }
    function isOilTempVisible(){
        return oilTemp!=0xFE
    }
    function isOilTempPercentageVisible(){
        return oilTempPercentage!=0xFF
    }
    function getOilTempPercentage(){
        return oilTempPercentage+" %"
    }
    function getOilTemp(unit){
        return (oilTemp===0xFF || oilTemp===0xFE?"---":(temperatureUnit?oilTemp:
               mGlobalId.item.c2f(oilTemp, 0)))+
               (unit?" "+outSideTempUnit:"")
    }
    function getOilTempColor(){
        return oilTemp>70?"white":"#a0ccf5"
    }
    ///////////////////////////////
    // get Diff Oil function
    ///////////////////////////////
    function isDiffOilTempVisible(){
        return diffOilTemp!=0xFE
    }
    function getDiffOilTemp(unit){
        return (diffOilTemp===0xFF || diffOilTemp===0xFE?"---":(temperatureUnit?diffOilTemp:
               mGlobalId.item.c2f(diffOilTemp, 0)))+
               (unit?" "+outSideTempUnit:"")
    }
    function getDiffOilTempColor(){
        return diffOilTemp>49?"white":"#a0ccf5"
    }
    // ℃ -> ℉
    function c2f(temp, f){
        return (temp*1.8+32).toFixed(f)
    }

    Timer{
        interval: 500
        running: autoRun
        repeat: true
        onTriggered: {
            if(temperatureUnit)
                outSideTemp=(Funcs.getRndInteger(-200, 500)/10).toFixed(1)
            else
                outSideTemp=Funcs.getRndInteger(0, 150)
            oilTempPercentage=Funcs.getRndInteger(0, 100)
        }
    }
    ////////////////////////////////
    // 【0x39】单位状态
    ////////////////////////////////

    ////////////////////////////////
    // 【0xEE】HUD 状态信息
    ////////////////////////////////

    ////////////////////////////////
    // 【0xFD】MCU Shell Cmd 功能配置
    // mGlobalId.item.shellInfoHide
    ////////////////////////////////
    property int shellInfoDuration: 0
    property string shellInfo: ""

    property int shellCmdCounts: 0
    property int shellCmdShow: 0

    function shellCmdHide(){
        shellCmdShow=0
    }
    function shellInfoHide(){
        shellInfoDuration=0
    }

    ////////////////////////////////
    // 【0xFE】MCU 调试端口
    ////////////////////////////////

    ////////////////////////////////
    // 【0xFF】协议升级
    // mGlobalId.item.driverModeAnimationEnabled
    ////////////////////////////////
    property int mcuUpdateTop: (acc && splashEnd) && (coldIap || updateMcuCounts)
    property int coldIap: 0
    property int mcuUpdatePercentage: 0
    property int mcuSameFileUpdate: 0
    property int systemUpdatePercentage: 0
    property int btUpdatePercentage: 0
    property int btSameFileUpdate: 0

    property int updateSrotage: 0
    property int updateStatus: -1
    property int updateMcuCounts: 0
    property int updateBtCounts: 0
    property int updateSystemCounts: 0
    property int updateDoing: 0

    /////////////////////////
    // Image for check
    /////////////////////////
    property int mediaImageEnabled: 0
    property int mediaImageCounts: 0
    Behavior on mcuUpdatePercentage{
        NumberAnimation{
            duration: 50
        }
    }
    function updateMcuHide(){
        updateMcuCounts=0
    }
    function getMcuUpdateProcess(){
        return mGlobalId.item.updateStatus?(mcuUpdatePercentage+"%"):"--%"
    }

    ////////////////////////////////
    // 【0x16】原车高配功能
    ////////////////////////////////
    //-------------------------------
    // FUNCID【0x00】蠕动模式 crawlInfoNotify
    //-------------------------------
    property int crawlLevel: 0
    //-------------------------------
    // FUNCID【0x01】并线辅助 bsmInfoNotify
    //-------------------------------
    property int bsmOn: 0
    property int bsmSensitivity: 0
    property int bsmBright: 0
    //-------------------------------
    // FUNCID【0x02】预碰撞安全系统 pcsInfoNotify
    //-------------------------------
    property int pcsOn: 0
    property int pcsSensitivity: 0
    //-------------------------------
    // FUNCID【0x03】地形模式 roadModeInfoNotify
    //-------------------------------
    property int roadMode: 0
//    onRoadModeChanged: {
//         switch(roadMode){
//         case 0:
//             break;
//         case 1: // 泥濘
//         case 2: //碎石
//             dashboard=2
//             break;
//         case 3: // 凹凸
//         case 4: // 山地
//         case 5: // 岩石
//             dashboard=4
//             break
//         case 6: // 自動路面
//         case 7: // 公路
//             dashboard=1
//             break;
//         case 8: // 雪地
//             dashboard=3
//             break;
//         }
//     }
    //-------------------------------
    // FUNCID【0x04】驾驶模式 driverModeInfoNotify
    //-------------------------------
    property var mDriverModeAnimationEnabled:
    [
        0,  // ram
        0,  // ford
        0,  // padao
        0,  // pratol
        0,  // landcruiser
        1,  //mGlobalHeight==860?1:0,  // lc76
        1,  // silverado
        Number(mNoLogo)?0:1,  // everest
        0,  // yukon
        1,  // gmc
    ]

    property int driverModeAnimationEnabled: mDriverModeAnimationEnabled[Number(mTrucksModel)]
    property int driverModeAnimationState: 1    // 0: stop, 1: playing
    property int driverMode: 0
    property int offRoadMode: 0
    property int offRoadModeCounts: 0
    onDriverModeChanged: {
        Funcs.setProperty("driverMode", driverMode)
    }
    onOffRoadModeChanged: {
        Funcs.setProperty("offRoadMode", offRoadMode)
    }
    property var driverModeItems:
    [
        "",
        "STANDARD",
        "SNOW",
        "SPORT",
        "PERSONAL",
        "COMFORT",
        "ECO PRO",
        "TRACTION",
        "DSC OFF",
        "SPORT+",
        "COMFORT+",
        "ECO PRO",
    ]
    property var driverModeColor:
    [
        "white",
        "white",
        "white",
        "red",    // 3 BWM SPORT
        "white",
        "yellow", // 5 BWM COMFORT
        "#083cf3",
        "white",    // 7 BMW TRACTION
        "yellow",    // 8 BMW DSC OFF
        "red",       // 9 BMW SPORT+
        "yellow", // 10 BMW COMFORT+
        "#083cf3",    // 11 BMW ECO PRO
    ]

    function getDriveModeItem(){
        return driverModeItems[driverMode]
    }
    function getDriveModeColor(){
        return driverModeColor[driverMode]
    }

    Timer{
        running: autoRun
        interval: 1000
        repeat: true
        onTriggered: {
            driverMode=Funcs.getRndInteger(3, 5)
        }
    }

    //-------------------------------
    // FUNCID【0x05】四驱能量显示4WD fourWDInfoNotify
    //-------------------------------
    property int aWDChanged: 0
    property var aWDState: [ 0, 0, 0, 0, 0 ] // frontLeft, frontRight
    //-------------------------------
    // FUNCID【0x06】尾门开度调整 pbdInfoNotify
    //-------------------------------
    property int pbdSystem: 0
    property int pbdKickSensor: 0
    property int pbdVolume: 0
    property int pbdAngle: 0
    //-------------------------------
    // FUNCID【0x07】后排空调显示 rearHvacInfoNotify
    //-------------------------------
    property int rearHvacMode: 0
    property int rearHvacFanSpeed: 0
    property int rearHvacAuto: 0
    property int rearHvacAc: 0
    property real rearHvacTemp: 0.0
    property real rearHvacTempF: 0.0
    //-------------------------------
    // FUNCID【0x08】辅助驾驶
    //-------------------------------

    //-------------------------------
    // FUNCID【0x09】车门蜂鸣器设置
    //-------------------------------

    //-------------------------------
    // FUNCID【0x0A】后车窗状态
    //-------------------------------
    property int rearLeftWindow: 0
    property int rearRightWindow: 0
    //-------------------------------
    // FUNCID【0x0B】路标辨识辅助系统
    //-------------------------------

    //-------------------------------
    // FUNCID【0x0C】TMN前车启动提醒
    //-------------------------------

    //-------------------------------
    // FUNCID【0x0D】底盘升降功能 chassisInfoNotify
    //-------------------------------
    property int chassisLiftState: 0 // 0: Normal, 1: Hi, 2: Lo
    property int chassisLiftUp: 0 // 0: hide, 1: still, 2: Flicker
    property int chassisLiftDown: 0 // 0: hide, 1: still, 2: Flicker
    property bool chassisLiftDoing: false
    property int chassisLiftEnable: 0
    //-------------------------------
    // FUNCID【0x0E】LDA 车道偏离 mGlobalId.item.ldaRightLaneFlicker
    //-------------------------------
    property int ldaEnable: ldaRightLaneState | ldaRightLaneState
    property int ldaRightLaneState: 0
    property int ldaRightLaneFlicker: 0
    property int ldaLeftLaneState: 0
    property int ldaLeftLaneFlicker: 0
    property int ldaRightArrow: 0
    property int ldaLeftArrow: 0
    property int ldaVehicleFlicker: 0
    property int ldaVehiclePosition: 0
    //-------------------------------
    // FUNCID【0x0F】奔驰照明设置 benzLampInfoNotify
    //-------------------------------
    property int benzSurroundLighting: 0
    property int benzInteriorLightingDelay: 0
    //-------------------------------
    // FUNCID【0x10】奔驰车辆设置 benzSetupInfoNotify
    //-------------------------------
    property int benzDoorAutoLock: 0
    property int benzDoorLockSound: 0
    property int benzDoorRainfallSensor: 0
    property int benzDoorSpeedLimited: 0
    //-------------------------------
    // FUNCID【0x40】【0x88】Trucks trucksInfoNotify
    //-------------------------------
    property var trucksSetupInfo:
    [
        0, //property int trucksHillStartAssist;          // 0 坡道輔助系統
        0, //property int trucksHeadLampsWithWipers;      // 1 前大燈用刮水器
        0, //property int trucksRemoteUnlockSequence;     // 2 遙控解鎖順序
        0, //property int trucksAutoUnlockOnExit;         // 3 下車自動解鎖車門
        0, //property int trucksFlashLampWithLock;        // 4 鎖車閃爍車燈
        0, //property int trucksIlluminApproach;          // 5 用鑰匙打開前大燈
        0, //property int trucksKeyOffPowerDelay;         // 6 鑰匙關閉電源延時
        0, //property int trucksLampOffDelay;             // 7 前大燈關閉延時
        //        // for RAM
        0, //property int trucksParkingAssistSystem;      // 8 泊車輔助系統
        0, //property int trucksAutoLockDoors;            // 9 自動車門上鎖
        0, //property int trucksAutoUnlockDoors;          // 10 自動解鎖車門
        0, //property int trucksRkeLinkedToMemory;        // 11 與記憶連接的遙控鑰匙
        0, //property int trucksRemoteStartComfortSys;    // 12 遠程啟動舒適系統
        0, //property int trucksHornWithRemoteStart;      // 13 啟動鳴笛
        0, //property int trucksHornWithRemoteLock;       // 14 鎖車鳴笛
        0, //property int trucksEasyExitSeat;             // 15 電動座椅輕鬆離開
        0, //property int trucksTiltMirrorInReverse;      // 16 倒車反轉後視鏡
        0, //property int trucksTrailerBreakType;         // 17 拖車制動類型
        1, //property int trucksCompassVariance;          // 18 指南針方差, 1-15
        0, //unsigned char Trailer Away;                  // 19 拖車離開
        1, //unsigned char Unit;                          // 20 單位  0: ENG, 1: METRIC
        10, //unsigned char OilLifeSerice;                // 21 Oil Life Service Duration
    ]

    property int trucksSetupInfoChanged: 0

    function getTruckOilLifeLevel(){
        switch(Number(mTrucksModel)){
        case 1: // ford f150
            switch(vehicleModel){
            case 0: // 2009-2010 F150
                return trucksSetupInfoChanged?(trucksSetupInfo[21]/10):(trucksSetupInfo[21]/10)
            case 1: // 2011-2014 F150
                return fordSetupInfoChanged?(fordSetupInfo[59]/10):(fordSetupInfo[59]/10)
            }
            break;
        case 7: // everest
        case 8: // yukon
            return fordSetupInfoChanged?(fordSetupInfo[59]/10):(fordSetupInfo[59]/10)
        default:
            return trucksSetupInfoChanged?(trucksSetupInfo[21]/10):(trucksSetupInfo[21]/10)
        }
    }

    property int trucksShiftState: 0
    property int trucksShiftGear: 0

    property int trucksTrailerDistance: 0
    property real trucksTrailerGain: 0.0
    property int trucksOilLifePercentage: 0
    property int trucksOilLifeTrip: 0
    property int trucksFrontRadarState: 0
    property int trucksRearRadarState: 0
    property int trucksOilPressure: 0           // bar


    function gettrucksOilPressure(){
        return trucksOilPressure+" bar"
    }
    function getTrucksTrailerDistance(){
        return (trucksTrailerDistance==0xFFFFFFFF?"----":Math.floor(trucksTrailerDistance*tripFactor/1000))+" "+tripUnit
    }
//    function getTrucksTrailerGain(){
//        return trucksTrailerGain==0xFF?"--.-":(trucksTrailerGain/10).toFixed(1)
//    }

    //-------------------------------
    // FUNCID【0x47】Off Road数据（11~14年福特F150）
    //-------------------------------
    property int truckOffRoadDiffLock: 0      // 差速锁
    property int truckOffRoadESP: 0           // ESP OFF
    property int truckOffRoadHDC: 0           // 下坡辅助 Hill Descent Control
    property int truckOffRoadMode: 0          // OFF ROAD MODE
    property int truckOffRoadCamera: 0        // 越野摄像头

    //-------------------------------
    // FUNCID【0x49】MyKey 数据（福特）
    //-------------------------------
    property int myKeyDistanceState: 0
    property int myKeyType: 0
    property int myKeyNums: 0
    property int myKeyKeys: 0
    property int myKeyDistance: 0xFFFFFF
    property int myKeyShow: 0
    property int myKeyText: 0

    function getMyKeys(){
        return "MyKey: "+myKeyNums
    }
    function getMyKeyDistance(){
        return (myKeyDistance===0xFFFFFF?"----.-":
               ((myKeyDistance/10*tripFactor).toFixed(1)))+" MyKey "+tripUnit
    }
    function isMyKeyDistanceVisible(){
        return myKeyDistanceState
    }
    function getMyKeyTypeNum(){
        return mMyKeyType[myKeyType]+": "+myKeyKeys
    }
    function getMyKeyNotify(){
        return mMyKeyNotify[myKeyText]
    }

    property var mMyKeyType:
    [
        mUserKey[language],
        mAdminKey[language],
    ]
    property var mMyKeyNotify:
    [
        mMyKeyNotify0[language],
        mMyKeyNotify1[language],
        mMyKeyNotify2[language],
        mMyKeyNotify3[language],
        mMyKeyNotify4[language],
        mMyKeyNotify5[language],
    ]

    property var mAdminKey: [
        "管理钥匙",                 // 简体中文
        "Admin Key",               // 英文
        "管理キー",                // 日文
        "管理鑰匙",                 // 繁體中文
        "Ключ администратора",     // 俄文
        "مفتاح الإدارة",           // 阿拉伯文
        "Llave de administrador",  // 西班牙文
        "Administratorenschlüssel", // 德文
        "Yönetici anahtarı",       // 土耳其文
        "관리 키",                  // 韩文
        "Clé d'administration",    // 法文
        "Chiave amministratore",   // 意大利文
        "Chave do administrador",  // 葡萄牙文（巴西）
        "व्यवस्थापक कुंजी",         // 印地文
        "กุญแจผู้ดูแลระบบ",         // 泰文
        "Khóa quản trị",            // 越南文
        "Kunci pentadbir",         // 马来西亚文
        "Kunci admin",             // 印尼文
        "Администраторски ключ",   // 保加利亞文
        "Klucz administratora",    // 波蘭文
        "Cheia de administrator",  // 羅馬尼亞文
        "Beheerderssleutel",       // 荷蘭文
        "کلید مدیریت",             // 波斯語
        "Správcovský klíč"         // 捷克語
    ]
    property var mUserKey: [
        "普通钥匙",                 // 简体中文
        "User Key",                // 英文
        "ユーザーキー",            // 日文
        "普通鑰匙",                 // 繁體中文
        "Ключ пользователя",       // 俄文
        "مفتاح المستخدم",           // 阿拉伯文
        "Llave de usuario",        // 西班牙文
        "Benutzerschlüssel",       // 德文
        "Kullanıcı anahtarı",      // 土耳其文
        "사용자 키",                // 韩文
        "Clé utilisateur",         // 法文
        "Chiave utente",           // 意大利文
        "Chave do usuário",        // 葡萄牙文（巴西）
        "उपयोगकर्ता कुंजी",         // 印地文
        "กุญแจผู้ใช้",             // 泰文
        "Khóa người dùng",         // 越南文
        "Kunci pengguna",          // 马来西亚文
        "Kunci pengguna",          // 印尼文
        "Потребителски ключ",       // 保加利亞文
        "Klucz użytkownika",       // 波蘭文
        "Cheia utilizatorului",    // 羅馬尼亞文
        "Gebruikerssleutel",       // 荷蘭文
        "کلید کاربر",              // 波斯語
        "Uživatelský klíč"         // 捷克語
    ]

    property var mMyKeyNotify0: [
        "槽中钥匙已经是MyKey",                          // 简体中文
        "The inserted key is already set as MyKey",     // 英文
        "挿入されたキーはすでにMyKeyです",               // 日文
        "槽中鑰匙已是MyKey",                            // 繁體中文
        "Вставленный ключ уже является MyKey",           // 俄文
        "المفتاح المُدرج هو بالفعل MyKey",               // 阿拉伯文
        "La llave insertada ya está configurada como MyKey", // 西班牙文
        "Der eingelegte Schlüssel ist bereits als MyKey definiert", // 德文
        "Takılan anahtar zaten MyKey olarak ayarlanmış", // 土耳其文
        "삽입된 키는 이미 MyKey로 설정되어 있습니다",      // 韓文
        "La clé insérée est déjà définie comme MyKey",    // 法文
        "La chiave inserita è già impostata come MyKey",  // 義大利文
        "A chave inserida já está definida como MyKey",   // 葡萄牙文（巴西）
        "डाली गई चाबी पहले से ही MyKey है",               // 印地文
        "กุญแจที่ใส่ไว้ได้รับการตั้งเป็น MyKey แล้ว",     // 泰文
        "Chìa khóa đã được thiết lập là MyKey",           // 越南文
        "Kunci yang dimasukkan sudah menjadi MyKey",      // 馬來西亞文
        "Kunci yang dimasukkan sudah diatur sebagai MyKey", // 印尼文
        "Поставеният ключ вече е зададен като MyKey",     // 保加利亞文
        "Włożony klucz jest już ustawiony jako MyKey",    // 波蘭文
        "Cheia introdusă este deja setată ca MyKey",      // 羅馬尼亞文
        "De ingevoerde sleutel is al ingesteld als MyKey", // 荷蘭文
        "کلید واردشده قبلاً به‌عنوان MyKey تنظیم شده‌است", // 波斯語
        "Vložený klíč je již nastaven jako MyKey"         // 捷克語
    ]
    property var mMyKeyNotify1: [
        "这把钥匙的MyKey功能将在下次启动时生效",             // 简体中文
        "MyKey function of this key will be activated on next start", // 英文
        "このキーのMyKey機能は次回の始動時に有効になります",     // 日文
        "此鑰匙的 MyKey 功能將於下次啟動時生效",               // 繁體中文
        "Функция MyKey этого ключа активируется при следующем запуске", // 俄文
        "وظيفة MyKey لهذه المفتاح ستصبح فعالة في التشغيل التالي",     // 阿拉伯文
        "La función MyKey de esta llave se activará al próximo arranque", // 西班牙文
        "Die MyKey-Funktion dieses Schlüssels wird beim nächsten Start aktiviert", // 德文
        "Bu anahtarın MyKey işlevi bir sonraki çalıştırmada etkinleşecektir", // 土耳其文
        "이 키의 MyKey 기능은 다음 시동 시 활성화됩니다",         // 韩文
        "La fonction MyKey de cette clé sera activée au prochain démarrage", // 法文
        "La funzione MyKey di questa chiave sarà attiva al prossimo avvio", // 意大利文
        "A função MyKey desta chave será ativada na próxima partida", // 葡萄牙文（巴西）
        "इस चाबी का MyKey फ़ंक्शन अगली बार स्टार्ट पर सक्रिय होगा", // 印地文
        "ฟังก์ชัน MyKey ของกุญแจนี้จะเริ่มทำงานในการสตาร์ทครั้งถัดไป", // 泰文
        "Chức năng MyKey của chìa khóa này sẽ hoạt động khi khởi động tiếp theo", // 越南文
        "Fungsi MyKey untuk kunci ini akan diaktifkan pada permulaan seterusnya", // 马来西亚文
        "Fungsi MyKey untuk kunci ini akan aktif saat start berikutnya", // 印尼文
        "Функцията MyKey на този ключ ще се активира при следващото стартиране", // 保加利亞文
        "Funkcja MyKey tego klucza zostanie aktywowana przy następnym uruchomieniu", // 波蘭文
        "Funcția MyKey a acestei chei va fi activată la următoarea pornire", // 羅馬尼亞文
        "De MyKey-functie van deze sleutel wordt geactiveerd bij de volgende start", // 荷蘭文
        "عملکرد MyKey این کلید در راه‌اندازی بعدی فعال می‌شود",  // 波斯語
        "Funkce MyKey tohoto klíče bude aktivována při příštím startu" // 捷克語
    ]
    property var mMyKeyNotify2: [
        "所有MyKey已清除",                       // 简体中文
        "All MyKeys have been cleared",         // 英文
        "すべてのMyKeyが消去されました",        // 日文
        "所有 MyKey 已清除",                    // 繁體中文
        "Все MyKey были удалены",               // 俄文
        "تم مسح جميع مفاتيح MyKey",             // 阿拉伯文
        "Todos los MyKey han sido borrados",    // 西班牙文
        "Alle MyKeys wurden gelöscht",          // 德文
        "Tüm MyKey'ler silindi",                // 土耳其文
        "모든 MyKey가 삭제되었습니다",           // 韩文
        "Tous les MyKey ont été effacés",       // 法文
        "Tutte le MyKey sono state cancellate", // 意大利文
        "Todos os MyKey foram apagados",        // 葡萄牙文（巴西）
        "सभी MyKey हटा दिए गए हैं",              // 印地文
        "ลบ MyKey ทั้งหมดแล้ว",                 // 泰文
        "Tất cả MyKey đã được xóa",             // 越南文
        "Semua MyKey telah dipadamkan",         // 马来西亚文
        "Semua MyKey telah dihapus",            // 印尼文
        "Всички MyKey бяха изтрити",            // 保加利亞文
        "Wszystkie MyKey zostały usunięte",     // 波蘭文
        "Toate MyKey au fost șterse",           // 羅馬尼亞文
        "Alle MyKeys zijn gewist",              // 荷蘭文
        "تمام MyKey پاک شده‌اند",               // 波斯語
        "Všechny MyKey byly vymazány"           // 捷克語
    ]
    property var mMyKeyNotify3: [
        "请将钥匙插入备用槽中",                    // 简体中文
        "Please insert the key into the backup slot", // 英文
        "キーを予備スロットに挿入してください",      // 日文
        "請將鑰匙插入備用插槽中",                   // 繁體中文
        "Пожалуйста, вставьте ключ в резервный слот", // 俄文
        "يرجى إدخال المفتاح في الفتحة الاحتياطية",    // 阿拉伯文
        "Inserte la llave en la ranura de respaldo", // 西班牙文
        "Bitte stecken Sie den Schlüssel in den Ersatzschacht", // 德文
        "Lütfen anahtarı yedek yuvaya takın",        // 土耳其文
        "예비 슬롯에 키를 삽입하세요",                // 韩文
        "Veuillez insérer la clé dans la fente de secours", // 法文
        "Inserisci la chiave nello slot di riserva", // 意大利文
        "Insira a chave no slot de backup",          // 葡萄牙文（巴西）
        "कृपया चाबी को बैकअप स्लॉट में डालें",        // 印地文
        "กรุณาใส่กุญแจลงในช่องสำรอง",                // 泰文
        "Vui lòng cắm chìa vào khe dự phòng",         // 越南文
        "Sila masukkan kunci ke slot sandaran",       // 马来西亚文
        "Silakan masukkan kunci ke slot cadangan",    // 印尼文
        "Моля, поставете ключа в резервния слот",      // 保加利亞文
        "Włóż klucz do gniazda zapasowego",           // 波蘭文
        "Introduceți cheia în slotul de rezervă",     // 羅馬尼亞文
        "Steek de sleutel in het reserveslot",        // 荷蘭文
        "لطفاً کلید را در شیار پشتیبان وارد کنید",     // 波斯語
        "Vložte klíč do záložního slotu"             // 捷克語
    ]
    property var mMyKeyNotify4: [
        "按住OK键创建MyKey",                          // 简体中文
        "Hold OK to create MyKey",                   // 英文
        "OKキーを長押ししてMyKeyを作成",               // 日文
        "按住OK鍵建立MyKey",                          // 繁體中文
        "Удерживайте OK для создания MyKey",          // 俄文
        "اضغط باستمرار على OK لإنشاء MyKey",           // 阿拉伯文
        "Mantenga presionado OK para crear MyKey",    // 西班牙文
        "Halten Sie OK gedrückt, um MyKey zu erstellen", // 德文
        "MyKey oluşturmak için OK tuşunu basılı tutun", // 土耳其文
        "MyKey 생성을 위해 OK 버튼을 길게 누르세요",      // 韓文
        "Maintenez OK enfoncé pour créer MyKey",       // 法文
        "Tieni premuto OK per creare MyKey",           // 義大利文
        "Mantenha OK pressionado para criar o MyKey",  // 葡萄牙文（巴西）
        "MyKey बनाने के लिए OK को दबाए रखें",            // 印地文
        "กดปุ่ม OK ค้างไว้เพื่อสร้าง MyKey",           // 泰文
        "Nhấn giữ OK để tạo MyKey",                    // 越南文
        "Tahan butang OK untuk cipta MyKey",           // 馬來西亞文
        "Tekan dan tahan OK untuk membuat MyKey",      // 印尼文
        "Задръжте OK, за да създадете MyKey",          // 保加利亞文
        "Przytrzymaj OK, aby utworzyć MyKey",          // 波蘭文
        "Țineți apăsat pe OK pentru a crea MyKey",     // 羅馬尼亞文
        "Houd OK ingedrukt om MyKey te maken",         // 荷蘭文
        "برای ایجاد MyKey دکمه OK را نگه دارید",        // 波斯語
        "Podržte OK pro vytvoření MyKey"              // 捷克語
    ]
    property var mMyKeyNotify5: [
        "按住OK键清除所有MyKeys",                      // 简体中文
        "Hold OK to clear all MyKeys",                // 英文
        "OKキーを長押ししてすべてのMyKeyを削除",        // 日文
        "按住OK鍵清除所有MyKeys",                      // 繁體中文
        "Удерживайте OK для удаления всех MyKey",      // 俄文
        "اضغط باستمرار على OK لمسح جميع مفاتيح MyKey",  // 阿拉伯文
        "Mantenga presionado OK para borrar todos los MyKeys", // 西班牙文
        "Halten Sie OK gedrückt, um alle MyKeys zu löschen", // 德文
        "Tüm MyKey'leri silmek için OK tuşunu basılı tutun", // 土耳其文
        "모든 MyKey를 삭제하려면 OK 버튼을 길게 누르세요",    // 韓文
        "Maintenez OK enfoncé pour effacer tous les MyKeys", // 法文
        "Tieni premuto OK per cancellare tutti i MyKeys",   // 義大利文
        "Mantenha OK pressionado para apagar todos os MyKeys", // 葡萄牙文（巴西）
        "सभी MyKeys को हटाने के लिए OK को दबाए रखें",        // 印地文
        "กดปุ่ม OK ค้างไว้เพื่อล้าง MyKey ทั้งหมด",        // 泰文
        "Nhấn giữ OK để xóa tất cả MyKey",                 // 越南文
        "Tahan butang OK untuk padam semua MyKey",         // 馬來西亞文
        "Tekan dan tahan OK untuk hapus semua MyKey",      // 印尼文
        "Задръжте OK, за да изтриете всички MyKey",         // 保加利亞文
        "Przytrzymaj OK, aby usunąć wszystkie MyKey",       // 波蘭文
        "Țineți apăsat pe OK pentru a șterge toate MyKey",  // 羅馬尼亞文
        "Houd OK ingedrukt om alle MyKey’s te wissen",      // 荷蘭文
        "برای حذف همه MyKey دکمه OK را نگه دارید",          // 波斯語
        "Podržte OK pro vymazání všech MyKey"              // 捷克語
    ]

    // FUNCID【0x88】0x000B Mustang/Everest fordInfoNotify
    //-------------------------------
    property var fordSetupInfo:
    [
        0, //property int trucksHillStartAssist;          // 0 防盗系统->设置 状态
        0, //property int trucksHeadLampsWithWipers;      // 1 防盗系统->询问退出 状态(野马)
        0, //property int trucksRemoteUnlockSequence;     // 2 照明->前照灯延时 状态
        0, //property int trucksAutoUnlockOnExit;         // 3 照明->日间行车灯 状态 (野马)
        0, //property int trucksFlashLampWithLock;        // 4 照明->自动远光灯 状态(撼路者)
        0, //property int trucksIlluminApproach;          // 5 车锁->行车自动落锁 状态(撼路者)
        0, //property int trucksKeyOffPowerDelay;         // 6 车锁->自动解锁 状态
        0, //property int trucksLampOffDelay;             // 7 车锁->误锁 状态
        0, //property int trucksParkingAssistSystem;      // 8 车锁->重锁 状态(野马)
        0, //property int trucksAutoLockDoors;            // 9 车锁->开锁 状态
        0, //property int trucksAutoUnlockDoors;          // 10 车锁->开关禁止 状态
        0, //property int trucksRkeLinkedToMemory;        // 11 电动后备箱 状态(撼路者)
        0, //property int trucksRemoteStartComfortSys;    // 12 遥控启动->空调控制 状态
        0, //property int trucksHornWithRemoteStart;      // 13 遥控启动->座椅 状态
        0, //property int trucksHornWithRemoteLock;       // 14 遥控启动->周期 状态
        0, //property int trucksEasyExitSeat;             // 15 车窗->遥控开启 状态
        0, //property int trucksTiltMirrorInReverse;      // 16 车窗->遥控关闭 状态(撼路者)
        0, //property int trucksTrailerBreakType;         // 17 雨刮器->重复雨刮一次 状态
        0, //property int trucksCompassVariance;          // 18 雨刮器->雨量感应 状态
        0, //unsigned char Trailer Away;                  // 19 雨刮器->后挡雨刮 状态(撼路者)
        0, //unsigned char Unit;                          // 20 MyColor->仪表颜色 状态(野马)
        0, //unsigned char OilLifeSerice;                 // 21 MyColor->车内照明->车内照明 状态(野马)
        0, //unsigned char OilLifeSerice;                 // 22 MyColor->车内照明->车内照明暗 状态(野马)
        0, //unsigned char OilLifeSerice;                 // 23 MyColor->车内照明->车内照明颜色 状态(野 马
        1, //unsigned char OilLifeSerice;                 // 24 MyColor->设定 MyColor->设定 MyColor 1->R 状态(野马)
        1, //unsigned char OilLifeSerice;                 // 25 MyColor->设定 MyColor->设定 MyColor 1->G 状态(野马
        1, //unsigned char OilLifeSerice;                 // 26 MyColor->设定 MyColor->设定 MyColor 1->B 状态(野马)
        1, //unsigned char OilLifeSerice;                 // 27 MyColor->设定 MyColor->设定 MyColor 2->R 状态(野马)
        1, //unsigned char OilLifeSerice;                 // 28 MyColor->设定 MyColor->设定 MyColor 2->G 状态(野马
        1, //unsigned char OilLifeSerice;                 // 29 MyColor->设定 MyColor->设定 MyColor 2->B 状态(野马)
        1, //unsigned char OilLifeSerice;                 // 30 MyColor->设定 MyColor->设定 MyColor 3->R 状态(野马)
        1, //unsigned char OilLifeSerice;                 // 31 MyColor->设定 MyColor->设定 MyColor 3->G 状态(野马
        1, //unsigned char OilLifeSerice;                 // 32 MyColor->设定 MyColor->设定 MyColor 3->B 状态(野马)
        0, //unsigned char OilLifeSerice;                 // 33 辅助驾驶->自动关闭引擎 状态
        0, //unsigned char OilLifeSerice;                 // 34 辅助驾驶->后方泊车辅助 状态(野马)
        0, //unsigned char OilLifeSerice;                 // 35 辅助驾驶->盲区监测 状态(撼路者)
        0, //unsigned char OilLifeSerice;                 // 36 辅助驾驶->倒挡来车预警 状态(撼路者)
        0, //unsigned char OilLifeSerice;                 // 37 辅助驾驶->提示铃声->找到泊车位 状态(撼路者)
        0, //unsigned char OilLifeSerice;                 // 38 辅助驾驶->提示铃声->信息 状态(撼路者)
        0, //unsigned char OilLifeSerice;                 // 39 辅助驾驶->巡航控制 状态(撼路者)
        0, //unsigned char OilLifeSerice;                 // 40 辅助驾驶->疲劳驾驶预警->疲劳驾驶预警 状态(撼路者)
        1, //unsigned char OilLifeSerice;                 // 41 辅助驾驶->车道保持系统->模式 状态(撼路者)
        1, //unsigned char OilLifeSerice;                 // 42 辅助驾驶->车道保持系统->强度 状态(撼路者)
        0, //unsigned char OilLifeSerice;                 // 43 辅助驾驶->碰撞预警->碰撞预警关闭(/开启)状态(撼 路者)
        1, //unsigned char OilLifeSerice;                 // 44 辅助驾驶->碰撞预警->警报灵敏度 状态(撼路者)
        0, //unsigned char OilLifeSerice;                 // 45 辅助驾驶->碰撞预警->车距提示 状态(撼路者)
        0, //unsigned char OilLifeSerice;                 // 46 辅助驾驶->碰撞预警->主动制动 状态(撼路者)
        0, //unsigned char OilLifeSerice;                 // 47 设置->显示设置->距离单位 状态
        0, //unsigned char OilLifeSerice;                 // 48 设置->显示设置->温度单位 状态
        0, //unsigned char OilLifeSerice;                 // 49 设置->显示设置->胎压 状态
        0, //unsigned char OilLifeSerice;                 // 50 设置->显示设置->语言 (廢棄)
        // 20250221 新增
        0,                                                // 51 辅助驾驶->拖车制动模式
        0,                                                // 52 辅助驾驶->拖车摆动控制
        0,                                                // 53 照明->回家照明
        0,                                                // 54 照明->迎宾灯
        0,                                                // 55 遥控启动->远程启动
        0,                                                // 56 DTE 计算
        0,                                                // 57 舒适进入
        0,                                                // 58 解锁中
        0,                                                // 59 Oil Life
        0,                                                // 60 遥控启动->前除霜
        0,                                                // 61 遥控启动->后除霜
        0,                                                // 62 遥控启动->乘客座椅
        0,                                                // 63 遥控启动->自动加热
        0,                                                // 64 遥控启动->持续时间
        0,                                                // 65 遥控启动->安静启动
        0,                                                // 66 雨刮器->前雨刮器
        0,                                                // 67 车锁->遥控落锁
        0,                                                // 68 车锁->遥控解锁
        0,                                                // 69 车锁->延迟门锁
        // 20250306 新增
        0,                                                // 70 Off Road Camera(越野摄像头)
        // 20250412 新增
        0,                                                // 71 蜂鸣器音量
        0,                                                // 72 降低后视镜
        0,                                                // 73 记忆座椅
        0,                                                // 74 校准罗盘
        1,                                                // 75 更改指南针区域

        // MyKey
        0xFF,                                              // 76 MyKey->紧急救援 状态
        0xFF,                                              // 77 MyKey->请勿打扰 状态
        0xFF,                                              // 78 MyKey->牵引力控制 状态
        0xFF,                                              // 79 MyKey->最高限速 状态
        0xFF,                                              // 80 MyKey->限速警告设定 状态
        0xFF,                                              // 81 MyKey->音限制 状态
        0,                                                 // 82 MyKey->创建MyKey 状态
        0,                                                 // 83 MyKey->清除Mykey 状态
        1,                                                 // 84 MyKey->MyKey 状态
    ]
    property int fordSetupInfoChanged: 0

    // 將應用的順序轉換成實際協議的id編號
    function mykey_param_id(index){
        if(Qt.platform.os!=="linux"){
            return index
        }
        switch(index){
        case 76:
            return 0
        case 77:
            return 1
        case 78:
            return 2
        case 79:
            return 3
        case 80:
            return 4
        case 81:
            return 5
        case 82:
            return 8
        case 83:
            return 7
        case 84:
            return 8
        }
    }

    // 將應用的順序轉換成實際協議的id編號
    function f150_11_14_param_id(index){
        if(Qt.platform.os!=="linux"){
            return index
        }
        switch(index){
        case 2: // 2 照明->前照灯延时 状态
            return 2
        case 5: // 5 车锁->行车自动落锁
            return 5
        case 6: // 6 车锁->自动解锁 状态
            return 6
        case 13: // 13 遥控启动->座椅
            return 11
        case 50: // 50 Vehicle->Language(原车中控语言)
            //(廢棄)
            return 0
        case 51: // 辅助驾驶->拖车制动模式
            return 0
        case 52: // 52 辅助驾驶->拖车摆动控制
            return 1
        case 56: // 56 DTE 计算
            return 3
        case 57: // 57 舒适进入
            return 4
        case 58: // 58 解锁中
            return 7
        case 59: // 59 Oil Life
            return 8
        case 60: // 60 遥控启动->前除霜
            return 9
        case 61: // 61 遥控启动->后除霜
            return 10
        case 62: // 62 遥控启动->乘客座椅
            return 12
        case 63: // 63 遥控启动->自动加热
            return 13
        case 64: // 64 遥控启动->持续时间
            return 14
        case 65: // 65 遥控启动->安静启动
            return 15
        case 66: // 66 雨刮器->前雨刮器
            return 16
        case 70: // 70 Off Road Camera
            return 17
        }
    }
    function yukon_15_18_param_id(index){
        if(Qt.platform.os!=="linux"){
            return index
        }
        switch(index){
        case 5: // 5 车锁->行车自动落锁
            return 0
        case 6: // 6 车锁->自动解锁 状态
            return 1
        case 53: // 53 照明->回家照明
            return 5
        case 54: // 54 照明->迎宾灯
            return 6
        case 55: // 55 遥控启动->远程启动
            return 7
        case 57: // 57 舒适进入
            return 14
        case 67: // 67 车锁->遥控落锁
            return 2
        case 68: // 68 车锁->遥控解锁
            return 3
        case 69: // 69 车锁->延迟门锁
            return 4
        case 71: // 71 蜂鸣器音量
            return 12
        case 72: // 72 降低后视镜
            return 13
        case 73: // 73 记忆座椅
            return 15
        case 75: // 74 更改指南针区域
            return 17
        }
    }

    //-------------------------------
    // FUNCID【0x1A】宝马 当前曲目信息
    //-------------------------------
    property string mediaCurrentInfo: ""
    property int mediaCurrentSource: 2
    property int mediaSourceListIndex: 1
    property int mediaSourceList: 0
    //-------------------------------
    // FUNCID【0x1B】宝马 媒体列表信息 mediaListInfoNotify
    //-------------------------------
    property int mediaListShow: 0
    property int mediaListPlayingIndex: 1
    property int mediaListCursorIndex: 2
    property int mediaListScrollback: 2
    property int mediaListTrackTotal: 5
    property int mediaListTrackCurrent: 2
    property int mediaListWinShowMax: 5
    property string mediaListTitle: "USB/SD音源"
    property string mediaListItem1: "1 xxxxxxxxxx"
    property string mediaListItem2: "2 xxxxxxxxx"
    property string mediaListItem3: "3 xxxxxxxxx "
    property string mediaListItem4: "4 xxxxxxxxxxxx"
    property string mediaListItem5: "5 xxxxxxxxxxxxx"
    property int mediaListItemCount: 5
    //-------------------------------
    // FUNCID【0x1D】宝马 动能回收、CHARGE POWER powerRecycleInfoNotify
    //-------------------------------
    property var energyDynamic: 0
    property var energyChargePower: 0
    property real energyEcoMile: 0
    property var energyBatteryPower: 0
    property int energyBatteryMile: 0
    //-------------------------------
    // FUNCID【0x1C】宝马 警告信息
    //-------------------------------
    // 共用 【0x03】弹窗提醒
    //-------------------------------
    // FUNCID【0x1E】ADBLUE adblueInfoNotify
    //-------------------------------
    property int adblueEnable: 0
    property int adblueColor: 0
    property int adblueMileage: 0
    //-------------------------------
    // FUNCID【0x1F】宝马 行人警告功能 pwsInfoNotify
    //-------------------------------
    property int pwsShow: 0
    property var pwsState: [0, 0, 0, 0, 0, 0, 0, 0]
    property int pwsShowChanged: 0
    //-------------------------------
    // FUNCID【0x20】宝马 动态驱动力分配系统 dpcInfoNotify
    //-------------------------------
    property int dpcFrontLeft: 0
    property int dpcFrontRight: 0
    property int dpcRearLeft: 0
    property int dpcRearRight: 0
    //-------------------------------
    // FUNCID【0x21】宝马设置项 bmwSetupInfoNotify
    //-------------------------------
    property var bmwSetupInfo:
    [
        0, // 0  无效值
        0, // 1  回家照明
        0, // 2  转向灯亮 3 次
        0, // 3  日间行车灯
        0, // 4  开锁
        0, // 5  座椅自动调整
        0, // 6  自动重锁
        0, // 7  行车后联锁
        0, // 8  上锁时闪烁
        0, // 9  解锁时闪烁
        0, // 10 胎压初始化
        0, // 11 灯光调节
        // M系
        0, // 12
        0, // 13
        0, // 14
        0, // 15
        0, // 16
    ]
    property int bmwSetupInfoChanged: 0

    property int bmwHomeLight: 0
    property int bmwTurnLightThirdTimes: 0
    property int bmwDRL: 0
    property int bmwDoorUnLock: 0
    property int bmwAutoSeatAdjust: 0
    property int bmwAutoRelock: 0
    property int bmwIntetLock: 0
    property int bmwLockFlashing: 0
    property int bmwUnLocFlashing: 0
    property int bmwTpmsInital: 0
    property int bmwLightBrightness: 0
    //-------------------------------
    // FUNCID【0x24】宝马 M系列车型 bmwMSetupInfoNotify
    //-------------------------------
    property int bmwDonglixiangying: 0
    property int bmwXuanguaxiangying: 0
    property int bmwZhuanxiangxiangying: 0
    property int bmwlHuandangchengxu: 0
    property int bmwJiashimoshiqiehuan: 0
    //-------------------------------
    // FUNCID【0x22】机油升数刻度 oilMeterInfoNotify
    //-------------------------------
    property var mEngOilStr:
    [
        "",
        "OK",
        ">MAX",
        "+1L",
        "SERVICE",
    ]
    property int engOilPercent: 0
    property int engOilStrIndex:0
    property string engOilStr: mEngOilStr[engOilStrIndex]
    //-------------------------------
    // FUNCID【0x23】奔驰s系设置 benzS600SetupInfoNotify
    //-------------------------------
    property var benzSSetupInfo: [
        0,  // 0, 底盘上升
        0,  // 1, esp
        0,  // 2, 雷达辅助 倒车摄像头R档自动 白天行驶灯
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0
    ]
    property int benzSSetupInfoChanged: 0
    //-------------------------------
    // FUNCID【0x25】奔驰c系设置 benzCSetupInfoNotify
    // mGlobalId.item.getBenzCSetupInfo
    //-------------------------------
    property var benzCSetupInfo: [
        0,  // 0, 無效
        0,  // 1, ESP
        0,  // 2, 碰撞预防辅助系统增强版
        0,  // 3, 注意力辅助系统
        0,  // 4, 速度限制
        0,  // 5, 低压续跑指示器启用
        0,  // 6, 盲点辅助
        0,  // 7, 车道保持辅助
        0,  // 8, 智能照明
        0,  // 9, 近光灯
        0,  // 10, 亮度
        0,  // 11, 日间行车灯
        0,  // 12, 环境氛围照明亮度
        0,  // 13, 环境氛围照明颜色
        0,  // 14, 定位照明
        0,  // 15, 车内照明延时
        0,  // 16, 自动车门锁止
        0,  // 17, 中央门锁声音反馈
        0,  // 18, 方便出入功能
        0,  // 19, 安全带调节
        0,  // 20, 当锁止时，折叠后视镜
        0,  // 21, 雷达传感器
        0,  // 22, PRE-SAFE 制动系统
        0,  // 23, 主动制动辅助系统
        0,  // 24, 恒定大灯模式
        0,  // 25, 环境照明功能
        1,  // 26, 按键灯亮度
        0,  // 27, 大灯延迟关闭
        0,  // 28, 开限挡板（Opening limiter tailgate）
        0,  // 29, 音频搜索功能（Audio search function）
        4,  // 30, DSR Speed
        0,  // 31, 雨量传感器灵敏度
        0,  // 32 底盘上升
        0,  // 33 雷达辅助
        0,  // 34 倒车摄像头 R档自动
        0,  // 35 距离警告
        0,  // 36 路线偏离警告
        0,  // 37 安全带调节功能
        0,  // 38 安全带调节功能

    ]
    property int benzCSetupInfoChanged: 0
    //-------------------------------
    // FUNCID【0x26】奔驰adblue benzAdblueInfoNotify
    // mGlobalId.item.benzAdBlueTextId
    //-------------------------------
    property int benzAdBlueVol: 0
    property int benzAdBlueTextId: 0
    property int benzAdBlueTextMileage: 0xFFFF
    Behavior on benzAdBlueVol{
        NumberAnimation{
            duration: 100
        }
    }
    function getBenzAdBlueMileage(unit){
        return " "+(benzAdBlueTextMileage==0xFFFF?"ss---":(benzAdBlueTextMileage*tripFactor).toFixed(0))+
               (unit?" "+tripUnit:"")+" "

    }
    //-------------------------------
    // FUNCID【0x27】奔驰C 手动拨片档位显示 benzCSetupInfo
    // mGlobalId.item.benzPTS
    //-------------------------------
    property int benzCBopianJiantou: 0//拨片箭头
    property int benzCBopianNumber: 0//拨片数字
    //-------------------------------
    // FUNCID【0x28】奔驰C eco benzCEcoInfoNotify
    //-------------------------------
    property int benzCEcoJiasuStatus: 0//加速高亮状态
    property int benzCEcoJiansuStatus: 0//减速高亮状态
    property int benzCEcoPinghengStatus: 0//平衡高亮状态
    property int benzCEcoZhengquanStatus: 0//外圈整圈高亮状态
    property int benzCEcoJiasuVol: 0//加速百分比
    property int benzCEcoJiansuVol: 0//减速百分比
    property int benzCEcoPinghengVol: 0//平衡百分比
    property real benzCEcoMileages: 0xFFFF //启动后里程
    property int benzCChargeBar: 0//能量条百分比
    //-------------------------------
    // FUNCID【0x29】奔驰C 车道保持 转向辅助系统 benzLdaInfoNotify
    // mGlobalId.item.benzCLKAS
    //-------------------------------
    property int benzCLDWS: 0//车道保持辅助系统
    property int benzCLKAS: 0//转向辅助系统
    property int benzCPTS: 0//驻车辅助系统
    //-------------------------------
    // FUNCID【0x2A】奔驰雷达 benzCRadarInfoNotify
    // mGlobalId.item.benzRadarFrontRight
    //-------------------------------
    property int benzRadarStatus: 0
    property int benzRadarFrontLeft: 0
    property int benzRadarFrontRight: 0
    //-------------------------------
    // FUNCID【0x2B】奔驰自适应巡航 benzAccInfoNotify
    // mGlobalId.item.benzAccCarStatus
    //-------------------------------
    property int benzAccShow: 0
    property int benzAccLineColor: 0
    property int benzAccLineStatus: 0
    property int benzAccCarColor: 0
    property int benzAccCarStatus: 0
    property int benzAccCarDistance: 0
    property int benzAccLineDistance: 0
    property int benzAccAnimationDuration: 300
//    onBenzAccShowChanged: {
//        if(benzAccShow){
//            drivingInfoIndexLast=drivingInfoIndex===4?0:drivingInfoIndex
//            drivingInfoIndex=4 // accInfo
//        }else{
//            drivingInfoIndex=drivingInfoIndexLast
//        }
//    }
    //-------------------------------
    // FUNCID【0xAA】所有车型设置项
    // mGlobalId.item.benzSetupInfo
    //-------------------------------
//    property var benzSetupInfo: [
//        0,  // 0, 无效值
//        0,  // 1, 恒定大灯模式
//        0,  // 2, 环境照明功能
//        0,  // 3, 按键灯亮度
//        0,  // 4, 大灯延迟关闭
//        0,  // 5, 车内照明延时关闭
//        0,  // 6, 开限挡板（Opening limiter tailgate）
//        0,  // 7, 自动车门锁止
//        0,  // 8, 音频搜索功能（Audio search function）
//        0,  // 9, 当锁止时，折叠后视镜
//        0,  // 10, DSR Speed
//        0,  // 11, 速度限制(冬季轮胎)
//    ]
    property int benzSetupInfoChanged: 0
    // mGlobalId.item.getBenzSetupInfo()
    function getBenzSetupInfo(index){
        switch(index){
        case 11: // Winter Tire Speed Limited
            return benzSetupInfoChanged?
                   (benzSetupInfo[index]===0?"OFF":benzSetupInfo[index]+" "+vehicleSpeedUnit):
                   (benzSetupInfo[index]===0?"OFF":benzSetupInfo[index]+" "+vehicleSpeedUnit)
        default:
            return benzSetupInfoChanged?benzSetupInfo[index]:benzSetupInfo[index]
        }
    }

    //-------------------------------
    // FUNCID【0x3F】注意力輔助系統 attentionAssistNotify
    //-------------------------------
    property int attentionAssistFatigueBar: 0
    property int attentionAssistFatigueState: 0
    property int attentionAssistDrivingHour: 0
    property int attentionAssistDrivingMin: 0

    ///////////////////////////////////
    // END
    ///////////////////////////////////
    ///////////////////////////////////
    // for Tesla
    ///////////////////////////////////
    property string vehicleVIN;
    property int socPercentage: 0               // 剩余电量
    property int oilDepthPercentage: 0          // 油⻔深度
    property int cellPower: 0                   // 电池功率 单位:W
    property int accFollowLevel: 0              // 跟⻋距离设置等级
    property int accFollowDistance: 0           // 当前跟⻋距离
    property int chargingInterfeceState: 0      // 当前跟⻋距离
    property int chargingMode: 0                // 充电模式
    property int energyValue: 0                 // 扭矩
    property int energyState: 0                 // 0:能量释放 1:能量回收
    property int energyPercentage: 0            // 扭矩百分比

    property real chargeTotal: 0
    property real dischargeTotal: 0
    property real chargeCycles: 0
    property real dischargeCycles: 0

    property real cellVoltMax: 0
    property real cellVoltMid: 0
    property real cellVoltMin: 0
    property int cellImbalance: 0
    property real nominalFullPack: 0
    property real energyBuffer: 0

    property real fullPackWhenNew: 0
    property real dcChargeTotal: 0
    property real acChargeTotal: 0

    property int brickChanged: 0
    property int brickIndex: 0
    property var brickVoltage:
    [
        0.001, 0.001, 0.001, 0.001, 0.001, 0.001,           // 00~05
        0.001, 0.001, 0.001, 0.001, 0.001, 0.001,           // 06~11
        0.001, 0.001, 0.001, 0.001, 0.001, 0.001,           // 12~17
        0.001, 0.001, 0.001, 0.001, 0.001, 0.001,           // 18~23
        0.001, 0.001, 0.001, 0.001, 0.001, 0.001,           // 24~29
        0.001, 0.001, 0.001, 0.001, 0.001, 0.001,           // 30~35
        0.001, 0.001, 0.001, 0.001, 0.001, 0.001,           // 36~41
        0.001, 0.001, 0.001, 0.001, 0.001, 0.001,           // 42~47
        0.001, 0.001, 0.001, 0.001, 0.001, 0.001,           // 48~53
        0.001, 0.001, 0.001, 0.001, 0.001, 0.001,           // 54~59
        0.001, 0.001, 0.001, 0.001, 0.001, 0.001,           // 60~65
        0.001, 0.001, 0.001, 0.001, 0.001, 0.001,           // 66~71
        0.001, 0.001, 0.001, 0.001, 0.001, 0.001,           // 72~77
        0.001, 0.001, 0.001, 0.001, 0.001, 0.001,           // 78~83
        0.001, 0.001, 0.001, 0.001, 0.001, 0.001,           // 84~89
        0.001, 0.001, 0.001, 0.001, 0.001, 0.001,           // 90~95
        0.001, 0.001, 0.001, 0.001, 0.001, 0.001,           // 96~101
        0.001, 0.001, 0.001, 0.001, 0.001, 0.001,           // 102~107
        0.001, 0.001, 0.001, 0.001, 0.001, 0.001,           // 108~113
    ]
    property int autoPilotState: 0              // 自动驾驶状态
    property int autoPilotHandsState: 0         // 自动驾驶手扶状态
    property int blindWarningState: 0           // 盲区状态
    //////////////////////////////////s
    // DynamicIsland mGlobalId.item.dynamicIslandEnable
    //////////////////////////////////
    property int dynamicIslandEnable: 1
    property string dynamicIslandMeg: ""
    property int dynamicIslandIcon: 0
    //////////////////////////////////
    // STORAGE mGlobalId.item.usbMounted
    //////////////////////////////////
    // usb
    property int usbMounted: 0
    // music
    property int usbMusicInfoIndex: 0
    property int usbMusicInfoDuration: 0
    property int usbMusicInfoCount: 0
    // video
    property int usbVideoInfoIndex: 0
    property int usbVideoInfoDuration: 0
    property int usbVideoInfoCount: 0
    // sd
    property int sdMounted: 0
    // music
    property int sdMusicInfoIndex: 0
    property int sdMusicInfoDuration: 0
    property int sdMusicInfoCount: 0
    // video
    property int sdVideoInfoIndex: 0
    property int sdVideoInfoDuration: 0
    property int sdVideoInfoCount: 0
    // local
    property int localMounted: 0
    // music
    property int localMusicInfoIndex: 0
    property int localMusicInfoDuration: 0
    property int localMusicInfoCount: 0
    // video
    property int localVideoInfoIndex: 0
    property int localVideoInfoDuration: 0
    property int localVideoInfoCount: 0
    ////////////////////////////////
    // RCC PREFIX
    // mGlobalId.item.mRccPrefix
    ////////////////////////////////
    property string mRccPrefix: {
        switch(Qt.platform.os){
        case 'linux':
            return "file:///etc/"
        case 'osx':
            if(mRCC_PREFIX_PATH==="NONE")
                return "file:///Users/joeasychou/Works/Project/QtProject/BENZ/"
            else
                return "file:///"+mRCC_PREFIX_PATH
        case 'windows':
            if(mRCC_PREFIX_PATH==="NONE")
                return "file:///C:/Qt/DP320/images/"
            else
                return "file:///"+mRCC_PREFIX_PATH
        }
    }
    ////////////////////////////////
    // Component
    ////////////////////////////////
    Timer{
        id: mPostTimerId
        interval: 300
        running: false
        onTriggered: {
            pressureUnit=Funcs.restore_properity("pressureUnit", pressureUnit)
            overSpeedWarningEnabled=Funcs.restore_properity("overSpeedWarningEnabled", overSpeedWarningEnabled)
            mainTentCustomize1=Funcs.restore_properity("mainTentCustomize1", mainTentCustomize1)
            mainTentCustomize2=Funcs.restore_properity("mainTentCustomize2", mainTentCustomize2)
            // factory setting
            frontTpmsDoorExchange=Funcs.restore_properity("frontTpmsDoorExchange", frontTpmsDoorExchange)
            rearTpmsDoorExchange=Funcs.restore_properity("rearTpmsDoorExchange", rearTpmsDoorExchange)
            angleInfoEnabled=Funcs.restore_properity("angleInfoEnabled", angleInfoEnabled)
            sinceStartInfoEnabled=Funcs.restore_properity("sinceStartInfoEnabled", sinceStartInfoEnabled)
            sinceResetInfoEnabled=Funcs.restore_properity("sinceResetInfoEnabled", sinceResetInfoEnabled)
            sinceRefuelingInfoEnabled=Funcs.restore_properity("sinceRefuelingInfoEnabled", sinceRefuelingInfoEnabled)
            clockInfoEnabled=Funcs.restore_properity("clockInfoEnabled", clockInfoEnabled)
            doorInfoEnabled=Funcs.restore_properity("doorInfoEnabled", doorInfoEnabled)
            //metricSystem=Funcs.restore_properity("metricSystem", metricSystem)
            fuelRefuelingPortPositon=Funcs.restore_properity("fuelRefuelingPortPositon", fuelRefuelingPortPositon)
            outSideTempInfoEnabled=Funcs.restore_properity("outSideTempInfoEnabled", outSideTempInfoEnabled)
            ecoInfoEnabled=Funcs.restore_properity("ecoInfoEnabled", ecoInfoEnabled)
             oilPressureInfoEnabled=Funcs.restore_properity("oilPressureInfoEnabled", oilPressureInfoEnabled)
            tpmsInfoEnabled=Funcs.restore_properity("tpmsInfoEnabled", tpmsInfoEnabled)
            cruiseInfoEnabled=Funcs.restore_properity("cruiseInfoEnabled", cruiseInfoEnabled)
            attentionAssistInfoEnabled=Funcs.restore_properity("attentionAssistInfoEnabled", attentionAssistInfoEnabled)
            vehicleSpeed320=Funcs.restore_properity("vehicleSpeed320", vehicleSpeed320)
            tachoSpeedMax6000=Funcs.restore_properity("tachoSpeedMax6000", tachoSpeedMax6000)
            gforceInfoEnabled=Funcs.restore_properity("gforceInfoEnabled", gforceInfoEnabled)
            subTankEnabled=Funcs.restore_properity("subTankEnabled", subTankEnabled)
            gearInfoEnabled=Funcs.restore_properity("gearInfoEnabled", gearInfoEnabled)
            oilTempEnabled=Funcs.restore_properity("oilTempEnabled", oilTempEnabled)
            dteEnabled=Funcs.restore_properity("dteEnabled", dteEnabled)
            chassisStateEnabled=Funcs.restore_properity("chassisStateEnabled", chassisStateEnabled)
            screenFlipEnabled=Funcs.restore_properity("screenFlipEnabled", screenFlipEnabled)


            switch(Number(mTrucksModel)){
            case 5: // lc76//
                mLc76VehicleSpeedMaxIndex=Funcs.restore_properity("mLc76VehicleSpeedMaxIndex", mLc76VehicleSpeedMaxIndex)
                break;
            case 6: // silverado
                mSilveradoVehicleSpeedMaxIndex=Funcs.restore_properity("mSilveradoVehicleSpeedMaxIndex", mSilveradoVehicleSpeedMaxIndex)
                mSilveradoTachoSpeedMaxIndex=Funcs.restore_properity("mSilveradoTachoSpeedMaxIndex", mSilveradoTachoSpeedMaxIndex)
                break;
            }
            // reverseAlarmEnabled mcu 記憶
            //reverseAlarmEnabled=Funcs.restore_properity("reverseAlarmEnabled", reverseAlarmEnabled)
            //fuelType=Funcs.restore_properity("fuelType", fuelType)
            mCompleted=1
        }
    }

    property int mCompleted: 0
    Component.onCompleted: {
        Funcs.initProperty()
        uartDebugEnabled=Funcs.restore_properity("uartDebugEnabled", uartDebugEnabled)
        vehicleModel=Funcs.restore_properity("vehicleModel", vehicleModel)
        dashboard=Funcs.restore_properity("dashboard", dashboard)
        language=Funcs.restore_properity("language", language)
        gpsAutoSetRtcEnabled=Funcs.restore_properity("gpsAutoSetRtcEnabled", gpsAutoSetRtcEnabled)
        drivingInfoIndex=Funcs.restore_properity("drivingInfoIndex", drivingInfoIndex)
        //console.log("Global: xxxxxxxxxxxxxx drivingInfoIndex:"+drivingInfoIndex)
        leftInfoIndex=Funcs.restore_properity("leftInfoIndex", leftInfoIndex)
        switch(Number(mTrucksModel)){
            case 0: // ram
            case 1:  // ford
                if(leftInfoIndex>1)
                    leftInfoIndex=0
                break
            case 2: // prado
                if(leftInfoIndex>4)
                    leftInfoIndex=0
                break;
        }
        rightInfoIndex=Funcs.restore_properity("rightInfoIndex", rightInfoIndex)
        if(rightInfoIndex>1)
            rightInfoIndex=0
        /////////
        upGaugeIndex=Funcs.restore_properity("upGaugeIndex", upGaugeIndex)
        if(upGaugeIndex>3)
            upGaugeIndex=0
        downGaugeIndex=Funcs.restore_properity("downGaugeIndex", downGaugeIndex)
        if(downGaugeIndex>3)
            downGaugeIndex=0
        //if(!followUnit){
            speedUnitOverride=Funcs.restore_properity("speedUnitOverride", speedUnitOverride)
            tempUnitOverride=Funcs.restore_properity("tempUnitOverride", tempUnitOverride)
            metricSystem=Funcs.restore_properity("metricSystem", metricSystem)
            rtc24h=Funcs.restore_properity("rtc24h", rtc24h)
            temperatureUnit=Funcs.restore_properity("temperatureUnit", temperatureUnit)
        //}
        consumptionUnit=Funcs.restore_properity("consumptionUnit", consumptionUnit)
        vehicleColor=Funcs.restore_properity("vehicleColor", vehicleColor)
        tripType=Funcs.restore_properity("tripType", tripType)
        modelCarSelection=Funcs.restore_properity("modelCarSelection", modelCarSelection)

        // Gyro
        mRollOffst=Funcs.restore_properity("mRollOffst", mRollOffst)
        mPitchOffset=Funcs.restore_properity("mPitchOffset", mPitchOffset)
        gXoffset=Funcs.restore_properity("gXoffset", gXoffset)
        gYoffset=Funcs.restore_properity("gYoffset", gYoffset)
        gZoffset=Funcs.restore_properity("gZoffset", gZoffset)

        mPostTimerId.restart()
    }
}
