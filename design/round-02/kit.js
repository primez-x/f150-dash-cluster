// Round 2 kit. Load after ../round-01/shared.js and before DOMContentLoaded.
// Every scale maximum, sweep, and threshold here is a design value. Integration binds tachoSpeedMax and native limits.
const ALARM = id => `${ASSETS}/installed/alarm/${id}.png`;
const ICON = n => `${IMG}/common/icon/${n}.png`;
const TRUCK_TOP = `${ASSETS}/installed/vehicles/ford/door/black.png`;
const ACC = "var(--accent)";

function place(html) { document.getElementById("canvas").insertAdjacentHTML("beforeend", html); }
function layer(svg) { place(`<svg class="abs" style="left:0;top:0" width="1920" height="932">${DEFS}${svg}</svg>`); }
const DEFS = `<defs>
  <filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="5" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
  <filter id="bloom" x="-100%" y="-100%" width="300%" height="300%"><feGaussianBlur stdDeviation="9"/></filter>
</defs>`;
const LABEL = "BMW Type Global";
const line = (x1, y1, x2, y2, stroke, w, extra = "") => `<line x1="${x1.toFixed(1)}" y1="${y1.toFixed(1)}" x2="${x2.toFixed(1)}" y2="${y2.toFixed(1)}" stroke="${stroke}" stroke-width="${w}" ${extra}/>`;
const text = (x, y, s, size, fill, anchor = "middle", family = LABEL, extra = "") => `<text x="${x.toFixed(1)}" y="${y.toFixed(1)}" text-anchor="${anchor}" font-family="${family}" font-size="${size}" fill="${fill}" ${extra}>${s}</text>`;
const near = (v, step) => Math.abs(v / step - Math.round(v / step)) < 1e-6;
// Focus falloff: 1 at the live value, 0 beyond span degrees.
const focus = (a, av, span = 32) => Math.max(0, 1 - Math.abs(a - av) / span);

// Backdrop: faint topographic contours (marching squares on a smooth field) and a low accent bloom.
// On the device this is one static image per mode.
function backdrop() {
  const W = 1920, H = 932, c = 24, nx = W / c, ny = Math.ceil(H / c);
  const hills = [[300, 820, 1, 330], [1650, 160, .9, 300], [1180, 980, .8, 380], [700, 40, .55, 260], [1880, 700, .6, 240]];
  const f = (x, y) => hills.reduce((t, [hx, hy, a, sd]) => t + a * Math.exp(-((x - hx) ** 2 + (y - hy) ** 2) / (2 * sd * sd)), 0)
    + .12 * Math.sin(x / 170 + y / 260) + .08 * Math.sin(y / 110 - x / 300);
  const g = [];
  for (let j = 0; j <= ny; j++) { g.push([]); for (let i = 0; i <= nx; i++) g[j].push(f(i * c, j * c)); }
  let d = "";
  for (let L = -.15; L < 1.1; L += .075) {
    for (let j = 0; j < ny; j++) for (let i = 0; i < nx; i++) {
      const v = [g[j][i], g[j][i + 1], g[j + 1][i + 1], g[j + 1][i]], x = i * c, y = j * c, pts = [];
      const e = (a, b, p, q) => { if ((v[a] < L) !== (v[b] < L)) { const t = (L - v[a]) / (v[b] - v[a]); pts.push([p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t]); } };
      e(0, 1, [x, y], [x + c, y]); e(1, 2, [x + c, y], [x + c, y + c]); e(2, 3, [x + c, y + c], [x, y + c]); e(3, 0, [x, y + c], [x, y]);
      for (let k = 0; k + 1 < pts.length; k += 2) d += `M${pts[k][0].toFixed(1)} ${pts[k][1].toFixed(1)}L${pts[k + 1][0].toFixed(1)} ${pts[k + 1][1].toFixed(1)}`;
    }
  }
  place(`<svg class="abs" style="left:0;top:0" width="${W}" height="${H}" aria-hidden="true">
    <defs>
      <radialGradient id="topoFade" cx="50%" cy="48%" r="62%"><stop offset="0" stop-color="#fff" stop-opacity=".12"/><stop offset=".55" stop-color="#fff" stop-opacity=".55"/><stop offset="1" stop-color="#fff" stop-opacity="1"/></radialGradient>
      <mask id="topoMask"><rect width="${W}" height="${H}" fill="url(#topoFade)"/></mask>
      <radialGradient id="floor" cx="50%" cy="100%" r="60%"><stop offset="0" style="stop-color:var(--ambient, var(--accent));stop-opacity:var(--ambient-o, .13)"/><stop offset="1" style="stop-color:var(--ambient, var(--accent));stop-opacity:0"/></radialGradient>
    </defs>
    <rect x="0" y="${H - 420}" width="${W}" height="420" fill="url(#floor)"/>
    <path d="${d}" fill="none" stroke="var(--accent)" stroke-opacity=".085" stroke-width="1.2" mask="url(#topoMask)"/>
  </svg>`);
}

// Top bar shared by every layout: clock, telltales, outside temperature, mode tag, cruise region.
function topBar({ mode, telltales = [], cruise = "off" }) {
  backdrop();
  place(`
  <div class="abs tb" style="left:64px" data-field="native RTC clock">10:42</div>
  <div class="abs mode-tag">${mode}</div>
  <div class="abs tb" style="right:64px" data-field="outSideTemp outSideTempUnit">68<small>°F</small></div>
  <div class="abs telltales" style="left:960px;top:26px;transform:translateX(-50%)" data-field="alarmTable">${telltales.map(id => `<img src="${ALARM(id)}" alt="">`).join("")}</div>
  <div class="abs cruise" style="left:810px;top:104px;width:300px;height:80px" data-state="${cruise}" data-unit="MPH"></div>
  <div id="physical-label">Physical preview · model index 0 assumption · scale 0.7752</div>`);
}

// Value arc: fine segments that fade in from zero, a white head, and one bloom at the head.
// Device note: render the segment ramp as a static masked image; only the mask angle animates.
function tailArc(cx, cy, r, aZero, aHead, width, color = ACC) {
  const span = aHead - aZero, step = 1.8, gap = .55, n = Math.max(1, Math.floor(Math.abs(span) / step));
  let s = "";
  for (let i = 0; i < n; i++) {
    const b0 = aZero + Math.sign(span) * i * step, b1 = b0 + Math.sign(span) * (step - gap);
    const op = (.08 + .92 * Math.pow((i + 1) / n, 1.7)).toFixed(3);
    s += `<path d="${arc(cx, cy, r, Math.min(b0, b1), Math.max(b0, b1))}" fill="none" stroke="${color}" stroke-opacity="${op}" stroke-width="${width}"/>`;
  }
  const [hx, hy] = polar(cx, cy, r, aHead);
  s += `<circle cx="${hx.toFixed(1)}" cy="${hy.toFixed(1)}" r="${(width * 1.5).toFixed(1)}" fill="${color}" opacity=".55" filter="url(#bloom)"/>`;
  s += `<circle cx="${hx.toFixed(1)}" cy="${hy.toFixed(1)}" r="${(width * .55).toFixed(1)}" fill="#fff"/>`;
  return s;
}

// Crescent gauge: an arc segment of a large circle. a0 = zero position, a1 = max position (degrees, 0 = 12 o'clock).
function crescent({ cx, cy, r, a0, a1, max, major, labelStep, value, redFrom = null, field, labelSide = 1 }) {
  const a = v => a0 + (a1 - a0) * v / max, lo = Math.min(a0, a1), hi = Math.max(a0, a1), av = a(value);
  let s = `<g data-field="${field}">`;
  s += `<path d="${arc(cx, cy, r - 16, lo, hi)}" fill="none" stroke="#ffffff" stroke-opacity=".035" stroke-width="12"/>`;
  if (redFrom != null) s += `<path d="${arc(cx, cy, r - 16, Math.min(a(redFrom), a(max)), Math.max(a(redFrom), a(max)))}" fill="none" stroke="#ff3b30" stroke-opacity=".28" stroke-width="12"/>`;
  s += tailArc(cx, cy, r - 16, a0, av, 12);
  for (let i = 0; i <= Math.round(max * 4 / major); i++) {
    const v = i * major / 4, isMajor = i % 4 === 0, red = redFrom != null && v >= redFrom, fo = focus(a(v), av);
    const [x0, y0] = polar(cx, cy, r + 4, a(v)), [x1, y1] = polar(cx, cy, r + (isMajor ? 24 : 12), a(v));
    const op = isMajor ? .55 + .45 * fo : .12 + .6 * fo;
    s += line(x0, y0, x1, y1, red ? "#ff3b30" : "#e8ecf1", isMajor ? 2.5 : 1.5, `stroke-opacity="${op.toFixed(2)}"`);
    if (isMajor && near(v, labelStep)) {
      const [lx, ly] = polar(cx, cy, r + 54 * labelSide, a(v));
      s += text(lx, ly + 9, v, 26, red ? "#ff3b30" : "#e8ecf1", "middle", LABEL, `fill-opacity="${(.4 + .6 * fo).toFixed(2)}"`);
    }
  }
  const [p0x, p0y] = polar(cx, cy, r + 2, av), [p1x, p1y] = polar(cx, cy, r + 30, av);
  s += line(p0x, p0y, p1x, p1y, "#fff", 3, `stroke-linecap="round"`);
  return s + `</g>`;
}

// Small companion arc inside a crescent or dial (fuel, coolant, temperatures).
function miniArc({ cx, cy, r, from, to, pct, lo, hi, field, color = ACC, labelR = 30 }) {
  const a1 = from + (to - from) * pct;
  let s = `<g data-field="${field}"><path d="${arc(cx, cy, r, Math.min(from, to), Math.max(from, to))}" fill="none" stroke="#ffffff" stroke-opacity=".05" stroke-width="6" stroke-linecap="round"/>`;
  s += `<path d="${arc(cx, cy, r, Math.min(from, a1), Math.max(from, a1))}" fill="none" stroke="${color}" stroke-width="6" stroke-linecap="round"/>`;
  const [lx, ly] = polar(cx, cy, r + labelR, from), [hx, hy] = polar(cx, cy, r + labelR, to);
  s += text(lx, ly + 7, lo, 16, "#6b7480") + text(hx, hy + 7, hi, 16, "#6b7480");
  return s + `</g>`;
}

// Round dial with a 270° sweep (sport and race).
function dial270({ cx, cy, r, max, major, labelStep, value, redFrom, field, ring = true }) {
  const a = v => -135 + 270 * v / max, av = a(value);
  let s = `<g data-field="${field}">`;
  if (ring) s += `<circle cx="${cx}" cy="${cy}" r="${r + 34}" fill="#07090c" stroke="#ffffff" stroke-opacity=".06" stroke-width="1.5"/>`;
  s += `<path d="${arc(cx, cy, r - 20, -135, 135)}" fill="none" stroke="#ffffff" stroke-opacity=".04" stroke-width="18"/>`;
  s += `<path d="${arc(cx, cy, r - 20, a(redFrom), 135)}" fill="none" stroke="#ff3b30" stroke-opacity=".3" stroke-width="18"/>`;
  s += tailArc(cx, cy, r - 20, -135, av, 18);
  for (let i = 0; i <= Math.round(max * 10 / major); i++) {
    const v = i * major / 10, isMajor = i % 10 === 0, isHalf = i % 5 === 0, red = v >= redFrom, fo = focus(a(v), av, 45);
    const [x0, y0] = polar(cx, cy, r + (isMajor ? 2 : isHalf ? 8 : 12), a(v)), [x1, y1] = polar(cx, cy, r + 22, a(v));
    const op = isMajor ? .6 + .4 * fo : .1 + .6 * fo;
    s += line(x0, y0, x1, y1, red ? "#ff3b30" : "#e8ecf1", isMajor ? 3 : 1.5, `stroke-opacity="${op.toFixed(2)}"`);
    if (isMajor && near(v, labelStep)) {
      const [lx, ly] = polar(cx, cy, r - 64, a(v));
      s += text(lx, ly + 11, v, 32, red ? "#ff3b30" : "#e8ecf1", "middle", LABEL, `fill-opacity="${(.45 + .55 * fo).toFixed(2)}"`);
    }
  }
  const [p0x, p0y] = polar(cx, cy, r - 48, av), [p1x, p1y] = polar(cx, cy, r + 24, av);
  s += line(p0x, p0y, p1x, p1y, "#fff", 4, `stroke-linecap="round"`);
  return s + `</g>`;
}

// Segmented rpm bar. Lit segments fade in from zero; only the head segments glow.
function segBar({ x0, x1, y, n, max, value, redFrom, h = 26, sag = 0, grow = false, w = 14, labels = true, field = "tacho rpm" }) {
  let s = `<g data-field="${field}">`;
  const lastLit = Math.floor(value / max * n - .5);
  for (let i = 0; i < n; i++) {
    const t = (i + .5) / n, x = x0 + (x1 - x0) * t, yy = y + sag * Math.pow(2 * t - 1, 2), v = max * t;
    const lit = v <= value, red = v >= redFrom, hh = grow ? h * (.45 + .9 * t) : h + (red ? 6 : 0);
    const op = lit ? .22 + .78 * Math.pow((i + 1) / (lastLit + 1), 1.5) : 1;
    const fill = lit ? (red ? "#ff3b30" : ACC) : (red ? "#2a1210" : "#12171d");
    const head = lit && i >= lastLit - 1;
    s += `<rect x="${(x - w / 2).toFixed(1)}" y="${(yy - hh).toFixed(1)}" width="${w}" height="${hh.toFixed(1)}" rx="${Math.min(3, w / 3)}" style="fill:${fill}" fill-opacity="${op.toFixed(2)}"${head ? ' filter="url(#glow)"' : ""}/>`;
  }
  if (labels) for (let k = 0; k <= max / 1000; k++) {
    const t = k * 1000 / max, x = x0 + (x1 - x0) * t, yy = y + sag * Math.pow(2 * t - 1, 2);
    s += text(x, yy + 30, k, 20, k * 1000 >= redFrom ? "#ff3b30" : "#56606b");
  }
  return s + `</g>`;
}

// Shift lights: lit from the first threshold to the shift point (design values).
function shiftLights({ cx, y, n = 15, gap = 10, d = 30, value, from, to }) {
  let s = `<g data-field="tacho rpm (shift point design value)">`;
  const total = n * d + (n - 1) * gap;
  for (let i = 0; i < n; i++) {
    const t = i / (n - 1), on = value >= from + (to - from) * t;
    const color = t < .6 ? "#5fb8ff" : t < .87 ? "#ffffff" : "#ff3b30";
    const x = cx - total / 2 + i * (d + gap) + d / 2;
    s += `<rect x="${x - d / 2}" y="${y - d / 4}" width="${d}" height="${d / 2}" rx="${d / 4}" fill="${on ? color : "#12171d"}" ${on ? 'filter="url(#glow)"' : ""}/>`;
  }
  return s + `</g>`;
}

// RWD drivetrain plan view. Front axle at top. States: 2H, 4A, 4H, 4L, N. Locker adds the rear e-locker.
// Field: getGearAwd() index into mFord4wd ["", "2WD", "4WD  LOCK", "N", "4WD  LOW", "4HLC", "4LLC", "4WD  AUTO"].
function drivetrain(state, locker = false, width = 220) {
  const on = "var(--accent)", off = "#283039";
  const rear = state !== "N", front = state === "4H" || state === "4L", auto = state === "4A";
  const fr = front ? on : auto ? on : off, frDash = auto ? 'stroke-dasharray="8 8" opacity=".75"' : "";
  const wheel = (x, y, p, dash = "") => `<rect x="${x}" y="${y}" width="30" height="64" rx="9" fill="#12171d" stroke="${p}" stroke-width="3" ${dash}/>`;
  let s = `<svg viewBox="0 0 220 300" width="${width}" height="${width * 300 / 220}" data-field="getGearAwd() mFord4wd; rear locker: alarmTable[76] pending verification">`;
  s += `<rect x="70" y="18" width="80" height="18" rx="5" fill="none" stroke="#2a323c" stroke-width="2"/>` + text(110, 32, "FRONT", 12, "#56606b");
  s += wheel(10, 46, fr, frDash) + wheel(180, 46, fr, frDash);
  s += `<line x1="40" y1="78" x2="180" y2="78" stroke="${fr}" stroke-width="6" ${frDash}/>`;
  s += `<circle cx="110" cy="78" r="13" fill="#12171d" stroke="${fr}" stroke-width="3" ${frDash}/>`;
  s += `<line x1="110" y1="91" x2="110" y2="134" stroke="${fr}" stroke-width="6" ${frDash}/>`;
  s += `<rect x="94" y="134" width="32" height="38" rx="6" fill="#12171d" stroke="${rear || front ? on : "#56606b"}" stroke-width="3"/>`;
  s += text(110, 160, state === "4L" ? "L" : state === "N" ? "N" : "", 18, state === "N" ? "#c9d1da" : on, "middle", "Konexy");
  s += `<line x1="110" y1="172" x2="110" y2="216" stroke="${rear ? on : off}" stroke-width="6"/>`;
  s += `<line x1="40" y1="232" x2="180" y2="232" stroke="${rear ? on : off}" stroke-width="${locker ? 9 : 6}"/>`;
  s += `<circle cx="110" cy="232" r="17" fill="#12171d" stroke="${locker ? "var(--caution)" : rear ? on : off}" stroke-width="3"/>`;
  if (locker) s += `<path d="M103 231 v-5 a7 7 0 0 1 14 0 v5" fill="none" stroke="var(--caution)" stroke-width="3"/><rect x="100" y="231" width="20" height="13" rx="2" fill="var(--caution)"/>`;
  s += wheel(10, 200, rear ? on : off) + wheel(180, 200, rear ? on : off);
  return s + `</svg>`;
}
function driveChips(state, locker) {
  return `<div class="chips" data-field="getGearAwd()">${["2H", "4A", "4H", "4L"].map(m => `<span class="${m === state ? "on" : ""}">${m}</span>`).join("")}<span class="lock ${locker ? "on" : ""}">R LOCK</span></div>`;
}

// G-force plot. Fields: getGforceX(), getGforceY(). 1.2 g radius is a design value.
function gforce({ cx, cy, r, gx, gy, peak }) {
  let s = `<g data-field="getGforceX() getGforceY()">`;
  for (const k of [1, .66, .33]) s += `<circle cx="${cx}" cy="${cy}" r="${r * k}" fill="none" stroke="#ffffff" stroke-opacity="${k === 1 ? .12 : .05}" stroke-width="1.5"/>`;
  s += line(cx - r, cy, cx + r, cy, "#ffffff", 1, `stroke-opacity=".05"`) + line(cx, cy - r, cx, cy + r, "#ffffff", 1, `stroke-opacity=".05"`);
  const px = cx + gx / 1.2 * r, py = cy - gy / 1.2 * r;
  if (peak) s += `<circle cx="${cx + peak[0] / 1.2 * r}" cy="${cy - peak[1] / 1.2 * r}" r="6" fill="none" stroke="${ACC}" stroke-opacity=".5" stroke-width="2"/>`;
  s += `<circle cx="${px}" cy="${py}" r="22" fill="${ACC}" opacity=".5" filter="url(#bloom)"/><circle cx="${px}" cy="${py}" r="9" fill="#fff"/>`;
  s += text(cx, cy + r + 44, Math.hypot(gx, gy).toFixed(2) + " g", 30, "#e8ecf1");
  return s + `</g>`;
}

// Fuel gauge for every layout: level first, range second, caution colour at reserve.
// RESERVE (1/8 tank) is a design value. ?fuel=<pct> previews any level; range scales with the level.
// fuelRefuelingPortPositon (0 left, 1 right) sets the filler arrow; the stock icon points right.
const RESERVE = 12.5;
function fuel({ pct, range, at, port = 0 }) {
  if (params.has("fuel")) { range = Math.round(range * +params.get("fuel") / pct); pct = +params.get("fuel"); }
  return `<div class="abs bar fuel${pct <= RESERVE ? " low" : ""}" style="${at}" data-field="fuelPercentage DTE fuelRefuelingPortPositon">
    <div class="head"><span class="k"><i class="ic${port ? "" : " flip"}" style="--src:url(${ICON("fuel")})"></i>FUEL</span><span class="v">${pct}<span class="u">%</span><span class="dte">${range}<span class="u">mi range</span></span></span></div>
    <div class="track"><i style="width:${pct}%"></i><b style="left:${RESERVE}%"></b></div><div class="ends"><span>E</span><span>F</span></div>
  </div>`;
}

function tpms(values = [35, 35, 34, 28], low = 3) {
  const t = (i, f) => `<span class="t${i === low ? " low" : ""}" data-field="mTpmsPressure ${f}">${values[i]}</span>`;
  return `<div class="tpms">${t(0, "LF")}<img src="${TRUCK_TOP}" alt="">${t(1, "RF")}${t(2, "LR")}${t(3, "RR")}</div>`;
}
