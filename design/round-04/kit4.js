// Round 4 kit: shared state, temperature colours, paged info card, alert, turn edges.
// Loads after round-01/shared.js and round-02/kit.js (backdrop, place, layer, arcs, segBar, fuel, ICON, ALARM, TRUCK_TOP).
// Query options: ?scene=normal|turn|cruise|cold|lowfuel|reserve|lowtire|braking|warmcoolant|hottrans|stale  ?accent=teal|ice|blue|slate
//   ?page=<n>  ?night=1  ?fuel=<pct>  &still=1  ?view=physical&ruler=1  ?bezel=0

// Temperatures arrive in °C: waterTemp, gearBoxTemp, oilTemp, diffOilTemp. 0xFE hides a reading; 0xFF shows "---".
// Firmware colour rules: oil cold below 70 °C, diff cold below 49 °C, coolant warm / hot from waterLevel 1 / 2.
// Every other limit here is a design value until checked against the truck.
const TEMP = {
  coolant: { icon: "water", label: "COOLANT", field: "waterTemp getWaterTemp() waterLevel", cold: 60, warm: 108, hot: 113, lo: 100, hi: 260 },
  trans: { icon: "gearBoxTemp", label: "TRANS", field: "gearBoxTemp getGearBoxTemp()", cold: 40, warm: 111, hot: 121, lo: 100, hi: 280 },
  oil: { icon: "oilTemp", label: "OIL", field: "oilTemp getOilTemp()", cold: 70, warm: 126, hot: 136, lo: 100, hi: 300 },
  diff: { icon: null, label: "DIFF", field: "diffOilTemp getDiffOilTemp()", cold: 49, warm: 111, hot: 131, lo: 80, hi: 280 },
};
// States: cold, normal (shown quiet), warm, hot, and nodata. nodata covers 0xFF and a reading the truck stopped sending.
const c2f = c => Math.round(c * 1.8 + 32);
function temp(kind, c) {
  const t = TEMP[kind], frac = x => Math.min(1, Math.max(0, (x - t.lo) / (t.hi - t.lo)));
  const zones = { coldTo: frac(c2f(t.cold)), warmFrom: frac(c2f(t.warm)), hotFrom: frac(c2f(t.hot)) };
  if (c == null) return { ...t, ...zones, kind, c, f: "--", state: "nodata", pct: 0 };
  const f = c2f(c);
  return { ...t, ...zones, kind, c, f, state: c >= t.hot ? "hot" : c >= t.warm ? "warm" : c < t.cold ? "cold" : "normal", pct: frac(f) };
}
const TCOL = { cold: "var(--cold)", normal: "var(--accent)", warm: "var(--warm)", hot: "var(--hot)" };
// Zone tint opacity on every temperature gauge: cold (blue), warm (amber), hot (red). A later kit can lower the tints to quiet the zones at rest.
const ZONE_TINT = { cold: .2, warm: .32, hot: .45 };
const tempText = (T, deg = true) => `<span class="rv">${T.f}${deg && T.state !== "nodata" ? `<span class="deg">°F</span>` : ""}</span>`;

// Engine redline for the 3.5 EcoBoost. Ford publishes no tach redline; owner reports put the stock tach marking at
// 5,800 to 6,200 RPM and the rev limiter near 6,500. Check against the original Ford cluster face or the owner's manual.
// TACHO_MAX follows the firmware scale setting tachoSpeedMax (6000 or 7000 RPM). Every RPM gauge reads both values from here.
const REDLINE = 6000, TACHO_MAX = 7000;

// Boost (towing): manifold pressure above atmospheric, in psi on both sides of zero. The 2017+ 3.5 EcoBoost peaks near 16 psi.
// Vacuum (closed throttle) fills left of the zero mark in quiet grey; boost fills right in the accent colour.
// No firmware field reports boost yet: the gauge needs a new vehicle signal (protocol work).
const BOOST_MIN = -10, BOOST_MAX = 20;
function boost(s, at) {
  const n = 15, step = (BOOST_MAX - BOOST_MIN) / n, b = s.boost;
  const segs = Array.from({ length: n }, (_, i) => {
    const c = BOOST_MIN + (i + .5) * step;
    if (b == null) return "<i></i>";
    if (b > 0 && c > 0 && c <= b) return `<i class="lit${c + step > b ? " head" : ""}"></i>`;
    if (b < 0 && c < 0 && c >= b) return `<i class="vac"></i>`;
    return "<i></i>";
  }).join("");
  return `<div class="abs boost${b == null ? " nodata" : ""}" style="${at}" data-field="boost: no firmware field yet (new vehicle signal needed)">
    <div class="top"><span class="k">BOOST</span><span class="rv">${b == null ? "--" : b < 0 ? `−${-b}` : b}<span class="u">psi</span></span></div>
    <div class="bseg">${segs}<b style="left:${-BOOST_MIN / (BOOST_MAX - BOOST_MIN) * 100}%"></b></div></div>`;
}

// Fuel warning by range: amber at LOW_RANGE miles to empty, red when the truck low-fuel light (alarm 151) comes on.
// lowPct is the tank fraction where the amber band starts at the current economy.
const LOW_RANGE = 50;
const fuelLow = s => s.range != null && s.range <= LOW_RANGE;
const lowPct = s => s.fuel && s.range ? Math.min(100, s.fuel * LOW_RANGE / s.range) : 0;
const fuelState = s => s.fuel == null ? "nodata" : fuelLight(s) ? "reserve" : fuelLow(s) ? "low" : "";
const fuelColor = (s, normal = ACC) => ({ reserve: "#ff3b30", low: "#ffb020" })[fuelState(s)] || normal;
const dash = v => v ?? "--";

const BASE = {
  daily: {
    mode: "daily", speed: 64, gear: "D", gearNum: 6, drive: "2H", rpm: 2150, fuel: 62, range: 312, cruise: "off", cruiseSet: 65, telltales: [],
    temps: { coolant: 96, oil: 104, trans: 82 }, tires: [35, 35, 35, 35], low: -1, trip: "128.4", avg: "17.8", mpgNow: 21.4,
    pages: ["trip", "economy", "tires", "temps", "vehicle"],
  },
  tow: {
    mode: "tow", speed: 58, gear: "D", gearNum: 4, drive: "2H", rpm: 2600, fuel: 46, range: 188, cruise: "off", cruiseSet: 65, telltales: [90],
    temps: { trans: 93, coolant: 99, oil: 110, diff: 85 }, tires: [38, 38, 41, 41], low: -1, trip: "86.2", avg: "9.6", mpgNow: 8.9,
    boost: 9, gain: 5.5, grade: 6, trailerMi: 342, brakeType: "Heavy", pages: ["trailer", "trip", "economy", "vehicle"],
  },
};
const COLD = { coolant: 38, oil: 31, trans: 24, diff: 20 };
const SCENES = {
  normal: s => s,
  turn: s => Object.assign(s, { turn: "l", cruise: "set" }),
  cruise: s => Object.assign(s, { cruise: "set", speed: 64, rpm: 1900, boost: 4 }),
  cold: s => Object.assign(s, { speed: 28, gearNum: 3, rpm: 1350, temps: Object.fromEntries(Object.keys(s.temps).map(k => [k, COLD[k]])) }),
  lowfuel: s => Object.assign(s, { fuel: Math.round(s.fuel * 45 / s.range), range: 45,
    alert: ["caution", ICON("fuel"), "FUEL LOW", "45 mi to empty", true] }),
  reserve: s => Object.assign(s, { fuel: 6, range: Math.round(s.range * 6 / s.fuel), telltales: [...s.telltales, 151],
    alert: ["warn", ICON("fuel"), "FUEL RESERVE", `${Math.round(s.range * 6 / s.fuel)} mi to empty · refuel now`, true] }),
  lowtire: s => Object.assign(s, { tires: [s.tires[0], s.tires[1], s.tires[2], 24], low: 3, telltales: [...s.telltales, 24],
    alert: ["caution", ALARM(24), "RIGHT REAR TIRE LOW", "24 psi"] }),
  // Live trailer braking. No firmware field reports pedal or controller output yet; see round 5 notes.
  braking: s => Object.assign(s, { braking: true, output: 4, speed: 46, rpm: 1500, boost: -9 }),
  warmcoolant: s => Object.assign(s, { temps: { ...s.temps, coolant: 110 } }),
  hottrans: s => Object.assign(s, { rpm: 3400, gearNum: 3, grade: 8, boost: 15, telltales: [...s.telltales, 8], temps: { ...s.temps, trans: 124, diff: 114 },
    alert: ["warn", ICON("gearBoxTemp"), "TRANSMISSION HOT", `${c2f(124)} °F · reduce load or speed`] }),
  // Signal timeout: the truck stopped sending fuel and oil temperature. Readings show "--" instead of the last value.
  stale: s => Object.assign(s, { fuel: null, range: null, temps: { ...s.temps, oil: null } }),
};

// Accent colour setting: one palette for every layout, teal by default. Amber and red stay reserved for warnings.
const ACCENTS = { teal: "90, 209, 192", ice: "143, 211, 255", blue: "77, 155, 255", slate: "148, 163, 184" };

function state(mode) {
  const accent = ACCENTS[params.get("accent")] || ACCENTS.teal;
  document.body.style.setProperty("--accent", `rgb(${accent})`);
  document.body.style.setProperty("--accent-dim", `rgba(${accent}, .18)`);
  if (params.has("still")) document.body.classList.add("still");
  if (params.has("ruler")) document.body.classList.add("ruler");
  if (params.get("bezel") === "0") document.body.classList.add("nobezel");
  if (params.has("night")) document.body.classList.add("night");
  const s = (SCENES[params.get("scene")] || SCENES.normal)(structuredClone(BASE[mode]));
  if (params.has("fuel") && s.fuel) Object.assign(s, { range: Math.round(s.range * +params.get("fuel") / s.fuel), fuel: +params.get("fuel") });
  s.page = +(params.get("page") || 0) % s.pages.length;
  s.T = Object.fromEntries(Object.entries(s.temps).map(([k, c]) => [k, temp(k, c)]));
  // The background glow takes the worst temperature or fuel colour: amber for a warm temperature or LOW_RANGE miles to empty,
  // red for a hot temperature or the low-fuel light. Other alerts leave the glow alone.
  const states = Object.values(s.T).map(T => T.state);
  if (states.includes("hot") || fuelLight(s)) document.body.classList.add("glow-hot");
  else if (states.includes("warm") || fuelLow(s)) document.body.classList.add("glow-warm");
  return s;
}

// Top corners hold only low-priority items (wheel rim). Telltales, cruise, and alerts stay top center.
// lowCorners moves the clock and outside temperature into the bottom corners beside the shroud, as stock UI1 does.
// Alerts appear in one place on every layout: a banner under the telltales. The banner covers the cruise readout while active.
function frame(s, { lowCorners = false } = {}) {
  const y = lowCorners ? "top:auto;bottom:44px" : "";
  backdrop(SHROUD_TOP);
  place(`
  <div class="abs tb" style="left:64px;${y}" data-field="native RTC clock">10:42</div>
  <div class="abs tb" style="right:64px;${y}" data-field="outSideTemp outSideTempUnit">68<small>°F</small></div>
  <div class="abs telltales" style="left:960px;top:22px;transform:translateX(-50%)" data-field="alarmTable">${s.telltales.map(id => `<img src="${ALARM(id)}" alt="">`).join("")}</div>
  <div class="abs cruise" style="left:810px;top:80px;width:300px;height:80px" data-state="${s.alert ? "off" : s.cruise}" data-unit="MPH"></div>
  ${s.alert ? `<div class="abs alert4 ${s.alert[0]}" data-field="alarmTable"><i class="ic${s.alert[4] ? " flip" : ""}" style="--src:url(${s.alert[1]})"></i><span class="t">${s.alert[2]}</span><span class="s">${s.alert[3]}</span></div>` : ""}`);
}

// Steering column shroud: the bezel hides this arch at the bottom center of the canvas (traced from a photo of the
// installed cluster running stock UI1). Shown by default so every preview matches the driver view; ?bezel=0 hides the shape.
// Keep content at least SHROUD_MARGIN px clear of the arch and the screen edges. The floor glow rises from the arch top so the glow stays visible.
// SHROUD_CUBIC is the left half of the arch; the right half mirrors at x 960.
const SHROUD_CUBIC = [[165, 932], [240, 820], [470, 758], [960, 752]], SHROUD_TOP = 752, SHROUD_MARGIN = 20;
const SHROUD = `M${SHROUD_CUBIC[0]} C${SHROUD_CUBIC.slice(1).join(" ")} C${SHROUD_CUBIC.slice(0, 3).reverse().map(([x, y]) => [1920 - x, y]).join(" ")} Z`;

// Point on the left half of the arch at t (0 = bottom corner, 1 = top center), with the unit normal that points away from the shroud.
function shroudAt(t) {
  const [p0, p1, p2, p3] = SHROUD_CUBIC, u = 1 - t;
  const at = i => u * u * u * p0[i] + 3 * u * u * t * p1[i] + 3 * u * t * t * p2[i] + t * t * t * p3[i];
  const d = i => 3 * u * u * (p1[i] - p0[i]) + 6 * u * t * (p2[i] - p1[i]) + 3 * t * t * (p3[i] - p2[i]);
  const n = Math.hypot(d(0), d(1));
  return { x: at(0), y: at(1), nx: d(1) / n, ny: -d(0) / n };
}
const BEZEL = `<svg class="abs bezel" width="1920" height="932" aria-hidden="true"><path d="${SHROUD}"/></svg>`;

// Shroud top edge for each canvas x (932 where the shroud does not reach).
function archTop() {
  const arch = document.querySelector(".bezel path"), top = new Array(1921).fill(932), len = arch.getTotalLength();
  for (let l = 0; l <= len; l += 1) { const p = arch.getPointAtLength(l), x = Math.round(p.x); top[x] = Math.min(top[x], p.y); }
  return top;
}

// Captures call this: every drawn element that reaches into the shroud or screen-edge margin, with the overlap in canvas px.
function shroudViolations() {
  const top = archTop();
  const limit = (x0, x1) => { let m = Infinity; for (let x = Math.max(0, Math.floor(x0)); x <= Math.min(1920, Math.ceil(x1)); x++) m = Math.min(m, top[x]); return m - SHROUD_MARGIN; };
  const c = document.getElementById("canvas").getBoundingClientRect(), k = 1920 / c.width;
  const name = el => `${el.tagName.toLowerCase()}${el.classList.length ? "." + [...el.classList].join(".") : ""}${el.closest("[data-field]") ? ` [${el.closest("[data-field]").dataset.field.slice(0, 40)}]` : ""}`;
  const out = new Map();
  for (const el of document.querySelectorAll("#canvas *")) {
    if (el.closest("svg[aria-hidden], defs, .turn, #physical-label") || ["svg", "g", "defs", "stop", "filter"].includes(el.tagName.toLowerCase())) continue;
    let over = -Infinity;
    if (el instanceof SVGGeometryElement) {
      const m = el.getScreenCTM(), sw = parseFloat(getComputedStyle(el).strokeWidth) || 0, n = el.getTotalLength();
      if (getComputedStyle(el).display === "none" || !el.getBoundingClientRect().width && !el.getBoundingClientRect().height) continue;
      for (let l = 0; l <= n; l += 2) {
        const p = new DOMPoint(el.getPointAtLength(l).x, el.getPointAtLength(l).y).matrixTransform(m), x = (p.x - c.left) * k, y = (p.y - c.top) * k;
        over = Math.max(over, y + sw / 2 - limit(x - sw / 2, x + sw / 2), SHROUD_MARGIN - x + sw / 2, x + sw / 2 - 1920 + SHROUD_MARGIN);
      }
    } else {
      const r = el.getBoundingClientRect();
      if (!r.width || !r.height) continue;
      const x0 = (r.left - c.left) * k, x1 = (r.right - c.left) * k;
      over = Math.max((r.bottom - c.top) * k - limit(x0, x1), SHROUD_MARGIN - x0, x1 - 1920 + SHROUD_MARGIN);
    }
    if (over > 0) out.set(name(el), Math.max(out.get(name(el)) || 0, Math.round(over)));
  }
  return [...out].map(([n, o]) => `${n} +${o}px`);
}

// Corner area below y 740 inside the margins, as one closed path per side (r mirrors). ?usable=1 draws both over a layout.
function cornerPath(side) {
  const pts = [];
  for (let i = 200; i >= 0; i--) { const p = shroudAt(i / 200), y = p.y - SHROUD_MARGIN; if (y >= 740 && y <= 932 - SHROUD_MARGIN) pts.push([side === "r" ? 1920 - p.x : p.x, y]); }
  const ex = side === "r" ? 1920 - SHROUD_MARGIN : SHROUD_MARGIN;
  return `M${ex} 740 L${pts.map(p => p.map(v => v.toFixed(1)).join(" ")).join(" L")} L${ex} ${932 - SHROUD_MARGIN} Z`;
}
const usableOverlay = () => `<svg class="abs usable" width="1920" height="932" aria-hidden="true">` +
  ["l", "r"].map(side => `<path d="${cornerPath(side)}" fill="#ffb020" fill-opacity=".12" stroke="#ffb020" stroke-width="2" stroke-dasharray="10 8"/>`).join("") +
  line(SHROUD_MARGIN, 740, 1920 - SHROUD_MARGIN, 740, "#ffb020", 1, `stroke-opacity=".5" stroke-dasharray="4 8"`) + `</svg>`;

// Captures call this with a PNG screenshot of the canvas (base64): the fraction of each corner area, in 12 px cells,
// that holds visible content (any pixel brighter than the backdrop).
async function cornerUse(png) {
  const img = new Image(); img.src = `data:image/png;base64,${png}`; await img.decode();
  const c = document.createElement("canvas"); c.width = img.width; c.height = img.height;
  const ctx = c.getContext("2d"); ctx.drawImage(img, 0, 0);
  const k = img.width / 1920, data = ctx.getImageData(0, 0, img.width, img.height).data, top = archTop(), C = 12, use = {};
  for (const side of ["l", "r"]) {
    let cells = 0, used = 0;
    for (let y = 740; y + C <= 932 - SHROUD_MARGIN; y += C) for (let x0 = SHROUD_MARGIN; x0 + C <= 960; x0 += C) {
      const xs = side === "r" ? 1920 - x0 - C : x0;
      if (y + C > Math.min(...top.slice(xs, xs + C + 1)) - SHROUD_MARGIN) continue;
      cells++;
      let lit = false;
      for (let yy = y; yy < y + C && !lit; yy += 2) for (let xx = xs; xx < xs + C && !lit; xx += 2) {
        const i = (Math.round(yy * k) * img.width + Math.round(xx * k)) * 4;
        lit = Math.max(data[i], data[i + 1], data[i + 2]) > 90;
      }
      if (lit) used++;
    }
    use[side] = Math.round(100 * used / cells);
  }
  return use;
}

// Turn edges and the true-size ruler go last so they sit above everything.
function finish(s) {
  if (params.has("usable")) place(usableOverlay());
  place(`
  <div class="abs turn l${s.turn === "l" ? " on" : ""}" data-field="turnLeftLight turnLeftLightEnabled"></div>
  <div class="abs turn r${s.turn === "r" ? " on" : ""}" data-field="turnRightLight turnRightLightEnabled"></div>
  ${BEZEL}
  <div id="physical-label">Physical preview · model index 0 assumption · scale 0.7752</div>`);
  document.getElementById("stage").insertAdjacentHTML("beforeend", `<div id="ruler"><span>100 mm<br>on the<br>real<br>screen</span></div>`);
}

const gear = (s, size) => `<div class="gear4" style="font-size:${size}px" data-field="trucksShiftGear getGearNum()">${s.gear}<sup>${s.gearNum}</sup></div>`;
const chip = s => `<span class="dchip d${s.drive}" data-field="getGearAwd()">${s.drive}</span>`;
const fuelLight = s => s.telltales.includes(151);   // alarmTable[151]: truck low-fuel light
const fuel4 = (s, at) => fuel({ pct: s.fuel, range: s.range, at, light: fuelLight(s), low: fuelLow(s), mark: lowPct(s) });

// Speed digits sit in fixed-width cells so the number never shifts sideways as the value changes.
const digits = n => String(n).split("").map(d => `<i>${d}</i>`).join("");

// Daily A crescents: speed left, tachometer right, coolant and oil arcs inside (90 px in, from t[0] to t[1]).
// a0 is the speed zero angle and a1 the speed maximum (0 = up, clockwise); the tachometer mirrors at x 960. temps false drops the arcs.
// With cruise set, a marker on the speed scale shows the set speed in the cruise readout colour.
function crescents(s, { cx = 800, cy = 470, r = 560, a0 = 238, a1 = 305, t = [238, 290], temps = true } = {}) {
  const sp = { cx, cy, r, a0, a1, max: 120 };
  let g = crescent({ ...sp, major: 10, labelStep: 20, value: s.speed, field: "speed", labelSide: 1 }) +
    crescent({ cx: 1920 - cx, cy, r, a0: 360 - a0, a1: 360 - a1, max: TACHO_MAX / 1000, major: 1, labelStep: 1, value: s.rpm / 1000, redFrom: REDLINE / 1000, field: "tacho rpm" }) +
    (temps ? tempArc({ cx, cy, r: r - 90, from: t[0], to: t[1], T: s.T.coolant }) +
    tempArc({ cx: 1920 - cx, cy, r: r - 90, from: 360 - t[0], to: 360 - t[1], T: s.T.oil }) : "");
  if (s.cruise === "set") {
    const a = sp.a0 + (sp.a1 - sp.a0) * s.cruiseSet / sp.max, p = (r, da = 0) => polar(sp.cx, sp.cy, r, a + da).map(v => v.toFixed(1)).join(" ");
    g += `<path data-field="cruiseSpeedSet" d="M${p(sp.r + 30)} L${p(sp.r + 46, -1.4)} L${p(sp.r + 46, 1.4)} Z" fill="var(--ok)"/>`;
  }
  return g;
}

// Daily B halo: RPM segments over the top, fuel arc closing the bottom (E lower left, F lower right). Returns the fuel readout.
// fuel: false draws the RPM segments only, for layouts that show fuel elsewhere.
function halo(s, { cx = 960, cy = 456, r = 256, fuel = true } = {}) {
  const n = 56, lastLit = Math.floor(s.rpm / TACHO_MAX * n - .5);
  let g = `<g data-field="tacho rpm">`;
  for (let i = 0; i < n; i++) {
    const t = (i + .5) / n, a = -105 + 210 * t, v = TACHO_MAX * t, lit = v <= s.rpm, isRed = v >= REDLINE;
    const [x0, y0] = polar(cx, cy, r, a), [x1, y1] = polar(cx, cy, r + (isRed ? 32 : 24), a);
    const op = lit ? .2 + .8 * Math.pow((i + 1) / (lastLit + 1), 1.6) : 1, head = lit && i >= lastLit - 1;
    g += line(x0, y0, x1, y1, lit ? (isRed ? "#ff3b30" : ACC) : isRed ? "#2a1210" : "#12171d", 7, `stroke-linecap="round" stroke-opacity="${op.toFixed(2)}"${head ? ' filter="url(#glow)"' : ""}`);
  }
  if (!fuel) { layer(g + `</g>`); return ""; }
  const e = 236, f = 124, at = p => e - (e - f) * p / 100;
  g += `</g><g data-field="fuelPercentage"><path d="${arc(cx, cy, r + 14, f, e)}" fill="none" stroke="#fff" stroke-opacity=".05" stroke-width="8"/>`;
  if (s.fuel != null) g += `<path d="${arc(cx, cy, r + 14, at(lowPct(s)), e)}" fill="none" stroke="#ffb020" stroke-opacity=".3" stroke-width="8"/>` + tailArc(cx, cy, r + 14, e, at(s.fuel), 8, fuelColor(s));
  const [ex, ey] = polar(cx, cy, r + 52, e), [fx, fy] = polar(cx, cy, r + 52, f);
  layer(g + text(ex, ey + 8, "E", 22, "#6b7480") + text(fx, fy + 8, "F", 22, "#6b7480") + `</g>`);
  return `<div class="abs fread ${fuelState(s)}" data-field="fuelPercentage DTE"><i class="ic" style="--src:url(${ICON("fuel")})"></i>` +
    `<span class="rv">${dash(s.fuel)}<span class="u">%</span></span><span class="sep"></span><span class="rv">${dash(s.range)}<span class="u">mi</span></span></div>`;
}

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
    `<div class="cells">${cell("NOW", s.mpgNow, "mpg", "instant mpg")}${cell("AVG", s.avg, "mpg", "mAvgFuel")}${cell("RANGE", dash(s.range), "mi", "DTE")}</div>
     <div class="meter"><i style="width:${s.mpgNow / 30 * 100}%"></i></div>`],
  tires: s => ["TIRES · PSI", "TpmsInfo.qml",
    `<div class="cells">${["LF", "RF", "LR", "RR"].map((k, i) => cell(k, s.tires[i], "", `mTpmsPressure ${k}`)).join("")}</div>`],
  temps: s => ["TEMPERATURES", "getWaterTemp getOilTemp getGearBoxTemp getDiffOilTemp",
    `<div class="cells">${Object.values(s.T).map(T => `<div class="cell temp ${T.state}" data-field="${T.field}"><div class="k">${T.label}</div>${tempText(T)}</div>`).join("")}</div>`],
  // Oil pressure: trucksOilPressure arrives in bar; shown in psi. Values on this truck are unverified.
  vehicle: s => ["VEHICLE", "OilLifeinfo.qml BatteryMeter.qml trucksOilPressure",
    `<div class="cells">${cell("OIL PRESS", Math.round(2.9 * 14.5), "psi", "trucksOilPressure (bar)")}${cell("OIL LIFE", "72", "%", "trucksOilLifePercentage")}${cell("BATT", "14.2", "V", "batterVoltage")}</div>`],
  // Trailer miles: trucksTrailerDistance. Brake type: trucksSetupInfo[17], Light or Heavy electric (vehicle setting).
  // Gain stays on the trailer brake readout only.
  trailer: s => ["TRAILER", "trucksTrailerDistance trucksSetupInfo[17]",
    `<div class="cells">${cell("DISTANCE", s.trailerMi, "mi", "trucksTrailerDistance getTrucksTrailerDistance()")}${cell("BRAKE TYPE", s.brakeType, "", "trucksSetupInfo[17] mTrailerBreakType")}</div>`],
};

// Paged card. Alerts appear in the banner under the telltales (frame), so the card always shows the current page.
function card(s, at) {
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
  const fill = T.state === "nodata" ? "" : `<g opacity="${T.state === "normal" ? .5 : 1}">${tailArc(cx, cy, r, a(0), a(T.pct), w, TCOL[T.state])}</g>`;
  return `<g data-field="${T.field}">${seg(0, 1, "#ffffff", .05)}${seg(0, T.coldTo, "#a0ccf5", ZONE_TINT.cold)}${seg(T.warmFrom, T.hotFrom, "#ffb020", ZONE_TINT.warm)}${seg(T.hotFrom, 1, "#ff3b30", ZONE_TINT.hot)}${fill}</g>`;
}
const zones = (T, dir) => `linear-gradient(${dir}, rgba(160, 204, 245, ${ZONE_TINT.cold}) 0 ${T.coldTo * 100}%, rgba(255, 255, 255, .05) ${T.coldTo * 100}% ${T.warmFrom * 100}%, ` +
  `rgba(255, 176, 32, ${ZONE_TINT.warm}) ${T.warmFrom * 100}% ${T.hotFrom * 100}%, rgba(255, 59, 48, ${ZONE_TINT.hot}) ${T.hotFrom * 100}% 100%)`;
const tempTrack = T => `<div class="ztrack" style="background:${zones(T, "90deg")}"><i style="width:${T.pct * 100}%"></i></div>`;
const tempCol = (T, h) => `<div class="zcol" style="height:${h}px;background:${zones(T, "0deg")}"><i style="height:${T.pct * 100}%"></i></div>`;
const tIcon = (T, h = 34) => T.icon ? `<img class="tic" src="${ICON(T.icon)}" style="height:${h}px" alt="">` : `<span class="k" style="letter-spacing:2px">DIFF</span>`;
