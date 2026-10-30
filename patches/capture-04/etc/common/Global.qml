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
    property int gpsAutoSetRtcEnabled: 1 // 使用GPS自動設置時間日期; on by default (GPS clock below)
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

    ////////////////////////////////
    // GPS clock mGlobalId.item.gpsClockStep
    ////////////////////////////////
    // The MCU clock (0x32 rtcInfoNotify) loses the time when the cluster loses power. With gpsAutoSetRtcEnabled on,
    // VehicleEvent syncRtcFromGps() writes the local time from GPS UTC (NMEA RMC) to the MCU clock (setRtc): once after
    // power-up, at once when the UTC offset changes, and when the MCU clock is 2 minutes or more off.
    // The time zone comes from the GPS position (gpsClockGrid). A new zone must hold for 60 s, so a stray fix or a short trip
    // across a zone line does not move the clock. Daylight saving time follows the US and Canada rule.
    // The native GPS time sync stays off (VehicleEvent timezone: 255): that path writes a whole-hour offset with no daylight
    // saving time into the clocks.
    property int gpsClockZone: -1                   // zone letter index (a = 0) of the clock zone; -1 = none yet. Saved.
    property int gpsClockCandidate: -1              // zone the position shows while the hold time runs
    property double gpsClockCandidateSince: 0       // UTC ms
    property double gpsClockWriteUtc: 0             // UTC ms of the last write in this power cycle; 0 = none yet
    property int gpsClockWriteOffset: 0             // UTC offset in minutes of the last write
    readonly property int gpsClockMinYear: 2026     // older GPS or MCU dates are not trusted (GPS week rollover, reset MCU clock)
    readonly property int gpsClockHoldMs: 60000
    readonly property int gpsClockDriftMs: 120000

    // NMEA RMC sentence to {utc: ms, lat: degrees, lon: degrees}. lat and lon are NaN when the sentence has no position.
    // null for an invalid fix (status V), a checksum that does not match, or a date before gpsClockMinYear.
    function gpsClockParseRmc(sentence){
        var s=String(sentence||"").trim()
        if(s.charAt(0)!=="$")
            return null
        var star=s.indexOf("*")
        if(star>=0){
            var sum=0
            for(var i=1;i<star;i++)
                sum^=s.charCodeAt(i)
            if(parseInt(s.substr(star+1, 2), 16)!==sum)
                return null
            s=s.substring(0, star)
        }
        var f=s.split(",")
        if(f.length<10||f[0].substr(3)!=="RMC"||f[2]!=="A"||!/^\d{6}/.test(f[1])||!/^\d{6}$/.test(f[9]))
            return null
        var part=function(v, at){ return Number(v.substr(at, 2)) }
        var utc=Date.UTC(2000+part(f[9], 4), part(f[9], 2)-1, part(f[9], 0), part(f[1], 0), part(f[1], 2), part(f[1], 4))
        var d=new Date(utc)
        if(d.getUTCFullYear()<gpsClockMinYear||d.getUTCDate()!==part(f[9], 0)||d.getUTCHours()!==part(f[1], 0)
                ||d.getUTCMinutes()!==part(f[1], 2)||d.getUTCSeconds()!==part(f[1], 4))
            return null
        // ddmm.mmmm or dddmm.mmmm with a hemisphere letter
        var degrees=function(v, h){
            var dot=v.indexOf(".")
            if(!v||dot<3)
                return NaN
            var value=Number(v.substring(0, dot-2))+Number(v.substring(dot-2))/60
            return h==="S"||h==="W"?-value:value
        }
        return {utc: utc, lat: degrees(f[3], f[4]), lon: degrees(f[5], f[6])}
    }

    // True while the US and Canada rule keeps daylight saving time at a UTC instant, for a standard UTC offset in minutes:
    // from the second Sunday in March at 2:00 standard time to the first Sunday in November at 2:00 daylight time.
    function gpsClockDst(utc, std){
        var year=new Date(utc+std*60000).getUTCFullYear()
        var march=new Date(Date.UTC(year, 2, 1)).getUTCDay()
        var november=new Date(Date.UTC(year, 10, 1)).getUTCDay()
        var start=Date.UTC(year, 2, 1+(7-march)%7+7, 2)-std*60000
        var end=Date.UTC(year, 10, 1+(7-november)%7, 2)-(std+60)*60000
        return utc>=start&&utc<end
    }

    // Zone letter index at a position; -1 outside the grid, or where no zone with a supported rule covers the cell.
    function gpsClockZoneAt(lat, lon){
        var spec=gpsClockGridSpec
        var r=Math.floor((lat-spec[0])/spec[2]), c=Math.floor((lon-spec[1])/spec[2])
        if(isNaN(r)||isNaN(c)||r<0||r>=spec[3]||c<0||c>=spec[4])
            return -1
        var row=gpsClockGrid[r], i=0, end=0
        while(i<row.length){
            var j=i+1
            while(j<row.length&&row.charCodeAt(j)>=48&&row.charCodeAt(j)<=57)
                j++
            end+=Number(row.substring(i+1, j))
            if(c<end)
                return row.charAt(i)==="."?-1:row.charCodeAt(i)-97
            i=j
        }
        return -1
    }

    // Local time in the MCU clock format: "yyyy-MM-dd hh:mm:ss" (as the Date and time menu writes the clock).
    function gpsClockText(ms){
        var d=new Date(ms)
        return d.getUTCFullYear()+"-"+Funcs.prefixInteger(d.getUTCMonth()+1, 2)+"-"+Funcs.prefixInteger(d.getUTCDate(), 2)+" "
                +Funcs.prefixInteger(d.getUTCHours(), 2)+":"+Funcs.prefixInteger(d.getUTCMinutes(), 2)+":"+Funcs.prefixInteger(d.getUTCSeconds(), 2)
    }

    // MCU clock local time as ms on the UTC scale, from rtcDate and rtcTime. NaN when unreadable.
    function gpsClockMcuMs(){
        var d=String(rtcDate).split("-"), t=String(rtcTime).split(":")
        return Date.UTC(Number(d[0]), Number(d[1])-1, Number(d[2]), Number(t[0]), Number(t[1]))
    }

    // One GPS fix: update the zone, then return the local time to write to the MCU clock, or "" for no write.
    function gpsClockStep(sentence){
        var fix=gpsClockParseRmc(sentence)
        if(!fix)
            return ""
        var here=gpsClockZoneAt(fix.lat, fix.lon), zone=Number(gpsClockZone)
        if(here>=0&&here!==zone){
            if(zone<0||here===gpsClockCandidate&&fix.utc-gpsClockCandidateSince>=gpsClockHoldMs){
                gpsClockZone=zone=here
                gpsClockCandidate=-1
                Funcs.setProperty("gpsClockZone", here)
            }else if(here!==gpsClockCandidate){
                gpsClockCandidate=here
                gpsClockCandidateSince=fix.utc
            }
        }else if(here===zone){
            gpsClockCandidate=-1
        }
        if(zone<0)
            return ""
        var std=gpsClockZones[zone][0]
        var offset=std+(gpsClockZones[zone][1]&&gpsClockDst(fix.utc, std)?60:0)
        var local=fix.utc+offset*60000
        if(gpsClockWriteUtc&&offset===gpsClockWriteOffset
                &&(fix.utc-gpsClockWriteUtc<gpsClockDriftMs||Math.abs(local-gpsClockMcuMs())<gpsClockDriftMs))
            return ""
        gpsClockWriteUtc=fix.utc
        gpsClockWriteOffset=offset
        return gpsClockText(local)
    }

    // The clock shows after a GPS write in this power cycle, or when the MCU date is plausible (a clock kept on constant power).
    // Otherwise the dashboard shows dashes: a wrong time is worse than no time.
    function rtcTrusted(){
        return gpsClockWriteUtc>0||Number(String(rtcDate).split("-")[0])>=gpsClockMinYear
    }

    // gpsClockGrid begin: generated by tools/build_timezone_grid.py. Do not edit.
    // Source: timezone-boundary-builder 2026e timezones-now.geojson.zip, sha256 a46516d04c43b32f5c527a2e5a3d5ad0308e65144730a57f04eec66c49ce59d0.
    // Zone rules: Python zoneinfo with tzdata 2025.3, checked for 2026 to 2035.
    // Data (c) OpenStreetMap contributors, Open Database License 1.0 (https://opendatacommons.org/licenses/odbl/1-0/).
    // Grid: south edge 14.0, west edge -180.0, cell 0.05 degree, 1160 rows from south to north, 2600 columns.
    // Each row is runs of a zone letter (a = gpsClockZones[0]) or "." (no zone) and a cell count.
    // gpsClockZones: [standard UTC offset in minutes, 1 = US and Canada daylight saving time rule].
    readonly property var gpsClockZones: [[-600,1],[-540,1],[-240,0],[-300,0],[-360,0],[-420,1],[-360,1],[-420,0],[-300,1],[-240,1],[-480,1],[-180,1],[-210,1],[720,0],[-600,0],[-660,0]]
    readonly property var gpsClockGridSpec: [14.0,-180.0,0.05,1160,2600]
    readonly property var gpsClockGrid: [
        ".1761e187.25d9.392c13.213",
        ".1760e188.25d9.10d5.378c12.213",
        ".1759e190.23d10.9d7.378c11.213",
        ".1757e192.23d10.8d9.377c10.214",
        ".1756e193.23d11.7d9.378c9.214",
        ".1755e195.22d11.6d11.376c11.213",
        ".1753e197.22d11.7d11.374c13.212",
        ".1752e198.22d11.7d11.373c14.212",
        ".1751e199.23d10.7d12.372c14.212",
        ".1750e200.23d10.8d10.373c14.212",
        ".1749e201.23d10.8d10.372c15.212",
        ".1748e202.24d8.10d9.371c16.212",
        ".1747e204.24d7.11d7.372c16.212",
        ".1746e205.25d5.13d5.372c17.212",
        ".1745e206.420c17.212",
        ".1744e207.420c16.213",
        ".1743e208.420c16.213",
        ".1742e212.417c16.213",
        ".1741e214.416c16.213",
        ".1740e216.416c14.214",
        ".1739e217.414c14.216",
        ".1738e218.413c11.220",
        ".1737e219.412c11.221",
        ".1735e221.412c11.221",
        ".1734e221.413c12.220",
        ".1733e221.414c12.220",
        ".1732e221.414c13.220",
        ".1731e221.414c14.220",
        ".1667e5.58e221.415c14.220",
        ".1667e11.51e204.1e10.3e1.376c6.36c14.220",
        ".1660e20.48e204.2e11.378c9.34c14.220",
        ".1659e23.44e204.4e12.55d3.319c9.34c13.221",
        ".1656e27.42e203.4e15.52d7.316c10.34c13.221",
        ".1655e32.36e204.3e17.2e6.44d8.17d7.291c11.31c14.222",
        ".1645e44.33e203.5e17.1e8.42d9.16d8.291c11.30c16.221",
        ".1641e53.25e205.5e18.1e9.41d9.16d9.291c9.31c17.220",
        ".1640e55.21e206.7e28.41d9.16d9.291c9.31c18.219",
        ".1639e57.19e205.9e17.1e10.41d9.16d9.292c7.30c20.219",
        ".1638e60.15e206.10e16.2e10.42d8.16d9.293c5.31c20.219",
        ".1636e64.8e209.12e10.9e9.43d6.17d8.329c22.218",
        ".1634e282.13e10.9e8.68d7.329c22.218",
        ".1629e282.18e10.11e5.405c22.218",
        ".1626e214.2e64.23e9.422c23.217",
        ".1625e216.4e57.27e9.421c25.216",
        ".1624e218.11e48.29e7.422c25.216",
        ".1624e218.14e43.33e2.425c26.215",
        ".1621e222.15e40.461c26.215",
        ".1619e225.17e35.463c26.215",
        ".1612e233.18e31.466c24.216",
        ".1606e240.18e29.461c5.1c24.216",
        ".206o7.1391e243.21e23.461c31.217",
        ".205o9.1387e246.24e19.145d2.314c10.1c14.3c1.220",
        ".204o11.1384e250.25e14.145d5.313c11.4c9.225",
        ".204o11.1383e251.30e8.145d9.310c11.5c7.226",
        ".204o11.1382e252.32e4.147d12.306c12.7c4.227",
        ".204o11.1380e255.182d16.301c17.234",
        ".205o10.1377e258.182d19.298c20.231",
        ".205o10.1374e262.181d23.291c24.230",
        ".206o9.1371e265.181d28.284c27.229",
        ".208o5.1371e268.179d33.279c28.229",
        ".1581e271.179d37.275c29.228",
        ".1576e277.178d41.271c29.228",
        ".1575e279.177d46.264c30.229",
        ".1574e280.177d51.258c31.229",
        ".1573e281.64e7.106d53.255c32.229",
        ".1573e281.63e9.105d54.79c6.168c33.229",
        ".1568e286.63e9.104d55.78c9.165c34.229",
        ".1566e289.61e11.103d55.78c11.162c16.1c18.229",
        ".1566e289.61e11.103d55.77c14.156c19.3c17.229",
        ".1564e291.61e11.103d55.77c15.122c8.24c19.4c16.230",
        ".1563e292.62e9.104d55.77c17.119c12.20c19.6c15.230",
        ".1562e293.63e7.105d54.78c19.117c14.18c18.8c14.230",
        ".1561e293.65e5.106d54.78c21.114c16.17c16.10c14.230",
        ".1561e291.178d53.79c23.82c5.25c16.17c17.9c14.230",
        ".1553e297.179d54.78c26.67c10.2c15.16c16.17c9.2c7.9c13.230",
        ".1553e295.181d54.78c28.63c32.13c16.18c7.2c8.10c11.231",
        ".1547e300.182d53.38i7.34c30.61c34.12c15.19c6.1c10.9c10.232",
        ".1542e280d1e23.183d53.36i13.30i1c30.47c7.5c42.5c15.21c15.10c9.232",
        ".1540e276d2e2d4e22.183d52.37i14.9i5.14i3c31.30c7.6c10.4c46.2c13.21c16.11c6.234",
        ".1535e280d10e22.182d52.36i16.3i16.7i5c32.17c20.4c10.4c47.2c11.22c16.251",
        ".1533e282d11e22.181d51.36i50c67.3c12.3c48.2c4.27c16.252",
        ".1530e285d11e22.180d51.32i55c67.3c12.3c56.25c16.252",
        ".1303h4.220e288d12e14d1e6.180d51.30i57c68.2c12.3c60.20c16.253",
        ".1301h8.217e291d10e12d9.180d50.21i3.6i57c69.2c77.17c15.255",
        ".1300h10.215e291d12e11d9.180d50.19i6.4i58c70.1c78.16c16.254",
        ".1300h11.214e291d13e10d9.180d49.19i8.2i60c69.2c78.15c16.254",
        ".1300h11.213e293d12e10d10.179d48.19i9.2i61c69.1c8.1c70.14c16.254",
        ".1300h11.212e294d13e9d10.1d6.173d44.22i10.1i59c71.3c4.2c73.12c16.254",
        ".1300h11.211e190.3e102d13e5d22.172d42.24i10.1i58c73.8c73.10c17.255",
        ".1300h11.210e190.10e95d42.171d39.27i10.1i57c74.9c72.9c17.256",
        ".1301h9.68h6.137e189.14e93d41.172d36.30i8.2i57c75.8c72.9c9.264",
        ".1302h7.67h9.136e188.17e91d41.173d33.32i7.3i56c76.9c72.8c9.264",
        ".1375h11.134e189.20e88d41.174d32.34i3.6i57c74.15c36.8c22.8c9.264",
        ".1374h12.131e191.24e2.8e74d42.176d21.52i58c73.16c29.20c16.8c9.264",
        ".483o7.884h13.130e190.35e74d42.183d4.62i59c72.17c7.45c12.8c8.265",
        ".482o9.867h1.15h13.128e189.39e73d42.250i58c71.70c12.10c5.266",
        ".480o12.863h7.12h13.124e191.42e73d41.251i20.1i36c71.70c11.282",
        ".479o14.861h8.12h12.123e191.49e68d41.254i7.10i37c71.71c10.282",
        ".478o15.861h9.11h12.121e192.61e3.1e53d40.272i36c71.73c7.284",
        ".477o17.860h9.12h10.118e185.78e51d39.273i36c71.77c1.286",
        ".477o19.858h9.13h9.116e185.81e50d37.276i36c70.364",
        ".477o23.854h9.15h7.115e186.83e48d37.116d9.151i37c68.365",
        ".477o25.853h8.17h7.111e188.86e45d37.114d13.150i37c67.365",
        ".477o27.851h7.17h9.109e189.87e44d38.113d14.151i5.1i29c67.365",
        ".477o28.853h1.20h9.108e189.90e42d38.113d15.156i29c66.366",
        ".477o29.873h10.106e189.92e41d39.111d16.156i27c68.366",
        ".477o30.872h10.106e188.95e39d39.111d16.157i26c68.366",
        ".477o31.871h10.105e189.96e38d39.111d16.155i29c67.366",
        ".476o32.871h9.105e189.99e35d40.111d16.147i37c66.367",
        ".476o33.871h8.104e186.103e34d41.111d15.13d9.124i39c66.367",
        ".475o34.872h6.104e187.103e33d42.112d13.13d13.120i40c66.367",
        ".475o34.981e188.103e33d42.113d10.14d16.118i39c66.368",
        ".474o34.981e189.103e34d41.137d17.116i40c66.368",
        ".474o34.981e188.104e36d39.137d17.116i40c66.368",
        ".474o32.982e189.104e36d1e1d37.137d17.116i39c66.369",
        ".474o31.982e190.104e38d37.138d16.116i38c67.369",
        ".474o31.982e190.105e38d36.139d15.116i37c68.369",
        ".475o29.982e190.106e39d35.140d13.86i4.28i34c69.370",
        ".475o28.983e190.107e40d33.142d10.87i4.28i32c71.370",
        ".476o27.983e189.110e38d33.148d2.90i3.29i31c70.371",
        ".477o25.982e191.82e7.21e39d32.273i26.4c70.371",
        ".477o24.983e189.83e9.20e41d29.2d6.269i20.8c69.371",
        ".477o23.984e189.83e9.20e42d37.270i18.9c67.372",
        ".477o22.984e188.85e9.20e44d36.271i15.11c65.373",
        ".477o20.986e187.86e9.20e44d37.271i13.13c63.374",
        ".477o18.987e188.86e9.20e46d36.271i9.16c62.375",
        ".463o9.6o14.990e188.86e9.20e52d31.296c60.376",
        ".462o14.2o11.992e187.89e7.21e53d31.296c58.377",
        ".461o27.993e186.91e5.22e55d29.297c55.379",
        ".461o25.995e185.119e56d29.297c53.380",
        ".458o26.998e183.120e57d28.298c51.381",
        ".457o27.998e182.121e58d27.299c49.382",
        ".456o29.997e32h2e148.122e58d26.300c47.383",
        ".456o29.997e31h3e146.92e3.29e59d25.301c45.384",
        ".455o30.997e30h4e145.91e7.27e60d24.254i14.34c43.385",
        ".454o31.997e29h4e146.90e9.26e60d23.254i17.32c42.386",
        ".454o31.998e26h6e146.89e10.26e61d20.256i18.32c40.387",
        ".452o33.999e8h3e14h6e145.89e11.27e60d21.252i22.32c38.388",
        ".450o34.1001e8h4e3h3e3h10e144.89e11.27e61d21.248i25.33c34.391",
        ".450o33.1003e6h11e2h11e143.90e11.28e61d20.245i29.18i15c32.392",
        ".449o32.1006e4h25e142.91e11.28e61d21.242i31.18i16c29.394",
        ".436o43.994h5.10e2h26e142.91e10.29e61d21.239i35.16i19c25.396",
        ".434o44.993h8.10h27e141.93e8.32e59d21.236i38.14i22c21.399",
        ".434o40.996h10.10h30e137.94e6.33e59d22.232i41.13i24c16.403",
        ".433o38.998h11.11h33e132.136e57d22.229i45.11i26.4c8.406",
        ".432o38.997h13.10h34e133.137e55d22.226i48.9i29.4c4.409",
        ".432o37.997h14.10h36e133.136e54d21.224i51.8i30.417",
        ".431o37.997h15.7h39e134.136e53d20.223i54.5i32.417",
        ".388o2.41o20.1o11.1001h16.6h40e134.139e50d20.220i57.2i35.417",
        ".386o7.37o21.1012h16.6h41e135.144e44d20.217i97.417",
        ".385o8.37o20.1013h15.7h39e137.150e38d20.214i99.418",
        ".384o14.32o20.1012h15.8h38e138.155e33d20.211i102.418",
        ".384o16.30o19.1013h14.9h37e138.161e28d19.209i104.419",
        ".384o16.6o8.16o18.1013h14.4h44e136.165e25d19.207i106.419",
        ".384o18.2o12.15o16.1014h13.4h45e135.167e21.4d17.205i106.422",
        ".385o32.15o14.1015h13.3h45e134.174e13.8d12.206i107.424",
        ".386o31.18o10.1016h12.4h41e137.180e7.14d4.206i109.425",
        ".387o31.18o8.1018h9.6h40e137.409i110.427",
        ".390o28.20o5.1020h7.7h40e136.116e6.286i112.427",
        ".391o27.1046h5.8h40e135.116e8.282i112.430",
        ".391o28.1059h35e1h1e136.116e10.279i113.431",
        ".392o27.1060h34e137.117e10.277i96.2i14.434",
        ".393o26.1063h31e137.117e10.276i98.5i8.436",
        ".394o25.1063h32e135.118e10.27e6.242i99.7i4.438",
        ".395o24.1063h32e135.118e10.25e9.239i101.449",
        ".401o17.1064h33e134.119e8.25e10.238i103.448",
        ".402o16.1064h33e134.120e6.26e11.235i105.448",
        ".404o13.1064h34e133.152e12.234i105.449",
        ".406o9.1065h29e2h3e134.152e12.233i106.449",
        ".1480h28e140.152e11.231i108.450",
        ".1480h27e141.151e12.229i109.451",
        ".1479h21e1h6e141.151e11.228i110.452",
        ".1478h22e2h3e143.151e10.227i110.454",
        ".1398h7.71h23e4h1e145.151e9.224i112.455",
        ".1396h10.69h28e146.151e9.222i113.456",
        ".1396h11.67h28e147.152e6.224i112.457",
        ".1394h15.64h29e148.378i114.458",
        ".358o7.1029h17.61h29e149.375i115.460",
        ".357o9.1027h19.59h30e149.372i117.461",
        ".357o9.1027h20.56h32e149.370i118.462",
        ".357o10.1026h21.53h27e156.368i119.463",
        ".357o10.1025h23.52h26e157.366i120.464",
        ".357o9.1026h23.51h27e157.364i120.466",
        ".357o9.1026h24.50h22e162.363i120.467",
        ".358o7.1027h24.49h23e162.361i121.468",
        ".359o5.1027h25.49h23e162.360i121.469",
        ".1391h25.48h23e163.358i122.470",
        ".303o6.1081h27.46h23e164.352i127.471",
        ".275o5.22o8.1080h27.45h24e164.347i132.471",
        ".273o9.19o10.1075h30.44h26e164.340i138.472",
        ".272o10.19o10.1073h32.44h25e165.339i138.473",
        ".272o11.18o10.1073h32.43h26e165.338i138.474",
        ".271o12.18o10.1072h32.44h23e1h1e166.338i137.475",
        ".270o14.17o10.1071h33.43h24e168.338i136.476",
        ".269o15.18o8.1071h33.44h24e168.337i136.477",
        ".269o15.19o6.1071h33.44h25e168.337i136.477",
        ".269o15.1095h32.45h25e169.336i136.478",
        ".269o14.1095h33.43h27e1h1e167.336i135.479",
        ".269o14.1093h34.43h30e167.335i135.480",
        ".269o13.1093h34.42h31e168.336i133.481",
        ".270o10.1093h36.40h33e168.336i132.482",
        ".272o6.1094h37.39h33e169.337i131.482",
        ".1362h47.38h34e169.338i129.483",
        ".1362h47.36h35e170.340i126.484",
        ".1360h49.35h36e171.348i116.485",
        ".1359h50.33h37e172.308i9.32i115.485",
        ".1357h51.32h30e2h6e173.305i17.28i113.486",
        ".1355h52.33h29e4h4e174.302i22.27i109.489",
        ".1354h53.31h31e182.287i8.6i28.22i107.491",
        ".1353h53.31h32e182.286i10.5i30.21i103.494",
        ".1352h53.31h32e183.286i11.4i30.22i100.496",
        ".1351h53.31h32e184.285i13.3i33.20i97.498",
        ".1350h48.36h33e185.284i13.3i35.19i94.500",
        ".1350h47.36h33e186.284i13.3i37.17i92.502",
        ".1349h47.37h32e187.285i12.4i37.17i88.505",
        ".239o2.1041h6.61h47.37h32e188.284i11.6i38.16i85.507",
        ".237o6.1038h8.60h45.39h30e190.286i8.13i35.14i82.509",
        ".236o8.1036h10.59h45.38h30e192.289i2.18i34.13i79.511",
        ".235o10.1035h10.60h44.37h30e193.311i32.13i78.512",
        ".235o10.1035h10.60h44.35h31e194.313i31.13i76.513",
        ".235o10.1035h10.61h43.34h31e191g5.314i30.13i74.514",
        ".235o10.1036h8.62h43.33h31e192g5.315i30.12i74.514",
        ".236o8.1038h7.62h43.32h32e191g7.316i28.12i73.515",
        ".237o6.1041h2.66h42.27h37e190g9.315i29.11i72.516",
        ".239o2.1111h41.24h41e189g10.315i29.11i71.517",
        ".1352h40.24h42e189g11.314i29.11i70.518",
        ".184o7.1161h39.24h42e188g13.314i29.10i70.519",
        ".183o9.1161h38.22h43e188g15.312i31.9i70.519",
        ".183o9.1161h37.20h47e185g17.312i31.8i70.520",
        ".182o10.1161h37.18h50e178g24.310i32.8i70.520",
        ".182o10.1161h36.18h51e171g5e1g25.309i33.7i70.521",
        ".162o7.14o9.1161h36.18h53e169g32.307i34.7i69.522",
        ".161o9.13o9.1161h36.18h54e168g32.303i38.7i69.522",
        ".160o10.14o7.1162h36.18h54e168g32.302i39.7i68.523",
        ".160o11.15o3.1164h36.18h54e168g33.300i40.7i68.523",
        ".160o11.1182h36.17h53e170g33.299i42.6i67.524",
        ".118o3.39o11.1181h36.18h51e172g33.299i42.6i66.525",
        ".116o8.36o10.1181h36.19h51e172g33.298i43.7i65.525",
        ".116o9.36o9.1180h33.23h49e174g33.298i43.8i63.526",
        ".115o11.36o7.1180h34.23h49e174g33.298i43.9i62.526",
        ".115o11.1222h35.23h49e174g33.297i44.9i61.527",
        ".115o11.1221h36.24h47e167g41.297i44.10i60.527",
        ".115o11.1217h40.24h47e163g2e1g42.297i44.10i59.528",
        ".115o10.1217h41.24h42e168g45.297i44.10i58.529",
        ".116o9.1216h41.26h35e174g44.294i48.10i58.529",
        ".118o5.1218h40.28h34e174g44.293i49.10i57.530",
        ".1338h39.32h33e172g47.291i52.9i57.530",
        ".1337h40.33h32e170g49.291i52.9i56.531",
        ".1335h42.32h32e171g49.290i53.9i55.532",
        ".1334h42.28h37e171g48.291i53.9i55.532",
        ".1325h52.24h40e171g48.291i53.9i54.533",
        ".1324h53.23h41e172g47.290i54.9i54.533",
        ".1322h55.22h41e171g49.290i54.9i53.534",
        ".1321h56.21h42e170g49.291i54.9i52.535",
        ".1321h56.21h42e168g51.290i55.9i51.536",
        ".1317h59.22h42e168g50.291i55.9i50.537",
        ".1316h59.23h42e169g49.290i56.9i48.539",
        ".1313h59.24h43e170g49.289i57.9i47.540",
        ".1311h60.22h45e163g3e3g51.289i57.9i45.542",
        ".1309h61.21h46e104g2e58g56.289i58.9i43.544",
        ".1307h62.21h47e96g10e58g56.289i57.10i42.545",
        ".1306h61.20h42e102g12e8g2e45g59.288i58.11i40.546",
        ".1306h60.19h43e103g15e4g2e46g60.287i58.12i38.547",
        ".1305h61.18h44e102g17e1g3e46g61.286i58.15i32.551",
        ".1305h60.18h44e103g22e45g61.285i59.18i27.553",
        ".1305h61.17h45e103g21e6g1e36g63.284i60.20i20.558",
        ".1303h64.16h46e103g29e33g65.283i59.23i16.560",
        ".1301h67.15h45e105g28e32g66.282i60.26i12.561",
        ".1300h68.15h45e105g27e32g68.281i59.29i9.562",
        ".1299h69.15h44e103g29e34g67.280i60.29i6.565",
        ".1297h70.16h44e103g28e35g68.279i59.601",
        ".77o9.1210h71.15h45e104g26e36g68.279i59.601",
        ".76o12.1207h71.14h46e105g26e36g69.278i58.602",
        ".76o13.1204h64.3h4.14h48e105g25e38g69.276i59.602",
        ".75o15.1202h64.20h49e106g25e39g69.275i59.602",
        ".75o15.1201h64.14h53e109g25e38g70.274i59.603",
        ".75o15.1201h62.15h55e109g22e35g76.273i59.603",
        ".75o16.1199h61.16h55e110g21e32g81.272i59.603",
        ".75o16.1198k2h59.17h55e106g1e2g24e27g85.271i58.604",
        ".50p4.22o14.1198k8h54.17h54e108g23e29g88.269i58.604",
        ".48p9.20o13.1198k14h5.3h40.17h53e109g23e28g90.268i57.605",
        ".47p11.20o12.1197k15.8h4k36.17h53e110g22e28g92.266i56.606",
        ".47p11.22o9.1196k17.10h1k36.19h51e111g21e29g94.264i56.606",
        ".31p5.10p13.23o5.1197k18.11k36.1h6.11h52e111g21e29g96.262i56.606",
        ".29p9.8p13.1224k19.10k37h8.9h53e112g19e30g97.261i55.607",
        ".28p11.8p12.1224k19.10k36h10.4h66e103g19e24g104.260i55.607",
        ".28p11.8p11.1225k18.12k35h10.3h69e101g20e24g105.258i56.606",
        ".27p12.8p11.1225k18.13k34h10.3h70e101g19e25g106.257i55.606",
        ".27p12.9p9.1226k18.12k35h10.2h70e102g18e24g111.255i55.605",
        ".28p11.11p6.1228k16.11k37h10.2h70e102g18e20g117.254i54.605",
        ".28p11.1247k14.10k38h82e100g20e17g122.252i53.606",
        ".28p10.1254k6.11k38h83e98g21e17g125.250i53.606",
        ".29p8.1196k2.73k38h83e90g1e4g1e2g21e17g128.248i53.606",
        ".32p3.1196k7.70k38h83e84g2e4g28e17g131.245i53.607",
        ".1230k9.67k39h84e83g3e3g29e17g133.111g7.125i53.607",
        ".1229k11.65k40h83e83g37e15g135.109g13.120i52.608",
        ".1229k11.64k41h83e79g41e14g137.81g7.4g2.13g15.119i51.609",
        ".1229k11.63k41h83e79g43e13g139.76g21.8g16.114i54.610",
        ".1229k12.61k42h83e78g44e12g141.74g24.6g17.111i56.610",
        ".1228k13.60k43h82e78g46e11g142.73g25.5g18.110i55.611",
        ".1228k13.60k43h82e72g3e1g49e8g146.68g52.108i55.612",
        ".1228k13.58k45h82e72g53e2g154.64g54.108i55.612",
        ".1228k12.58k46h83e72g210.61g56.106i55.613",
        ".1228k12.58k46h82e74g210.57g59.105i56.613",
        ".1228k12.54k50h82e73g212.49g66.105i55.614",
        ".1228k12.52k52h83e68g216.48g67.104i55.615",
        ".1229k10.53k51h84e68g219.37g74.103i57.615",
        ".1230k8.51k54h83e68g222.29g79.73i4.27i56.616",
        ".1287k55h84e68g225.3g3.17g81.72i9.23i57.616",
        ".1286k55h87e64g235.13g84.66g5i11.21i56.617",
        ".1282k58h88e64g236.4g3.2g88.64g6i13.18i57.617",
        ".1281k59h88e60g338.62g7i15.15i57.618",
        ".1280k59h89e59g340.60g9i16.12i58.618",
        ".1279k59h90e56g344.59g5i23.8i58.619",
        ".1279k58h93e54g344.59g5i25.6i58.619",
        ".1279k57h94e54g344.59g4i6g3i18.3i59.620",
        ".1279k56h93e56g345.57g5i4g5i80.620",
        ".1279k55h94e57g344.55g8i2g6i80.620",
        ".1279k55h94e57g344.53g18i80.620",
        ".1279k54h95e57g348.48g19i79.621",
        ".1279k53h96e57g363.31g20i80.621",
        ".1279k52h97e55g370.24g21i81.621",
        ".1279k51h98e57g375.14g24i80.622",
        ".1277k52h99e58g1e1g410i80.622",
        ".1276k52h100f1e59g411i79.622",
        ".1275k52h103e57g2f2g408i79.622",
        ".1273k53h103f1e59f4g407i77.623",
        ".1273k52h103f4e57f8g403i78.622",
        ".1272k52h104f7e54f8g404i77.622",
        ".1272k52h104f7e54f10g1f3g398i76.623",
        ".1272k51h104f8e53f15g398i76.623",
        ".1273k49h105f9e51f16g399i75.623",
        ".1273k48h103f14e49f15g401i74.623",
        ".1273k47h103f14e49f16g401i74.623",
        ".1272k47h104f17e46f16g401i74.623",
        ".1270k48h104f18e8f1e37f16g401i74.623",
        ".1269k48h105f18e7f5e2f1e30f17g400i75.623",
        ".1268k48h106f21e1f12e24f22g400i76.622",
        ".1268k47h109f34e22f22g399i77.622",
        ".1268k46h110f34e21f23g399i77.622",
        ".1268k45h114f32e18f25g399i77.622",
        ".1268k45h113f33e16f27g398i79.621",
        ".1268k44h113f37e12f28g398i80.620",
        ".1267k44h113f38e1f2e9f28g397i81.620",
        ".1266k44h114f78g397i81.620",
        ".1265k44h116f77g397i81.620",
        ".1263k45h117f77g397i81.620",
        ".1263k45h112f82g397i82.619",
        ".1262k46h112f82g397i83.618",
        ".1261k47h112f82g397i83.618",
        ".1261k47h112f82g398i82.618",
        ".1261k47h112f82g397i84.617",
        ".1260k48h112f82g397i84.617",
        ".1259k49h112f82g397i85.616",
        ".1259k47h114f82g396i87.615",
        ".1259k46h115f82g396i88.614",
        ".1259k44h117f82g396i89.613",
        ".1258k43h119f82g396i90.612",
        ".1257k43h120f82g397i89.612",
        ".1257k43h120f82g13f2g382i90.611",
        ".1257k43h120f119g361i91.311j2.296",
        ".1256k44h120f119g361i92.307j8.293",
        ".1255k45h120f119g361i94.304j11.291",
        ".1253k47h120f119g362i95.302j12.290",
        ".1251k47h122f119g363i94.301j14.289",
        ".1250k48h122f119g364i94.300j15.288",
        ".1249k50h121f119g363i97.298j15.288",
        ".1249k51h120f119g362i100.296j15.288",
        ".1249k51h120f119g359i105.295j14.288",
        ".1249k52h119f119g358i108.294j13.288",
        ".1249k54h117f119g357i111.294j10.289",
        ".1230k3.16k54h117f119g358i111.295j6.291",
        ".1228k8.14k53h117f119g358i112.591",
        ".1226k11.13k54h116f119g358i113.590",
        ".1225k13.11k56h115f119g357i116.588",
        ".1225k13.11k60h111f119g357i118.586",
        ".1224k14.11k60h111f119g356i122.583",
        ".1223k15.11k61h110f119g356i123.582",
        ".1223k15.11k61h110f119g357i122.582",
        ".1223k14.12k61h110f119g357i124.580",
        ".1207k7.8k14.12k58h114f119g357i125.579",
        ".1205k11.6k13.12k58h115f119g357i126.578",
        ".1204k12.7k14.10k58h115f119g357i126.578",
        ".1203k14.6k15.8k60h114f119g356i128.577",
        ".1202k15.8k14.5k62h114f119g356i128.577",
        ".1201k22.2k14.3k63h115f119g356i127.578",
        ".1201k38.2k64h115f119g356i127.578",
        ".1201k38.1k65h115f119g356i129.576",
        ".1201k104h115f119g356i129.576",
        ".1201k12.1k93h113f119g355i131.575",
        ".1202k8.4k94h112f119g355i132.574",
        ".1204k4.6k95h111f119g355i134.572",
        ".1215k94h111f119g355i137.7i6.556",
        ".1196k3.17k7.2k84h111f119g355i140.2i9.555",
        ".1193k9.1k1.22k83h111f120g353i153.554",
        ".1192k18.13k2.1k83h111f120g353i153.554",
        ".1188k28.3k90h111f120g353i153.554",
        ".1187k122h111f120g353i154.553",
        ".1186k123h111f120g353i154.553",
        ".1185k124h111f120g353i154.553",
        ".1184k126h110f120g352i156.552",
        ".1184k127h109f120g352i157.551",
        ".1184k127h109f120g352i158.550",
        ".1184k129h107f120g352i159.549",
        ".1185k10.5k115h105f120g351i161.548",
        ".1186k8.5k117h104f120g351i163.546",
        ".1186k130h104f120g351i165.544",
        ".1184k131h105f120g351i167.8i7.527",
        ".1183k129h108f120g351i169.5i9.526",
        ".1182k130h108f120g351i183.526",
        ".1182k130h108f120g350i185.525",
        ".1182k129h109f120g350i185.525",
        ".1182k129h109f120g350i186.524",
        ".1182k128h110f120g350i187.523",
        ".1182k127h111f120g349i190.521",
        ".1182k126h112f120g349i191.520",
        ".1181k126h113f120g349i192.519",
        ".1181k126h113f120g349i194.517",
        ".1181k126h113f120g349i195.516",
        ".1181k126h103f1h3f126g352i195.513",
        ".1179k128h103f3h1f126g353i200.507",
        ".1178k129h103f3h1f126g353i201.506",
        ".1177k130h105f1h1f126g353i202.505",
        ".1177k131h103f1h2f126g354i201.505",
        ".1177k131h68f35h4f125g355i200.505",
        ".1176k132h68f35h1f128g355i200.505",
        ".1175k132h69f164g356i200.504",
        ".1174k133h69f164g356i200.504",
        ".1173k134h69f164g358i198.504",
        ".1171k135h70f164g358i198.504",
        ".1170k136h70f3h16f145g359i197.504",
        ".1169k137h69f4h19f142g359i197.504",
        ".1169k137h68f5h21f140g359i197.504",
        ".1168k138h68f5h16f4h1f140g361i195.504",
        ".1167k138h62f2h5f5h16f4h1f140g361i195.504",
        ".1166k139h62f2h5f5h16f4h2f139g363i193.504",
        ".1165k140h62f12h17f2h3f139g366i189.505",
        ".1164k141h61f13h21f140g367i188.505",
        ".1163k142h61f13h21f140g367i187.506",
        ".1163k142h61f8h4f1h19f142g366i188.506",
        ".1161k144h61f8h4f1h16f145g366i187.507",
        ".1159k145h11k2h48f9h14f1h3f148g365i187.508",
        ".1158k147h9k3h48f9h17f149g363i189.508",
        ".1157k151h2k8h47f10h1f3h13f148g363i188.509",
        ".1157k162h46f14h13f148g363i188.509",
        ".1156k163h45f15h14f147g365i185.510",
        ".1156k163h44f18h12f147g366i184.510",
        ".1156k163h45f18h12f146g367i182.511",
        ".1156k163h45f20h2f3h5f146g367i182.511",
        ".1155k164h45f176g366i183.511",
        ".1155k164h45f176g366i182.512",
        ".1155k164h46f175g365i183.512",
        ".1155k163h47f175g365i183.512",
        ".1155k163h48f174g361i187.512",
        ".1155k163h49f173g360i187.513",
        ".1154k164h50f172g360i187.513",
        ".1152k166h52f5h2f163g360i186.514",
        ".1151k167h54f2h3f163g361i185.514",
        ".1150k168h54f1h2f165g362i184.514",
        ".1149k169h56f186g344i183.513",
        ".1148k171f2h4f7h40f188g343i185.512",
        ".1147k172f241g342i187.511",
        ".1146k173f241g342i187.511",
        ".1146k173f241g340i190.510",
        ".1146k173f241g339i192.509",
        ".1146k173f241g332i2g5i192.509",
        ".1146k173f241g332i4g2i194.508",
        ".1145k174f241g331i201.508",
        ".1144k175f241g329i204.507",
        ".1138k4.2k175f241g320i7g2i204.507",
        ".1136k183f241g319i215.506",
        ".1135k184f241g318i216.506",
        ".1133k186f241g316i218.506",
        ".1133k186f241g316i220.504",
        ".1132k187f251g307i220.503",
        ".1132k188f250g307i221.502",
        ".1132k188f250g307i222.501",
        ".1133k187f250g306i224.500",
        ".1133k186f251g305i225.500",
        ".1134k185f251g303i228.499",
        ".1134k185f251g302i230.498",
        ".1134k185f251g302i230.498",
        ".1135k185f250g301i231.498",
        ".1134k185f251g301i232.497",
        ".1133k186f251g301i233.496",
        ".1133k186f251g284i12g3i235.496",
        ".1131k188f250g285i250.496",
        ".1130k189f250g285i250.496",
        ".1129k191f249g283i253.495",
        ".1128k192f249g283i253.495",
        ".1127k193f249g279i1g2i254.495",
        ".1126k194f249g279i257.495",
        ".1124k196f249g279i256.496",
        ".1123k197f249g281i254.496",
        ".1122k198f251g280i254.495",
        ".1121k199f251g280i256.493",
        ".1120k200f251g279i258.492",
        ".1120k200f251g279i259.491",
        ".1119k201f251g279i260.490",
        ".1119k201f251g279i261.489",
        ".1120k200f251g278i262.489",
        ".1120k200f251g278i263.488",
        ".1119k201f253g275i265.487",
        ".1119k201f253g276i266.485",
        ".1118k202f253g276i268.483",
        ".1118k202f253g276i269.482",
        ".1118k202f253g277i269.481",
        ".1118k202f253g277i269.481",
        ".1118k202f253g277i270.480",
        ".1118k202f253g277i271.479",
        ".1118k202f253g277i272.478",
        ".1118k202f253g277i272.478",
        ".1118k202f239g291i273.477",
        ".1118k202f239g291i274.476",
        ".1117k203f239g291i274.476",
        ".1116k204f239g291i274.476",
        ".1115k205f239g291i274.476",
        ".1114k206f239g291i274.476",
        ".1113k207f239g291i274.476",
        ".1112k208f239g291i275.475",
        ".1110k210f254g276i275.475",
        ".1109k211f254g276i275.475",
        ".1108k212f254g276i275.475",
        ".1107k213f254g276i276.474",
        ".1107k213f254g276i276.474",
        ".1107k213f254g276i276.474",
        ".1106k214f254g276i276.474",
        ".1105k215f254g276i282.468",
        ".1105k215f254g276i289.461",
        ".1105k215f254g276i292.458",
        ".1105k215f254g276i294.456",
        ".1106k214f254g276i299.451",
        ".1107k213f254g276i303.447",
        ".1108k212f256g274i306.444",
        ".1108k212f256g283i299.442",
        ".1109k211f256g283i302.439",
        ".1109k211f256g285i303.436",
        ".1110k210f256g285i305.434",
        ".1111k209f256g286i308.430",
        ".1111k209f256g286i311.427",
        ".1111k209f256g286i312.9i2.11i6.398",
        ".1110k210f255g287i313.5i8.4i13.395",
        ".1110k210f255g287i313.3i28.394",
        ".1111k209f255g296i304.3i28.394",
        ".1111k209f255g296i304.2i30.393",
        ".1111k209f255g296i336.393",
        ".1111k209f255g296i336.393",
        ".1111k209f255g296i335.394",
        ".1111k209f252g299i335.394",
        ".1112k208f252g298i336.394",
        ".1112k208f252g299i335.394",
        ".1111k209f252g299i336.393",
        ".1109k211f252g299i336.393",
        ".1108k212f252g298i337.393",
        ".1107k213f264g286i337.393",
        ".1107k213f264g286i337.393",
        ".1107k213f264g273i350.393",
        ".1107k213f264g273i350.393",
        ".1107k213f264g273i350.393",
        ".1108k212f264g273i349.394",
        ".1107k153f324g274i348.394",
        ".1107k153f325g273i347.395",
        ".1106k154f325g273i347.395",
        ".1106k154f325g273i346.396",
        ".1106k154f325g274i344.397",
        ".1105k155f324g275i342.399",
        ".1105k155f324g275i332.409",
        ".1104k156f324g276i331.409",
        ".1104k156f325g275i332.408",
        ".1104k132f14k10f325g275i333.407",
        ".1104k132f349g275i334.406",
        ".1104k132f349g275i334.406",
        ".1102k134f349g275i335.405",
        ".1102k134f347g277i335.405",
        ".1101k135f347g276i336.405",
        ".1101k135f348g275i335.406",
        ".1101k135f347g276i334.407",
        ".1102k134f347g276i335.406",
        ".1103k133f346g277i335.406",
        ".1103k133f346g277i336.405",
        ".1104k132f340g283i337.404",
        ".1105k131f340g282i338.404",
        ".1105k131f340g282i339.403",
        ".1105k131f340g282i338.82j12.310",
        ".1105k131f340g282i339.78j18.307",
        ".1106k130f340g282i340.76j22.304",
        ".1106k130f340g282i341.74j25.302",
        ".1106k130f340g282i342.73j26.301",
        ".1106k130f340g282i344.70j29.299",
        ".1107k129f340g282i347.67j31.297",
        ".1108k128f340g282i351.63j32.296",
        ".1109k127f340g282i360.2i6.45j35.294",
        ".1109k127f340g282i369.44j37.292",
        ".1110k126f340g282i370.43j38.291",
        ".1110k126f340g282i372.41j39.87j9.194",
        ".1110k126f340g283i372.3i7.30j40.83j14.192",
        ".1110k126f343g280i383.29j40.81j17.191",
        ".1111k125f343g280i384.27j43.78j20.189",
        ".1111k125f343g280i385.26j45.76j21.188",
        ".1111k125f344g280i384.26j47.74j22.187",
        ".1111k125f344g280i383.25j50.73j22.187",
        ".1111k125f344g280i383.24j52.72j22.187",
        ".1111k125f344g280i383.23j55.71j21.187",
        ".1111k125f353g272i385.20j58.70j6.1j11.188",
        ".1112k124f354g271i389.16j65.72j8.189",
        ".1112k126f353g270i392.4j2.1j74.73j1.192",
        ".1112k127f11k7f336g269i392j81.265",
        ".1112k128f9k7f337g269i391j83.264",
        ".1112k144f337g270i391j86.260",
        ".1112k145f335g271i391j93.253",
        ".1112k146f332g274i391j95.250",
        ".1112k146f332g274i392j97.247",
        ".1112k147f329g276i393j100.243",
        ".1112k147f329g277i394j102.239",
        ".1112k148f328g277i395j103.237",
        ".1112k150f328g276i395j105.234",
        ".1112k151f329g274i394j109.231",
        ".1113k151f329g274i393j111.229",
        ".1113k151f328g276i391j115.226",
        ".1113k151f328g277i390j120.221",
        ".1113k151f331g274i390j123.218",
        ".1113k152f329g277i386j128.215",
        ".1114k152f329g277i380j3i2j129.214",
        ".1114k152f329g279i377j136.213",
        ".1114k153f328g281i374j138.212",
        ".1114k153f328g279i376j139.211",
        ".1114k153f328g276i379j140.210",
        ".1114k154f7k1f11k4f12k3f289g274i382j139.210",
        ".1114k155f4k8f3k8f9k5f289g271i384j144.206",
        ".1114k155f4k21f5k9f286g263i392j147.204",
        ".1114k156f3k36f284g263i394j149.201",
        ".1114k157f2k37f282g263i393j153.199",
        ".1115k156f2k37f282g262i392j157.197",
        ".1114k157f2k38f283g260i389j161.196",
        ".1114k156f3k38f284g259i389j164.193",
        ".1114k156f3k37f284g260i389j166.191",
        ".1114k153f6k38f282g261i389j168.189",
        ".1113k153f6k41f280g261i389j169.188",
        ".1113k153f5k42f279g261i391j168.188",
        ".1113k199f262g279i391j169.187",
        ".1114k197f263g274i396j169.187",
        ".1114k197f263g274i396j169.187",
        ".1113k198f266g271i396j169.187",
        ".1112k200f265g271i396j168.188",
        ".1112k200f267g269i396j167.189",
        ".1112k200f267g259i406j167.189",
        ".1112k200f267g259i406j166.190",
        ".1112k200f268g233i7g18i406j164.192",
        ".1113k200f262g238i7g18i406j161.119m16.60",
        ".1112k201f262g238i431j158.119m22.57",
        ".1112k202f261g238i431j157.73l3.41m26.56",
        ".1112k202f261g231i438j157.69l11.34m30.55",
        ".1112k202f261g228i441j156.68l14m6.14m44.54",
        ".1112k196f3k3f252g227i4g6i441j156.67l15m65.53",
        ".1112k196f258g228i6g3i441j156.66l16m65.53",
        ".1111k194f254g236i6g2i441j156.66l15m67.52",
        ".1111k192f256g236i449j156.66l15m67.52",
        ".1110k192f257g237i448j156.66l13m69.52",
        ".1110k192f257g237i448j156.66l12m71.51",
        ".1110k191f258g238i447j157.65l12m71.51",
        ".1110k189f259g240i446j159.63l12m71.51",
        ".1110k188f260g240i444j163.61l12m72.50",
        ".1110k188f260g241i442j165.60l12m72.50",
        ".1109k187f262g242i421j3i16j168.49m7.2l11m74.49",
        ".1108k187f263g242i419j9i11j171.43m12.1l10m75.49",
        ".1107k187f264g243i417j15i4j175.38m17l9m76.48",
        ".1106k184f268g244i416j15i2j179.32m22.1l6m78.47",
        ".1106k183f267g246i422j190m14.12m113.47",
        ".1105k182f269g247i424j184m143.46",
        ".1105k183f268g248i425j179m146.46",
        ".1105k182f269g248i426j175m149.46",
        ".1104k183f241g3f16g4f5g249i427j171m151.46",
        ".1104k183f239g6f1g1f1g3f6g9f3g250i426j168m154.46",
        ".1104k182f240g13f2g265i426j165m156.47",
        ".1102k184f238g283i425j162m159.47",
        ".1101k184f239g284i424j159m161.48",
        ".1100k184f240g284i424j159m161.48",
        ".1100k182f239g288i423j57i4j98m161.48",
        ".1099k182f240g289i422j19i6j31i8j95m160.49",
        ".1099k181f241g289i427j12i11j26i13j92m160.49",
        ".1099k181f240g248d1g2d1g30i1g8i451j22i19j88m160.49",
        ".1098k182f240g247d9g25i462j3i3j5i30j87m160.49",
        ".1098k182f240g245d13g7i1g3i1g9i466j1i40j85m160.49",
        ".1098k182f240g244d16g5i524j81m161.49",
        ".1098k182f240g240d20g4i527j79m160.50",
        ".1098k182f240g239d21i536j74m160.50",
        ".1099k181f240g239d21i537j73m159.51",
        ".1099k181f240g238d22i539j71m159.51",
        ".1099k181f240g235d25i541j69m158.52",
        ".1098k182f240g234d26i542j68m158.52",
        ".1094k186f240g236d24i544j17c50m156.53",
        ".1092k188f240g237d23i561c50m156.53",
        ".1090k190f240g239d21i561c50m156.53",
        ".1087k193f240g242d18i561c50m155.54",
        ".1085k195f240g244d16i561c50m155.54",
        ".1084k196f240g244d16i561c50m154.55",
        ".1082k198f240g244d16i561c51m152.56",
        ".1079k201f240g244d16i561c53m150.56",
        ".1077k203f240g244d16i561c54m148.57",
        ".1074k187h10k9f119e7f9e38f9e111g191d16i561c55m146.58",
        ".1072k189h25f113e174g191d16g1i560c56m145.58",
        ".1070k189h26f114e174g208i560c12i11c35m142.59",
        ".1068k191h25f115e174g208i560c10i15c34m141.59",
        ".1066k193h24f116e174g208i560c1i24c35m139.60",
        ".1064k198h1k1h17f118e174g208i584c38m136.61",
        ".1063k202h15f119e174g228i563c40m135.61",
        ".1061k203h13f122e174g228i562c42m133.62",
        ".1060k204h13f122e174g228i559c47m130.63",
        ".1059k205h13f122e174g228i556c51m128.64",
        ".1058k205h13f123e174g228i555c53m125.66",
        ".1057k206h5f2h5f124e174g228i552c57m123.67",
        ".1056k207h5f131e173g229i551c60m129.59",
        ".1054k207h7f131e173g229i546c66m129.58",
        ".1053k208h8f130e173g229i543c70m129.57",
        ".1051k211h7f130e173g229i542c73m127.57",
        ".1048k214h6f131e173g229i538c78m112.1m13.57",
        ".1044k218h1k2h2f132e173g229i538c79m110.2m13.57",
        ".1040k228f131e173g229i538c81m107.3m12.58",
        ".1037k232f130e173g229i538c82m105.5m10.59",
        ".1036k236f127e173g229i538c83m103.9m5.61",
        ".1035k236f128e173g229i538c84m99.78",
        ".1034k237f128e173g229i539c85m91.84",
        ".1034k238f127e173g229i539c86m83.91",
        ".1034k237f128e173g229i539c87m74.99",
        ".1034k236f129e173g229i539c89m67.104",
        ".1033k237f129e172g230i539c90m64.106",
        ".1032k238f129e172g230i539c91m63.106",
        ".1031k237f131e172g230i539c92m63.105",
        ".1029k239f131e172g230i539c93m62.105",
        ".1028k239f132e172g230i539c95m61.104",
        ".1025k242f132e172g230i539c96m60.104",
        ".1022k246f131e172g230i539c97m59.104",
        ".1017k252f130e171g231i539c98m59.103",
        ".1014k254f131e171g231i539c99m58.103",
        ".1012k253f134e171g231i539c100m58.102",
        ".1010k254f135e171g230d1i539c101m57.102",
        ".1008k254f137e171g228d3i539c103m55.102",
        ".1007k253f139e171g226d5i539c104m53.103",
        ".1005k255f139e171g224d7i539c105m52.103",
        ".1003k257f139e171g222d9i539c106m50.104",
        ".13a9.979k257f141e171g220d11i539c108m48.104",
        ".11a13.975k254f1k3f142e171g218d13i539c111m45.104",
        ".11a14.973k255f146e171g217d14i539c114m41.105",
        ".10a17.969k257f146e171g216d15i539c115m40.105",
        ".10a18.966k259f146e171g216d15i539c116m40.104",
        ".10a19.1a8.954k260f147e171g215d15i540c116m41.103",
        ".10a30.950k256f153e171g215d15i540c117m40.103",
        ".11a33.15a5.925k255f155e170g216d15i540c118m40.102",
        ".11a36.9a13.918k256f156e170g216d18i537c118m41.101",
        ".12a60.913k257f157e170g216d18i537c118m41.101",
        ".12a65.906k259f157e170g216d18i537c118m42.100",
        ".12a69.900k260f158e170g217d15i507j2i30c118m42.100",
        ".12a73.895k262f157e170g218d14i506j5i28c118m42.100",
        ".12a75.891k264f157e170g219d13i506j7i26c118m42.100",
        ".13a76.887k266f157e170g220d12i497j1i1j2i3j10i25c118m41.101",
        "a1.13a81.2a3.874k264f161e170g221d11i495j19i25c118m41.101",
        "a2.14a100.5a20.832k265f161e170g223d9i491j22i26c118m42.100",
        "a2.14a129.826k267f161e170g225d7i491j22i26c118m43.99",
        "a3.13a131.823k267f162e170g227d5i491j22i26c118m43.99",
        "a3.14a131.821k268f162e170g229d3i485j2i3j25i24c118m43.99",
        "a3.16a9.2a121.816k266f166e169g232d1i485j29i8j17c118m43.99",
        "a2.29a124.811k266f167e169g233i477j5i2j30i8j134m44.99",
        "a2.32a10.3a111.807k267f167e169g233i471j3i3j39i8j132m44.99",
        ".62a98.803k269f167e169g233i471j3i2j40i8j132m43.100",
        ".67a94.11a5.785k269f168e169g233i469j46i8j133m40.103",
        ".72a89.8a11.781k270f168e169g233i469j46i7j134m39.104",
        ".74a8.2a77.7a18.774k275f164e169g233i469j47i3j137m39.104",
        ".85a47.9a20.6a22.769k278f163e169g233i469j48i1j138m38.105",
        ".94a7.3a23.14a20.6a25.765k279f163e169g233i471j185m38.105",
        ".105a21.16a18.7a27.761k282f162e169g233i471j185m38.105",
        ".107a18.18a16.8a36.751k281f164e169g233i470j46i1j139m37.106",
        ".109a14.23a10.11a43b9.733k283f164e169g233i470j46i2j138m37.106",
        ".112a8.48a43b11.728k284f165e169g233i470j46i4j136m36.107",
        ".169a42b14.724k286f164e169g233i460j4i6j47i11j128m36.107",
        ".171a41b17.719k286f178e155g234i458j7i7j49i6j129m35.108",
        ".173a39b23.712k286f180e154g254i437j10i4j54i1j130m35.108",
        ".179a33b25.709k287f180e154g254i434j2i1j10i3j186m35.108",
        ".181a32b25.706k288f182e6f1e146g254i432j15i3j186m35.108",
        ".185a3.2a23b26.704k288f183e4f3e146g254i432j18i2j184m35.108",
        ".191a22b26.703k286f194e145g254i431j19i2j184m35.108",
        ".191a23b26.3b8.690k287f194e145g254i431j205m36.107",
        ".193a21b41.685k286f195e145g256i430j205m36.107",
        ".195a18.1b43.682k287f194e146g258i428j205m36.107",
        ".198a14.5b42.679k287f194e147g259i428j3i3j198m36.107",
        ".198a13.6b50.670k278f4k4f195e148g261i433j197m37.106",
        ".200a9.9b52.666k279f202e149g262i432j197m37.106",
        ".219b53.663k279f201e151g264i429j203m33.105",
        ".220b54.660k279f197e156g265i428j209m27.105",
        ".222b53.658k273f202e158g265i430j212m22.105",
        ".224b53.656k272f203e158g265i429j218m17.105",
        ".225b55.652k272f203e159g265i422j228m14.105",
        ".226b56.650k271f1k2f194e166g265i421j231m11.106",
        ".227b57.647k275f193e167g265i421j234m7.107",
        ".229b56.646k275f193e167g264i421j237m4.108",
        ".231b17.2b36.644k275f194e167g262i421j241m1.109",
        ".234b11.5b36.644k269h1k3f196e166g262i420j242.111",
        ".232b14.4b47.632k269h2k1f198e166g261i422j240.112",
        ".232b15.3b55.624k269h2f199e166g260i422j240.113",
        ".232b15.3b57.622k266h2k1h2f199e166g258i423j239.115",
        ".232b15.3b58.621k265h6f199e166g257i422j239.117",
        ".232b14.5b58.620k265h6f199e166g256i422j238.119",
        ".233b12.8b58.33b6.579k267h4f199e166g236i443j235.121",
        ".234b10.10b58.29b13.576k258h12f199e165g237i442j233.124",
        ".257b55.25b20.573k258h12f199e162g240i443j230.126",
        ".262b53.20b24.571k258h12f199e159g243i445j227.127",
        ".272b45.17b26.571k254h15f199e156g246i445j226.128",
        ".273b46.15b26.571k254h15f199e155g247i444j226.129",
        ".274b46.7b3.4b27.571k252h16f199e154g248i444j226.129",
        ".277b86.570k245h1k2h1k1h17f199e153g249i443j227.129",
        ".282b83.569k243h23f199e152g250i444j225.130",
        ".294b72.562b3.4k236h29f199e151g251i445j2i1j221.130",
        ".294b77.31b12.511b10.1b1k233h30f199e151g251i448j3i1j216.131",
        ".294b79.26b17.507b19k227h31f199e151g251i454j214.131",
        ".294b80.17b28.503b24k223h31f199e151g251i456j61i5j146.131",
        ".295b79.15b32.501b56.1b2k188h31f199e151g251i456j60i5j147.131",
        ".296b79.13b34.500b64k183h31f199e151g251i454j31i1j1i2j15i4j6i6j148.131",
        ".299b77.12b35.498b69k173h2k2h33f199e152g250i453j9i1j21i5j16i15j148.131",
        ".300b77.9b37.498b69k172h38f199e153g249i452j7i6j18i9j1i1j9i18j146.132",
        ".301b77.1b44.498b72k169h38f199e154g248i451j7i6j19i12j6i21j143.134",
        ".302b121.499b72k167h39f199e155g247i450j7i6j15i18j3i23j2i2j128.145",
        ".303b120.500b72k164h41f199e156g246i449j6i8j11i52j125.148",
        ".304b118.500b74k160h44f199e159g243i449j6i8j10i53j122.151",
        ".307b115.499b75k158h46f199e163g239i463j9i54j119.154",
        ".313b108.499b77k157h46f199e163g239i463j7i57j114.158",
        ".317b103.499b80k154h47f199e163g239i463j7i56j112.161",
        ".322b96.500b82k151h49f199e163g239i96g4i362j6i57j111.163",
        ".329b89.499b82k146h2k2h51f199e163g239i94g6i362j4i61j106.166",
        ".329b88.499b83k141h1k1h58f199e163g239i91g9i362j2i66j100.169",
        ".328b88.500b83k140h61f199e163g239i89g11i424j102.173",
        ".328b87.501b82k141h61f199e163g239i87g13i423j98.178",
        ".329b87.500b82k142h60f199e162g240i86g14i424j93.182",
        ".329b97.22b8.25b12.424b80k141h62f199e162g240i83g17i425j90.184",
        ".330b100.16b12.21b16.414b88k139h64f199e162g240i81g19i425j89.185",
        ".333b6.6b87.13b14.19b18.408b93k137h1k2h63f199e162g240i74g26i423j90.186",
        ".346b87.11b15.18b19.406b95k135h68f199e162g240i72g28i424j88.187",
        ".347b87.10b15.3b7.7b21.404b95k137h67f199e162g240i68g32i423j88.188",
        ".348b89.7b28.4b21.403b97k135h68f199e162g240i64g36i423j88.188",
        ".350b88.7b28.4b19.404b99k131h70f199e161g241i61g39i422j88.189",
        ".352b89.5b28.3b19.404b99k131h70f199e161g241i53g47i421j88.190",
        ".354b90.4b8.1b18.3b18.404b99k131h70f199e161g241i50g50i424j84.191",
        ".357b88.12b18.5b15.405b99k131h70f199e161g241i49g51i422j1i2j82.192",
        ".359b91.6b19.7b12.404b97k1b2k132h70f199e161g241i46g54i418j87.194",
        ".363b89.4b19.10b6.406b94k139h70f199e161g241i45g55i418j86.195",
        ".368b85.3b18.30b2.390b95k138h71f199e161g241i44g56i418j84.197",
        ".374b79.3b17.26b11.385b94k139h72f199e161g241i43g57i420j81.198",
        ".384b69.3b17.25b23.373b92k142h72f199e161g242i42g57i416j83.200",
        ".204b8.173b87.25b29.367b92k143h72f199e161g244i39g58i416j82.201",
        ".201b13.171b86.25b32.365b87k147h73f199e161g246i35g60i416j81.202",
        ".199b17.170b83.27b34.362b84k152h72f199e161g247i33g61i415j81.203",
        ".198b20.170b80.28b34.360b83k155h72f199e161g249i29g63i420j76.203",
        ".197b21.172b78.29b34.357b85k152h75f199e161g251i22g68i419j76.204",
        ".197b21.174b76.30b33.355b77k1b6k155h75f199e161g252i19g70i418j76.205",
        ".197b21.177b75.29b32.353b79k163h74f199e161g254i16g71i417j76.206",
        ".197b21.179b75.28b32.351b79k162h76f199e161g256i10g75i416j77.206",
        ".197b20.182b76.27b32.348b80k162h76f199e161g257i8g76i416j76.207",
        ".199b17.186b74.28b33.344b80k162h77f199e161g259i4g78i417j75.207",
        ".190b4.7b11.193b72.27b37.336b84k162h77f199e161g341i418j73.208",
        ".186b12.209b71.24b40.334b81k165h78f199e161g341i418j73.208",
        ".185b14.212b68.23b44.329b83k164h78f199e161g341i420j70.209",
        ".184b21.208b67.22b46.327b83k163h79f199e161g341i420j69.210",
        ".184b23.208b66.21b47.326b84k161h80f199e161g341i421j66.212",
        ".184b24.210b64.19b49.325b77k168h80f199e161g341i421j64.214",
        ".184b25.211b62.16b54.323b78k166h81f199e161g341i423j61.215",
        ".184b25.212b61.14b63.316b79k163h83f199e161g341i421j1i1j60.216",
        ".184b25.213b61.13b65.313b81k161h84f199e161g341i421j61.217",
        ".184b25.214b63.9b67.312b80k162h84f199e161g341i421j60.218",
        ".185b23.216b64.7b68.311b78k166h82f199e161g341i421j60.218",
        ".187b19.219b66.5b67.309b79k166h83f199e161g341i423j58.218",
        ".190b13.223b66.4b67.307b79k168h83f199e161g341i423j58.218",
        ".428b136.304b80k165h2k1h84f199e161g341i423j58.218",
        ".431b134.302b80k166h87f199e161g341i423j58.218",
        ".434b131.302b80k164h89f199e161g341i423j58.218",
        ".435b130.301b80k164h90f199e161g341i424j57.218",
        ".436b129.299b80k163h93f199e161g341i422j58.219",
        ".437b128.298b80k160h97f199e161g341i421j58.220",
        ".438b126.298b81k159h98f199e161g340i418j61.221",
        ".439b125.297b81k159h99f199e161g340i417j61.222",
        ".439b124.298b80k160h99f199e161g340i416j61.223",
        ".439b123.298b80k161h99f199e161g340i416j60.224",
        ".439b129.292b79k162h99f199e161g340i415j60.225",
        ".440b130.290b78k162h100f199e161g340i414j60.226",
        ".440b131.288b78k164h99f199e161g340i411j62.227",
        ".440b132.285b80k165h98f199e161g340i411j60.229",
        ".416b9.15b132.282b81k167h98f199e161g340i411j59.230",
        ".413b16.10b133.280b82k162h104f199e161g340i412j56.232",
        ".412b19.8b133.277b84k153h1k2h2k1h108f199e161g340i415j52.233",
        ".364b2.11b3.31b22.4b135.275b85k152h116f199e161g340i416j50.234",
        ".359b13.1b14.4b6.1b5.7b162.273b85k151h1k1h117f199e161g340i416j48.236",
        ".354b52.3b163.270b90k146h122f199e161g340i419j43.238",
        ".351b220.269b91k144h125f199e161g340i423j38.239",
        ".349b220.270b89k144h128f199e161g340i418j3i1j37.241",
        ".349b216.272b89k141h4k1h128f199e161g340i417j40.243",
        ".348b216.271b90k136h4k1h134f199e161g340i417j39.244",
        ".348b215.271b90k137h139f199e161g340i418j37.245",
        ".349b217.267b90k140h137f199e161g340i417j1i1j1i1j32.247",
        ".349b219.265b87k139h141f199e161g340i415j5i9j23.248",
        ".351b218.262b86k141h142f199e161g340i415j9i3j24.249",
        ".354b215.259b86k144h142f199e161g340i408j2i1j2i1j36.250",
        ".356b220.247b26k2b62k147h140f199e161g340i402j47.251",
        ".354b229.238b29k5b56k150h139f199e161g340i402j46.252",
        ".353b233.233b31k7b55k148h140f199e161g340i402j9i1j35.253",
        ".352b237.226b34k11b51k149h140f199e161g340i404j3i3j36.254",
        ".352b244.215b38k14b45k148h144f199e161g340i410j35.255",
        ".351b247.71b7.132b40k21b37k150h144f199e161g340i409j35.256",
        ".351b249.66b13.126b42k23b35k151h144f199e161g340i409j35.256",
        ".351b250.63b17.121b43k26b29k155h145f199e161g340i409j34.257",
        ".351b251.1b9.52b19.116b45k27b28k154h147f199e161g340i409j33.258",
        ".351b263.49b20.113b46k29b29k151h149f199e161g340i409j32.259",
        ".350b265.48b20.111b46k31b1k1b24k153h150f199e161g340i406j1i2j31.260",
        ".316b13.20b267.48b19.110b45k36b24k152h150f199e161g340i404j36.260",
        ".274b6.34b17.17b269.48b18.96b57k40b23k150h151f199e161g340i402j37.261",
        ".270b14.28b25.9b271.20b11.17b17.21b10.62b59k42b23k147h154f199e161g340i401j38.261",
        ".266b20.24b308.17b19.11b16.20b14.57b61k46b17k149h155f199e161g340i402j37.261",
        ".262b29.18b311.14b23.9b14.20b16.52b63k52b11k150h156f199e161g340i402j37.261",
        ".259b35.14b352.8b10.21b19.47b64k57b6k151h157f199e161g340i403j35.262",
        ".254b42.11b354.38b26.35b67k216h157f199e161g340i403j34.263",
        ".251b46.9b356.37b42.13b72k218h156f199e161g340i403j33.264",
        ".248b49.8b357.38b126k219h155f199e161g340i404j30.266",
        ".246b52.6b358.38b124k221h155f199e161g340i406j27.267",
        ".143b4.98b424.32b117h1k40h12k8h25k4h3k37h6k23h50k18h155f199e161g340i402j30.268",
        ".138b13.94b426.20b126h383f320e1f1e3f1e4f29g341i402j30.268",
        ".137b20.87b430.13b129h305f438g341i401j30.269",
        ".136b25.82b436.5b132h305f438g341i404j26.270",
        ".136b27.80b557h1b16h303f439g341i404j25.271",
        ".136b28.79b546h1b7h6b14h301f441g341i402j26.272",
        ".136b28.79b538h9b4h11b13h300f441g340d1i402j24.274",
        ".133b31.80b535h28b11h299f442g340d3i403j2i1j17.275",
        ".131b33.81b534h337f443g340d5i405j14.277",
        ".130b33.85b531h337f443g340d7i410j6.278",
        ".130b32.96b521h337f443g340d9i411j2.279",
        ".130b30.100b519h333f447g340d10i411.280",
        ".129b29.107b514h332f448g340d12i408.281",
        ".129b24.118b11.1b496h331f449g340d14i405.282",
        ".129b21.125b3.6b495h330f450g340d16i403.282",
        ".129b20.137b493h331f449g340d18i400.283",
        ".130b18.140b491h332f448g340d20i398.283",
        ".131b15.143b490h285f4h3f3h17f3h17f448g340d22i396.283",
        ".133b12.139b495h284f11h5f1h4f16h10f449g340d24i393.284",
        ".282b497h284f19h2f18h7f450g340d26i391.284",
        ".280b499h284f40h6f450g340d27i390.284",
        ".279b500h283f497g340d29i387.285",
        ".279b500h283f497g340d31i385.285",
        ".277b502h280f500g340d33i383.285",
        ".275b504h281f499g340d35i381.285",
        ".273b506h282f498g340d37i378.286",
        ".271b508h281f499g340d39i376.286",
        ".271b508h283f497g340d41i375.285",
        ".269b510h283f497g340d43i374.284",
        ".269b510h282f498g340d44i374.283",
        ".268b511h282f498g340d46i373.282",
        ".268b511h280f500g340d48i371.282",
        ".268b511h278f502g340d50i369.282",
        ".268b511h276f504g340d52i367.282",
        ".268b511h272f508g340d54i364.283",
        ".268b511h269f511g340d56i361.284",
        ".268b511h268f512g340d58i359.284",
        ".268b511h266f514g340d59i357.285",
        ".269b510h263f517g340d61i356.284",
        ".270b509h262f518g340d63i355.283",
        ".271b508h262f518g340d65i353.283",
        ".271b508h259f2h1f518g340d67i352.282",
        ".271b508h259f521g340d69i350.282",
        ".271b508h244f1h12f523g340d71i349.281",
        ".272b507h237f543g340d73i348.280",
        ".274b505h237f543g340d75i347.279",
        ".276b503h236f544g340d76i347.278",
        ".281b498h236f544g340d78i347.276",
        ".282b497h237f543g340d80i346.275",
        ".283b496h237f543g340d82i346.273",
        ".284b495h238f542g340d84i345.272",
        ".284b495h237f543g340d86i345.270",
        "n1.284b494h234f546g340d88i344.269",
        "n2.283b494h232f548g340d90i344.267",
        "n2.283b494h231f549g340d92i343.266",
        "n2.202b7.76b492h229f551g337d96i342.266",
        "n2.197b15.76b489h229f551g335d100i341.265",
        "n1.196b20.75b487h228f552g332d105i339.265",
        "n1.195b33.61b489h227f553g330d109i338.264",
        ".195b36.58b490h228f552g327d114i336.264",
        ".191b42.55b491h228f552g324d117i335.265",
        ".187b46.55b491h229f551g322d119i335.265",
        ".186b47.55b491h229f551g319d122i335.265",
        ".164b13.8b49.55b490h225f555g316d125i334.266",
        ".160b21.1b53.56b488h223f557g314d127i334.266",
        ".157b78.60b484h223f557g311d130i333.267",
        ".156b80.65b478h220f560g309d132i333.267",
        ".155b81.67b476h223f557g306d135i333.267",
        ".154b81.70b27.5b442h224f556g302d139i332.268",
        ".154b80.74b21.9b441h223f557g298d143i332.268",
        ".154b78.82b9.14b442h225f555g294d147i332.268",
        ".154b73.109b443h224f556g294d147i331.269",
        ".154b61.121b443h223f557g294d147i331.269",
        ".154b58.124b443h223f557g295d146i331.269",
        ".154b54.129b442h219f561g295d146i331.269",
        ".155b53.130b441h217f563g295d146i330.270",
        ".156b51.133b439h219f561g296d145i330.270",
        ".156b23.1b25.138b14.5b6.6b405h219f561g296d145i329.271",
        ".156b20.7b17.174b405h214f1h4f561g297d144i328.272",
        ".157b18.193b411h212f568g297d144i327.273",
        ".160b12.194b413h209f571g298d141i329.273",
        ".135n6.224b414h207f573g298d140i329.274",
        ".132n15.217b415h204f576g299d137i330.275",
        ".122n26.191b10.15b415h203f577g300d135i330.276",
        ".119n34.185b14.12b415h204f576g300d133i331.277",
        ".115n46.135b9.25b25.7b417h203f578g300d131i331.278",
        ".112n52.107b10.7b23.17b28.4b419h202f579g300d129i334.277",
        ".111n54.103b47.11b453h201f580g301d127i337.275",
        ".110n55.102b512h200f581g301d125i341.273",
        ".109n57.100b513h185f5h9f582g302d123i345.270",
        ".105n61.99b514h188f3h5f585g303d120i349.268",
        ".101n66.96b516h188f593g303d119i352.266",
        ".87n80.95b517h185f596g304d116i356.264",
        ".84n84.93b518h182f599g304d115i359.262",
        ".83n85.93b518h182f599g305d112i363.260",
        "n1.81n87.92b518h181f600g305d111i367.257",
        "n2.75n92.63b13.16b518h176f605g306d108i370.256",
        "n3.73n92.62b17.12b520h170f611g307d106i372.255",
        "n7.67n94.61b19.9b522h172f609g307d104i375.254",
        "n9.64n95.60b21.7b523h172f609g308d102i376.254",
        "n13.59n96.60b21.5b525h173f608g308d100i379.253",
        "n15.57n96.60b21.3b527h175f606g309d98i381.252",
        "n16.57n95.61b19.3b528h175f606g309d96i384.251",
        "n18.56n94.62b17.4b528h171f610g310d94i386.250",
        "n19.54n95.65b11.7b528h171f610g310d92i389.249",
        "n19.9n24.20n97.76b534h168f613g310d91i393.246",
        "n58.12n100.3n11.57b538h170f611g311d88i397.244",
        "n61.4n122.51b541h171f610g311d86i401.242",
        "n191.43b545h173f608g311d84i405.240",
        "n194.26b10.1b548h175f606g311d82i410.237",
        "n197.22n1b559h175f606g311d80i414.235",
        "n199.16n6b558h176f605g311d47i448.234",
        "n199.12n10b558h178f603g312d45i450.233",
        "n200.10n11b558h178f603g312d43i453.232",
        "n200.8n13b558h177f605g311d42i454.232",
        "n200.6n15b558h176f606g314d38i456.231",
        "n221b558h175f607g317d34i457.231",
        "n221b558h173f609g320d30i459.230",
        "n221b10.1b547h171f611g323d26i461.229",
        "n221b9.5b544h175f607g326d21i463.229",
        "n221b6.13b539h152f1h10f1h11f607g329d17i466.227",
        "n221.23b535h150f5h8f3h5f611g332d13i468.226",
        "n217.31b531h149f633g335d9i470.225",
        "n217.33b529h150f632g339i477.223",
        "n217.37b525h150f632g339i478.222",
        "n216.41b522h150f632g339i479.221",
        "n215.45b519h150f632g339i481.219",
        "n212.51b516h145f1h2f634g339i481.219",
        "n208.58b72.9b432h146f636g339i482.218",
        "n204.66b70.11b428h147f635g339i483.217",
        "n202.72b66.9b430h147f635g339i484.216",
        "n196.82b62.6b433h150f632g339i485.215",
        "n195.87b58.2b437h150f632g339i485.215",
        "n192.95b492h148f634g339i485.215",
        "n190.102b46.2b439h145f637g339i485.215",
        "n187.111b38.2b441h146f636g339i485.215",
        "n184.121b27.5b442h146f636g339i484.216",
        "n184.150b445h146f636g339i483.217",
        "n182.142b455h144f638g339i481.219",
        "n180.139b460h143f639g339i479.221",
        "n178.137b464h145f637g339i478.222",
        "n177.135b467h145f897g79i476.224",
        "n176.135b468h97f945g79i474.226",
        "n172.139b468h98f944g79i472.228",
        "n166.145b468h98f944g79i470.230",
        "n152.159b468h99f943g79i468.232",
        "n139.173b467h100f942g79i466.234",
        "n131.181b467h100f942g79i463.237",
        "n129.182b468h99f943g79i460.240",
        "n125.185b469h98f944g79i457.243",
        "n122.185b472h98f944g79i451.249",
        "n120.184b475h98f944g79i445.255",
        "n118.182b479h97f945g79i442.258",
        "n116.182b481h97f945g79i439.261",
        "n113.182b484h93f949g79i437.263",
        "n108.184b487h93f949g79i434.266",
        "n106.184b489h93f949g79i431.269",
        "n102.185b492h93f949g79i429.271",
        "n99.183b497h93f949g79i426.274",
        "n97.178b504h93f949g79i424.276",
        "n92.180b507h93f949g79i422.278",
        "n91.179b509h93f949g79i419.281",
        "n86.183b510h93f949g79i417.283",
        "n83.176b520h93f949g79i415.285",
        "n79.176b524h93f949g79i412.288",
        "n76.177b526h93f949g79i408.292",
        "n71.181b527h93f949g79i404.296",
        "n67.185b527h93f949g79i399.301",
        "n64.188b527h93f949g79i394.306",
        "n60.192b527h93f949g79i391.309",
        "n54.200b525h93f949g79i388.312",
        "n52.204b523h93f949g79i386.314",
        "n48.213b518h93f949g79i383.317",
        "n46.218b515h93f949g79i381.319",
        "n44.220b515h93f949g79i379.321",
        "n41.223b515h93f949g79i379.321",
        "n38.226b515h93f949g79i379.321",
        "n34.230b515h93f949g79i379.321",
        "n32.232b515h93f949g79i379.321",
        "n30.234b515h92f950g79i379.321",
        "n27.238b514h92f950g79i379.321",
        "n23.243b513h92f950g79i379.321",
        "n20.249b510h92f950g79i379.321",
        "n16.287b476h91f951g79i379.321",
        "n6.307b466h91f951g79i379.321",
        "n3.314b462h91f951g79i379.321",
        "n1.318b460h91f951g79i378.322",
        ".321b458h90f951g80i378.322",
        ".323b456h90f950g81i377.323",
        ".325b454h90f949g82i376.324",
        ".325b454h73.17f949g82i376.324",
        ".325b454h60.32f946g83i375.325",
        ".325b454h59.34f944g84i374.326",
        ".325b454h57.37f942g85i373.327",
        ".325b454h55.42f938g86i372.328",
        ".326b453h54.45f935g87i371.329",
        ".326b453h51.50f932g88i370.330",
        ".327b452h11.4h32.57f48.1f879g89i369.331",
        ".328b456.106f37.10f874g89i368.332",
        ".329b448.122f25.18f868g90i368.332",
        ".331b442.132f16.28f860g91i368.332",
        ".333b434.187f854g92i367.333",
        ".334b429.195f849g93i367.333",
        ".336b424.203f842g95i366.334",
        ".337b419.210f838g96i364.336",
        ".339b414.216f833g98i362.338",
        ".341b356.14b36.225f829g99i360.340",
        ".343b349.24b27.232f825g100i358.342",
        ".346b342.44b5.241f820g102i355.345",
        ".349b331.303f814g103i354.346",
        ".352b317.330f797g104i352.348",
        ".356b15.1b291.340f791g106i350.350",
        ".377b281.349f786g107i349.351",
        ".381b271.359f780g109i347.353",
        ".1n19.364b265.366f775g110i345.355",
        "n27.359b193.8b35.397f770g111i343.357",
        "n38.351b185.19b21.409f764g113i340.360",
        "n48.343b179.456f760g114i334.366",
        "n52.342b175.458f758g115i329.371",
        "n56.340b172.461f754g117i326.374",
        "n59.340b167.464f752g118i323.377",
        "n61.343b158.470f748g120i316.384",
        "n63.347b24.4b118.478f745g121i310.390",
        "n63.356b11.11b77.11b18.488f743g122i306.394",
        "n64.19n12.349b74.519f739g124i303.397",
        "n64.14n21.347b69.523f737g125i299.401",
        "n64.11n25.347b65.528f734g126i295.405",
        "n63.11n28.347b59.534f730g128i291.409",
        "n61.11n30.349b51.541f728g129i289.411",
        "n59.13n29.352b42.550f724g131i287.413",
        "n55.18n28.355b33.558f721g132i286.414",
        "n53.21n24.361b26.563f719g133i284.416",
        "n51.24n19.368b16.572f715g135i282.418",
        "n49.30n12.961f712g136i280.420",
        "n45.1008f710g137i277.423",
        "n41.1014f706g139i272.428",
        ".1n32.1024f703g140i267.433",
        ".13n6.1040f699g142i259.441",
        ".1060f697g143i253.447",
        ".1062f690g148i240.460",
        ".1064f683g153i237.463",
    ]
    // gpsClockGrid end
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
        updateTowDashboard()
    }
    // Tow/Haul: the TOW telltale (alarm 90) shows the towing layout. Tow/Haul off returns to the saved driver layout.
    // Only TOW changes act, so a layout the driver selects while towing stays.
    property int towDashboard: 1
    property int dashboardBeforeTow: -1     // driver layout to restore; -1 when the towing layout was not selected automatically
    property int towState: -1               // -1 until the first alarm frame after startup
    onDashboardBeforeTowChanged: {
        Funcs.setProperty("dashboardBeforeTow", dashboardBeforeTow)
    }
    function updateTowDashboard(){
        var tow=alarmTable[90]>0?1:0
        if(tow===towState)
            return
        towState=tow
        if(tow){
            if(dashboardBeforeTow<0&&dashboard!==towDashboard){
                dashboardBeforeTow=dashboard
                dashboard=towDashboard
            }
        }else if(dashboardBeforeTow>=0){
            if(dashboard===towDashboard)
                dashboard=dashboardBeforeTow
            dashboardBeforeTow=-1
        }
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
    property bool fuelPercentageValid: fuelPercentage>=0 && fuelPercentage<=100
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
    property bool mainTankPercentageValid: mainTankPercentage>=0 && mainTankPercentage<=100
    property bool subTankPercentageValid: subTankPercentage>=0 && subTankPercentage<=100
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
        return (fuelPercentageValid?fuelPercentage:"---")+"%"
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
    property string lpkUnit: lpkUnitIndex===1?mLpkUnit[1]:mFuelUnit[consumptionUnit]
    property real lpk: 0x7FFF             // 瞬时油耗
    property bool lpkValid: lpk!==0x7FFF && lpk!==0x7FFE
    function isLpkVisible(){
        return lpk!=0x7FFE
    }
    function getLpkData(){
        if(!lpkValid)
            return 0
        return lpkUnitIndex===1?lpk.toFixed(1):lpk>100?0:getFuelConsumption(lpk)
    }
    function getLPK(unit){
        return (!lpkValid?"--.-":lpkUnitIndex===1?lpk.toFixed(1):getFuelConsumption(lpk))+
               (unit?(" "+lpkUnit):"")
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
        if(!rtcTrusted())
            return "--:--"
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
        if(!rtcTrusted())
            return ""
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
        dashboardBeforeTow=Funcs.restore_properity("dashboardBeforeTow", dashboardBeforeTow)
        language=Funcs.restore_properity("language", language)
        gpsAutoSetRtcEnabled=Funcs.restore_properity("gpsAutoSetRtcEnabled", gpsAutoSetRtcEnabled)
        gpsClockZone=Funcs.restore_properity("gpsClockZone", gpsClockZone)
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
