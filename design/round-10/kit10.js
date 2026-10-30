// Round 10 kit: fuel at bottom center on every layout. Loads after round-08/kit8.js.
// The steering column cover still hides the screen below y 752 (traced from a photo). Bottom center is the strip above the cover.
// Fuel module: a band along the cover top from x 660 to 1260 (E left, F right, filling left to right), the level left of E
// and the range right of F, on one line. Corner bands end at x 500 to leave room for the two readouts.
const FUEL_C = { x0: 660, n: 13, d: 26, len: 22, w: 9 }, CORNER_X1 = 500;
function fuelCenter(s) {
  const half = shroudRail(FUEL_C.x0, 958, FUEL_C.n, FUEL_C.d);
  const pts = [...half, ...half.slice().reverse().map(p => ({ ...p, x: 1920 - p.x, nx: -p.nx }))];
  layer(rail({ n: pts.length, pts, len: FUEL_C.len, w: FUEL_C.w, value: (s.fuel ?? 0) / 100, color: fuelColor(s, QUIET),
    warnTo: lowPct(s) / 100, glow: false, ends: ["E", "F"], field: "fuelPercentage" }));
  return `<div class="abs fread fc ${fuelState(s)}" style="right:${1920 - FUEL_C.x0 + 34}px" data-field="fuelPercentage">${fuelIcon}<span class="rv">${dash(s.fuel)}<span class="u">%</span></span></div>` +
    `<div class="abs fread fc ${fuelState(s)}" style="left:${1920 - FUEL_C.x0 + 34}px" data-field="DTE"><span class="rv">${dash(s.range)}<span class="u">mi</span></span></div>`;
}

// Temperature band colours by state: quiet grey when normal.
const TEMP_TINT = { cold: "#a0ccf5", normal: QUIET, warm: "#ffb020", hot: "#ff3b30" };
