// Round 10 kit: fuel at bottom center on every layout. Loads after round-08/kit8.js.
// The steering column cover still hides the screen below y 752 (traced from a photo). Bottom center is the strip above the cover.
// Fuel module: a band along the cover top from x 660 to 1260 (E left, F right, filling left to right), the level left of E
// and the range right of F, on one line. Corner bands end at x 500 to leave room for the two readouts.
const FUEL_C = { x0: 660, n: 13, d: 26, len: 22, w: 9 }, CORNER_X1 = 500;
// ends: null draws the band without the E and F letters. level: false drops the percent and keeps the fuel symbol.
// quarters: true adds tick marks at 1/4, 1/2, and 3/4, with a longer tick and a ½ label at the middle.
function fuelCenter(s, { ends = ["E", "F"], level = true, quarters = false } = {}) {
  const half = shroudRail(FUEL_C.x0, 958, FUEL_C.n, FUEL_C.d);
  const pts = [...half, ...half.slice().reverse().map(p => ({ ...p, x: 1920 - p.x, nx: -p.nx }))];
  layer(rail({ n: pts.length, pts, len: FUEL_C.len, w: FUEL_C.w, value: (s.fuel ?? 0) / 100, color: fuelColor(s, QUIET),
    warnTo: lowPct(s) / 100, glow: false, ends, field: "fuelPercentage" }));
  if (quarters) layer(`<g data-field="fuel gauge quarter marks">${[.25, .5, .75].map(t => {
    const f = t * pts.length - .5, a = pts[Math.floor(f)], b = pts[Math.ceil(f)], m = (u, v) => (u + v) / 2;
    const p = { x: m(a.x, b.x), y: m(a.y, b.y), nx: m(a.nx, b.nx), ny: m(a.ny, b.ny) }, r0 = FUEL_C.len + 6, r1 = r0 + (t === .5 ? 14 : 8);
    return line(p.x + p.nx * r0, p.y + p.ny * r0, p.x + p.nx * r1, p.y + p.ny * r1, "#6b7480", 3, `stroke-linecap="round"`) +
      (t === .5 ? text(p.x + p.nx * (r1 + 16), p.y + p.ny * (r1 + 16) + 7, "½", 20, "#6b7480") : ""); }).join("")}</g>`);
  return `<div class="abs fread fc ${fuelState(s)}" style="right:${1920 - FUEL_C.x0 + 34}px" data-field="fuelPercentage">${fuelIcon}${level ? `<span class="rv">${dash(s.fuel)}<span class="u">%</span></span>` : ""}</div>` +
    `<div class="abs fread fc ${fuelState(s)}" style="left:${1920 - FUEL_C.x0 + 34}px" data-field="DTE"><span class="rv">${dash(s.range)}<span class="u">mi</span></span></div>`;
}

// Temperature band colours by state: quiet grey when normal.
const TEMP_TINT = { cold: "#a0ccf5", normal: QUIET, warm: "#ffb020", hot: "#ff3b30" };
