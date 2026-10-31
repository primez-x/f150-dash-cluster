// Round 38 kit: the speed bar moves to the bottom-center gauge; fuel moves to the bottom-right corner. Loads after
// round-37/kit37.js (the steering arc above the digits and ?unit stay; the speed bar under the digits goes).
//
// User direction (2026-10-30): rework the bottom-center fuel gauge into the MPH bar gauge. Fuel shifts to the bottom-right
// corner in place of the trailer brake band. Braking moves to one of three places, the ?brake=a|b|c pick:
// - A: a thin continuous line just above the speed rail. The gain shows as a dim range with a white marker; the output
//   lights in the accent colour while braking. The trailer brake symbol sits at the left end of the line.
// - B: inside the speed rail. While braking, the output fills the rail from the right end inward in white, with the gain as
//   a white marker; the trailer brake symbol shows at the right end. At rest the rail shows speed only. The rail has one
//   scale (0 to 100 mph), so the brake fill uses the same width for 0 to 10: at speed with heavy braking the two fills meet,
//   and the brake fill covers the top of the speed fill (the digits still show the speed).
// - C: the trailer page of the right card only (round 17). While braking, the card already jumps to the trailer page
//   (SEC_FOCUS brake), so the live output still shows without a second gauge.
//
// Speed rail: the round 10 fuel rail geometry (FUEL_C) along the cover top, 0 mph left, 100 mph right. The ticks every 10 mph,
// the cruise arrow, and the set-speed number stand above the rail: below the rail is the column cover and the 20 px margin,
// so the round 37 flip (markers under the bar) has no room here. The arrow points down at the set speed.
// Fuel corner: a band that mirrors the rpm band (E at the corner, F toward the center), the fuel symbol in the old trailer
// brake symbol place, and the range number right-aligned at the 40 px line under the drive chips.
const BRK = ["b", "c"].includes(params.get("brake")) ? params.get("brake") : "a";
SCENES.brakefast = s => Object.assign(SCENES.braking(s), { speed: 68, output: 7, rpm: 1900 });

const railPts = d => {
  const h = shroudRail(FUEL_C.x0, 958, FUEL_C.n, d);
  return [...h, ...h.slice().reverse().map(p => ({ ...p, x: 1920 - p.x, nx: -p.nx }))];
};
const MPH_RAIL = { n: FUEL_C.n * 2, len: FUEL_C.len, w: FUEL_C.w, pts: railPts(FUEL_C.d) };
// Option A brake line: a 6 px line 14 px above the speed segments, the same width as the rail.
const BRK_LINE = { w: 6, pts: railPts(FUEL_C.d + FUEL_C.len + 14) };
// Distances from the rail base along the outward normal: ticks, then the cruise arrow tip.
const TICK0 = MPH_RAIL.len + (BRK === "a" ? 26 : 8), ARROW0 = TICK0 + 14 + 6;

// Point and outward normal at fraction f of a rail scale; the ends extrapolate to the outer edge of the end segments.
function railAt(pts, f) {
  const n = pts.length, k = f * n - .5, i = Math.max(0, Math.min(n - 2, Math.floor(k))), u = k - i, a = pts[i], b = pts[i + 1];
  const m = (p, q) => p + (q - p) * u;
  return { x: m(a.x, b.x), y: m(a.y, b.y), nx: m(a.nx, b.nx), ny: m(a.ny, b.ny) };
}
const at = (p, r) => [p.x + p.nx * r, p.y + p.ny * r];
const railArrow = v => {
  const p = railAt(MPH_RAIL.pts, Math.min(1, v / SPEED_MAX)), [tx, ty] = at(p, ARROW0), [bx, by] = at(p, ARROW0 + 15);
  return `M${tx.toFixed(1)} ${ty.toFixed(1)} L${(bx - p.ny * 9).toFixed(1)} ${(by + p.nx * 9).toFixed(1)} L${(bx + p.ny * 9).toFixed(1)} ${(by - p.nx * 9).toFixed(1)} Z`;
};
// Top-centre of the set-speed number (28 px type), 8 px above the arrow base.
const setNumAt = v => { const [x, y] = at(railAt(MPH_RAIL.pts, Math.min(1, v / SPEED_MAX)), ARROW0 + 23); return [x, y - 28]; };

function brakeLine(s) {
  const on = !!s.braking;
  const path = (f0, f1) => Array.from({ length: 41 }, (_, i) => railAt(BRK_LINE.pts, f0 + (f1 - f0) * i / 40))
    .map((p, i) => `${i ? "L" : "M"}${p.x.toFixed(1)} ${p.y.toFixed(1)}`).join(" ");
  const seg = (f, col) => f > 0 ? `<path d="${path(0, f)}" stroke="${col}" stroke-width="${BRK_LINE.w}" stroke-linecap="round" fill="none"/>` : "";
  const m = railAt(BRK_LINE.pts, s.gain / 10), [mx0, my0] = at(m, -8), [mx1, my1] = at(m, 8);
  layer(`<g data-field="${BRAKE_FIELD}">${seg(1, "#1d252e")}${seg(s.gain / 10, "var(--accent-dim)")}${on ? seg(s.output / 10, ACC) : ""}` +
    line(mx0, my0, mx1, my1, "#fff", 2, `stroke-opacity=".6"`) + `</g>`);
  const [x, y] = at(railAt(BRK_LINE.pts, 0), 0);
  place(`<div class="abs brk38 ${on ? "on" : ""}" style="right:${(1920 - x + 16).toFixed(1)}px;top:${(y - 15).toFixed(1)}px" data-field="${BRAKE_FIELD}">${sym("trailerBrake", 30)}</div>`);
}

// Brake output from the right end inward, drawn over the speed segments; only lit segments draw, so at rest nothing shows.
function brakeFill(s) {
  if (!s.braking) return;
  const pts = MPH_RAIL.pts.slice().reverse(), n = pts.length, v = s.output / 10;
  let g = `<g data-field="${BRAKE_FIELD}">`;
  pts.forEach((p, i) => {
    if ((i + .5) / n <= v) g += line(p.x, p.y, p.x + p.nx * MPH_RAIL.len, p.y + p.ny * MPH_RAIL.len, "#e8ecf1", MPH_RAIL.w, `stroke-linecap="round"`);
  });
  const m = railAt(pts, s.gain / 10);
  g += line(m.x - m.nx * 4, m.y - m.ny * 4, m.x + m.nx * (MPH_RAIL.len + 8), m.y + m.ny * (MPH_RAIL.len + 8), "#fff", 2, `stroke-opacity=".6"`);
  layer(g + `</g>`);
  const [x, y] = at(railAt(MPH_RAIL.pts, 1), MPH_RAIL.len / 2);
  place(`<div class="abs brk38 on" style="left:${x + 18}px;top:${y - 15}px" data-field="${BRAKE_FIELD}">${sym("trailerBrake", 30)}</div>`);
}

function speedRail(s) {
  let g = rail({ n: MPH_RAIL.n, pts: MPH_RAIL.pts, len: MPH_RAIL.len, w: MPH_RAIL.w, value: Math.min(1, s.speed / SPEED_MAX), field: "speed" });
  if (TICKS) {
    g += `<g data-field="speed scale, a tick every 10 mph">`;
    for (let v = 0; v <= SPEED_MAX; v += 10) {
      const p = railAt(MPH_RAIL.pts, v / SPEED_MAX), [x0, y0] = at(p, TICK0), [x1, y1] = at(p, TICK0 + (v % 20 ? 8 : 14));
      g += line(x0, y0, x1, y1, "#4a525c", 2);
    }
    g += `</g>`;
  }
  layer(g);
  if (BRK === "a") brakeLine(s);
  if (BRK === "b") brakeFill(s);
  const m = cruiseMark(s) || (s.cruise === "available" && s.cruiseSet ? [s.cruiseSet, "var(--caution)"] : null);
  if (!m) return;
  layer(`<path id="cset-arrow" data-field="cruiseSpeed getCruiseLimSpeed() · colour from cruiseSpeedSet (SET)" d="${railArrow(m[0])}" fill="${m[1]}" stroke="#05070a" stroke-width="3" paint-order="stroke"/>`);
  const [x, y] = setNumAt(m[0]);
  place(`<div class="abs cset32${s.adjusting ? " hold" : ""}" style="left:${x.toFixed(1)}px;top:${y.toFixed(1)}px" data-field="cruiseSpeed getCruiseLimSpeed() (shows while the set speed changes)">${m[0]}</div>`);
}

// The round 32 set-speed demo on the rail.
cruiseDemo = function (s) {
  const arrow = document.getElementById("cset-arrow"), num = document.querySelector(".cset32");
  let v = s.cruiseSet, i = 0;
  const steps = [0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, -1, -1, 0, 0, 0, 0, 0, 0, 0];
  setInterval(() => {
    const d = steps[i++ % steps.length];
    if (!d) return;
    v += d;
    const [x, y] = setNumAt(v);
    arrow.setAttribute("d", railArrow(v));
    num.textContent = v;
    num.style.left = `${x.toFixed(1)}px`;
    num.style.top = `${y.toFixed(1)}px`;
    num.classList.remove("show");
    void num.offsetWidth;
    num.classList.add("show");
  }, 600);
};

const fuelCorner = s => band2({ side: "r", x1: CORNER_X1, n: 20, value: (s.fuel ?? 0) / 100, color: fuelColor(s, QUIET),
  warnTo: lowPct(s) / 100, ends: ["E", "F"], field: "fuelPercentage" });
// The fuel symbol rides in the .corner.r box that kit25 cornerIcons moves to the old trailer brake symbol place.
const fuelMark = s => `<div class="abs corner r fuel38 ${fuelState(s)}" data-field="fuelPercentage"><span class="k">${sym("fuel", 40)}</span></div>`;
const rangeNum = s => `<div class="abs num34 a fuel38 ${fuelState(s)}" style="right:40px;top:700px"><span class="n34" data-field="DTE"><b>${dash(s.range)}</b><i>mi</i></span></div>`;

const finish37 = finish;
finish = function (s) {
  finish37(s);
  document.body.classList.add(`brk38-${BRK}`);
};
