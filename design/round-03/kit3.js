// Round 3 kit: one fixed layout for every mode, sized for reading while driving.
// Loads after round-01/shared.js and round-02/kit.js (backdrop, place, layer, segBar, fuel, ICON, ALARM, TRUCK_TOP).
//
// Legibility tiers. Glass: 13.1 in diagonal at 1920 x 720, so 311.6 mm wide and 0.1623 mm per px.
// Model index 0 scale 0.7752 gives 0.1258 mm per canvas px. Eye distance assumed 750 mm.
// ISO 15008 character heights: about 20 arcmin for driving values, about 12 arcmin as the floor for any text.
// Cap heights: 34.7 and 20.8 canvas px. BMW Type Global cap ratio 0.754 gives 46 px and 28 px (kit3.css).
//
// Query options: ?scene=normal|turn|lowfuel|lowtire|hottrans  &still=1 holds the turn light on
//                ?view=physical&ruler=1 shows a 100 mm ruler for a true-size check.

const TURN = side => `${IMG}/common/turnlight/tsico_${side}_h.png`;

// Sample values per mode. Temperatures: [fill %, text, state]. Coolant and transmission come from
// percentage fields only, so the text is NORM / HOT, not degrees.
const BASE = {
  daily: {
    name: "DAILY", speed: 64, gear: "D", gearNum: 6, drive: "2H", locker: false, rpm: 2150, fuel: 62, range: 312,
    cruise: "off", telltales: [],
    temps: { trans: [50, "NORM"], coolant: [48, "NORM"], oil: [55, "208°"] },
    tires: [35, 35, 35, 35], low: -1,
    flex: [["AVG", "17.8", "mpg", "mAvgFuel"], ["TRIP A", "128.4", "mi", "mTripA"]],
    dock: [["ODO", "48213 mi", "odometer"], ["OIL LIFE", "72%", "trucksOilLifePercentage"], ["BATT", "14.2 V", "batterVoltage"]],
  },
  tow: {
    name: "TOWING", speed: 58, gear: "D", gearNum: 4, drive: "2H", locker: false, rpm: 2600, fuel: 46, range: 188,
    cruise: "off", telltales: [90],
    temps: { trans: [58, "NORM"], coolant: [52, "NORM"], oil: [60, "214°"] },
    tires: [38, 38, 41, 41], low: -1,
    flex: [["TRAILER GAIN", "5.5", "", "trucksTrailerGain"], ["GRADE", "+6", "%", "mPitch (grade = tan pitch)"]],
    dock: [["AVG", "9.6 mpg", "mAvgFuel"], ["TRIP A", "86.2 mi", "mTripA"], ["BATT", "14.1 V", "batterVoltage"]],
  },
};

const SCENES = {
  normal: s => s,
  turn: s => Object.assign(s, { turn: "l", cruise: "set" }),
  lowfuel: s => Object.assign(s, { fuel: 9, range: Math.round(s.range * 9 / s.fuel), telltales: [...s.telltales, 151],
    alert: ["caution", ICON("fuel"), "LOW FUEL", `${Math.round(s.range * 9 / s.fuel)} mi to empty`, true] }),
  lowtire: s => Object.assign(s, { tires: [s.tires[0], s.tires[1], s.tires[2], 24], low: 3, telltales: [...s.telltales, 24],
    alert: ["caution", ALARM(24), "RIGHT REAR TIRE LOW", "24 psi"] }),
  hottrans: s => Object.assign(s, { rpm: 3400, gearNum: 3, telltales: [...s.telltales, 8],
    temps: { ...s.temps, trans: [93, "HOT", "warn"] },
    flex: s.flex.map(r => r[0] === "GRADE" ? ["GRADE", "+8", "%", r[3]] : r),
    alert: ["warn", ICON("gearBoxTemp"), "TRANSMISSION HOT", "Reduce load or speed"] }),
};

const TEMP_ROWS = [["trans", "TRANS", "gearBoxTemp", "gearBoxTempPercentage"], ["coolant", "COOLANT", "water", "waterTempPercentage"],
  ["oil", "OIL", "oilTemp", "oilTemp oilTempPercentage"]];

function tempsCols(t) {
  return `<div class="abs temps cols" style="left:40px;top:200px;width:515px">${TEMP_ROWS.map(([key, label, icon, field]) => {
    const [pct, text, state = ""] = t[key];
    return `<div class="tcol ${state}" data-field="${field}"><div class="v">${text}</div>
      <div class="col"><span class="hot"></span><i style="height:${pct}%"></i></div><img src="${ICON(icon)}" alt=""><div class="k">${label}</div></div>`;
  }).join("")}</div>`;
}

function tempsRows(t) {
  return `<div class="abs temps" style="left:96px;top:214px;width:420px">${TEMP_ROWS.map(([key, label, icon, field]) => {
    const [pct, text, state = ""] = t[key];
    return `<div class="trow ${state}" data-field="${field}"><div class="head"><span class="k"><img src="${ICON(icon)}" alt="">${label}</span><span class="v">${text}</span></div>
      <div class="track"><span class="hot"></span><i style="width:${pct}%"></i></div></div>`;
  }).join("")}</div>`;
}

function tires(v, low) {
  const t = (i, f) => `<span class="t${i === low ? " low" : ""}" data-field="mTpmsPressure ${f}">${v[i]}</span>`;
  return `<div class="abs tires" style="left:1420px;top:200px;width:400px">
    <div class="k">TIRES<span class="u">psi</span></div>
    <div class="grid">${t(0, "LF")}<img src="${TRUCK_TOP}" alt="">${t(1, "RF")}${t(2, "LR")}${t(3, "RR")}</div></div>`;
}

// One dashboard. temps: "cols" | "rows". tach: "seg" | "line".
function dash({ mode, temps, tach }) {
  const s = (SCENES[params.get("scene")] || SCENES.normal)(structuredClone(BASE[mode]));
  if (params.has("still")) document.body.classList.add("still");
  if (params.has("ruler")) document.body.classList.add("ruler");
  backdrop();
  const max = 7000, red = 6000;
  if (tach === "seg") layer(segBar({ x0: 560, x1: 1150, y: 662, n: 36, max, value: s.rpm, redFrom: red, h: 34, w: 11, labels: false }));
  place(`
  <div class="abs corner" style="left:64px" data-field="native RTC clock">10:42</div>
  <div class="abs corner mode" style="left:64px">${s.name}</div>
  <div class="abs corner" style="right:64px" data-field="outSideTemp outSideTempUnit">68<small>°F</small></div>
  <div class="abs telltales" style="left:960px;top:22px;transform:translateX(-50%)" data-field="alarmTable">${s.telltales.map(id => `<img src="${ALARM(id)}" alt="">`).join("")}</div>
  <div class="abs cruise" style="left:810px;top:104px;width:300px;height:80px" data-state="${s.cruise}" data-unit="MPH"></div>

  <div class="abs big speed" data-field="speed">${s.speed}</div>
  <div class="abs sunit" data-field="vehicleSpeedUnit">MPH</div>
  <div class="abs gdiv"></div>
  <div class="abs big gear" data-field="trucksShiftGear getGearNum()">${s.gear}<sup>${s.gearNum}</sup></div>
  <div class="abs drive" data-field="getGearAwd() alarmTable[76]"><span>${s.drive}</span>${s.locker ? `<span class="lock">R LOCK</span>` : ""}</div>

  ${fuel({ pct: s.fuel, range: s.range, at: "left:560px;top:472px;width:800px" })}
  ${tach === "line" ? `<div class="abs tline" data-field="tacho rpm"><b style="width:${(max - red) / max * 100}%"></b><i style="width:${s.rpm / max * 100}%"></i></div>` : ""}
  <div class="abs rpmv" data-field="tacho rpm"><span class="v">${s.rpm}</span><span class="u">rpm</span></div>
  ${s.alert ? `<div class="abs alert ${s.alert[0]}" data-field="alarmTable"><i class="ic${s.alert[4] ? " flip" : ""}" style="--src:url(${s.alert[1]})"></i><div><div class="t">${s.alert[2]}</div><div class="s">${s.alert[3]}</div></div></div>` : ""}

  ${temps === "rows" ? tempsRows(s.temps) : tempsCols(s.temps)}
  ${tires(s.tires, s.low)}
  <div class="abs flex" style="left:1420px;top:500px;width:400px">${s.flex.map(([k, v, u, f]) =>
    `<div class="row" data-field="${f}"><span class="k">${k}</span><span class="v">${v}${u ? `<span class="u">${u}</span>` : ""}</span></div>`).join("")}</div>
  <div class="abs dock3">${s.dock.map(([k, v, f]) => `<div class="chip" data-field="${f}"><span class="k">${k}</span><span class="v">${v}</span></div>`).join("")}</div>

  <div class="abs turn l${s.turn === "l" ? " on" : ""}" data-field="turnLeftLight turnLeftLightEnabled"><img src="${TURN("left")}" alt=""></div>
  <div class="abs turn r${s.turn === "r" ? " on" : ""}" data-field="turnRightLight turnRightLightEnabled"><img src="${TURN("right")}" alt=""></div>
  <div id="physical-label">Physical preview · model index 0 assumption · scale 0.7752</div>`);
  document.getElementById("stage").insertAdjacentHTML("beforeend", `<div id="ruler"><span>100 mm<br>on the<br>real<br>screen</span></div>`);
}
