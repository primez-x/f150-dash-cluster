// Round 44 kit: the alert panel padding, the overspeed warning, and the set-speed direction tint. Loads after
// round-43/kit43.js.
//
// User picks (2026-10-31): alert panel A (tinted glass) is locked, with the padding fixed; the card jumps stay; "+N" stays.
// The ACC and LIM labels are not set-speed changes: the adapter reports adaptive cruise (ACC) and a speed limiter (LIM).
// Picks (2026-10-31): overspeed B, set-speed direction B. The ACC and LIM labels go: this truck has neither.
// - Alert padding (kit44.css): the bezel mask now draws over the panel, as the truck bezel does. Inside the visible area the
//   content block sits 20 px below the arch over the text and 20 px above the panel bottom (round 43: about 23 and 12).
//   The sides match at 36 px.
// - ?over=a|b, ?scene=overspeed. The stock overspeed warning (OverSpeedWarning, unit 173) compares the speed with the
//   threshold from the menu ("Speed warning at"). The round 42 badge looked like a road sign, so the badge goes.
//   Both: a red threshold tick and the threshold number on the speed scale, shown only while over the threshold; no blink.
//   A: the speed digits turn red. B: the digits stay white; the speed scale fills red from the threshold to the speed.
// - ?dir=a|b, ?scene=setup|setdown. While the driver changes the set speed, the temporary number tints by direction:
//   up lime, down sky blue. The cruise green stays the colour of a held set speed.
//   A: the number only. B: the number and the arrow, plus a short trail on the scale from the old set speed to the new one.
const OVER44 = params.get("over") === "b" ? "b" : "a";
const DIR44 = params.get("dir") === "b" ? "b" : "a";
const UP44 = "#b8f060", DOWN44 = "#4fb3ff", WARN44 = "#ff3b30";
SCENES.overspeed = s => Object.assign(s, { speed: 76, over: 70, rpm: 2400 });
SCENES.setup = s => Object.assign(s, { cruise: "set", cruiseSet: 66, from: 58, adjusting: true });
SCENES.setdown = s => Object.assign(s, { cruise: "set", cruiseSet: 62, from: 70, adjusting: true });

// One speed scale for both layouts: the Daily A speed crescent (round 4 crescent, a0 252) or the Towing A gauge (round 39 A).
// r is the distance outward from the speed fill; the fill is r 0.
const DAILY_SP = { cx: 800, cy: 470, r: 560, a0: 252, a1: 305, max: 120 };
const spA = v => DAILY_SP.a0 + (DAILY_SP.a1 - DAILY_SP.a0) * v / DAILY_SP.max;
const scaleAt = (v, r) => CRESCENTS ? polar(DAILY_SP.cx, DAILY_SP.cy, DAILY_SP.r - 16 + r, spA(v)) : at(gAt(v), G39.bar + r);
const scalePath = (v0, v1, r) => CRESCENTS
  ? arc(DAILY_SP.cx, DAILY_SP.cy, DAILY_SP.r - 16 + r, Math.min(spA(v0), spA(v1)), Math.max(spA(v0), spA(v1)))
  : gPath(v0, v1, G39.bar + r);
const scaleLine = (v, r0, r1, col, w) => { const [x0, y0] = scaleAt(v, r0), [x1, y1] = scaleAt(v, r1); return line(x0, y0, x1, y1, col, w, `stroke-linecap="round"`); };
// Scale labels: Daily A 26 px at r + 54 from the ticks; Towing A 18 px at G39.num.
const scaleLabel = (v, col) => {
  const [x, y] = CRESCENTS ? polar(DAILY_SP.cx, DAILY_SP.cy, DAILY_SP.r + 54, spA(v)) : at(gAt(v), G39.num);
  return text(x, y + (CRESCENTS ? 9 : 0), v, CRESCENTS ? 26 : 18, col, "middle", LABEL, `font-weight="600"`);
};

function over44(s) {
  if (!s.over || s.speed <= s.over) return;
  document.body.classList.add(`over44-${OVER44}`);
  // The threshold tick crosses the fill (Daily A 12 px wide, Towing A 8 px); the number takes the scale label row.
  let g = `<g data-field="getOverSpeedWaningSpeed() · overSpeedWarningState">`;
  if (OVER44 === "b") g += `<path d="${scalePath(s.over, Math.min(s.speed, CRESCENTS ? DAILY_SP.max : SPEED_MAX), 0)}" fill="none" stroke="${WARN44}" stroke-width="${CRESCENTS ? 12 : 8}" filter="url(#glow)"/>`;
  g += scaleLine(s.over, -14, CRESCENTS ? 28 : -26, WARN44, 4) + scaleLabel(s.over, WARN44);
  layer(g + `</g>`);
}

function dir44(s) {
  if (!s.adjusting || s.from == null) return;
  const col = s.cruiseSet > s.from ? UP44 : DOWN44;
  document.body.classList.add(`dir44-${DIR44}`);
  // Daily A has no set-speed number in the round 42 mock: the number takes r + 92, outside the scale labels (vnL rail r 101).
  if (CRESCENTS) {
    const [x, y] = polar(DAILY_SP.cx, DAILY_SP.cy, DAILY_SP.r + 100, spA(s.cruiseSet));
    place(`<div class="abs cset32 hold" style="left:${x.toFixed(1)}px;top:${(y - 14).toFixed(1)}px" data-field="cruiseSpeed (shows while the set speed changes)">${s.cruiseSet}</div>`);
  }
  document.querySelector(".cset32").style.color = col;
  if (DIR44 === "a") return;
  const arrow = CRESCENTS ? document.querySelector('path[data-field="cruiseSpeedSet"]') : document.getElementById("cset-arrow");
  arrow?.setAttribute("fill", col);
  // Trail: along the arrow track (Daily A arrow r + 30 to r + 46; Towing A tip at SET_AT.r), from the old set speed to the
  // arrow; the trail fades with the number.
  const r = CRESCENTS ? 16 + 38 : SET_AT.r + 8 - G39.bar;
  layer(`<path data-field="cruiseSpeed change" d="${scalePath(s.from, s.cruiseSet, r)}" fill="none" stroke="${col}" stroke-opacity=".6" stroke-width="4" stroke-linecap="round"/>`);
}
