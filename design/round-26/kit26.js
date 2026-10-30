// Round 26 kit: the speed bar above the speed digits. Loads after round-25/kit25.js.
//
// User direction (2026-10-30): the speed Y position felt off; the big speed value goes below the bar; the bar needs no numbers.
// - The center group lines up with the cards: the bar sits on the card top line (y 236), and the row of cruise, gear, and drive
//   mode sits on the line of the temperature symbols (center y 545). Before, the digits started 40 px above the cards.
// - The digits sit under the bar, with MPH under the digits. No numbers on the bar: the digits carry the number.
// - The cruise set mark sits under the bar and points up at the bar, so the mark stays clear of the ticks above.
// - At crawl speed the steering bar takes the same place, with the ticks above the bar (the center tick marks straight ahead).
// - ?ticks=a|b. A: a plain bar. B: ticks every 10 mph above the bar, longer every 20. B is locked (2026-10-30) and is the
//   default; ?ticks=a stays for the round 26 comparison.
const TICKS = params.get("ticks") !== "a";
// The bar follows the card top, so a later kit that moves the cards moves the bar too.
const barY = () => CARD.top + 3;

speedRuler = function (s, y = barY()) {
  let g = `<g data-field="speed">` + line(SCALE.x0, y, SCALE.x1, y, "#1d252e", 6, `stroke-linecap="round"`) +
    line(SCALE.x0, y, speedX(s.speed), y, ACC, 6, `stroke-linecap="round"`);
  if (TICKS) for (let v = 0; v <= SPEED_MAX; v += 10) g += line(speedX(v), y - 10, speedX(v), y - (v % 20 ? 18 : 26), "#4a525c", 2);
  const m = cruiseMark(s);
  if (m) g += `<path data-field="cruiseSpeedSet" d="M${speedX(m[0])} ${y + 6} l-8 14 h16 Z" fill="${m[1]}"/>`;
  layer(g + `</g>`);
};

steerBar = function (s, y = barY()) {
  const x = steerX(s.steer), r = `stroke-linecap="round"`;
  let g = `<g data-field="angle getAngle() · MCU 0x26 trackInfoNotify (stock: Wheel angle display)">` +
    line(SCALE.x0, y, SCALE.x1, y, "#1d252e", 6, r) + line(960, y, x, y, ACC, 6, r);
  for (let a = -40; a <= 40; a += 10) g += line(steerX(a), y - 12, steerX(a), y - (a ? 20 : 32), a ? "#4a525c" : "#8a929c", a ? 2 : 3);
  g += `<rect x="${(x - 8).toFixed(1)}" y="${y - 17}" width="16" height="34" rx="6" fill="${ACC}" stroke="#05070a" stroke-width="3" transform="rotate(${s.steer} ${x.toFixed(1)} ${y})"/>`;
  layer(g + `</g>`);
};
