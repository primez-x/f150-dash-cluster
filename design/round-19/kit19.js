// Round 19 kit: drive modes, a speed scale, and cruise on the locked center-axis Towing A. Loads after round-18/kit18.js.

// Drive mode scenes. getGearAwd() indexes mFord4wd: 2WD, 4WD AUTO, 4WD LOCK (4H), 4WD LOW (4L). Rear locker: alarmTable[76],
// pending verification on the truck. ?cruise=set|acc|lim overrides the cruise state for any scene.
SCENES.d4a = s => Object.assign(s, { drive: "4A" });
SCENES.d4h = s => Object.assign(s, { drive: "4H", speed: 38, gearNum: 3, rpm: 1900 });
SCENES.d4l = s => Object.assign(s, { drive: "4L", speed: 6, gearNum: 1, rpm: 1400, grade: 12, boost: -6 });
SCENES.locker = s => Object.assign(SCENES.d4l(s), { locker: true });
// Cruise set during an alert: the alert banner covers the cruise readout; the set-speed mark stays on the speed scale.
SCENES.alertcruise = s => Object.assign(SCENES.hottrans(s), { cruise: "set" });
// Width check: three speed digits, the widest speed readout.
SCENES.fast = s => Object.assign(s, { speed: 104, rpm: 3100 });

// Drive chip: 2H is the quiet outline chip. 4A, 4H, and 4L fill (kit8). The rear locker adds an amber chip with a padlock.
SYM.padlock = `<rect x="13" y="24" width="28" height="22" rx="4" fill="#000"/><path d="M19 24v-6a8 8 0 0 1 16 0v6"/>`;
const driveChip = s => chip(s) + (s.locker ? `<span class="dchip lock" data-field="rear locker: alarmTable[76] pending verification">${sym("padlock", 22)}R</span>` : "");

// Speed scale under the speed digits, 0 to 100 mph, centered on x 960. The fill is the accent colour (speed is a primary gauge).
// With cruise set or adaptive cruise, a green mark shows the set speed; with the limiter, a white mark shows the limit.
const SPEED_MAX = 100, SCALE = { x0: 720, x1: 1200 };
const cruiseMark = s => ({ set: [s.cruiseSet, "var(--ok)"], acc: [s.cruiseSet, "var(--ok)"], lim: [70, "#e8ecf1"] })[s.cruise];
const speedX = v => SCALE.x0 + (SCALE.x1 - SCALE.x0) * Math.min(1, v / SPEED_MAX);

// Option A: a straight ruler. Ticks every 10 mph, longer every 20, no numbers; the digits carry the number.
function speedRuler(s, y = 362) {
  let g = `<g data-field="speed">` + line(SCALE.x0, y, SCALE.x1, y, "#1d252e", 6, `stroke-linecap="round"`) +
    line(SCALE.x0, y, speedX(s.speed), y, ACC, 6, `stroke-linecap="round"`);
  for (let v = 0; v <= SPEED_MAX; v += 10) g += line(speedX(v), y + 10, speedX(v), y + (v % 20 ? 18 : 26), "#4a525c", 2);
  const m = cruiseMark(s);
  if (m) g += `<path data-field="cruiseSpeedSet" d="M${speedX(m[0])} ${y - 6} l-8 -14 h16 Z" fill="${m[1]}"/>`;
  layer(g + `</g>`);
}

// Option B: a segment arch that echoes the shroud curve and the corner bands. Segments hang down from the arch and light up
// to the speed; the cruise mark sits under the arch.
function speedArch(s, apex = 358) {
  const R = 1500, cy = apex + R, n = 26, a0 = Math.asin((960 - SCALE.x0) / R) * 180 / Math.PI;
  let g = `<g data-field="speed">`;
  for (let i = 0; i < n; i++) {
    const t = i / (n - 1), a = -a0 + 2 * a0 * t, v = SPEED_MAX * t, lit = v <= s.speed;
    const [x0, y0] = polar(960, cy, R, a), [x1, y1] = polar(960, cy, R - (v % 20 ? 14 : 22), a);
    g += line(x0, y0, x1, y1, lit ? ACC : "#1d252e", 6, `stroke-linecap="round"${lit ? ` stroke-opacity="${(.3 + .7 * Math.pow(v / Math.max(1, s.speed), 1.5)).toFixed(2)}"` : ""}`);
  }
  const m = cruiseMark(s);
  if (m) {
    const a = -a0 + 2 * a0 * Math.min(1, m[0] / SPEED_MAX), p = (r, da = 0) => polar(960, cy, r, a + da).map(v => v.toFixed(1)).join(" ");
    g += `<path data-field="cruiseSpeedSet" d="M${p(R - 28)} L${p(R - 42, -.35)} L${p(R - 42, .35)} Z" fill="${m[1]}"/>`;
  }
  layer(g + `</g>`);
}
