// Round 4 kit: shared state, temperature colours, paged info card, alert, turn edges.
// Loads after round-01/shared.js and round-02/kit.js (backdrop, place, layer, arcs, segBar, fuel, ICON, ALARM, TRUCK_TOP).
// Query options: ?scene=normal|turn|cruise|cold|lowfuel|reserve|lowtire|braking|warmcoolant|hottrans  ?accent=teal|ice|blue|slate  ?page=<n>  &still=1  ?view=physical&ruler=1

// Temperatures arrive in °C: waterTemp, gearBoxTemp, oilTemp, diffOilTemp. 0xFE hides a reading; 0xFF shows "---".
// Firmware colour rules: oil cold below 70 °C, diff cold below 49 °C, coolant warm / hot from waterLevel 1 / 2.
// Every other limit here is a design value until checked against the truck.
const TEMP = {
  coolant: { icon: "water", label: "COOLANT", field: "waterTemp getWaterTemp() waterLevel", cold: 60, warm: 108, hot: 113, lo: 100, hi: 260 },
  trans: { icon: "gearBoxTemp", label: "TRANS", field: "gearBoxTemp getGearBoxTemp()", cold: 40, warm: 111, hot: 121, lo: 100, hi: 280 },
  oil: { icon: "oilTemp", label: "OIL", field: "oilTemp getOilTemp()", cold: 70, warm: 126, hot: 136, lo: 100, hi: 300 },
  diff: { icon: null, label: "DIFF", field: "diffOilTemp getDiffOilTemp()", cold: 49, warm: 111, hot: 131, lo: 80, hi: 280 },
};
const c2f = c => Math.round(c * 1.8 + 32);
function temp(kind, c) {
  const t = TEMP[kind], f = c2f(c), frac = x => Math.min(1, Math.max(0, (x - t.lo) / (t.hi - t.lo)));
  return { ...t, kind, c, f, state: c >= t.hot ? "hot" : c >= t.warm ? "warm" : c < t.cold ? "cold" : "normal",
    pct: frac(f), coldTo: frac(c2f(t.cold)), warmFrom: frac(c2f(t.warm)), hotFrom: frac(c2f(t.hot)) };
}
const TCOL = { cold: "var(--cold)", normal: "var(--accent)", warm: "var(--warm)", hot: "var(--hot)" };
const tempText = (T, deg = true) => `<span class="rv">${T.f}${deg ? `<span class="deg">°F</span>` : ""}</span>`;

const BASE = {
  daily: {
    mode: "daily", name: "DAILY", speed: 64, gear: "D", gearNum: 6, drive: "2H", rpm: 2150, fuel: 62, range: 312, cruise: "off", telltales: [],
    temps: { coolant: 96, oil: 104, trans: 82 }, tires: [35, 35, 35, 35], low: -1, trip: "128.4", avg: "17.8", mpgNow: 21.4,
    pages: ["trip", "economy", "tires", "temps", "vehicle"],
  },
  tow: {
    mode: "tow", name: "TOWING", speed: 58, gear: "D", gearNum: 4, drive: "2H", rpm: 2600, fuel: 46, range: 188, cruise: "off", telltales: [90],
    temps: { trans: 93, coolant: 99, oil: 110, diff: 85 }, tires: [38, 38, 41, 41], low: -1, trip: "86.2", avg: "9.6", mpgNow: 8.9,
    gain: 5.5, grade: 6, pages: ["trailer", "trip", "economy", "vehicle"],
  },
};
const COLD = { coolant: 38, oil: 31, trans: 24, diff: 20 };
const SCENES = {
  normal: s => s,
  turn: s => Object.assign(s, { turn: "l", cruise: "set" }),
  cruise: s => Object.assign(s, { cruise: "set", speed: 64, rpm: 1900 }),
  cold: s => Object.assign(s, { speed: 28, gearNum: 3, rpm: 1350, temps: Object.fromEntries(Object.keys(s.temps).map(k => [k, COLD[k]])) }),
  lowfuel: s => Object.assign(s, { fuel: 11, range: Math.round(s.range * 11 / s.fuel),
    alert: ["caution", ICON("fuel"), "FUEL LOW", `${Math.round(s.range * 11 / s.fuel)} mi to empty`, true] }),
  reserve: s => Object.assign(s, { fuel: 6, range: Math.round(s.range * 6 / s.fuel), telltales: [...s.telltales, 151],
    alert: ["warn", ICON("fuel"), "FUEL RESERVE", `${Math.round(s.range * 6 / s.fuel)} mi to empty · refuel now`, true] }),
  lowtire: s => Object.assign(s, { tires: [s.tires[0], s.tires[1], s.tires[2], 24], low: 3, telltales: [...s.telltales, 24],
    alert: ["caution", ALARM(24), "RIGHT REAR TIRE LOW", "24 psi"] }),
  // Live trailer braking. No firmware field reports pedal or controller output yet; see round 5 notes.
  braking: s => Object.assign(s, { braking: true, output: 4, speed: 46, rpm: 1500 }),
  warmcoolant: s => Object.assign(s, { temps: { ...s.temps, coolant: 110 } }),
  hottrans: s => Object.assign(s, { rpm: 3400, gearNum: 3, grade: 8, telltales: [...s.telltales, 8], temps: { ...s.temps, trans: 124, diff: 114 },
    alert: ["warn", ICON("gearBoxTemp"), "TRANSMISSION HOT", `${c2f(124)} °F · reduce load or speed`] }),
};

// Accent colour setting: one palette for every layout, teal by default. Amber and red stay reserved for warnings.
const ACCENTS = { teal: "90, 209, 192", ice: "143, 211, 255", blue: "77, 155, 255", slate: "148, 163, 184" };

function state(mode) {
  const accent = ACCENTS[params.get("accent")] || ACCENTS.teal;
  document.body.style.setProperty("--accent", `rgb(${accent})`);
  document.body.style.setProperty("--accent-dim", `rgba(${accent}, .18)`);
  if (params.has("still")) document.body.classList.add("still");
  if (params.has("ruler")) document.body.classList.add("ruler");
  const s = (SCENES[params.get("scene")] || SCENES.normal)(structuredClone(BASE[mode]));
  s.page = +(params.get("page") || 0) % s.pages.length;
  s.T = Object.fromEntries(Object.entries(s.temps).map(([k, c]) => [k, temp(k, c)]));
  // The background glow takes the worst temperature or fuel colour: amber for a warm temperature or 1/8 tank,
  // red for a hot temperature or the low-fuel light. Other alerts leave the glow alone.
  const states = Object.values(s.T).map(T => T.state), fuel = params.has("fuel") ? +params.get("fuel") : s.fuel;
  if (states.includes("hot") || fuelLight(s)) document.body.classList.add("glow-hot");
  else if (states.includes("warm") || fuel <= LOW) document.body.classList.add("glow-warm");
  return s;
}

// Corners hold only low-priority items (wheel rim). Telltales and cruise stay top center.
function frame(s) {
  backdrop();
  place(`
  <div class="abs tb" style="left:64px" data-field="native RTC clock">10:42</div>
  <div class="abs mode-tag">${s.name}</div>
  <div class="abs tb" style="right:64px" data-field="outSideTemp outSideTempUnit">68<small>°F</small></div>
  <div class="abs telltales" style="left:960px;top:22px;transform:translateX(-50%)" data-field="alarmTable">${s.telltales.map(id => `<img src="${ALARM(id)}" alt="">`).join("")}</div>
  <div class="abs cruise" style="left:810px;top:104px;width:300px;height:80px" data-state="${s.cruise}" data-unit="MPH"></div>`);
}

// Turn edges and the true-size ruler go last so they sit above everything.
function finish(s) {
  place(`
  <div class="abs turn l${s.turn === "l" ? " on" : ""}" data-field="turnLeftLight turnLeftLightEnabled"></div>
  <div class="abs turn r${s.turn === "r" ? " on" : ""}" data-field="turnRightLight turnRightLightEnabled"></div>
  <div id="physical-label">Physical preview · model index 0 assumption · scale 0.7752</div>`);
  document.getElementById("stage").insertAdjacentHTML("beforeend", `<div id="ruler"><span>100 mm<br>on the<br>real<br>screen</span></div>`);
}

const gear = (s, size) => `<div class="gear4" style="font-size:${size}px" data-field="trucksShiftGear getGearNum()">${s.gear}<sup>${s.gearNum}</sup></div>`;
const chip = s => `<span class="dchip" data-field="getGearAwd()">${s.drive}</span>`;
const fuelLight = s => s.telltales.includes(151);   // alarmTable[151]: truck low-fuel light
const fuel4 = (s, at) => fuel({ pct: s.fuel, range: s.range, at, light: fuelLight(s) });

function tires4(s, h, at) {
  const t = (i, f) => `<span class="rv${i === s.low ? " low" : ""}" data-field="mTpmsPressure ${f}">${s.tires[i]}</span>`;
  return `<div class="abs tp" style="${at}">${t(0, "LF")}<img src="${TRUCK_TOP}" style="height:${h}px" alt="">${t(1, "RF")}${t(2, "LR")}${t(3, "RR")}</div>`;
}

// Paged info pages. Firmware sources: menu/assist TripAB, MpgInfo, AvgFuelinfo, TpmsInfo, OilLifeinfo, BatteryMeter, RunTimeInfo.
const cell = (k, v, u = "", f = "", cls = "") => `<div class="cell ${cls}" data-field="${f}"><div class="k">${k}</div><div class="rv">${v}${u ? `<span class="u">${u}</span>` : ""}</div></div>`;
const PAGES = {
  trip: s => ["TRIP A", "TripAB.qml RunTimeInfo.qml",
    `<div class="cells">${cell("DIST", s.trip, "mi", "mTripA")}${cell("TIME", "2:41", "h", "RunTimeInfo")}${cell("AVG", s.avg, "mpg", "mAvgFuel")}</div>`],
  economy: s => ["FUEL ECONOMY", "MpgInfo.qml AvgFuelinfo.qml",
    `<div class="cells">${cell("NOW", s.mpgNow, "mpg", "instant mpg")}${cell("AVG", s.avg, "mpg", "mAvgFuel")}${cell("RANGE", s.range, "mi", "DTE")}</div>
     <div class="meter"><i style="width:${s.mpgNow / 30 * 100}%"></i></div>`],
  tires: s => ["TIRES · PSI", "TpmsInfo.qml",
    `<div class="cells">${["LF", "RF", "LR", "RR"].map((k, i) => cell(k, s.tires[i], "", `mTpmsPressure ${k}`)).join("")}</div>`],
  temps: s => ["TEMPERATURES", "getWaterTemp getOilTemp getGearBoxTemp getDiffOilTemp",
    `<div class="cells">${Object.values(s.T).map(T => `<div class="cell temp ${T.state}" data-field="${T.field}"><div class="k">${T.label}</div>${tempText(T)}</div>`).join("")}</div>`],
  vehicle: s => ["VEHICLE", "OilLifeinfo.qml BatteryMeter.qml odometer",
    `<div class="cells">${cell("ODO", "48213", "mi", "odometer")}${cell("OIL LIFE", "72", "%", "trucksOilLifePercentage")}${cell("BATT", "14.2", "V", "batterVoltage")}</div>`],
  trailer: s => ["TRAILER", "trucksTrailerGain mPitch",
    `<div class="cells">${cell("BRAKE GAIN", s.gain.toFixed(1), "", "trucksTrailerGain")}
      <div class="cell" data-field="mPitch (grade = tan pitch)"><div class="k">GRADE</div><div class="rv"><svg width="64" height="30" style="margin-right:12px"><path d="M2 28 L62 ${28 - 26 * Math.min(1, s.grade / 10)} L62 28 Z" fill="var(--accent-dim)" stroke="var(--accent)" stroke-width="2"/></svg>+${s.grade}<span class="u">%</span></div></div></div>
     <div class="meter"><i style="width:${s.gain * 10}%"></i></div>`],
};

// The card and the alert share one box. While an alert is active, the alert replaces the card.
function card(s, at) {
  if (s.alert) return `<div class="abs alert4 ${s.alert[0]}" style="${at}" data-field="alarmTable"><i class="ic${s.alert[4] ? " flip" : ""}" style="--src:url(${s.alert[1]})"></i><div><div class="t">${s.alert[2]}</div><div class="s">${s.alert[3]}</div></div></div>`;
  const [title, src, body] = PAGES[s.pages[s.page]](s);
  return `<div class="abs card" style="${at}" data-field="drivingInfoIndex (steering wheel left / right) · ${src}">
    <span class="chev l">‹</span><span class="chev r">›</span>
    <div class="top"><span class="ttl">${title}</span><span class="dots">${s.pages.map((_, i) => `<i${i === s.page ? ' class="on"' : ""}></i>`).join("")}</span></div>
    ${body}</div>`;
}

// Temperature gauges. Zone tints: cold (blue), normal, warm (amber), hot (red). Fill and value take the state colour.
function tempArc({ cx, cy, r, from, to, T, w = 8 }) {
  const a = p => from + (to - from) * p;
  const seg = (p0, p1, col, op) => `<path d="${arc(cx, cy, r, Math.min(a(p0), a(p1)), Math.max(a(p0), a(p1)))}" fill="none" stroke="${col}" stroke-opacity="${op}" stroke-width="${w}"/>`;
  return `<g data-field="${T.field}">${seg(0, 1, "#ffffff", .05)}${seg(0, T.coldTo, "#a0ccf5", .2)}${seg(T.warmFrom, T.hotFrom, "#ffb020", .32)}${seg(T.hotFrom, 1, "#ff3b30", .45)}${tailArc(cx, cy, r, a(0), a(T.pct), w, TCOL[T.state])}</g>`;
}
const zones = (T, dir) => `linear-gradient(${dir}, rgba(160, 204, 245, .2) 0 ${T.coldTo * 100}%, rgba(255, 255, 255, .05) ${T.coldTo * 100}% ${T.warmFrom * 100}%, ` +
  `rgba(255, 176, 32, .32) ${T.warmFrom * 100}% ${T.hotFrom * 100}%, rgba(255, 59, 48, .45) ${T.hotFrom * 100}% 100%)`;
const tempTrack = T => `<div class="ztrack" style="background:${zones(T, "90deg")}"><i style="width:${T.pct * 100}%"></i></div>`;
const tempCol = (T, h) => `<div class="zcol" style="height:${h}px;background:${zones(T, "0deg")}"><i style="height:${T.pct * 100}%"></i></div>`;
const tIcon = (T, h = 34) => T.icon ? `<img src="${ICON(T.icon)}" style="height:${h}px;opacity:.85" alt="">` : `<span class="k" style="letter-spacing:2px">DIFF</span>`;
