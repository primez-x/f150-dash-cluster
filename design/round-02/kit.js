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
  <filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="10"/></filter>
</defs>`;
const line = (x1, y1, x2, y2, stroke, w, extra = "") => `<line x1="${x1.toFixed(1)}" y1="${y1.toFixed(1)}" x2="${x2.toFixed(1)}" y2="${y2.toFixed(1)}" stroke="${stroke}" stroke-width="${w}" ${extra}/>`;
const text = (x, y, s, size, fill, anchor = "middle", family = "Konexy") => `<text x="${x.toFixed(1)}" y="${y.toFixed(1)}" text-anchor="${anchor}" font-family="${family}" font-size="${size}" fill="${fill}">${s}</text>`;
const near = (v, step) => Math.abs(v / step - Math.round(v / step)) < 1e-6;

// Top bar shared by every layout: clock, telltales, outside temperature, mode tag, cruise region.
function topBar({ mode, telltales = [], cruise = "off" }) {
  place(`
  <div class="abs tb num" style="left:64px" data-field="native RTC clock">10:42</div>
  <div class="abs mode-tag">${mode}</div>
  <div class="abs tb num" style="right:64px" data-field="outSideTemp outSideTempUnit">68<small>°F</small></div>
  <div class="abs telltales" style="left:960px;top:26px;transform:translateX(-50%)" data-field="alarmTable">${telltales.map(id => `<img src="${ALARM(id)}" alt="">`).join("")}</div>
  <div class="abs cruise" style="left:810px;top:104px;width:300px;height:80px" data-state="${cruise}" data-unit="MPH"></div>
  <div id="physical-label">Physical preview · model index 0 assumption · scale 0.7752</div>`);
}

// Crescent gauge: an arc segment of a large circle. a0 = zero position, a1 = max position (degrees, 0 = 12 o'clock).
function crescent({ cx, cy, r, a0, a1, max, major, labelStep, value, redFrom = null, field, labelSide = 1 }) {
  const a = v => a0 + (a1 - a0) * v / max, lo = Math.min(a0, a1), hi = Math.max(a0, a1);
  let s = `<g data-field="${field}">`;
  s += `<path d="${arc(cx, cy, r, lo, hi)}" fill="none" stroke="#1a2129" stroke-width="2"/>`;
  s += `<path d="${arc(cx, cy, r - 16, lo, hi)}" fill="none" stroke="#11161c" stroke-width="14" stroke-linecap="round"/>`;
  const av = a(value);
  s += `<path d="${arc(cx, cy, r - 16, Math.min(a0, av), Math.max(a0, av))}" fill="none" stroke="${ACC}" stroke-width="14" stroke-linecap="round" filter="url(#glow)" opacity=".95"/>`;
  for (let i = 0; i <= Math.round(max * 2 / major); i++) {
    const v = i * major / 2, isMajor = i % 2 === 0, red = redFrom != null && v >= redFrom;
    const [x0, y0] = polar(cx, cy, r + 4, a(v)), [x1, y1] = polar(cx, cy, r + (isMajor ? 26 : 14), a(v));
    s += line(x0, y0, x1, y1, red ? "#ff3b30" : isMajor ? "#c9d1da" : "#3d4651", isMajor ? 3 : 2);
    if (isMajor && near(v, labelStep)) {
      const [lx, ly] = polar(cx, cy, r + 56 * labelSide, a(v));
      s += text(lx, ly + 10, v, 28, red ? "#ff3b30" : "#9aa4af");
    }
  }
  if (redFrom != null) s += `<path d="${arc(cx, cy, r - 16, Math.min(a(redFrom), a(max)), Math.max(a(redFrom), a(max)))}" fill="none" stroke="#ff3b30" stroke-opacity=".35" stroke-width="14"/>`;
  const [p0x, p0y] = polar(cx, cy, r - 40, av), [p1x, p1y] = polar(cx, cy, r + 20, av);
  s += line(p0x, p0y, p1x, p1y, "#fff", 5, `stroke-linecap="round" filter="url(#glow)"`);
  return s + `</g>`;
}

// Small companion arc inside a crescent or dial (fuel, coolant, temperatures).
function miniArc({ cx, cy, r, from, to, pct, lo, hi, field, color = ACC, labelR = 30 }) {
  const a1 = from + (to - from) * pct;
  let s = `<g data-field="${field}"><path d="${arc(cx, cy, r, Math.min(from, to), Math.max(from, to))}" fill="none" stroke="#161c23" stroke-width="8" stroke-linecap="round"/>`;
  s += `<path d="${arc(cx, cy, r, Math.min(from, a1), Math.max(from, a1))}" fill="none" stroke="${color}" stroke-width="8" stroke-linecap="round"/>`;
  const [lx, ly] = polar(cx, cy, r + labelR, from), [hx, hy] = polar(cx, cy, r + labelR, to);
  s += text(lx, ly + 7, lo, 18, "#6b7480", "middle", "BMW Type Global") + text(hx, hy + 7, hi, 18, "#6b7480", "middle", "BMW Type Global");
  return s + `</g>`;
}

// Round dial with a 270° sweep (sport and race).
function dial270({ cx, cy, r, max, major, labelStep, value, redFrom, field, ring = true }) {
  const a = v => -135 + 270 * v / max;
  let s = `<g data-field="${field}">`;
  if (ring) s += `<circle cx="${cx}" cy="${cy}" r="${r + 30}" fill="#0a0d11" stroke="#1d242c" stroke-width="2"/>`;
  s += `<path d="${arc(cx, cy, r - 20, -135, 135)}" fill="none" stroke="#11161c" stroke-width="22"/>`;
  s += `<path d="${arc(cx, cy, r - 20, -135, a(value))}" fill="none" stroke="${ACC}" stroke-width="22" filter="url(#glow)"/>`;
  s += `<path d="${arc(cx, cy, r - 20, a(redFrom), 135)}" fill="none" stroke="#ff3b30" stroke-opacity=".45" stroke-width="22"/>`;
  for (let i = 0; i <= Math.round(max * 5 / major); i++) {
    const v = i * major / 5, isMajor = i % 5 === 0, red = v >= redFrom;
    const [x0, y0] = polar(cx, cy, r + (isMajor ? 0 : 6), a(v)), [x1, y1] = polar(cx, cy, r + 20, a(v));
    s += line(x0, y0, x1, y1, red ? "#ff3b30" : isMajor ? "#e8ecf1" : "#3d4651", isMajor ? 4 : 2);
    if (isMajor && near(v, labelStep)) {
      const [lx, ly] = polar(cx, cy, r - 66, a(v));
      s += text(lx, ly + 12, v, 34, red ? "#ff3b30" : "#c9d1da");
    }
  }
  const [p0x, p0y] = polar(cx, cy, r - 44, a(value)), [p1x, p1y] = polar(cx, cy, r + 22, a(value));
  s += line(p0x, p0y, p1x, p1y, "#fff", 6, `stroke-linecap="round" filter="url(#glow)"`);
  return s + `</g>`;
}

// Segmented rpm bar. Optional arch. Segments grow taller toward redline when grow is true.
function segBar({ x0, x1, y, n, max, value, redFrom, h = 26, sag = 0, grow = false, w = 14, labels = true, field = "tacho rpm" }) {
  let s = `<g data-field="${field}">`;
  for (let i = 0; i < n; i++) {
    const t = (i + .5) / n, x = x0 + (x1 - x0) * t, yy = y + sag * Math.pow(2 * t - 1, 2), v = max * t;
    const lit = v <= value, red = v >= redFrom, hh = grow ? h * (.45 + .9 * t) : h + (red ? 6 : 0);
    const fill = lit ? (red ? "#ff3b30" : ACC) : (red ? "#3a1512" : "#151b22");
    s += `<rect x="${(x - w / 2).toFixed(1)}" y="${(yy - hh).toFixed(1)}" width="${w}" height="${hh.toFixed(1)}" rx="3" style="fill:${fill}"${lit ? ' filter="url(#glow)"' : ""}/>`;
  }
  if (labels) for (let k = 0; k <= max / 1000; k++) {
    const t = k * 1000 / max, x = x0 + (x1 - x0) * t, yy = y + sag * Math.pow(2 * t - 1, 2);
    s += text(x, yy + 30, k, 22, k * 1000 >= redFrom ? "#ff3b30" : "#56606b");
  }
  return s + `</g>`;
}

// Shift lights: lit from lightsFrom to redline. Flash state uses all lights in redline red.
function shiftLights({ cx, y, n = 15, gap = 10, d = 30, value, from, to }) {
  let s = `<g data-field="tacho rpm (shift point design value)">`;
  const total = n * d + (n - 1) * gap;
  for (let i = 0; i < n; i++) {
    const t = i / (n - 1), on = value >= from + (to - from) * t;
    const color = t < .6 ? "#5fb8ff" : t < .87 ? "#ffffff" : "#ff3b30";
    const x = cx - total / 2 + i * (d + gap) + d / 2;
    s += `<circle cx="${x}" cy="${y}" r="${d / 2}" fill="${on ? color : "#14191f"}" ${on ? 'filter="url(#glow)"' : ""} stroke="#232b34" stroke-width="2"/>`;
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
  s += `<rect x="70" y="18" width="80" height="18" rx="5" fill="none" stroke="#2a323c" stroke-width="2"/>` + text(110, 32, "FRONT", 12, "#56606b", "middle", "BMW Type Global");
  s += wheel(10, 46, fr, frDash) + wheel(180, 46, fr, frDash);
  s += `<line x1="40" y1="78" x2="180" y2="78" stroke="${fr}" stroke-width="6" ${frDash}/>`;
  s += `<circle cx="110" cy="78" r="13" fill="#12171d" stroke="${fr}" stroke-width="3" ${frDash}/>`;
  s += `<line x1="110" y1="91" x2="110" y2="134" stroke="${fr}" stroke-width="6" ${frDash}/>`;
  s += `<rect x="94" y="134" width="32" height="38" rx="6" fill="#12171d" stroke="${rear || front ? on : "#56606b"}" stroke-width="3"/>`;
  s += text(110, 160, state === "4L" ? "L" : state === "N" ? "N" : "", 18, state === "N" ? "#c9d1da" : on);
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
  for (const k of [1, .66, .33]) s += `<circle cx="${cx}" cy="${cy}" r="${r * k}" fill="none" stroke="${k === 1 ? "#2a323c" : "#1a2028"}" stroke-width="2"/>`;
  s += line(cx - r, cy, cx + r, cy, "#1a2028", 2) + line(cx, cy - r, cx, cy + r, "#1a2028", 2);
  const px = cx + gx / 1.2 * r, py = cy - gy / 1.2 * r;
  if (peak) s += `<circle cx="${cx + peak[0] / 1.2 * r}" cy="${cy - peak[1] / 1.2 * r}" r="6" fill="none" stroke="${ACC}" stroke-opacity=".5" stroke-width="2"/>`;
  s += `<circle cx="${px}" cy="${py}" r="12" fill="${ACC}" filter="url(#glow)"/>`;
  s += text(cx, cy + r + 40, Math.hypot(gx, gy).toFixed(2) + " g", 30, "#e8ecf1");
  return s + `</g>`;
}

function tpms(values = [35, 35, 34, 28], low = 3) {
  const t = (i, f) => `<span class="t${i === low ? " low" : ""}" data-field="mTpmsPressure ${f}">${values[i]}</span>`;
  return `<div class="tpms">${t(0, "LF")}<img src="${TRUCK_TOP}" alt="">${t(1, "RF")}${t(2, "LR")}${t(3, "RR")}</div>`;
}
