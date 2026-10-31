// Round 37 kit: the speed bar under the speed digits and a steering arc above them. Loads after round-35/kit35.js
// (round 36 adds styles only).
//
// User direction (2026-10-30): the speed bar goes below the big speed number; an arc above the number shows the steering
// position; the bar markers flip. The user named both "cruise and MPH above the big number" and "MPH stays below the number",
// so the pick covers both:
// - ?unit=a|b. A: MPH and the cruise symbol stay under the digits; the bar sits under MPH. B: MPH and the cruise symbol move
//   above the digits, under the arc; the bar takes the old MPH place under the digits.
// - Speed bar: ticks every 10 mph now hang below the bar (longer every 20). The cruise arrow sits under the bar and points up
//   at the set speed; the set-speed number shows under the arrow while the set speed changes (round 32 timing).
// - Steering arc: a shallow arc above the digits, from SCALE.x0 to SCALE.x1, apex ARC.top. The fill runs from straight ahead
//   to the wheel position; a pill at the position stands across the arc. Ticks every 10 degrees on the outer side, the center
//   tick longer. Shown at every speed (the round 20 to 36 steering bar showed at crawl speed only, in place of the speed bar).
// - Reverse: the large R (round 31) keeps the center row, so the speed bar hides; the steering arc stays.
const UNIT = params.get("unit") === "b" ? "b" : "a";
const BAR_Y = UNIT === "a" ? 512 : 488;
const ARC = { top: 218, sag: 32 };
ARC.r = ((SCALE.x1 - 960) ** 2 + ARC.sag ** 2) / (2 * ARC.sag);
ARC.half = Math.asin((SCALE.x1 - 960) / ARC.r);   // radians at the arc ends
ARC.cy = ARC.top + ARC.r;
const STEER_FIELD = "angle getAngle() · MCU 0x26 trackInfoNotify (stock: Wheel angle display)";

const arcAt = (a, dr = 0) => {
  const t = Math.max(-1, Math.min(1, a / STEER_MAX)) * ARC.half, r = ARC.r + dr;
  return [960 + r * Math.sin(t), ARC.cy - r * Math.cos(t), t * 180 / Math.PI];
};
const arcPath = (a0, a1) => {
  const [x0, y0] = arcAt(a0), [x1, y1] = arcAt(a1);
  return `M${x0.toFixed(1)} ${y0.toFixed(1)} A${ARC.r.toFixed(1)} ${ARC.r.toFixed(1)} 0 0 ${a1 > a0 ? 1 : 0} ${x1.toFixed(1)} ${y1.toFixed(1)}`;
};

function steerArc(s) {
  const r = `stroke-linecap="round" fill="none"`, [px, py, deg] = arcAt(s.steer);
  let g = `<g data-field="${STEER_FIELD}"><path d="${arcPath(-STEER_MAX, STEER_MAX)}" stroke="#1d252e" stroke-width="6" ${r}/>`;
  if (s.steer) g += `<path d="${arcPath(0, s.steer)}" stroke="${ACC}" stroke-width="6" ${r}/>`;
  for (let a = -40; a <= 40; a += 10) {
    const [x0, y0] = arcAt(a, 10), [x1, y1] = arcAt(a, a ? 18 : 30);
    g += line(x0, y0, x1, y1, a ? "#4a525c" : "#8a929c", a ? 2 : 3);
  }
  g += `<rect x="${(px - 8).toFixed(1)}" y="${(py - 17).toFixed(1)}" width="16" height="34" rx="6" fill="${ACC}" stroke="#05070a" stroke-width="3" transform="rotate(${deg.toFixed(1)} ${px.toFixed(1)} ${py.toFixed(1)})"/>`;
  layer(g + `</g>`);
}

// Flipped cruise arrow: under the bar, pointing up at the set speed.
const setArrowUp = (x, y) => `M${x.toFixed(1)} ${y + 5} l-9 15 h18 Z`;
speedRuler = function (s, y = BAR_Y) {
  let g = `<g data-field="speed">` + line(SCALE.x0, y, SCALE.x1, y, "#1d252e", 6, `stroke-linecap="round"`) +
    line(SCALE.x0, y, speedX(s.speed), y, ACC, 6, `stroke-linecap="round"`);
  if (TICKS) for (let v = 0; v <= SPEED_MAX; v += 10) g += line(speedX(v), y + 10, speedX(v), y + (v % 20 ? 18 : 26), "#4a525c", 2);
  layer(g + `</g>`);
  const m = cruiseMark(s) || (s.cruise === "available" && s.cruiseSet ? [s.cruiseSet, "var(--caution)"] : null);
  if (!m) return;
  layer(`<path id="cset-arrow" data-field="cruiseSpeed getCruiseLimSpeed() · colour from cruiseSpeedSet (SET)" d="${setArrowUp(speedX(m[0]), y)}" fill="${m[1]}" stroke="#05070a" stroke-width="3" paint-order="stroke"/>`);
  place(`<div class="abs cset32${s.adjusting ? " hold" : ""}" style="left:${speedX(m[0])}px;top:${y + 32}px" data-field="cruiseSpeed getCruiseLimSpeed() (shows while the set speed changes)">${m[0]}</div>`);
};

// The round 32 set-speed demo, with the flipped arrow.
cruiseDemo = function (s) {
  const arrow = document.getElementById("cset-arrow"), num = document.querySelector(".cset32");
  let v = s.cruiseSet, i = 0;
  const steps = [0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, -1, -1, 0, 0, 0, 0, 0, 0, 0];
  setInterval(() => {
    const d = steps[i++ % steps.length];
    if (!d) return;
    v += d;
    arrow.setAttribute("d", setArrowUp(speedX(v), BAR_Y));
    num.textContent = v;
    num.style.left = `${speedX(v)}px`;
    num.classList.remove("show");
    void num.offsetWidth;
    num.classList.add("show");
  }, 600);
};

const finish35 = finish;
finish = function (s) {
  finish35(s);
  document.body.classList.add(`unit37-${UNIT}`);
};
