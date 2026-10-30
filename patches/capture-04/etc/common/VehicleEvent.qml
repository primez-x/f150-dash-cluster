/****************************************************************************
**
** Copyright (C) 2023 ShenZhen SNTron Technology Co., Ltd.
** Contact: http://www.sntron.cn
**
** This file is part of the VehicleEvent of the QML.
**
****************************************************************************/
import QtQuick 2.12
import plugins.VehicleEvent 1.0
import "qrc:/functions.js" as Funcs

Item {
    /////////////////////////////////////
    // VehicleEvent Plugins startd
    /////////////////////////////////////
    property var mCanVender:
    [
        VehicleEvent.CANBOX_VENDOR_NONE,
        VehicleEvent.CANBOX_VENDOR_JLY,
        VehicleEvent.CANBOX_VENDOR_DSXW,
        VehicleEvent.CANBOX_VENDOR_TESLA,
    ]

    property var mSwcHoldType:
    [
        VehicleEvent.SWC_LONG_HOLD,
        VehicleEvent.SWC_LONG_HOLD,
        VehicleEvent.SWC_LONG_HOLD,
        VehicleEvent.SWC_LONG_HOLD,
        VehicleEvent.SWC_LONG_HOLD,
        VehicleEvent.SWC_COMMON_HOLD,
        VehicleEvent.SWC_COMMON_HOLD,
        VehicleEvent.SWC_COMMON_HOLD,
        VehicleEvent.SWC_LONG_HOLD,
        VehicleEvent.SWC_COMMON_HOLD,
    ]
    property var mMenuSwcHoldType:
    [
        VehicleEvent.SWC_COMMON_HOLD,
        VehicleEvent.SWC_COMMON_HOLD,
        VehicleEvent.SWC_COMMON_HOLD,
        VehicleEvent.SWC_COMMON_HOLD,
        VehicleEvent.SWC_COMMON_HOLD,
        VehicleEvent.SWC_COMMON_HOLD,
        VehicleEvent.SWC_COMMON_HOLD,
        VehicleEvent.SWC_COMMON_HOLD,
        VehicleEvent.SWC_COMMON_HOLD,
        VehicleEvent.SWC_COMMON_HOLD,
    ]

    VehicleEvent{
        id: mHandleId
        // LZ也是用CANBOX_VENDOR_JLY, 只有mcu升級時用CANBOX_VENDOR_LZ標示
        vendor: mCanVender[mGlobalId.item.mVehicleEventVendor]//VehicleEvent.CANBOX_VENDOR_JLY
        port: mGlobalId.item.mVehicleEventUart
        baudrate: mGlobalId.item.mVehicleEventUartBaud //115200
        //swcHoldType: mGlobalId.item.menuBarIndex?VehicleEvent.SWC_COMMON_HOLD:VehicleEvent.SWC_LONG_HOLD
        swcHoldType: mGlobalId.item.menuBarIndex?mMenuSwcHoldType[Number(mTrucksModel)]:
                                                 mSwcHoldType[Number(mTrucksModel)]
        followUnit: mGlobalId.item.followUnit
        //=============================
        // Pressure (hPa)
        //=============================
        pressureBus: 1
        pressureVendor: VehicleEvent.PRESSURE_VENDOR_LPS22HH
        //=============================
        // Gyro
        //=============================
        gyroBus: 1
        gyroVendor: VehicleEvent.GYRO_VENDOR_LIS3DH
        gyroCalib: mGlobalId.item.mGyroCalibration
        //=============================
        // Gps
        //=============================
        gpsPort: 4
        gpsBaudrate: 9600
        // 不使用GPS校時，timezone=255通知插件
        // "GMT-12:00 国际日期变更线西"
        timezone: 255 //mGlobalId.item.timeZone
        //=============================
        // Driving Mode animation
        //=============================
        drivingModeEnabled: mGlobalId.item.driverModeAnimationEnabled
        drivingModeIndex: mGlobalId.item.offRoadMode
        //drivingModeAnimation: "/mnt/1+1+1+1+7.mp4"
        //=============================
        // 無開機動畫，splashEnd=1
        //=============================
        splashEnd: !Number(mSplashPlay)?2:0
        //=============================
        // 開關開機/關機動畫，避免侵權
        //=============================
        nologo: Number(mNoLogo)
        //=============================
        // USB image preview.
        //=============================
        showImage: mGlobalId.item.mediaImageEnabled
        // mcu simulation
        //=============================
        simulation: Qt.platform.os!=="linux"
        //=============================
        // boot/shutdown animation
        //=============================
        shutdownAnimation: mTranslationId.item.mShutdownAnimation
        bootAnimation: mTranslationId.item.mBootAnimation
        //=============================
        // debug settings
        //=============================
        debug: mDataLogFramesOpen?mGlobalId.item.uartDebugEnabled:(mGlobalId.item.uartDebugEnabled&1)
        debugFilter: "0x04, 0x34"
        //=============================
        // bright min/max settings
        //=============================
        brightnessMin: mTranslationId.item.mBrightnessMin //mGlobalId.item.brightnessMin
        brightnessMax: mTranslationId.item.mBrightnessMax //mGlobalId.item.brightnessMax
        //=============================
        // search update file settings
        //=============================
        systemUpdFiles: "dashboard*.zip"
        mcuUpdFiles: "jly*.bin"
        shellFiles: "*.shell"
        btUpdFiles: "fw5000*.bin*"
        ////////////////////////////////
        // readyInfoNotify
        ////////////////////////////////
        onReadyNotify: {
            mGlobalId.item.startEnd=1
        }
        onActivitedNotify: {
            mGlobalId.item.activited=getActivited()
            //console.log("[onActivitedNotify:"+mGlobalId.item.activited+"]")
        }
        onMessageInfo: {
            //mGlobalId.item.mcuUartData
        }
        ////////////////////////////////
        // uart debug uartRxInfoNotify/uartTxInfoNotify
        ////////////////////////////////
        onUartRxInfoNotify: {
            var temp=getUartRxData()
            if(mGlobalId.item.mcuUartDataCnt++>9){
                mGlobalId.item.mcuUartData=""
                mGlobalId.item.mcuUartDataCnt=0
            }
            mGlobalId.item.mcuUartData=mGlobalId.item.mcuUartData+temp+"\n"
        }
        onUartTxInfoNotify: {
            var temp=getUartTxData()
            if(mGlobalId.item.armUartDataCnt++>9){
                mGlobalId.item.armUartData=""
                mGlobalId.item.armUartDataCnt=0
            }
            mGlobalId.item.armUartData=mGlobalId.item.armUartData+temp+"\n"
        }
        /////////////////////////////////////////////
        // Driving Mode animation
        /////////////////////////////////////////////
        onDrivingModeAnimationRequestViewParam: {
            // console.log("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")
            // console.log(" xxxxxxxxxxx onDrivingModeAnimationRequestViewParam xxxxxxxxx")
            // console.log("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")
            switch(Number(mTrucksModel)){
            case 0: // ram
                break
            case 1: // ford
                break
            case 2: // padao
                break
            case 3: // patrol
                break
            case 4: // landcruiser
                break
            case 5: // lc76
                mHandleId.setDrivingModeAnimationView(0, "/etc/images/vehicles/lc76/driving/0.mp4",
                                                      0, "/etc/images/vehicles/lc76/driving/00.mp4");
                mHandleId.setDrivingModeAnimationView(1, "/etc/images/vehicles/lc76/driving/1.mp4",
                                                      0, "",);
                mHandleId.setDrivingModeAnimationView(2, "/etc/images/vehicles/lc76/driving/2.mp4",
                                                      0, "",);
                mHandleId.setDrivingModeAnimationView(3, "/etc/images/vehicles/lc76/driving/3.mp4",
                                                      0, "",);
                mHandleId.setDrivingModeAnimationView(4, "/etc/images/vehicles/lc76/driving/4.mp4",
                                                      0, "",);
                break;
            case 6: // silverado
                mHandleId.setDrivingModeAnimationView(0, "/etc/images/vehicles/silverado/driving/highway.mp4",
                                                      1, "/etc/images/vehicles/silverado/driving/highway_xh.mp4");
                mHandleId.setDrivingModeAnimationView(1, "/etc/images/vehicles/silverado/driving/desert.mp4",
                                                      1, "/etc/images/vehicles/silverado/driving/desert_xh.mp4");
                mHandleId.setDrivingModeAnimationView(2, "/etc/images/vehicles/silverado/driving/snow.mp4",
                                                      1, "/etc/images/vehicles/silverado/driving/snow_xh.mp4");
                mHandleId.setDrivingModeAnimationView(3, "/etc/images/vehicles/silverado/driving/rock.mp4",
                                                      0, "");
                break;
            case 7: // everest
                mHandleId.setDrivingModeAnimationView(0, "/etc/images/vehicles/everest/driving/highway.mp4",
                                                      1, "/etc/images/vehicles/everest/driving/highway_xh.mp4");
                mHandleId.setDrivingModeAnimationView(1, "/etc/images/vehicles/everest/driving/desert.mp4",
                                                      1, "/etc/images/vehicles/everest/driving/desert_xh.mp4");
                mHandleId.setDrivingModeAnimationView(2, "/etc/images/vehicles/everest/driving/snow.mp4",
                                                      1, "/etc/images/vehicles/everest/driving/snow_xh.mp4");
                mHandleId.setDrivingModeAnimationView(3, "/etc/images/vehicles/everest/driving/rock.mp4",
                                                      0, "");
                break;
            case 8: // yukon
                break
            case 9: // gmc
                mHandleId.setDrivingModeAnimationView(0, "/etc/images/vehicles/gmc/driving/0.mp4",
                                                      0, "");
                mHandleId.setDrivingModeAnimationView(1, "/etc/images/vehicles/gmc/driving/1.mp4",
                                                      0, "",);
                mHandleId.setDrivingModeAnimationView(2, "/etc/images/vehicles/gmc/driving/2.mp4",
                                                      0, "",);
                mHandleId.setDrivingModeAnimationView(3, "/etc/images/vehicles/gmc/driving/3.mp4",
                                                      0, "",);
                break;
            }
        }
        onDrivingModeAnimationState: {
            mGlobalId.item.driverModeAnimationState=getDriverModeAnimationState()
            //console.log("[x-----------x onDrivingModeAnimationState state:"+mGlobalId.item.driverModeAnimationState+"]")
        }
        //////////////////////// TESLA STARTED //////////////////////////
        ////////////////////////////////
        ///  socInfoNotify
        ////////////////////////////////
        onSocInfoNotify: {
            mGlobalId.item.socPercentage=getSocPercentage()
        }
        ////////////////////////////////
        ///  cellPowerInfoNotify
        ////////////////////////////////
        onCellPowerInfoNotify: {
            mGlobalId.item.cellPower=getCellPower()
        }
        ////////////////////////////////
        ///  teslaAccInfoNotify
        ////////////////////////////////
        onTeslaAccInfoNotify: {
            mGlobalId.item.accFollowLevel=getTeslaAccFollowLevel()
            mGlobalId.item.accFollowDistance=getTeslaAccFollowDistance()
        }
        ////////////////////////////////
        ///  chargingStateInfoNotify
        ////////////////////////////////
        onChargingStateInfoNotify: {
            mGlobalId.item.chargingInterfeceState=getChargingInterfaceState()
            mGlobalId.item.chargingMode=getChargingMode()
        }
        ////////////////////////////////
        ///  energeInfoNotify
        ////////////////////////////////
        onEnergeInfoNotify: {
            mGlobalId.item.energyValue=getEnergeValue()
            mGlobalId.item.energyState=getEnergyState()
            mGlobalId.item.energyPercentage=getEnergyPercentage()
        }
        ////////////////////////////////
        ///  cellInfoNotify
        ////////////////////////////////
        onCellInfoNotify: {
            mGlobalId.item.chargeTotal=getChargeTotal()
            mGlobalId.item.dischargeTotal=getDischargeTotal()
            mGlobalId.item.chargeCycles=getChargeCycles()
            mGlobalId.item.dischargeCycles=getDischargeCycles()

            mGlobalId.item.cellVoltMax=getCellVoltMax()
            mGlobalId.item.cellVoltMid=getCellVoltMid()
            mGlobalId.item.cellVoltMin=getCellVoltMin()
            mGlobalId.item.cellImbalance=getCellImbalance()
            mGlobalId.item.nominalFullPack=getNominalFullPack()
            mGlobalId.item.energyBuffer=getEnergyBuffer()

            mGlobalId.item.fullPackWhenNew=getFullPackWhenNew()
            mGlobalId.item.dcChargeTotal=getDcChargeTotal()
            mGlobalId.item.acChargeTotal=getAcChargeTotal()
        }
        ////////////////////////////////
        ///  brickInfoNotify
        ////////////////////////////////
        onBrickInfoNotify: {
            mGlobalId.item.brickIndex=getBrickIndex()
            for(var i=0;i<6;i++)
                mGlobalId.item.brickVoltage[i+(mGlobalId.item.brickIndex*6)]=getBrickVoltage(mGlobalId.item.brickIndex*6+i)
            mGlobalId.item.brickChanged=!mGlobalId.item.brickChanged
        }
        ////////////////////////////////
        ///  autoPilotInfoNotify
        ////////////////////////////////
        onAutoPilotInfoNotify: {
            mGlobalId.item.autoPilotState=getAutoPilottState()
            mGlobalId.item.autoPilotHandsState=getAutoPilotHandsState()
        }
        ////////////////////////////////
        ///  blindInfoNotify
        ////////////////////////////////
        onBlindInfoNotify: {
            mGlobalId.item.blindWarningState=getBlindWarningState()
        }
        //////////////////////// TESLA END //////////////////////////


        ////////////////////////////////
        // alarmInfoNotify
        ////////////////////////////////
        onAlarmInfoNotify: {
            for(var i=0; i<mGlobalId.item.alarmMax;i++){
                //if(i!==30)
                    mGlobalId.item.alarmTable[i]=getAlarm(i)
            }
            mGlobalId.item.alarmChanged=!mGlobalId.item.alarmChanged
        }
        ////////////////////////////////
        // onUnitInfoNotify
        ////////////////////////////////
        onUnitInfoNotify: {
            // mGlobalId.item.metricSystem=Number(getTripUnit())?0:1
            // mGlobalId.item.temperatureUnit=Number(getTempUnit())?0:1
            // mGlobalId.item.consumptionUnit=getFuelUnit()
            // mGlobalId.item.trucksSetupInfo[20]=mGlobalId.item.metricSystem
            if(mGlobalId.item.followUnit){
                if(!mGlobalId.item.speedUnitOverride)
                    mGlobalId.item.metricSystem=getTripUnit()
                if(!mGlobalId.item.tempUnitOverride)
                    mGlobalId.item.temperatureUnit=getTempUnit()
                mGlobalId.item.rtc24h=getTime24h()
                //mGlobalId.item.consumptionUnit=getFuelUnit()
                // console.log("--------------------------------------------")
                // console.log("mGlobalId.item.metricSystem:"+mGlobalId.item.metricSystem)
                // console.log("mGlobalId.item.rtc24h:"+mGlobalId.item.rtc24h)
                // console.log("mGlobalId.item.temperatureUnit:"+mGlobalId.item.temperatureUnit)
                //console.log("mGlobalId.item.consumptionUnit:"+mGlobalId.item.consumptionUnit)
            }
        }
        ////////////////////////////////
        // onNotifyInfoNotify
        ////////////////////////////////
        onNotifyInfoNotify: {
            var duration;
            //if(!getNotifyIsEmpty()){
                var temp=getNotifyInfo().split("#")
                if(Number(temp[0])>mTranslationId.item.mNotifyTextItemLength-1){
                    // 測試架發送超過，所以這裡直接忽略
                    // console.log("xxx onNotifyInfoNotify notifyText="+Number(temp[0]))
                    // console.log("xxx onNotifyInfoNotify >"+
                    //             Number(mTranslationId.item.mNotifyTextItemLength-1))
                    return
                }
                mGlobalId.item.notifyText=Number(temp[0])
                mGlobalId.item.notifyIcon=Number(temp[1])
                duration=(Number(temp[2])*1000)
                mGlobalId.item.nofifyDpf=Number(temp[3])
                mGlobalId.item.nofifyU16=Number(temp[4])
                // changed 效果
                if(mGlobalId.item.notifyDuration===duration){
                    if(duration)
                        mGlobalId.item.notifyDuration=duration+1
                    else
                        mGlobalId.item.notifyDuration=0
                }else
                    mGlobalId.item.notifyDuration=duration
//                console.log("--------------------------------------------------------")
                // console.log("[onNotifyInfoNotify notifyText:"+mGlobalId.item.notifyText+"]")
                // console.log("[onNotifyInfoNotify notifyIcon:"+mGlobalId.item.notifyIcon+"]")
//                console.log("[onNotifyInfoNotify temp[2]:"+duration+"]")
//                console.log("[onNotifyInfoNotify notifyDuration:"+mGlobalId.item.notifyDuration+"]")
//                console.log("[onNotifyInfoNotify nofifyDpf:"+mGlobalId.item.nofifyDpf+"]")
//                console.log("[onNotifyInfoNotify nofifyU16:"+mGlobalId.item.nofifyU16+"]")
//                console.log("--------------------------------------------------------")
            //}
        }
        ////////////////////////////////
        // shellInfoNotify
        ////////////////////////////////
        onShellInfoNotify: {
            mGlobalId.item.shellInfo=getShellCmdInfo()
            mGlobalId.item.shellInfoDuration=getShellCmdDuration()*1000
            //console.log("[onShellInfoNotify info:"+mGlobalId.item.shellInfo+"]")
            //console.log("[onShellInfoNotify shellInfoDuration:"+mGlobalId.item.shellInfoDuration+"]")
        }
        ////////////////////////////////
        // onDialog2InfoNotify
        ////////////////////////////////
        onDialog2InfoNotify: {
            if(!getDialog2IsEmpty()){
                var dialog=getDialog2Info().split("#")
                var duration=(Number(dialog[0])*1000)
                mGlobalId.item.dialogColor=Number(dialog[1])
                mGlobalId.item.dialogId=Number(dialog[2])
                mGlobalId.item.dialogIcon=Number(dialog[3])
                mGlobalId.item.dialogParam=Number(dialog[4])
                // changed
                if(mGlobalId.item.dialogDuration===duration){
                    if(duration)
                        mGlobalId.item.dialogDuration=(duration+10)
                    else
                        mGlobalId.item.dialogDuration=duration
                }else
                    mGlobalId.item.dialogDuration=(duration)
            }
        }
        ///////////////////////////////////////
        /// speedInfoNotify
        ///////////////////////////////////////
        onSpeedInfoNotify: {
            var temp=Number(getVehicleSpeed())
            mGlobalId.item.vehicleSpeedDelta=Math.abs(mGlobalId.item.vehicleSpeed-temp)
            mGlobalId.item.vehicleSpeed=temp

            temp=Number(getTachoSpeed())
            mGlobalId.item.tachoSpeedDelta=Math.abs(mGlobalId.item.tachoSpeed-temp)
            mGlobalId.item.tachoSpeed=temp
        }
        ///////////////////////////////////////
        /// fuelInfoNotify
        ///////////////////////////////////////
        // The native decoder raises this on every fuel frame (0x06), which the heartbeat polls.
        onFuelInfoNotify: {
            var g=mGlobalId.item
            g.fuelFrameMs=Date.now()
            g.dte=getDte()             // 续航里程
            // The gauges keep the last reading in 0..100. The raw bytes stay in the *Raw properties for the data log.
            g.fuelPercentageRaw=getFuelPercentage()
            if(g.fuelPercentageValid){
                g.fuelPercentage=g.fuelPercentageRaw
                g.fuelPercentageSeen=true
            }
            g.fuelRefuelingPortPositon=getFuelFillerRight()
            g.fuelLevel=g.fuelWarningLevel(g.fuelPercentageSeen?g.fuelPercentage:-1, getFuelState(), g.fuelPercentageValid)
            g.mainTank=getFuelTank(0)
            g.subTank=getFuelTank(1)
            g.mainTankPercentageRaw=getTankFuelPercetage(0)
            if(g.mainTankPercentageValid)
                g.mainTankPercentage=g.mainTankPercentageRaw
            g.subTankPercentageRaw=getTankFuelPercetage(1)
            if(g.subTankPercentageValid)
                g.subTankPercentage=g.subTankPercentageRaw
            g.mainTankState=getTankFuelState(0)
            g.subTankState=getTankFuelState(1)
        }
        ///////////////////////////////////////
        /// dashboardInfoNotify
        ///////////////////////////////////////
        onDashboardInfoNotify: {
            var temp=Number(getDashboardId())
            if(temp<5)
                mGlobalId.item.dashboard=temp//getDashboardId()
        }
        ///////////////////////////////////////
        /// fordMyKeyInfoNotify
        ///////////////////////////////////////
        onFordMyKeyInfoNotify: {
            mGlobalId.item.myKeyDistanceState=getFordMyKeyDistanceState()
            mGlobalId.item.myKeyType=getFordMyKeyType()
            mGlobalId.item.myKeyNums=getFordMyKeyNums()
            mGlobalId.item.myKeyKeys=getFordMyKeyKeys()
            mGlobalId.item.myKeyDistance=getFordMyKeyDistance()
            mGlobalId.item.myKeyShow=getFordMyKeyDialogState()
            mGlobalId.item.myKeyText=getFordMyKeyDialogText()
        }
        ///////////////////////////////////////
        /// tripInfoNotify
        ///////////////////////////////////////
        onTripInfoNotify: {
            mGlobalId.item.odo=getOdo()
            mGlobalId.item.tripA=getTrip(0)
            mGlobalId.item.tripB=getTrip(1)
            switch(Number(mTrucksModel)){
            case 0: // ram
            case 1: // ford
            case 5: // lc76
            case 7: // everest
            //case 2: // prado
            //case 3: // patrol
            case 4: // landcruiser
                 break;
            case 2: // prado
            case 3: // patrol
//            case 4: // landcruiser
            case 6: // silverado
            case 8: // yukon
                mGlobalId.item.tripType=!getTripType()?1:getTripType()
                break;
            }
//            console.log("------------------------------------------")
//            console.log("[onTripInfoNotify TripA:"+mGlobalId.item.tripA+"]")
//            console.log("[onTripInfoNotify TripB:"+mGlobalId.item.tripB+"]")
        }
        ///////////////////////////////////////
        /// tpmsInfoNotify
        ///////////////////////////////////////
        onTpmsInfoNotify: {
            mGlobalId.item.tpmsLFState=getTpmsState(VehicleEvent.TPMS_LF)
            mGlobalId.item.tpmsLFPressure=getTpmsPressure(VehicleEvent.TPMS_LF)
            mGlobalId.item.tpmsRFState=getTpmsState(VehicleEvent.TPMS_RF)
            mGlobalId.item.tpmsRFPressure=getTpmsPressure(VehicleEvent.TPMS_RF)
            mGlobalId.item.tpmsLRState=getTpmsState(VehicleEvent.TPMS_LR)
            mGlobalId.item.tpmsLRPressure=getTpmsPressure(VehicleEvent.TPMS_LR)
            mGlobalId.item.tpmsRRState=getTpmsState(VehicleEvent.TPMS_RR)
            mGlobalId.item.tpmsRRPressure=getTpmsPressure(VehicleEvent.TPMS_RR)
            mGlobalId.item.tpmsRearState=getTpmsState(VehicleEvent.TPMS_BACKUP)
            mGlobalId.item.tpmsRearPressure=getTpmsPressure(VehicleEvent.TPMS_BACKUP)
//            console.log("------------------------------------------")
//            console.log("[onTpmsInfoNotify tpmsLFState:"+mGlobalId.item.tpmsLFState+"]")
//            console.log("[onTpmsInfoNotify tpmsLFPressure:"+mGlobalId.item.tpmsLFPressure+"]")
        }
        ///////////////////////////////////////
        /// doorInfoNotify
        ///////////////////////////////////////
        onDoorInfoNotify: {
            mGlobalId.item.doorLeftFront=getDoor(VehicleEvent.DOOR_STATE_LF)
            mGlobalId.item.doorRightFront=getDoor(VehicleEvent.DOOR_STATE_RF)
            mGlobalId.item.doorLeftRear=getDoor(VehicleEvent.DOOR_STATE_LR)
            mGlobalId.item.doorRightRear=getDoor(VehicleEvent.DOOR_STATE_RR)
            mGlobalId.item.doorTrunk=getDoor(VehicleEvent.DOOR_STATE_TRUNK)
            mGlobalId.item.doorHood=getDoor(VehicleEvent.DOOR_STATE_HOOD)
           // console.log("[onDoorInfoNotify doorLeftFront:"+mGlobalId.item.doorLeftFront+"]")
           // console.log("[onDoorInfoNotify doorRightFront:"+mGlobalId.item.doorRightFront+"]")
           // console.log("[onDoorInfoNotify doorLeftRear:"+mGlobalId.item.doorLeftRear+"]")
           // console.log("[onDoorInfoNotify doorRightRear:"+mGlobalId.item.doorRightRear+"]")
           // console.log("[onDoorInfoNotify doorTrunk:"+mGlobalId.item.doorTrunk+"]")
           // console.log("[onDoorInfoNotify doorHood:"+mGlobalId.item.doorHood+"]")
        }
        ///////////////////////////////////////
        /// sinceReset/Refueling/start InfoNotify
        ///////////////////////////////////////
        onSinceResetInfoNotify: {
            mGlobalId.item.sinceResetAvgFuel=getSinceAvgFuel(VehicleEvent.SINCE_RESET)
            mGlobalId.item.sinceResetAvgSpeed=getSinceAvgSpeed(VehicleEvent.SINCE_RESET)
            mGlobalId.item.sinceResetTravelTime=getSinceTravelTime(VehicleEvent.SINCE_RESET)
            mGlobalId.item.sinceResetTravelMileage=getSinceDrivingMileage(VehicleEvent.SINCE_RESET)
        }
        onSinceRefuelingInfoNotify: {
            mGlobalId.item.sinceRefuelingDte=getSinceDte(VehicleEvent.SINCE_REFUELING)
            mGlobalId.item.sinceRefuelingAvgFuel=getSinceAvgFuel(VehicleEvent.SINCE_REFUELING)
            mGlobalId.item.sinceRefuelingAvgSpeed=getSinceAvgSpeed(VehicleEvent.SINCE_REFUELING)
        }
        onSinceStartInfoNotify: {
            mGlobalId.item.sinceStartAvgFuel=getSinceAvgFuel(VehicleEvent.SINCE_START)
            mGlobalId.item.sinceStartAvgSpeed=getSinceAvgSpeed(VehicleEvent.SINCE_START)
            mGlobalId.item.sinceStartTravelTime=getSinceTravelTime(VehicleEvent.SINCE_START)
            mGlobalId.item.sinceStartTravelMileage=getSinceDrivingMileage(VehicleEvent.SINCE_START)
        }
        ///////////////////////////////////////
        /// ecoInfoNotify
        ///////////////////////////////////////
        onEcoInfoNotify: {
            mGlobalId.item.ecoEnabled=getEcoEnabled()
            mGlobalId.item.ecoState=getEcoShow()
            mGlobalId.item.ecoValue=getEcoValue()
        }
        ///////////////////////////////////////
        /// lpkInfoNotify
        ///////////////////////////////////////
        onLpkInfoNotify: {
            mGlobalId.item.lpk=getLpk()
            mGlobalId.item.lpkUnitIndex=getLpkUnit()
        }
        ///////////////////////////////////////
        /// idleInfoNotify
        ///////////////////////////////////////
        onIdleInfoNotify: {
            mGlobalId.item.idleTimeMode=getIStopTimeMode()
            mGlobalId.item.idleUseTime=getIStopUseTime()
            mGlobalId.item.idleStartSavingsFuel=getIStopStartSavingsFuel()
            mGlobalId.item.idleResetSavingsFuel=getIStopResetSavingsFuel()
            mGlobalId.item.idleStartTotalTime=getIStopStartTotalTime()
            mGlobalId.item.idleResetTotalTime=getIStopResetTotalTime()
        }
        ///////////////////////////////////////
        /// cruiseInfoNotify
        ///////////////////////////////////////
        onCruiseInfoNotify: {
            mGlobalId.item.cruiseState=getCruiseState()
            mGlobalId.item.cruiseSpeedSet=getCruiseSpeedSet()
            mGlobalId.item.cruiseSpeedUnit=getCruiseSpeedUnit()
            mGlobalId.item.cruiseLimState=getLimSpeedState()
            mGlobalId.item.cruiseSetSpeedState=getCruiseSpeedState()

            mGlobalId.item.cruiseSpeed=getCruiseSetSpeed()

            mGlobalId.item.cruiseAccFollowDistacnce=getCruiseAccFollowDistance()
            mGlobalId.item.cruiseAccFrontCarState=getCruiseAccFrontCarState()
            mGlobalId.item.cruiseAccDistacnceColor=getCruiseAccDistanceColor()
            mGlobalId.item.cruiseAccState=getCruiseAccState()
            mGlobalId.item.cruiseAccInterfaceState=getCruiseAccInterfaceState()

            mGlobalId.item.cruiseLimSpeed=getCruiseLimitSpeed()
            var downhillState=getCruiseDownHillSpeedState()
            mGlobalId.item.cruiseDownHillSpeedState=downhillState
            if(mGlobalId.item.alarmTable[30]!==downhillState){
                mGlobalId.item.alarmTable[30]=downhillState
                mGlobalId.item.alarmChanged=!mGlobalId.item.alarmChanged
            }
        }
        ///////////////////////////////////////
        /// waterInfoNotify
        ///////////////////////////////////////
        onWaterInfoNotify: {
            mGlobalId.item.waterTemp=getWaterTemp()
            mGlobalId.item.waterTempPercentage=getWaterTempPercentage()
            mGlobalId.item.waterLevel=getWaterTempState()
            //console.log("[onWaterInfoNotify waterTemp:"+mGlobalId.item.waterTemp+"]")
        }
        ////////////////////////////////
        // brightInfoNotify
        ////////////////////////////////
        onBrightInfoNotify: {
            mGlobalId.item.brightness=getBright()
            mGlobalId.item.brightMode=getBrightMode()
            mGlobalId.item.brightSetMode=getBrightSetMode()
            mGlobalId.item.lightBrightness=getLightBright()
            mGlobalId.item.darkBrightness=getDarkBright()
//            console.log("[onBrightInfoNotify brightness:"+mGlobalId.item.brightness)
//            console.log("[onBrightInfoNotify brightMode:"+mGlobalId.item.brightMode)
//            console.log("[onBrightInfoNotify brightSetMode:"+mGlobalId.item.brightSetMode)
//            console.log("[onBrightInfoNotify lightBrightness:"+mGlobalId.item.lightBrightness)
//            console.log("[onBrightInfoNotify darkBrightness:"+mGlobalId.item.darkBrightness)
        }
        ////////////////////////////////
        // swcInfoNotify
        ////////////////////////////////
        onSwcInfoNotify: swcInput(getSwcKey(), getSwcState())
        ////////////////////////////////
        // radarInfoNotify
        ////////////////////////////////
        onRadarInfoNotify: {
            mGlobalId.item.radarFrontLeft=getRadarFrontDistance(VehicleEvent.RADAR_FRONT_L)
            mGlobalId.item.radarFrontLeftMiddle=getRadarFrontDistance(VehicleEvent.RADAR_FRONT_LM)
            mGlobalId.item.radarFrontCenter=getRadarFrontDistance(VehicleEvent.RADAR_FRONT_C)
            mGlobalId.item.radarFrontRightMiddle=getRadarFrontDistance(VehicleEvent.RADAR_FRONT_RM)
            mGlobalId.item.radarFrontRight=getRadarFrontDistance(VehicleEvent.RADAR_FRONT_R)

            mGlobalId.item.radarFrontLeftLevel=getRadarFrontState(VehicleEvent.RADAR_FRONT_L)
            mGlobalId.item.radarFrontLeftMiddleLevel=getRadarFrontState(VehicleEvent.RADAR_FRONT_LM)
            mGlobalId.item.radarFrontCenterLevel=getRadarFrontState(VehicleEvent.RADAR_FRONT_C)
            mGlobalId.item.radarFrontRightMiddleLevel=getRadarFrontState(VehicleEvent.RADAR_FRONT_RM)
            mGlobalId.item.radarFrontRightLevel=getRadarFrontState(VehicleEvent.RADAR_FRONT_R)

            mGlobalId.item.radarRearLeft=getRadarRearDistance(VehicleEvent.RADAR_REAR_L)
            mGlobalId.item.radarRearLeftMiddle=getRadarRearDistance(VehicleEvent.RADAR_REAR_LM)
            mGlobalId.item.radarRearCenter=getRadarRearDistance(VehicleEvent.RADAR_REAR_C)
            mGlobalId.item.radarRearRightMiddle=getRadarRearDistance(VehicleEvent.RADAR_REAR_RM)
            mGlobalId.item.radarRearRight=getRadarRearDistance(VehicleEvent.RADAR_REAR_R)

            mGlobalId.item.radarRearLeftLevel=getRadarRearState(VehicleEvent.RADAR_REAR_L)
            mGlobalId.item.radarRearLeftMiddleLevel=getRadarRearState(VehicleEvent.RADAR_REAR_LM)
            mGlobalId.item.radarRearCenterLevel=getRadarRearState(VehicleEvent.RADAR_REAR_C)
            mGlobalId.item.radarRearRightMiddleLevel=getRadarRearState(VehicleEvent.RADAR_REAR_RM)
            mGlobalId.item.radarRearRightLevel=getRadarRearState(VehicleEvent.RADAR_REAR_R)

            mGlobalId.item.radarEnabled++ //getRadarShow()
            //console.log("[radarFrontLeft: "+mGlobalId.item.radarFrontLeft+"]")
            //console.log("[radarEnabled: "+mGlobalId.item.radarEnabled+"]")
        }
        ////////////////////////////////
        // trackInfoNotigy
        ////////////////////////////////
        onTrackInfoNotify: {
            mGlobalId.item.angle=-getTrackAngel()
        }
        ////////////////////////////////
        // versionNotify
        ////////////////////////////////
        onVersionNotify: {
            mGlobalId.item.mcuVersion=getVersion()
            //console.log("xxxxxxxxx mcuVersion:"+mGlobalId.item.mcuVersion)
        }
        ////////////////////////////////
        // rtcInfoNotify
        ////////////////////////////////
        onRtcInfoNotify: {
            var temp=getRtc().split(" ")
            var time=temp[1].split(":")
            mGlobalId.item.rtcDate=temp[0]
            mGlobalId.item.rtcTime=Funcs.prefixInteger(time[0], 2)+":"+Funcs.prefixInteger(time[1], 2)
            mGlobalId.item.dateTime[0]=temp[0]
            mGlobalId.item.dateTime[1]=temp[1]
            mGlobalId.item.dateTime[2]=temp[2]
            mGlobalId.item.dateTime[3]=time[0]
            mGlobalId.item.dateTime[4]=time[1]
//            console.log("[onRtcInfoNotify:"+getRtc())
//            console.log("[onRtcInfoNotify Date:"+mGlobalId.item.rtcDate)
//            console.log("[onRtcInfoNotify Time:"+mGlobalId.item.rtcTime)
        }
        ////////////////////////////////
        // gearInfoNotify
        ////////////////////////////////
        onGearInfoNotify: {
            // for JLY/DSXW/LZ
            mGlobalId.item.gearString=getGear()
            //console.log("[onGearInfoNotify gearString:"+mGlobalId.item.gearString)
            // for TESLA
            mGlobalId.item.gear=getGearIndex()
            // for Trucks (Pickup/Jeep)
            mGlobalId.item.gearHasAwd=getHas4WD()
            if(mGlobalId.item.gearHasAwd){
                mGlobalId.item.gearAwd=get4WDGear()
                mGlobalId.item.gearAwdFlicker=get4WDFlicker()
            }
        }
        ////////////////////////////////
        // accInfoNotify
        ////////////////////////////////
        onAccInfoNotify: {
            mGlobalId.item.acc=getAcc()
            mGlobalId.item.coldIap=getColdIap()
            //console.log("[onAccInfoNotify: acc="+mGlobalId.item.acc+"]")
        }
        ////////////////////////////////
        // splashEndNotify
        ////////////////////////////////
        onSplashEndNotify: {
            mGlobalId.item.splashEnd=getSplashEnd()
            //console.log("[onSplashEndNotify splashEnd="+mGlobalId.item.splashEnd+"]")
        }
        ////////////////////////////////
        // turnLightInfoNotify
        ////////////////////////////////
        onTurnLightInfoNotify: {
            mGlobalId.item.turnLeftLight=getTurnLeftLight()
            mGlobalId.item.turnRightLight=getTurnRightLight()
//            console.log("[onTurnLightInfoNotify turnLeftLight:"+mGlobalId.item.turnLeftLight+"]")
//            console.log("[onTurnLightInfoNotify turnRightLight:"+mGlobalId.item.turnRightLight+"]")
        }
        ////////////////////////////////
        // maintentInfoNotify
        ////////////////////////////////
        onMaintentInfoNotify: {
            var id=getMainTainId()
            if(id>7){
                //console.log(".")
                return
            }
            var duration=Number(getMainTainDuration()*1000)
            mGlobalId.item.mainTentState[id]=getMainTainState(id)
            mGlobalId.item.mainTentMileage[id]=getMainTainMileage(id)
            mGlobalId.item.mainTentYear[id]=getMainTainYear(id)
            mGlobalId.item.mainTentMonth[id]=getMainTainMonth(id)
            mGlobalId.item.mainTentDay[id]=getMainTainDay(id)
            mGlobalId.item.mainTentReminder[id]=getMainTainReminder(id)
            if(mGlobalId.item.mainTentId!==id){
                if(getMainTainDuration()!==0){
                    mGlobalId.item.mainTentId=id
                    // for changed
                    if(mGlobalId.item.mainTentDuration===duration){
                        if(duration)
                            mGlobalId.item.mainTentDuration=duration+10
                        else
                            mGlobalId.item.mainTentDuration=duration
                    }else
                        mGlobalId.item.mainTentDuration=duration
                }
            }
            else{
                if(mGlobalId.item.mainTentDuration!==duration){
                    mGlobalId.item.mainTentDuration=duration
                }else{
                    if(duration)
                        mGlobalId.item.mainTentDuration=duration+10
                    else
                        mGlobalId.item.mainTentDuration=duration
                }
            }
//            console.log("----------------------------------------------")
//            console.log("[onMaintentInfoNotify: mainTentId="+mGlobalId.item.mainTentId+"]")
//            console.log("[onMaintentInfoNotify: mainTentState="+mGlobalId.item.mainTentState[id]+"]")
//            console.log("[onMaintentInfoNotify: mainTentReminder="+mGlobalId.item.mainTentReminder[id]+"]")
//            console.log("[onMaintentInfoNotify: mainTentMileage="+mGlobalId.item.mainTentMileage[id]+"]")
//            console.log("[onMaintentInfoNotify: mainTentDuration="+mGlobalId.item.mainTentDuration+"]")
            mGlobalId.item.mainTentChanged=!mGlobalId.item.mainTentChanged
        }
        ////////////////////////////////
        // overSpeedWarningNotify
        ////////////////////////////////
        onOverSpeedWarningNotify: {
            mGlobalId.item.overSpeedWarningEnabled=getOverSpeedWarningEnabled()
            mGlobalId.item.overSpeedWarningState=getOverSpeedWarningShow()
            mGlobalId.item.overSpeedWarningSpeed=getOverSpeedWarningSpeed()
            //console.log("[onOverSpeedWarningNotify overSpeedWarningEnabled: "+mGlobalId.item.overSpeedWarningEnabled+"]")
            //console.log("[onOverSpeedWarningNotify overSpeedWarningState: "+mGlobalId.item.overSpeedWarningState+"]")
            //console.log("[onOverSpeedWarningNotify overSpeedWarningSpeed: "+mGlobalId.item.overSpeedWarningSpeed+"]")
        }
        ////////////////////////////////
        // vehicleInfoNotify
        ////////////////////////////////
        onVehicleInfoNotify: {
            //mGlobalId.item.metricSystem=!getMph();
            //mGlobalId.item.vehicleColor=getVehicleColor()
            //mGlobalId.item.vehicleModel=getVehicleModel()
            mGlobalId.item.oilDepthPercentage=getOilDepthPercentage()
            mGlobalId.item.vehicleVIN=getVIN()

            mGlobalId.item.oilPressurePercentage=getOilPressure() //getOilPercentage()
            mGlobalId.item.batterVoltage=getBatteryVoltage()//.toFixed(1)
            mGlobalId.item.gearBoxTemp=getGearBoxTemp()
            mGlobalId.item.gearBoxTempPercentage=getGearBoxTempPercentage()
            mGlobalId.item.outSideTemp=getOutSideTemp()
            mGlobalId.item.inSideTemp=getInSideTemp()
            mGlobalId.item.oilTempPercentage=getOilTempPercentage()
            mGlobalId.item.oilTemp=getOilTemp()
            mGlobalId.item.diffOilTemp=getDiffOilTemp()
            mGlobalId.item.reverseAlarmEnabled=getReverseAlarm()
        }
        ////////////////////////////////
        // hudInfoNotify
        ////////////////////////////////
        onHudInfoNotify: {

        }
        ////////////////////////////////
        ///  原车高配功能
        ////////////////////////////////
        ////////////////////////////////
        ///  crawlInfoNotify
        ////////////////////////////////
        onCrawlInfoNotify: {
            mGlobalId.item.crawlLevel=getCrawlLevel()
        }
        ////////////////////////////////
        ///  bsmInfoNotify
        ////////////////////////////////
        onBsmInfoNotify: {
            mGlobalId.item.bsmOn=getBsmOnOff()
            mGlobalId.item.bsmSensitivity=getBsmSensitivity()
            mGlobalId.item.bsmBright=getBsmBright()
            //console.log("[onBsmInfoNotify bsmOn="+mGlobalId.item.bsmOn+"]")
            mGlobalId.item.trucksSetupInfoChanged=!mGlobalId.item.trucksSetupInfoChanged
        }
        ////////////////////////////////
        ///  pcsInfoNotify
        ////////////////////////////////
        onPcsInfoNotify: {
            mGlobalId.item.pcsOn=getPcsOnOff()
            mGlobalId.item.pcsSensitivity=getPcsSensitivity()
            mGlobalId.item.trucksSetupInfoChanged=!mGlobalId.item.trucksSetupInfoChanged
        }
        ////////////////////////////////
        ///  roadModeInfoNotify
        ////////////////////////////////
        onRoadModeInfoNotify: {
            switch(Number(mTrucksModel)){
            // case 7: // everest
            //     switch(getDriverMode()){
            //     case 0:
            //         mGlobalId.item.offRoadMode=0
            //         break;
            //     case 1:
            //         mGlobalId.item.offRoadMode=1
            //         break;
            //     case 4:
            //         mGlobalId.item.offRoadMode=2
            //         break;
            //     case 8:
            //         mGlobalId.item.offRoadMode=3
            //         break;
            //     }
            //     break;
            default:
                mGlobalId.item.roadMode=getRoadMode()
                break;
            }
        }
        ////////////////////////////////
        ///  driverModeInfoNotify
        ////////////////////////////////
        onDriverModeInfoNotify: {
            mGlobalId.item.driverMode=getDriverMode()
        }
        ////////////////////////////////
        ///  fourWDInfoNotify
        ////////////////////////////////
        onFourWDInfoNotify: {
            mGlobalId.item.aWDState[0]=getAwdState(0)
            mGlobalId.item.aWDState[1]=getAwdState(1)
            mGlobalId.item.aWDState[2]=getAwdState(2)
            mGlobalId.item.aWDState[3]=getAwdState(2)
            mGlobalId.item.aWDState[4]=getAwdState(3)
            mGlobalId.item.aWDChanged=!mGlobalId.item.mGlobal4WDChanged
        }
        ////////////////////////////////
        ///  pbdInfoNotify
        ////////////////////////////////
        onPbdInfoNotify: {
            mGlobalId.item.pbdSystem=getPbdSystem()
            mGlobalId.item.pbdKickSensor=getPbdKicksersor()
            mGlobalId.item.pbdVolume=getPbdVolume()
            mGlobalId.item.pbdAngle=getPbdAngle()
        }
        ////////////////////////////////
        /// rearHvacInfoNotify
        ////////////////////////////////
        onRearHvacInfoNotify: {
            mGlobalId.item.rearHvacMode=getRearHvacMode()
            mGlobalId.item.rearHvacFanSpeed=getRearHvacFan()
            mGlobalId.item.rearHvacAuto=getRearHvacAuto()
            mGlobalId.item.rearHvacAc=getRearHvacAc()
            // 暫時先屏蔽，因為上傳的是字符串
            //mGlobalId.item.rearHvacTemp=getRearHvacTemp()
            //mGlobalId.item.rearHvacTempF=getRearHvacTempF()
        }
        ////////////////////////////////
        ///  chassisInfoNotify
        ////////////////////////////////
        onChassisInfoNotify: {
            mGlobalId.item.chassisLiftState=getChassisLiftState()
            mGlobalId.item.chassisLiftUp=getChassisLiftUp()
            mGlobalId.item.chassisLiftDown=getChassisLiftDown()
            mGlobalId.item.chassisLiftDoing=getChassisLiftDoing()
            mGlobalId.item.chassisLiftEnable=getChassisEnable()
        }
        ////////////////////////////////
        ///  ldaInfoNotify
        ////////////////////////////////
        onLdaInfoNotify: {
            mGlobalId.item.ldaRightLaneState=getRightLaneState()
            mGlobalId.item.ldaRightLaneFlicker=getRightLaneFlicker()
            mGlobalId.item.ldaLeftLaneState=getLeftLaneState()
            mGlobalId.item.ldaLeftLaneFlicker=getLeftLaneFlicker()
            mGlobalId.item.ldaRightArrow=getRightArrow()
            mGlobalId.item.ldaLeftArrow=getLeftArrow()
        }
        ////////////////////////////////
        ///  benzLampInfoNotify
        ////////////////////////////////
        onBenzLampInfoNotify: {
            mGlobalId.item.benzCSetupInfo[25]=getBenzSurroundLighting()
            mGlobalId.item.benzCSetupInfo[15]=getBenzLightingDelay()
            //mGlobalId.item.benzSurroundLighting=getBenzSurroundLighting()
            mGlobalId.item.benzInteriorLightingDelay=getBenzLightingDelay()
            mGlobalId.item.benzSetupInfoChanged=!mGlobalId.item.benzSetupInfoChanged
        }
        ////////////////////////////////
        ///  benzSetupInfoNotify
        ////////////////////////////////
        onBenzSetupInfoNotify: {
            mGlobalId.item.benzCSetupInfo[16]=getBenzDoorAutoLock()
            //mGlobalId.item.benzDoorAutoLock=getBenzDoorAutoLock()
            mGlobalId.item.benzCSetupInfo[17]=getBenzDoorLockSound()
            //mGlobalId.item.benzDoorLockSound=getBenzDoorLockSound()
            mGlobalId.item.benzCSetupInfo[31]=getBenzRainfallSensorSensitivity()
            //mGlobalId.item.benzDoorRainfallSensor=getBenzRainfallSensorSensitivity()
            mGlobalId.item.benzCSetupInfo[4]=getBenzSpeedLimited()
            //mGlobalId.item.benzDoorSpeedLimited=getBenzSpeedLimited()
            mGlobalId.item.benzSetupInfoChanged=!mGlobalId.item.benzSetupInfoChanged
        }
        ////////////////////////////////
        ///  benzAllSetupInfoNotify
        ////////////////////////////////
        onBenzAllSetupInfoNotify: {
            mGlobalId.item.benzCSetupInfo[4]=getBenzAllSetup(4)
            mGlobalId.item.benzCSetupInfo[15]=getBenzAllSetup(15)
            mGlobalId.item.benzCSetupInfo[16]=getBenzAllSetup(16)
            mGlobalId.item.benzCSetupInfo[20]=getBenzAllSetup(20)
            mGlobalId.item.benzCSetupInfo[24]=getBenzAllSetup(24)
            mGlobalId.item.benzCSetupInfo[25]=getBenzAllSetup(25)       // 环境照明功能
            mGlobalId.item.benzCSetupInfo[26]=getBenzAllSetup(26)
            mGlobalId.item.benzCSetupInfo[27]=getBenzAllSetup(27)
            mGlobalId.item.benzCSetupInfo[28]=getBenzAllSetup(28)
            mGlobalId.item.benzCSetupInfo[29]=getBenzAllSetup(29)
            mGlobalId.item.benzCSetupInfo[30]=getBenzAllSetup(30)
            mGlobalId.item.benzSetupInfoChanged=!mGlobalId.item.benzSetupInfoChanged
        }
        ////////////////////////////////
        ///  jeepInfoNotify
        ////////////////////////////////
        onJeepInfoNotify: {

        }
        ////////////////////////////////
        ///  mediaCurrentInfoNotify
        ////////////////////////////////
        onMediaCurrentInfoNotify:{
            mGlobalId.item.mediaCurrentInfo=getMediaCurrentInfo()
            mGlobalId.item.mediaCurrentSource=getMediaCurrentSource()
        }
        ////////////////////////////////
        ///  mediaListInfoNotify
        ////////////////////////////////
        onMediaListInfoNotify: {
            mGlobalId.item.mediaListShow=getMediaListShow()
            mGlobalId.item.mediaListPlayingIndex=getMediaListPlayingIndex()
            mGlobalId.item.mediaListCursorIndex=getMediaListCursorIndex()
            mGlobalId.item.mediaListScrollback=getMediaListScrollback()
            mGlobalId.item.mediaListTrackTotal=getMediaListTrackTotal()
            mGlobalId.item.mediaListTrackCurrent=getMediaListTrackCurrent()
            mGlobalId.item.mediaListWinShowMax=getMediaListWinShowMax()
            mGlobalId.item.mediaListTitle=getMediaLis

            mGlobalId.item.mediaListTitle=""
            mGlobalId.item.mediaListItem1=""
            mGlobalId.item.mediaListItem2=""
            mGlobalId.item.mediaListItem3=""
            mGlobalId.item.mediaListItem4=""
            mGlobalId.item.mediaListItem5=""

            var temp=getMediaItems().split("#")
            mGlobalId.item.mediaListItemCount=temp.length
            if(mGlobalId.item.mediaListItemCount>=1)
                mGlobalId.item.mediaListTitle=temp[0]
            if(mGlobalId.item.mediaListItemCount>=2)
                mGlobalId.item.mediaListItem1=temp[1]
            if(mGlobalId.item.mediaListItemCount>=3)
                mGlobalId.item.mediaListItem2=temp[2]
            if(mGlobalId.item.mediaListItemCount>=4)
                mGlobalId.item.mediaListItem3=temp[3]
            if(mGlobalId.item.mediaListItemCount>=5)
                mGlobalId.item.mediaListItem4=temp[4]
            if(mGlobalId.item.mediaListItemCount>=6)
                mGlobalId.item.mediaListItem5=temp[5]
        }
        ////////////////////////////////
        ///  dialogInfoNotify
        ////////////////////////////////
        onDialogInfoNotify: {
            var duration;
            if(!getNotifyIsEmpty()){
                var temp=getNotifyInfo().split("#")
                mGlobalId.item.notifyText=Number(temp[0])
                mGlobalId.item.notifyIcon=Number(temp[1])
                duration=(Number(temp[2])*1000)
                // changed 效果
                if(mGlobalId.item.notifyDuration===duration){
                    if(duration)
                        mGlobalId.item.notifyDuration=(duration+10)
                    else
                        mGlobalId.item.notifyDuration=duration
                }else
                    mGlobalId.item.notifyDuration=duration
//                console.log("--------------------------------------------------------")
//                console.log("[onDialogInfoNotify notifyText:"+mGlobalId.item.notifyText+"]")
//                console.log("[onDialogInfoNotify notifyIcon:"+mGlobalId.item.notifyIcon+"]")
//                console.log("[onDialogInfoNotify temp[2]:"+duration+"]")
//                console.log("[onDialogInfoNotify notifyDuration:"+mGlobalId.item.notifyDuration+"]")
//                console.log("[onDialogInfoNotify nofifyDpf:"+mGlobalId.item.nofifyDpf+"]")
//                console.log("[onDialogInfoNotify nofifyU16:"+mGlobalId.item.nofifyU16+"]")
//                console.log("--------------------------------------------------------")
            }
            //dialog_notify()
        }
//        function dialog_notify(){
//            if(mGlobalId.item.notifyShow){
//                //console.log("Notify is on top side already!")
//                return
//            }else{
//                //console.log("Notify will display soon!")
//                if(!getNotifyIsEmpty()){
//                    var temp=getNotifyInfo().split("#")
//                    mGlobalId.item.notifyText=Number(temp[0])
//                    mGlobalId.item.notifyIcon=Number(temp[1])
//                    var duration=Number(temp[2])*1000
//                    if(mGlobalId.item.notifyDuration!==duration){
//                        if(duration)
//                            mGlobalId.item.notifyDuration=duration+10
//                        else
//                            mGlobalId.item.notifyDuration=duration
//                    }else
//                        mGlobalId.item.notifyDuration=duration
//                    if(mGlobalId.item.notifyDuration)
//                        mGlobalId.item.notifyShow=1
//                    else{
//                        mGlobalId.item.notifyShow=0
//                        mEventHandleId.item.getNotify()
//                    }
//                }
//            }
//        }
        ////////////////////////////////
        ///  powerRecycleInfoNotify
        ////////////////////////////////
        onPowerRecycleInfoNotify: {
            mGlobalId.item.energyDynamic=getKersDynamic()
            mGlobalId.item.energyChargePower=getKersChargePower()
            mGlobalId.item.energyEcoMile=getKersEcoMileage()
            mGlobalId.item.energyBatteryPower=getKersBatteryPower()
            mGlobalId.item.energyBatteryMile=getKersBatteryMile()
        }
        ////////////////////////////////
        ///  adblueInfoNotify
        ////////////////////////////////
        onAdblueInfoNotify: {
            mGlobalId.item.adblueEnable=getAdblueEnabled()
            mGlobalId.item.adblueColor=getAdblueColor()
            mGlobalId.item.adblueMileage=getAdblueMileage()
        }
        ////////////////////////////////
        ///  pwsInfoNotify
        ////////////////////////////////
        onPwsInfoNotify: {
            for(var i=0;i<8;i++)
                mGlobalId.item.pwsState[Number(i)]=getPwsTarget(Number(i))
            mGlobalId.item.pwsShow=getPwsShow()
            switch(mGlobalId.item.pwsShow){
            case 0:
                mGlobalId.item.pwsShowChanged=0
                break;
            case 1:
            case 2:
                mGlobalId.item.pwsShowChanged++
                break;
            }
        }
        ////////////////////////////////
        ///  dpcInfoNotify
        ////////////////////////////////
        onDpcInfoNotify: {
            mGlobalId.item.dpcFrontLeft=getDpcFrontLevel(0)
            mGlobalId.item.dpcFrontRight=getDpcFrontLevel(1)
            mGlobalId.item.dpcRearLeft=getDpcRearLevel(0)
            mGlobalId.item.dpcRearRight=getDpcRearLevel(1)
        }
        ////////////////////////////////
        ///  trucksTrailerInfoNotify
        ////////////////////////////////
        onTrucksTrailerInfoNotify: {
            mGlobalId.item.trucksTrailerDistance=getTrucksTrailerDistance()
            mGlobalId.item.trucksTrailerGain=getTrucksTrailerGain()
            mGlobalId.item.trucksOilLifePercentage=getTrucksTrailerOilLifePercentage()
            mGlobalId.item.trucksOilLifeTripRaw=getTrucksTrailerOilLifeTrip()
            mGlobalId.item.trucksFrontRadarState=getTrucksTrailerFrontRadarState()
            mGlobalId.item.trucksRearRadarState=getTrucksTrailerRrearRadarState()
            mGlobalId.item.trucksOilPressure=getTrucksTrailerOilPressure()
        }
        ////////////////////////////////
        ///  trucksShiftInfoNotify
        ////////////////////////////////
        onTrucksShiftInfoNotify: {
            mGlobalId.item.trucksShiftState=getTrucksShiftState()
            mGlobalId.item.trucksShiftGear=getTrucksShiftGear()
        }
        ////////////////////////////////
        ///  trucksInfoNotify
        ////////////////////////////////
        onTrucksInfoNotify: {
            for(var i=0;i<mGlobalId.item.trucksSetupInfo.length-1;i++)
                mGlobalId.item.trucksSetupInfo[i]=getTruckSetup(i)
            mGlobalId.item.trucksSetupInfoChanged=!mGlobalId.item.trucksSetupInfoChanged
        }
        ////////////////////////////////
        ///  fordInfoNotify
        ////////////////////////////////
        onFordInfoNotify: {
            for(var i=0;i<mGlobalId.item.fordSetupInfo.length;i++){
                mGlobalId.item.fordSetupInfo[i]=Number(getFordSetup(i))
                //console.log("[onFordInfoNotify fordSetupInfo["+i+"]="+mGlobalId.item.fordSetupInfo[i]+"]")
            }
            //console.log("fordSetupInfo[79]="+mGlobalId.item.fordSetupInfo[79])
            mGlobalId.item.fordSetupInfo[84]=1 // MyKey狀態是一直顯示
            mGlobalId.item.fordSetupKnown=true
            mGlobalId.item.fordSetupInfoChanged=!mGlobalId.item.fordSetupInfoChanged
        }
        ////////////////////////////////
        ///  offRoadInfoNotify
        ////////////////////////////////
        onOffRoadInfoNotify: {
            mGlobalId.item.truckOffRoadDiffLock=getOffRoadDiffLock()        // 差速锁
            mGlobalId.item.truckOffRoadESP=getOffRoadESP()                  // ESP OFF
            mGlobalId.item.truckOffRoadHDC=getOffRoadHDC()                  // 下坡辅助 Hill Descent Control
            mGlobalId.item.truckOffRoadMode=getOffRoadMode()                // OFF ROAD MODE
            mGlobalId.item.truckOffRoadCamera=getOffRoadCamera()            // 越野摄像头
        }
        ////////////////////////////////
        ///  bmwSetupInfoNotify
        ////////////////////////////////
        onBmwSetupInfoNotify: {
            mGlobalId.item.bmwSetupInfo[1]=getBmwHomeLight()                // 1  回家照明
            mGlobalId.item.bmwSetupInfo[2]=getBmwTurnLight3Times()          // 2  转向灯亮 3 次
            mGlobalId.item.bmwSetupInfo[3]=getBmwDrl()                      // 3  日间行车灯
            mGlobalId.item.bmwSetupInfo[4]=getBmwDoorUnlock()               // 4  开锁
            mGlobalId.item.bmwSetupInfo[5]=getBmwAutomaticSeatAdjustment()  // 5  座椅自动调整
            mGlobalId.item.bmwSetupInfo[6]=getBmwAutomaticReLock()          // 6  自动重锁
            mGlobalId.item.bmwSetupInfo[7]=getBmwInterlockingAfterDriving() // 7  行车后联锁
            mGlobalId.item.bmwSetupInfo[8]=getBmwFlashingWhenLock()         // 8  上锁时闪烁
            mGlobalId.item.bmwSetupInfo[9]=getBmwFlashingWhenUnLock()       // 9  解锁时闪烁
            mGlobalId.item.bmwSetupInfo[10]=0                               // 10 胎压初始化
            mGlobalId.item.bmwSetupInfo[11]=getBmwLampBrightness()          // 11 灯光调节

            mGlobalId.item.bmwSetupInfoChanged=!mGlobalId.item.bmwSetupInfoChanged

//            mGlobalId.item.bmwHomeLight=getBmwHomeLight()
//            mGlobalId.item.bmwTurnLightThirdTimes=getBmwTurnLight3Times()
//            mGlobalId.item.bmwDRL=getBmwDrl()
//            mGlobalId.item.bmwDoorUnLock=getBmwDoorUnlock()
//            mGlobalId.item.bmwAutoSeatAdjust=getBmwAutomaticSeatAdjustment()
//            mGlobalId.item.bmwAutoRelock=getBmwAutomaticReLock()
//            mGlobalId.item.bmwIntetLock=getBmwInterlockingAfterDriving()
//            mGlobalId.item.bmwLockFlashing=getBmwFlashingWhenLock()
//            mGlobalId.item.bmwUnLocFlashing=getBmwFlashingWhenUnLock()
//            mGlobalId.item.bmwLightBrightness=getBmwLampBrightness()
        }
        ////////////////////////////////
        ///  bmwMSetupInfoNotify
        ////////////////////////////////
        onBmwMSetupInfoNotify: {
            mGlobalId.item.bmwDonglixiangying=getBmwMDonglixiangying()
            mGlobalId.item.bmwXuanguaxiangying=getBmwMXuanguaxiangying()
            mGlobalId.item.bmwZhuanxiangxiangying=getBmwMZhuanxiangxiangying()
            mGlobalId.item.bmwlHuandangchengxu=getBmwMHuandangchengxu()
            mGlobalId.item.bmwJiashimoshiqiehuan=getBmwMJiashimoshiqiehuan()
        }
        ////////////////////////////////
        ///  oilMeterInfoNotify
        ////////////////////////////////
        onOilMeterInfoNotify: {
            mGlobalId.item.engOilPercent=getOilPressure()
            mGlobalId.item.engOilStrIndex=getOilStr()
        }
        ////////////////////////////////
        ///  benzS600SetupInfoNotify and benzCSetupInfoNotify
        ////////////////////////////////
        onBenzS600SetupInfoNotify: {
            // 32, 1, 33, 34, 11, 35, 36, 8, 37, 17, 9, 38, 4,
            mGlobalId.item.benzCSetupInfo[32]=getBenzDipanMode()
            mGlobalId.item.benzCSetupInfo[1]=getBenzEspSwitch()
            mGlobalId.item.benzCSetupInfo[33]=getBenzRadarSwitch()
            mGlobalId.item.benzCSetupInfo[34]=getBenzCameraR()
            mGlobalId.item.benzCSetupInfo[11]=getBenzDayLightSwitch()
            mGlobalId.item.benzCSetupInfo[35]=getDistanceWarning()
            mGlobalId.item.benzCSetupInfo[36]=getPianliWarning()
            mGlobalId.item.benzCSetupInfo[8]=getZhinengzhaoming()
            mGlobalId.item.benzCSetupInfo[37]=getAnquandaitiaojie()
            mGlobalId.item.benzCSetupInfo[17]=getZhongyangmensuofankui()
            mGlobalId.item.benzCSetupInfo[9]=getJinguangdeng()
            mGlobalId.item.benzCSetupInfo[38]=getZishiyingdadeng()
            mGlobalId.item.benzCSetupInfo[4]=getBenzSpeedLimited()
//            console.log("[onBenzS600SetupInfoNotify BenzDipanMode="+mGlobalId.item.benzCSetupInfo[32]+"]")

//            mGlobalId.item.benzSSetupInfo[0]=getBenzDipanMode()
//            mGlobalId.item.benzSSetupInfo[1]=getBenzEspSwitch()
//            mGlobalId.item.benzSSetupInfo[2]=getBenzRadarSwitch()
//            mGlobalId.item.benzSSetupInfo[3]=getBenzCameraR()
//            mGlobalId.item.benzSSetupInfo[4]=getBenzDayLightSwitch()
//            mGlobalId.item.benzSSetupInfo[5]=getDistanceWarning()
//            mGlobalId.item.benzSSetupInfo[6]=getPianliWarning()
//            mGlobalId.item.benzSSetupInfo[7]=getZhinengzhaoming()
//            mGlobalId.item.benzSSetupInfo[8]=getAnquandaitiaojie()
//            mGlobalId.item.benzSSetupInfo[9]=getZhongyangmensuofankui()
//            mGlobalId.item.benzSSetupInfo[10]=getJinguangdeng()
//            mGlobalId.item.benzSSetupInfo[11]=getZishiyingdadeng()
//            mGlobalId.item.benzSSetupInfo[12]=getBenzEspTestMode()
            mGlobalId.item.benzSSetupInfoChanged=!mGlobalId.item.benzSSetupInfoChanged
        }
        ////////////////////////////////
        ///  benzCSetupInfoNotify
        ////////////////////////////////
        onBenzCSetupInfoNotify: {
            mGlobalId.item.benzCSetupInfo[1]=getBenzEspSwitch()                 // ESP
            mGlobalId.item.benzCSetupInfo[2]=getBenzCpaPlusSwitch()             // 碰撞预防辅 助系统增强版
            mGlobalId.item.benzCSetupInfo[3]=getBenzAttentionAssist()           // 注意力辅助系统
//            if(getBenzSpeedLimited()===0)
//                mGlobalId.item.benzCSetupInfo[4]=0
//            else
//                mGlobalId.item.benzCSetupInfo[4]=(250-getBenzSpeedLimited)/10   // 速度限制(冬季轮胎)
            mGlobalId.item.benzCSetupInfo[4]=getBenzSpeedLimited()              // 速度限制(冬季轮胎)
            //mGlobalId.item.benzCSetupInfo[5]=1                                // 轮胎压力 低压续跑指示器启用
            mGlobalId.item.benzCSetupInfo[6]=getBenzCMangdianfuzhu()            // 盲点辅助系统
            mGlobalId.item.benzCSetupInfo[7]=getBenzCChedaobaochi()             // 车道保持辅助系统
            mGlobalId.item.benzCSetupInfo[8]=getBenzCZhinengzhaoming()          // 智能照明系统
            mGlobalId.item.benzCSetupInfo[9]=getBenzCJinguangdeng()             // 近光灯设置
            // 下面是老C、E级需要添加的
            mGlobalId.item.benzCSetupInfo[10]=getBenzCLiangdu()                 // 亮度
            mGlobalId.item.benzCSetupInfo[11]=getBenzCRijianXinchengdeng()      // 日间行车灯
            mGlobalId.item.benzCSetupInfo[12]=getBenzCFenWeiLiangDu()           // 环境氛围照明亮度
            mGlobalId.item.benzCSetupInfo[13]=getBenzCFenweiyanse()             // 环境氛围照明颜色
            mGlobalId.item.benzCSetupInfo[14]=getBenzCDingweizhaoming()         // 定位照明
            mGlobalId.item.benzCSetupInfo[15]=getBenzCZhaomingyanshi()          // 车内照明延时
            mGlobalId.item.benzCSetupInfo[16]=getBenzCZidongchemensuo()         // 自动车门锁止
            mGlobalId.item.benzCSetupInfo[17]=getBenzCZhongyangmensuoshengyinfankui()   // 中央门锁声音反馈
            mGlobalId.item.benzCSetupInfo[18]=getBenzCFangbianchuru()           // 方便出入功能
            mGlobalId.item.benzCSetupInfo[19]=getBenzCAnquandaitiaojie()        // 安全带调节
            mGlobalId.item.benzCSetupInfo[20]=getBenzCZhediehoushijing()        // 当锁止时，折叠后视镜
            mGlobalId.item.benzCSetupInfo[21]=getBenzCRadarSensor()             // 雷达传感器
            mGlobalId.item.benzCSetupInfo[22]=getBenzCBrakeSystem()             // PRE-SAFE 制动系统
            mGlobalId.item.benzCSetupInfo[23]=getBenzCAEB()                     // 主动制动辅助系统

//            mGlobalBenzCInfo[18]=benzCAnquandaitiaojie
//            mGlobalBenzCInfo[19]=benzCZhediehoushijing
//            mGlobalBenzCInfo[20]=benzCRadarSensor
//            mGlobalBenzCInfo[21]=benzCBrakeSystem
//            mGlobalBenzCInfo[22]=benzCAEB

            mGlobalId.item.benzCSetupInfoChanged=!mGlobalId.item.benzCSetupInfoChanged
        }
        ////////////////////////////////
        ///  benzAdblueInfoNotify
        ////////////////////////////////
        onBenzAdblueInfoNotify: {
            mGlobalId.item.benzAdBlueVol=getBenzAdBlueVol()
            mGlobalId.item.benzAdBlueTextId=getBenzAdBlueTextId()
            mGlobalId.item.benzAdBlueTextMileage=getBenzAdBlueTextMileage()
        }
        ////////////////////////////////
        ///  benzCGearInfoNotify
        ////////////////////////////////
        onBenzCGearInfoNotify: {
            mGlobalId.item.benzCBopianJiantou=getBenzCBopianJiantou()
            mGlobalId.item.benzCBopianNumber=getBenzCBopianNumber()
        }
        ////////////////////////////////
        ///  benzCEcoInfoNotify
        ////////////////////////////////
        onBenzCEcoInfoNotify: {
            mGlobalId.item.benzCEcoJiasuStatus=getBenzCEcoJiasuStatus()//加速高亮状态
            mGlobalId.item.benzCEcoJiansuStatus=getBenzCEcoJiansuStatus()//减速高亮状态
            mGlobalId.item.benzCEcoPinghengStatus=getBenzCEcoPinghengStatus()//平衡高亮状态
            mGlobalId.item.benzCEcoZhengquanStatus=getBenzCEcoZhengquanStatus()//外圈整圈高亮状态
            mGlobalId.item.benzCEcoJiasuVol=getBenzCEcoJiasuVol()//加速百分比
            mGlobalId.item.benzCEcoJiansuVol=getBenzCEcoJiansuVol()//减速百分比
            mGlobalId.item.benzCEcoPinghengVol=getBenzCEcoPinghengVol()//平衡百分比
            mGlobalId.item.benzCEcoMileages=getBenzCEcoMileages()//启动后里程
            mGlobalId.item.benzCChargeBar=getBenzCChargeVol()//能量条百分比
        }
        ////////////////////////////////
        ///  benzLdaInfoNotify
        ////////////////////////////////
        onBenzLdaInfoNotify: {
            mGlobalId.item.benzCLDWS=getBenzCLdws()//车道保持辅助系统
            mGlobalId.item.benzCLKAS=getBenzCLkas()//转向辅助系统
            mGlobalId.item.benzCPTS=getBenzCPTS()//驻车辅助系统
        }
        ////////////////////////////////
        ///  benzCRadarInfoNotify
        ////////////////////////////////
        onBenzCRadarInfoNotify: {
            mGlobalId.item.benzRadarStatus=getBenzRadarStatus()
            mGlobalId.item.benzRadarFrontLeft=getBenzRadarFrontLeft()
            mGlobalId.item.benzRadarFrontRight=getBenzRadarFrontRight()
        }
        ////////////////////////////////
        ///  benzAccInfoNotify
        ////////////////////////////////
        onBenzAccInfoNotify: {
            mGlobalId.item.benzAccShow=getBenzAccShow()
            mGlobalId.item.benzAccLineColor=getBenzAccLineColor()
            mGlobalId.item.benzAccLineStatus=getBenzAccLineStatus()
            mGlobalId.item.benzAccCarColor=getBenzAccCarColor()
            mGlobalId.item.benzAccCarStatus=getBenzAccCarStatus()
            mGlobalId.item.benzAccCarDistance=getBenzAccCarDistance()
            mGlobalId.item.benzAccLineDistance=getBenzAccLineDistance()
        }
        ////////////////////////////////
        // attentionAssistNotify
        ////////////////////////////////
        onAttentionAssistNotify: {
            mGlobalId.item.attentionAssistFatigueBar=getAttentionAssistFatigueBar()
            mGlobalId.item.attentionAssistFatigueState=getAttentionAssistFatigueState()
            mGlobalId.item.attentionAssistDrivingHour=getAttentionAssistDrivingHour()
            mGlobalId.item.attentionAssistDrivingMin=getAttentionAssistDrivingMin()
        }
        /////////////////////////////
        // usb storage update
        /////////////////////////////
        onUsbUpdateFileNotify: {
            mGlobalId.item.updateSrotage=VehicleEvent.STORAGE_TYPE_USB

            if(!mGlobalId.item.mcuUpdatePercentage){
                // 如果mcu 升級進度不為0, 代表升級中，此時拔表U盤繼續升級
                mGlobalId.item.updateMcuCounts=getMcuUpdateFileCount(VehicleEvent.STORAGE_TYPE_USB);
            }
            mGlobalId.item.updateBtCounts=getBtUpdateFileCount(VehicleEvent.STORAGE_TYPE_USB);
            mGlobalId.item.updateSystemCounts=getSystemUpdateFileCount(VehicleEvent.STORAGE_TYPE_USB);
            //mGlobalId.item.shellCmdCounts=getShellCmdFileCount(VehicleEvent.STORAGE_TYPE_USB)
//            console.log("[onUsbUpdateFileNotify updateMcuCounts:"+mGlobalId.item.updateMcuCounts);
//            console.log("[onUsbUpdateFileNotify updateBtCounts:"+mGlobalId.item.updateBtCounts);
//            console.log("[onUsbUpdateFileNotify updateSystemCounts:"+mGlobalId.item.updateSystemCounts);
//            console.log("[onUsbUpdateFileNotify shellCmdCounts:"+mGlobalId.item.shellCmdCounts);
            //mPostMcuUpdateTimerId.restart()
        }
        Timer{
            id: mPostMcuUpdateTimerId
            interval: 100
            running: false
            onTriggered: {
                //mEventHandleId.item.setMcuUpdateFile(
                //    mEventHandleId.item.getMcuUpdateName(VehicleEvent.STORAGE_TYPE_USB, 0))
                //console.log("updateMcuCounts:"+mGlobalId.item.updateMcuCounts)
                for(var i=0;i<mGlobalId.item.updateMcuCounts;i++){
                    console.log("[MCU Update: "+mEventHandleId.item.getMcuUpdateName(i))
                }
            }
        }
        /////////////////////////////
        // usb update state
        /////////////////////////////
        onMcuUpdateStatusNotify: {
            mGlobalId.item.updateStatus=getMcuUpdateStatus()
            //console.log("[mcuUpdateStatusNotify updateStatus:"+mGlobalId.item.updateStatus+"]")
        }
        /////////////////////////////
        // usb update percentage
        /////////////////////////////
        onMcuUpdatePercentageNotify: {
            var temp=getMcuUpdatePercentage()
            mGlobalId.item.mcuUpdatePercentage=temp
            //console.log("[onMcuUpdatePercentageNotify: "+mGlobalId.item.mcuUpdatePercentage+"]")
        }
        /////////////////////////////
        // usb storage mount state
        /////////////////////////////
        onUsbMountStateChanged: {
            mGlobalId.item.usbMounted=getStorageState(VehicleEvent.STORAGE_TYPE_USB)
            if(!mGlobalId.item.usbMounted && !mGlobalId.item.mcuUpdatePercentage){
                mGlobalId.item.updateStatus=-1
                mGlobalId.item.updateMcuCounts=getMcuUpdateFileCount(VehicleEvent.STORAGE_TYPE_USB);
                mGlobalId.item.updateBtCounts=getBtUpdateFileCount(VehicleEvent.STORAGE_TYPE_USB);
                mGlobalId.item.updateSystemCounts=getSystemUpdateFileCount(VehicleEvent.STORAGE_TYPE_USB);
            }
        }
        /////////////////////////////
        // sd/tf storage mount state
        /////////////////////////////
        onSdMountStateChanged: {
            mGlobalId.item.sdMounted=getStorageState(VehicleEvent.STORAGE_TYPE_SD)
            if(!mGlobalId.item.sdMounted){
                mGlobalId.item.updateStatus=-1
                mGlobalId.item.updateMcuCounts=getMcuUpdateFileCount(VehicleEvent.STORAGE_TYPE_SD);
                mGlobalId.item.updateBtCounts=getBtUpdateFileCount(VehicleEvent.STORAGE_TYPE_SD);
                mGlobalId.item.updateSystemCounts=getSystemUpdateFileCount(VehicleEvent.STORAGE_TYPE_SD);
            }
        }
        ///////////////////////////////////////
        /// Pitch/Roll pitchRollNotify
        ///////////////////////////////////////
        onPitchRollNotify: {
            if(mGlobalId.item.mGyroCalibration){
                mGlobalId.item.mRollOffst=getRoll()
                mGlobalId.item.mPitchOffset=-getPitch()
            }else{
                mGlobalId.item.mRoll=-getRoll()+mGlobalId.item.mRollOffst
                mGlobalId.item.mPitch=getPitch()+mGlobalId.item.mPitchOffset
                //console.log("[onPitchRollNotify mRoll="+mGlobalId.item.mRoll)
                //console.log("[onPitchRollNotify mPitch="+mGlobalId.item.mPitch)
            }
        }
        onGForceNotify: {
            if(mGlobalId.item.mGyroCalibration){
                mGlobalId.item.gXoffset=-getGforeY()
                mGlobalId.item.gYoffset=-getGforeX()
                mGlobalId.item.gZoffset=-getGforeZ()
            }else{
                mGlobalId.item.gY=getGforeX()+mGlobalId.item.gYoffset // 8是校正值
                mGlobalId.item.gX=getGforeY()+mGlobalId.item.gXoffset
                mGlobalId.item.gZ=getGforeZ()+mGlobalId.item.gZoffset
            }
            //console.log("[gX:"+mGlobalId.item.gX+" gY:"+mGlobalId.item.gY+", gZ:"+mGlobalId.item.gZ+"]")
        }
        ///////////////////////////////////////
        /// Altitude/hPa pressureNotify
        ///////////////////////////////////////
        onPressureNotify: {
            mGlobalId.item.mhPa=getPressure()
            mGlobalId.item.mAltitude=getAltitude()
        }
        ///////////////////////////////////////
        /// Gps/Gnss
        ///////////////////////////////////////
        onGpsAccuracyInfoNotify: {
            mGlobalId.item.gpsInUsed=getGpsInUsed()
            mGlobalId.item.gpsFixed=getGpsFixedStatus()
            mGlobalId.item.gpsAccuracy=getGpsAccuracy().toFixed(1)
//            console.log("[GPS INUSED: "+mGlobalId.item.gpsInUsed+"]");
//            console.log("[GPS FIXED MODE: "+mGlobalId.item.gpsFixed+"]");
//            console.log("[GPS ACCURACY: "+mGlobalId.item.gpsAccuracy+"]");
            //console.log("[NMEA: "+getGpsNmea(YachtEvent.NMEA_TYPE_GSA)+"]");
        }
        onGpsAltitudeInfoNotify: {
            mGlobalId.item.gpsAltitude=getGpsAltitude().toFixed(1)
            //console.log("[GPS ALTITUDE: "+mGlobalId.item.gpsAltitude+"]");
            //console.log("[NMEA: "+getGpsNmea(YachtEvent.NMEA_TYPE_GGA)+"]");
        }
        onGpsBearingInfoNotify: {
            if(mGlobalId.item.vehicleSpeed>5)
                mGlobalId.item.gpsBearing=getGpsBearing()
            //console.log("[GPS Bearing: "+mGlobalId.item.gpsBearing+"]");
        }
        onGpsDateTimeInfoNotify: {
            syncRtcFromGps()
        }
        onGpsLatLongInfoNotify: {
            mGlobalId.item.gpsFixedValid=getGpsIsFixed()
            mGlobalId.item.gpsInView=getGpsInView()
            mGlobalId.item.gpsLatitude=getGpsLatitude().toFixed(5)
            mGlobalId.item.gpsLongitude=getGpsLongitude().toFixed(5)
//            console.log("[GPS FIXED VALID: "+mGlobalId.item.gpsFixedValid+"]");
//            console.log("[GPS INVIEW: "+mGlobalId.item.gpsInView+"]");
//            console.log("[GPS LAT: "+mGlobalId.item.gpsLatitude+"]");
//            console.log("[GPS LONG: "+mGlobalId.item.gpsLongitude+"]");
            //console.log("[NMEA: "+getGpsNmea(YachtEvent.NMEA_TYPE_RMC)+"]");
            syncRtcFromGps()
        }
        onGpsSNRInfoNotify: {
            mGlobalId.item.gpsSNR=(getGpsSNR()/10).toFixed(0)
            //console.log("[GPS SNR: "+mGlobalId.item.gpsSNR+"]");
        }

    }
    /////////////////////////////////////
    // VehicleEvent Plugins end
    /////////////////////////////////////

    /////////////////////////////
    // fuel setup mEventHandleId.item.setFuelTank
    /////////////////////////////
    function setFuelTank(sub, liter){
        var tank=(liter/mGlobalId.item.tankUnitFactor).toFixed(0)
        mHandleId.setFuelParam(sub, tank)
    }
    function setFuelFillerRightSide(dir){
        mHandleId.setFuelFillerRightSide(dir)
    }
    /////////////////////////////
    // trip setup mEventHandleId.item.resetOilLife
    /////////////////////////////
    function setOdo(meter){
        var temp=(meter/mGlobalId.item.tripFactor).toFixed(0)
        //console.log("[setOdo "+temp+"]")
        mHandleId.setTripParam(2, temp)
    }
    function resetTrip(b){
        //console.log("[reset trip"+b+"]")
        mHandleId.setTripParam(b, 0)
    }
    function resetOilLife(){
        //console.log("[resetOilLife]")
        if(Number(mTrucksModel)===1 && mGlobalId.item.vehicleModel===1){
            // 2011-2014 F150: the vendor sends the oil life value from Vehicle > Assist row 59 with this Ford setup id.
            mGlobalId.item.fordSetupInfo[59]=100
            setFordSetup(14, mGlobalId.item.f150_11_14_param_id(59), 100)
            return
        }
        mHandleId.setOilLifeReset2()
    }
    /////////////////////////////
    // sinceReset setup mEventHandleId.item.resetSinceReset
    /////////////////////////////
    function resetSinceReset(){
        if(Qt.platform.os != "linux"){
            return
        }
        mHandleId.setSinceResetZero()
    }
    /////////////////////////////
    // rtc setup mEventHandleId.item.setRtc
    /////////////////////////////
    // The Date and time menu and syncRtcFromGps() both write the clock here. The clock shows after a write (Global.qml rtcTrusted).
    function setRtc(rtc){
        console.log("setRtc: "+rtc)
        mHandleId.setRtc(rtc)
        mGlobalId.item.gpsClockRtcSet=true
    }
    /////////////////////////////
    // GPS clock: write the local time from GPS to the MCU clock (Global.qml gpsClockStep).
    // Both GPS notifications call this; which one the native plugin raises after an RMC sentence is not verified on the truck.
    // A second call for the same fix writes nothing.
    /////////////////////////////
    function syncRtcFromGps(){
        if(!mGlobalId.item.gpsAutoSetRtcEnabled)
            return
        var rtc=mGlobalId.item.gpsClockStep(mHandleId.getGpsNmea(VehicleEvent.NMEA_TYPE_RMC))
        if(rtc)
            setRtc(rtc)
    }
    ////////////////////////////////
    // overSpeedWarningNotify
    // setup mEventHandleId.item.setOverSpeedWarningEnabled
    ////////////////////////////////
    function setOverSpeedWarningEnabled(on){
        console.log("[setOverSpeedWarningEnabled: "+on+"]")
        mHandleId.setOverSpeedWarning(0, on)
    }
    function setOverSpeedWarningSpeed(speed){
        var temp=(speed/mGlobalId.item.tripFactor).toFixed(0)
        console.log("[setOverSpeedWarningSpeed: "+temp+"]")
        mHandleId.setOverSpeedWarning(1, temp)
    }
    /////////////////////////////
    // maintent setup mEventHandleId.item.setMaintentCustomId
    /////////////////////////////
    function setMaintentCustomId(id, item){
        console.log("[setMaintentCustomId id:"+id+" item="+item+"]")
        mHandleId.setMainTainItem(id, item)
    }
    function setMaintentMileage(id, mileage){
        var temp=(mileage/mGlobalId.item.tripFactor).toFixed(0)
        console.log("[setMaintentMileage id:"+id+" mileage="+temp+"]")
        mHandleId.setMainTainMileage(id, temp)
    }
    function setMaintentDate(id, date){
        console.log("[setMaintentDate id:"+id+" date="+date+"]")
        mHandleId.setMainTainDate(id, date)
    }
    function setMaintentReset(id){
        if(Qt.platform.os != "linux"){
            console.log("[setMaintentReset id:"+id+"]")
            return
        }
        mHandleId.setMainTainState(id, 1)
    }
    ////////////////////////////////
    ///  dialog2InfoNotify mEventHandleId.item.unitInquire
    ////////////////////////////////
    function getDialog2ListTotal(){
        return mHandleId.getDialog2ListTotal();
    }
    function getDialog2ListInfo(index){
        return mHandleId.getDialog2ListInfo(index)
    }
    //////////////////////////////
    // info inquire mEventHandleId.item.seniorFordMyKeySetupInquire
    //////////////////////////////
    function systemInquire(){
        mHandleId.infoInquire(VehicleEvent.INFO_INQUIRE_SYSTEM);
    }
    function fuelInquire(){
        mHandleId.infoInquire(VehicleEvent.INFO_INQUIRE_FUEL);
    }
    function tripInquire(){
        mHandleId.infoInquire(VehicleEvent.INFO_INQUIRE_TRIP);
    }
    function tpmsReset(){
        mHandleId.setTpmsReset()
    }
    function waterInquire(){
        mHandleId.infoInquire(VehicleEvent.INFO_INQUIRE_WATER);
    }
    function gearInquire(){
        mHandleId.infoInquire(VehicleEvent.INFO_INQUIRE_GEAR);
    }
    function rtcInquire(){
        mHandleId.infoInquire(VehicleEvent.INFO_INQUIRE_RTC);
    }
    function outSideTempInquire(){
        mHandleId.infoInquire(VehicleEvent.INFO_INQUIRE_VEHICLES);
    }
    function dashboardInquire(){
        mHandleId.infoInquire(VehicleEvent.INFO_INQUIRE_VEHICLES);
    }
    function lpkInquire(){
        mHandleId.infoInquire(VehicleEvent.INFO_INQUIRE_LPK);
    }
    function ecoInquire(){
        mHandleId.infoInquire(VehicleEvent.INFO_INQUIRE_ECO);
    }
    function unitInquire(){
        //console.log("xxxxxxxxxxxxxxxxxxx unitInquire xxxxxxxxxxxxxxxxxxxxx")
        mHandleId.infoInquire(VehicleEvent.INFO_INQUIRE_UNIT);
    }
    function sinceInquire(index){
        switch(index){
        case 0: // since reset
            mHandleId.infoInquire(VehicleEvent.INFO_INQUIRE_SINCE_RESET);
            break
        case 1: // since refueling
            mHandleId.infoInquire(VehicleEvent.INFO_INQUIRE_SINCE_REFUELING);
            break
        case 2: // since start
            mHandleId.infoInquire(VehicleEvent.INFO_INQUIRE_SINCE_START);
            break
        case 3: // since individual
            mHandleId.infoInquire(VehicleEvent.INFO_INQUIRE_TRIP);
            mHandleId.infoInquire(VehicleEvent.INFO_INQUIRE_LPK);
            mHandleId.infoInquire(VehicleEvent.INFO_INQUIRE_FUEL);
            break
        }
    }
    function maintenacneInquire(){
        mHandleId.infoInquire(VehicleEvent.INFO_INQUIRE_MAINTENANCE);
    }
    function overspeedInquire(){
        mHandleId.infoInquire(VehicleEvent.INFO_INQUIRE_OVERSPEED);
    }
    function brightnessInquire(){
        mHandleId.infoInquire(VehicleEvent.INFO_INQUIRE_BRIGHTNESS);
    }
    function epsInquire(){
        mHandleId.infoInquire(VehicleEvent.INFO_INQUIRE_EPS);
    }
    function tpmsInquire(){
        mHandleId.infoInquire(VehicleEvent.INFO_INQUIRE_TPMS);
    }
    function seniorSetupInquire(){
        mHandleId.seniorInfoInquire(VehicleEvent.INFO_INQUIRE_SENIOR_SETUP, 0x0009)
    }
    function seniorF150_11_14_SetupInquire(){
        mHandleId.seniorInfoInquire(VehicleEvent.INFO_INQUIRE_SENIOR_SETUP, 0x000E)
    }
    function seniorFordSetupInquire(){
        mHandleId.seniorInfoInquire(VehicleEvent.INFO_INQUIRE_SENIOR_SETUP, 0x000B)
    }
    function seniorFordMyKeySetupInquire(){
        mHandleId.seniorInfoInquire(VehicleEvent.INFO_INQUIRE_SENIOR_SETUP, 0x0010)
    }
    function vehiclesInquire(){
        if(Qt.platform.os != "linux"){
            return
        }
        mHandleId.infoInquire(VehicleEvent.INFO_INQUIRE_VEHICLES);
    }
    function versionInquire(){
        if(Qt.platform.os != "linux"){
            return
        }
        mHandleId.infoInquire(VehicleEvent.INFO_INQUIRE_VERSION);
    }
    function shellCmdInquire(){
        if(Qt.platform.os != "linux"){
            // dummy
            mHandleId.infoInquire(VehicleEvent.INFO_INQUIRE_SHELLCMD);
            return
        }
        //mGlobalId.item.updateSrotage=VehicleEvent.STORAGE_TYPE_LOCAL
        //mGlobalId.item.shellCmdCounts=mHandleId.getShellCmdFileCount(VehicleEvent.STORAGE_TYPE_LOCAL)
    }
    function mcuUpdateInquire(){
        if(Qt.platform.os != "linux"){
            // dummy
            mHandleId.infoInquire(VehicleEvent.INFO_INQUIRE_MCU_UPDATE);
            return
        }
    }
    //////////////////////////////
    // senior config inquire mEventHandleId.item.tpmsReset.
    /////////////////////////////
    function ptsInquire(){
        //mHandleId.infoInquire(VehicleEvent.INFO_INQUIRE_VERSION);
    }
    ////////////////////////////////////////
    // BMW设置项 mEventHandleId.item.setBmw
    ////////////////////////////////////////
    function setBmw(id, data){
        //console.log("[setBenz id="+id+", data="+data+"]")
        switch(id){
        case 1: // 回家照明
            mHandleId.setBmwHomeLight(data)
            break;
        case 2: // 转向灯亮 3 次
            mHandleId.setBmwTurnLight3Times(data)
            break;
        case 3: // 日间行车灯
            mHandleId.setBmwDrl(data)
            break
        case 4: // 开锁
            mHandleId.setBmwDoorUnlock(data)
            break;
        case 5: // 座椅自动调整
            mHandleId.setBmwAutomaticSeatSdjustment(data)
            break;
        case 6: // 自动重锁
            mHandleId.setBmwAutomaticReLock(data)
            break;
        case 7: // 行车后联锁
            mHandleId.setBmwInterlockingAfterDriving(data)
            break;
        case 8: // 上锁时闪烁
            mHandleId.setBmwFlashingWhenLock(data)
            break;
        case 9: // 解锁时闪烁
            mHandleId.setBmwFlashingWhenUnLock(data)
            break;
        case 10: // 胎压初始化
            mHandleId.setBmwTpmsInitial(data)
            break;
        case 11: // 灯光调节
            mHandleId.setBmwLampBrightness(data)
            break
        }
    }
    // 奔驰设置项 mEventHandleId.item.setBenz
    function setBenz(id, data){
        //console.log("[setBenz id="+id+", data="+data+"]")
        switch(id){
//        case 4: // 速度限制(冬季轮胎)
//            mHandleId.setBenzCSpeedLimited(data)
//            //mHandleId.setBenzSpeedLimited(data)
//            break;
        case 15: // 车内照明延时
            mHandleId.setBenzLightingDelay(data)
            break;
        case 16: // 自动车门锁止
            mHandleId.setBenzDoorAutoLock(data)
            break;
        case 17: // 中央门锁声音反馈
            mHandleId.setBenzDoorLockSound(data)
            break;
        case 25: // 环境照明功能
            mHandleId.setBenzSurroundLighting(data)
            break;
        case 31: // 雨量传感器灵敏度
            mHandleId.setBenzRainfallSensorSensitivity(data)
            break;
        }
    }
    /////////////////////////////
    // 奔驰设置项 mEventHandleId.item.setBenzC
    /////////////////////////////
    function setBenzC(id, data){
        //console.log("[VehilceEvent setBenzC id="+id+", data="+data+"]")
        switch(id){
        case 1: // EPS
            mHandleId.setBenzCEspSwitch(data)
            break;
        case 2: // 碰撞预防辅 助系统增强版
            mHandleId.setBenzCpaPlusSwitch(data)
            break;
        case 3: // 注意力辅助系统
            mHandleId.setBenzAttentionAssist(data)
            break;
        case 4: // 速度限制(冬季轮胎)
            mHandleId.setBenzCSpeedLimited(data)
            //mHandleId.setBenzSpeedLimited(data)
            break;
        case 5: // 低压续跑指示器启用
            mHandleId.setBenzCMoextended(data)
            break;
        case 6: // 盲点辅助系统
            mHandleId.setBenzCMangdianfuzhu(data)
            break;
        case 7: // 车道保持辅助系统
            mHandleId.setBenzCChedaobaochi(data)
            break;
        case 8: // 智能照明系统
            mHandleId.setBenzCZhinengzhaoming(data)
            break;
        case 9: // 近光灯设置
            mHandleId.setBenzCJinguangdeng(data)
            break;
        case 10: // 亮度
            mHandleId.setBenzCLiangdu(data)
            break;
        case 11: // 日间行车灯
            mHandleId.setBenzCRijianXinchengdeng(data)
            break;
        case 12: // 环境氛围照明亮度
            mHandleId.setBenzCFenWeiLiangDu(data)
            break;
        case 13: // 环境氛围照明颜色
            mHandleId.setBenzCFenweiyanse(data)
            break;
        case 14: // 定位照明
            mHandleId.setBenzCDingweizhaoming(data)
            break;
        case 15: // 车内照明延时
            mHandleId.setBenzCZhaomingyanshi(data)
            break;
        case 16: // 自动车门锁止
            mHandleId.setBenzCZidongchemensuo(data)
            break;
        case 17: // 中央门锁声音反馈
            mHandleId.setBenzCZhongyangmensuoshengyinfankui(data)
            break;
        case 18: // 方便出入功能
            mHandleId.setBenzCFangbianchuru(data)
            break;
        case 19: // 安全带调节
            mHandleId.setBenzCAnquandaitiaojie(data)
            break;
        case 20: // 当锁止时，折叠后视镜
            mHandleId.setBenzCZhediehoushijing(data)
            break;
        case 21: // 雷达传感器
            mHandleId.setBenzCRadarSensor(data)
            break;
        case 22: // PRE-SAFE 制动系统
            mHandleId.setBenzCBrakeSystem(data)
            break;
        case 23: // 主动制动辅助系统
            mHandleId.setBenzCAEB(data)
            break;
        }
    }
    // 奔驰设置项 mEventHandleId.item.setBenzS600
    function setBenzS600(id, data){
        switch(id){
        case 32: // 底盘上升
            mHandleId.setBenzDipanMode(data)
            break;
        case 1: // ESP
            mHandleId.setBenzEspSwitch(data)
            break;
        case 33: // 雷达辅助
            mHandleId.setBenzRadarSwitch(data)
            break;
        case 34: // 倒车摄像头 R档自动
            mHandleId.setBenzCameraR(data)
            break;
        case 11: // 日间行驶灯
            mHandleId.setBenzDayLightSwitch(data)
            break
        case 35: // 距离警告
            mHandleId.setDistanceWarning(data)
            break
        case 36: // 路线偏离警告
            mHandleId.setPianliWarning(data)
            break
        case 8: // 智能照明系统
            mHandleId.setZhinengzhaming(data)
            break
        case 37: // 安全带调节功能
            mHandleId.setAnquandaitiaojie(data)
            break
        case 17: // 门锁声音反馈
            mHandleId.setZhongyangmensuofankui(data)
            break
        case 9: // 近光灯
            mHandleId.setJinguangdeng(data)
            break
        case 38: // 自适应大灯辅助系统
            mHandleId.setZishiyingdadeng(data)
            break
        case 4: // 速度限制(冬季轮胎)
            mHandleId.setBenzCSpeedLimited(data)
            break
        }
        // 32, 1, 33, 34, 11, 35, 36, 8, 37, 17, 9, 38, 4,
    }

    // 奔驰设置项 mEventHandleId.item.setBenzAll
    function setBenzAll(id, data){
        mHandleId.setBenzAllSetup(id, data)
    }
    ////////////////////////////////////////
    // Trucks设置项 mEventHandleId.item.setTrucks
    ////////////////////////////////////////
    function setTrucks(id, data){
        //console.log("[setTrucks id="+id+", data="+data+"]")
        mHandleId.setTruckSetup(id, data);
    }
    function setSeniorTrucks(model, type, id, data){
        //console.log("[mTrucksModel="+model+", type="+type+", id="+id+", data="+data+"]")
        mHandleId.setSeniorTruckSetup(model, type, id, data);
        mSeniorTrucksTimerId.restart()
    }
    Timer{
        id: mSeniorTrucksTimerId
        interval: 50
        running: false
        onTriggered: {
            seniorSetupInquire()
        }
    }
    ////////////////////////////////////////
    // Mustang/Ford设置项 mEventHandleId.item.setFordSetup
    ////////////////////////////////////////
    function setFordSetup(vehicle, id, data){
        console.log("[setFordSetup id="+id+", data="+data+"]")
        mHandleId.setFordSetup(vehicle, id, data)
    }

    //////////////////////////////
    // cfg inquire mEventHandleId.item.trucksCfgInquire
    //////////////////////////////
    function benzAdBlueInquire(){
        mHandleId.cfgInfoInquire(VehicleEvent.CFG_INQUIRE_BENZ_ADBLUE)
    }
    function benzAccInquire(){
        mHandleId.cfgInfoInquire(VehicleEvent.CFG_INQUIRE_BENZ_ACC)
    }
    function benzEcoInquire(){
        mHandleId.cfgInfoInquire(VehicleEvent.CFG_INQUIRE_BENZ_ECO)
    }
    function attentionAssistInquire(){
        mHandleId.cfgInfoInquire(VehicleEvent.CFG_INQUIRE_ATTENTION_ASSIST)
    }
    function benzCfgInquire(){
        switch(mGlobalId.item.vehicleModel){
        case 2: // S600
            mHandleId.cfgInfoInquire(VehicleEvent.CFG_INQUIRE_BENZ_S600_SETTING)
            break
        case 10: // R500
            mHandleId.cfgInfoInquire(VehicleEvent.CFG_INQUIRE_BENZ_ALL_SETTING)
            break
        default:
            mHandleId.cfgInfoInquire(VehicleEvent.CFG_INQUIRE_BENZ_C_SETTING)
            break
        }
    }
    function bmwCfgInquire(){
        mHandleId.cfgInfoInquire(VehicleEvent.CFG_INQUIRE_BMW_SETTING)
    }
    function trucksCfgInquire(){
        mHandleId.cfgInfoInquire(VehicleEvent.CFG_INQUIRE_TRUCKS_SETTING)
    }
    /////////////////////////////
    // bsm setting mEventHandleId.item.setBsmSettings
    /////////////////////////////
    function setBsmSettings(id){
        console.log("setBsmSettings: "+id)
        mHandleId.setBsmSettings(id)
    }
    /////////////////////////////
    // pcs setting mEventHandleId.item.setPcsSettings
    /////////////////////////////
    function setPcsSettings(id){
        console.log("setPcsSettings: "+id)
        mHandleId.setPcsSettings(id)
    }
    /////////////////////////////
    // disp mEventHandleId.item.setBright
    /////////////////////////////
    function getBrightness(){
        if(Qt.platform.os != "linux")
            return 80
        return mHandleId.getBright()
    }
    function setBright(dark, bright){
        var brightness=Math.floor(bright/25)*25
        if(brightness>250)
            brightness=25
        //console.log("[setBright: "+brightness+"]")
        if(dark)
            mGlobalId.item.darkBrightness=brightness
        else
            mGlobalId.item.lightBrightness=brightness
        if(!dark)
            mHandleId.setLightBright(brightness)
        else
            mHandleId.setDarkBright(brightness)
    }
    //////////////////////////////
    // metricSystem mEventHandleId.item.getMetricSystemChanged()
    function getMetricSystemChanged(){
        if(Qt.platform.os != "linux"){
            // trip
            mGlobalId.item.odo=1234
            mGlobalId.item.tripA=123.4
            mGlobalId.item.tripB=432.1
            // fuel
            mGlobalId.item.dte=100
            // vehicles
            mGlobalId.item.oilPressurePercentage=80 //getOilPercentage()
            mGlobalId.item.batterVoltage=13.5
            mGlobalId.item.gearBoxTemp=109
            mGlobalId.item.outSideTemp=27.5
            mGlobalId.item.oilTempPercentage=90
            mGlobalId.item.oilTemp=192
            // water
            mGlobalId.item.waterTemp=87
            return
        }
        mEventHandleId.item.fuelInquire()
        mEventHandleId.item.tripInquire()
        mEventHandleId.item.vehiclesInquire()
        mEventHandleId.item.waterInquire()
        console.log("[inquire fuel/trip/vehicles cause MetricSystem changed!]")
    }

    //////////////////////////////
    //////////////////////////////
    // notify mEventHandleId.item.getNotify
    //////////////////////////////
    function getNotify(){
        console.log("[getNotify]")
//        if(Qt.platform.os != "linux")
//            return
        if(!mHandleId.getNotifyIsEmpty()){
            var temp=mHandleId.getNotifyInfo().split("#")
            console.log("[getNotify "+temp+"]")
            mGlobalId.item.notifyText=Number(temp[0])
            mGlobalId.item.notifyIcon=Number(temp[1])
            mGlobalId.item.notifyDuration=Number(temp[2])*1000
        }
    }
    function setMediaSource(src){
        if(Qt.platform.os != "linux"){
            console.log("setMediaSource:"+src)
            return
        }
        mHandleId.setMediaSource(src)
    }

    //////////////////////////////////
    // update mEventHandleId.item.setMediaSource
    //////////////////////////////////
    // can mcu
    function getMcuUpdateName(index){
        var name=mHandleId.getMcuUpdateFileName(VehicleEvent.STORAGE_TYPE_USB, index).split("/")
        return name[name.length-1]
    }
    function getMcuUpdatePathName(index){
        if(Qt.platform.os != "linux")
            return "can_app.bin"
        return mHandleId.getMcuUpdateFileName(VehicleEvent.STORAGE_TYPE_USB, index)
    }
    function setMcuUpdateFile(file){
        console.log("[setMcuUpdateFile: "+file+"]")
        return mHandleId.setUpdate(VehicleEvent.MEDIAP_TYPE_CAN,
                                   VehicleEvent.CANBOX_VENDOR_JLY,
                                   file)
    }
    // bt mcu
    function getBtUpdateName(index){
        if(Qt.platform.os != "linux")
            return
        return mHandleId.getBtUpdateFileName(VehicleEvent.STORAGE_TYPE_USB, index)
    }
    function setBtUpdateFile(file){
        console.log("[setBtUpdateFile: "+file+"]")
        // 透過LinkEvent 升級
        //return mHandleId.setUpdate(VehicleEvent.MEDIAP_TYPE_MCU, file)
    }
    // system
    function getSystemUpdateName(index){
        var name=mHandleId.getSystemUpdateFileName(VehicleEvent.STORAGE_TYPE_USB, index).split("/")
        return name[name.length-1]
    }
    function getSystemUpdatePathName(index){
        var name=mHandleId.getSystemUpdateFileName(VehicleEvent.STORAGE_TYPE_USB, index)
        return name[name.length-1]
    }
    function setSystemUpdateFile(file){
        console.log("[setSystemUpdateFile: "+file+"]")
        return mHandleId.setUpdate(VehicleEvent.MEDIAP_TYPE_SYSTEM, file)
    }
    // shell cmd
    function getSehllCmdCount(){
        var etc=mHandleId.getShellCmdFileCount(VehicleEvent.STORAGE_TYPE_LOCAL)
        var usb=mHandleId.getShellCmdFileCount(VehicleEvent.STORAGE_TYPE_USB)
        mGlobalId.item.shellCmdCounts=Number(etc)+Number(usb)
//        console.log("[getSehllCmdCount etc:"+etc+"]")
//        console.log("[getSehllCmdCount usb:"+usb+"]")
//        console.log("[getSehllCmdCount shellCmdCounts:"+mGlobalId.item.shellCmdCounts+"]")
        return mGlobalId.item.shellCmdCounts
    }
    function getSehllCmdName(index){
        var name
        var etc=mHandleId.getShellCmdFileCount(VehicleEvent.STORAGE_TYPE_LOCAL)
        var usb=mHandleId.getShellCmdFileCount(VehicleEvent.STORAGE_TYPE_USB)
        if(etc && index<Number(etc)){
            name=mHandleId.getShellCmdFileName(VehicleEvent.STORAGE_TYPE_LOCAL, index).split("/")
            //console.log("[getSehllCmdName name:"+name+"]")
            return name[name.length-1]
        }else{
            if(usb){
                name=mHandleId.getShellCmdFileName(VehicleEvent.STORAGE_TYPE_USB, index-etc).split("/")
                return name[name.length-1]
            }
        }
        return "NONE"
        //var name=mHandleId.getShellCmdFileName(VehicleEvent.STORAGE_TYPE_USB, index).split("/")
    }
    function getShellCmdPathName(index){
        return mHandleId.getMcuUpdateFileName(VehicleEvent.STORAGE_TYPE_USB, index)
    }
    function setShellCmdFile(name){
        console.log("[setShellCmdFile: "+name+"]")
        return mHandleId.setShellCmd(name)
    }
    function dynamic_island(index, msg){
        mGlobalId.item.dynamicIslandIcon=index
        mGlobalId.item.dynamicIslandMeg=msg
    }

    /////////////////////////////
    // shell/adb mEventHandleId.item.setVehicleModel
    /////////////////////////////
    function setMcuReset(){
        if(Qt.platform.os != "linux")
            return
        mHandleId.setMcuReset()
    }
    function setReverseAlarm(onoff){
        mHandleId.setReverseAlarm(onoff)
    }
    function setMPH(mph){
        if(Qt.platform.os != "linux")
            return
        mHandleId.setMPH(mph)
    }
    function setUnit(type, data){
        mHandleId.setUnit(type, data)
    }
    function setUnit2(type, data){
        if(type===2)
            mGlobalId.item.speedUnitOverride=1
        else if(type===1)
            mGlobalId.item.tempUnitOverride=1
        if(Qt.platform.os != "linux"){
            console.log("xxxxx setUnit2 type:"+type+", data:"+data)
            return
        }
        mHandleId.setUnit2(type, data)
    }
    function followVehicleUnits(){
        mGlobalId.item.speedUnitOverride=0
        mGlobalId.item.tempUnitOverride=0
        if(mGlobalId.item.followUnit){
            mGlobalId.item.metricSystem=mHandleId.getTripUnit()
            mGlobalId.item.temperatureUnit=mHandleId.getTempUnit()
            mGlobalId.item.rtc24h=mHandleId.getTime24h()
        }
    }
    function setVehicleColor(color){
        if(Qt.platform.os != "linux")
            return
        mHandleId.setVehicleColor(color)
    }
    function setVehicleModel(model){
        if(Qt.platform.os != "linux"){
            console.log("[1 setVehicleModel: "+model+"]")
            return
        }
        mHandleId.setVehicleModel(model)
    }
    function shell(cmd){
        if(Qt.platform.os != "linux")
            return
        mHandleId.shell(cmd)
    }
    function adb(onoff){
        if(Qt.platform.os != "linux"){
            console.log("adb")
            return
        }
        mHandleId.adb(onoff)
    }
    function splash(animation){
        if(Qt.platform.os != "linux"){
            console.log("splash")
            return
        }
        mHandleId.splash(animation)
    }

    /////////////////////////////
    // Wheel key bounce filter. The truck key trace (2026-10-30) shows one Down press as two or three press-release pairs:
    // each extra press starts 9-20 ms after a release and lasts 10-21 ms. Real presses start 120 ms or more after a release.
    // A release reaches the pages mSwcSettleMs later. A press inside that time is switch bounce:
    // - the same key: the key stays down, and the release waits again;
    // - another key: the press, its hold, and its release are dropped.
    // Each drop writes one "viknav-key-drop <ms> <code> <state> <reason>" line to the Launcher log. A "bounce" line stands for
    // the press and the waiting release that the press joins. A clock set backward does not count as a short gap.
    /////////////////////////////
    readonly property int mSwcSettleMs: 50
    property double mSwcReleasedAt: -1000  // time of the last release; -1000 before the first release
    property int mSwcPendingKey: -1     // released key that waits for the settle time
    property int mSwcDropKey: -1        // key whose hold and release are dropped
    Timer {
        id: mSwcSettleTimer
        interval: mSwcSettleMs
        onTriggered: swcFlush()
    }
    function swcDeliver(key, state) {
        var g=mGlobalId.item
        g.swcKey=key
        g.swcState=state
        g.swcChanged=!g.swcChanged
    }
    function swcDrop(key, state, reason) {
        console.log("viknav-key-drop "+Date.now()+" "+key+" "+state+" "+reason)
    }
    function swcFlush() {
        if(mSwcPendingKey<0)
            return
        var key=mSwcPendingKey
        mSwcPendingKey=-1
        mSwcSettleTimer.stop()
        swcDeliver(key, 0)
    }
    function swcInput(key, state) {
        var now=Date.now()
        var gap=now-mSwcReleasedAt
        if(state===1) {
            if(gap>=0 && gap<mSwcSettleMs) {
                if(key===mSwcPendingKey) {
                    mSwcPendingKey=-1
                    mSwcSettleTimer.stop()
                    swcDrop(key, state, "bounce")
                } else {
                    swcFlush()
                    mSwcDropKey=key
                    swcDrop(key, state, "other-key")
                }
                return
            }
            // A new press of a dropped key means the release of the dropped press was lost.
            if(key===mSwcDropKey)
                mSwcDropKey=-1
        } else if(key===mSwcDropKey) {
            if(state===0) {
                mSwcDropKey=-1
                mSwcReleasedAt=now
            }
            swcDrop(key, state, "other-key")
            return
        }
        swcFlush()
        if(state===0) {
            mSwcReleasedAt=now
            mSwcPendingKey=key
            mSwcSettleTimer.restart()
            return
        }
        swcDeliver(key, state)
    }

    /////////////////////////////
    // Data logger. With Factory "Debug logging" on (any value), one line per second of decoded values ("viknav-data {...}")
    // goes to the Launcher log (/tmp/Launcher.log, in RAM). Debug values 2 (UART receive) and 4 (UART transmit) also make the
    // native plugin print every UART frame there. The frame print stops after mDataLogFrameSeconds in one power cycle,
    // so the log in RAM stays bounded. The USB record action (tools/usb-install) copies the log to a drive while the truck runs.
    /////////////////////////////
    readonly property int mDataLogFrameSeconds: 5400
    property bool mDataLogFramesOpen: true
    property int mDataLogTicks: 0
    // oilPressurePercentage (vehicleInfoNotify) and engOilPercent (oilMeterInfoNotify) both read getOilPressure().
    // The log keeps both, so a drive shows which notification the truck sends.
    readonly property var mDataLogNames: [
        "vehicleSpeed", "tachoSpeed", "gearString", "metricSystem", "temperatureUnit", "consumptionUnit", "lpkUnitIndex",
        "fuelPercentage", "fuelPercentageRaw", "fuelFrameMs", "fuelLevel", "dte", "mainTank", "subTank",
        "mainTankPercentage", "mainTankPercentageRaw", "subTankPercentage", "subTankPercentageRaw",
        "mainTankState", "subTankState", "lpk", "odo", "tripA", "tripB", "tripType",
        "sinceResetAvgFuel", "sinceResetAvgSpeed", "sinceResetTravelTime", "sinceResetTravelMileage",
        "sinceStartAvgFuel", "sinceStartAvgSpeed", "sinceStartTravelTime", "sinceStartTravelMileage",
        "sinceRefuelingDte", "sinceRefuelingAvgFuel", "sinceRefuelingAvgSpeed",
        "waterTemp", "oilTemp", "gearBoxTemp", "oilPressurePercentage", "engOilPercent", "batterVoltage", "trucksOilLifePercentage", "trucksOilLifeTripRaw", "trucksTrailerDistance", "rtcDate", "rtcTime"
    ]
    Timer {
        interval: 1000
        repeat: true
        running: mGlobalId.item.uartDebugEnabled!==0
        onTriggered: {
            var g=mGlobalId.item, values={}
            for(var i=0;i<mDataLogNames.length;i++)
                values[mDataLogNames[i]]=g[mDataLogNames[i]]
            mDataLogTicks++
            console.log("viknav-data "+JSON.stringify({tick: mDataLogTicks, ms: Date.now(), v: values}))
            if(mDataLogFramesOpen&&(g.uartDebugEnabled&6)&&mDataLogTicks>=mDataLogFrameSeconds){
                mDataLogFramesOpen=false
                console.log("viknav-data frame print stopped for this power cycle")
            }
        }
    }

    Component.onCompleted: {
        if(Qt.platform.os != "linux")
            mGlobalId.item.startEnd=1
        mHandleId.enabled=true
        mGlobalId.item.pluginsVersion=mHandleId.getPluginsVersion()
        console.log("[Starting VehicleEvent .....]")
        console.log("[VehicleEvent Ver:"+mGlobalId.item.pluginsVersion+"]")
    }
}
