// Round 39 kit: a speed gauge design for the bottom-center rail. Loads after round-38/kit38.js.
//
// User direction (2026-10-30): the bottom gauge is a speed gauge now, so the gauge needs a design of its own (round 38 kept the
// coarse fuel segments). Both options follow the column cover from x 660 to x 1260, 0 mph left, 100 mph right, and read like
// a speedometer: a numbered scale at 0, 20, 40, 60, 80, and 100 along the cover, ticks every 10 mph above the numbers.
// The cruise arrow sits on top of the gauge and points down at the set speed; the set-speed number shows above the arrow.
// - ?gauge=a|b. A: a continuous bar. The fill brightens from the left to the current speed; ticks every 5 mph hang from
//   the bar toward the numbers, and ticks up to the current speed light grey.
//   B: a comb of fine ticks, one every 2 mph, taller every 10 mph. Ticks up to the current speed light in the accent colour,
//   brighter toward the current speed; the tick at the current speed glows.
// - The trailer brake shows option C (round 38 recommendation: the trailer page of the right card only); that pick stays open.
//
// Distances (px) from the cover edge along the outward normal; the 20 px margin ends at 20.
const GAUGE = params.get("gauge") === "b" ? "b" : "a";
const EDGE = railPts(0);
const G39 = { num: 24, tick: 48, bar: 70, comb: 50 };
Object.assign(SET_AT, { pts: EDGE, r: GAUGE === "a" ? 78 : 80 });
const gAt = v => railAt(EDGE, Math.min(1, Math.max(0, v / SPEED_MAX)));
const gLine = (v, r0, r1, col, w, extra = "") => { const p = gAt(v), [x0, y0] = at(p, r0), [x1, y1] = at(p, r1); return line(x0, y0, x1, y1, col, w, extra); };
const gPath = (v0, v1, r) => Array.from({ length: 41 }, (_, i) => at(gAt(v0 + (v1 - v0) * i / 40), r))
  .map(([x, y], i) => `${i ? "L" : "M"}${x.toFixed(1)} ${y.toFixed(1)}`).join(" ");
const gNums = () => [0, 20, 40, 60, 80, 100].map(v => { const [x, y] = at(gAt(v), G39.num); return text(x, y, v, 18, "#6b7480"); }).join("");

function gaugeBar(s) {
  const v = Math.min(SPEED_MAX, s.speed), [x0] = at(gAt(0), G39.bar), [x1] = at(gAt(v), G39.bar);
  let g = `<defs><linearGradient id="spd39" gradientUnits="userSpaceOnUse" x1="${x0.toFixed(1)}" y1="0" x2="${Math.max(x0 + 1, x1).toFixed(1)}" y2="0">` +
    `<stop offset="0" stop-color="${ACC}" stop-opacity=".25"/><stop offset="1" stop-color="${ACC}"/></linearGradient></defs>` +
    `<path d="${gPath(0, SPEED_MAX, G39.bar)}" stroke="#1d252e" stroke-width="8" stroke-linecap="round" fill="none"/>`;
  if (v > 0) g += `<path d="${gPath(0, v, G39.bar)}" stroke="url(#spd39)" stroke-width="8" stroke-linecap="round" fill="none" filter="url(#glow)"/>`;
  for (let t = 0; t <= SPEED_MAX; t += 5) g += gLine(t, G39.bar - 10, G39.bar - (t % 10 ? 16 : 22), t <= v ? "#8a929c" : "#3a434d", 2);
  return g;
}

function gaugeComb(s) {
  const v = Math.min(SPEED_MAX, s.speed), head = Math.floor(v / 2) * 2;
  let g = "";
  for (let t = 0; t <= SPEED_MAX; t += 2) {
    const major = t % 10 === 0, r1 = G39.comb + (major ? 26 : 16), lit = t <= v && v > 0;
    const op = lit ? (.3 + .7 * Math.pow((t + 2) / (head + 2), 1.4)).toFixed(2) : 1;
    g += gLine(t, G39.comb, r1, lit ? ACC : major ? "#3a434d" : "#262e38", major ? 4 : 3,
      `stroke-linecap="round" stroke-opacity="${op}"${lit && t === head ? ' filter="url(#glow)"' : ""}`);
  }
  return g;
}

speedRail = function (s) {
  layer(`<g data-field="speed">${GAUGE === "a" ? gaugeBar(s) : gaugeComb(s)}${gNums()}</g>`);
  railCruise(s);
};

const finish38 = finish;
finish = function (s) {
  finish38(s);
  document.body.classList.add(`gauge39-${GAUGE}`);
};
