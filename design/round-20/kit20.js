// Round 20 kit: steering angle, pitch and roll, compass heading, and altitude on the locked Towing A (round 19 A, ruler).
// Loads after round-19/kit19.js.
//
// Firmware fields (capture-04 etc/common) and what the stock layouts (handoff/claude-dashboard ui1 to ui6) show:
// - Wheel angle: angle, from MCU message 0x26 trackInfoNotify: angle = -getTrackAngel(); getAngle() = angle x 45 / 128 degrees.
//   Stock AngleInfo ("Steering angle") shows the degrees in every gear while the factory setting angleInfoEnabled
//   ("Wheel angle display") is on, so the MCU sends 0x26 in every gear. Sign: positive = right (stock draws the right arc
//   for mAngle >= 0).
// - Pitch and roll: mPitch and mRoll from the motion sensor inside the cluster. The firmware sets the sign (mRoll = -getRoll())
//   and the zero (mGyroCalibration). Stock PitchInfo and RollInfo show both at every speed, with the Ford truck images
//   (gyro/ford/pitch, gyro/ford/roll) turned to the angle. 0xFFFF = no data: show "--".
// - Heading: gpsBearing (0 to 359.9 degrees). The firmware updates the bearing only above 5. See the heading tape below.
// - Altitude: getAltitude(): the GPS altitude with a GPS fix, otherwise the barometric altitude (mAltitude), in metres.
//   Shown in feet with the MPH units.
//
// The motion sensor reads acceleration as tilt: a fast corner reads as roll. So the tilt focus triggers only at crawl speed
// (CRAWL_MPH and under) or in reverse. The level page itself shows at every speed, as on the stock layouts.
Object.assign(BASE.tow, { steer: 0, roll: 1, heading: 48, altFt: 1840 });
BASE.tow.pages = ["trailer", "tires", "engine", "level", "trip"];
SCENES.crawl = s => Object.assign(s, { speed: 3, gearNum: 1, rpm: 900, boost: -8, grade: 3, roll: 4, steer: -22, heading: 262 });
SCENES.backing = s => Object.assign(s, { speed: 2, gear: "R", gearNum: "", rpm: 800, boost: -8, grade: -1, roll: 2, steer: 18, heading: 141 });
SCENES.tilt = s => Object.assign(s, { speed: 4, gearNum: 1, rpm: 1000, boost: -6, grade: 5, roll: 13, steer: 8, heading: 352, altFt: 6420 });
SCENES.tilthot = s => Object.assign(SCENES.tilt(s), { roll: -21, steer: -6 });
// A hot transmission outranks the tilt focus: the level page stays off screen and shows an amber symbol beside the dots.
SCENES.tiltstack = s => SCENES.tilt(SCENES.hottrans(s));
// Mountain pass: a long climb at altitude. The climb focus jumps the panel to the level page.
SCENES.pass = s => Object.assign(SCENES.climb(s), { heading: 284, altFt: 9580, roll: -2 });

const CRAWL_MPH = 8, TILT = { warn: 10, hot: 20 };   // design values, to tune on the truck
const crawl = s => s.speed <= CRAWL_MPH || s.gear === "R";
const tiltState = s => !crawl(s) ? "" : Math.abs(s.roll) >= TILT.hot ? "hot" : Math.abs(s.roll) >= TILT.warn ? "warm" : "";
FOCUS.splice(FOCUS.findIndex(([k]) => k === "tires") + 1, 0, ["tilt", s => !!tiltState(s)]);   // mRoll, crawl only

// Level page: grade and roll. The grade moves here from the engine page, so one reading has one place; the corner band
// already shows rpm and boost, so the engine page keeps the two numbers. Climb, descent, and tilt jump to the level page.
SYM.roll = `<g transform="rotate(14 27 30)"><path d="M17 19l3-7h14l3 7"/><rect x="8" y="19" width="38" height="13" rx="3"/><path d="M13 32v7M41 32v7M3 44h48"/></g>`;
PAGE_SYM.level = "roll";
PAGE_STATE.level = tiltState;
Object.assign(SEC_FOCUS, { climb: "level", descent: "level", tilt: "level" });
SEC.engine = s => `<div class="cells">${scell("tach", s.rpm.toLocaleString("en-US"), "rpm", "tacho rpm")}${scell("turbo", boostText(s), "psi", "boost: turbo, boostPercentage (JLY 0x40, vehicleInfoNotify); scale from the truck log")}</div>`;

const GRADE_FIELD = "mPitch getPitchString() (grade = tan pitch)", ROLL_FIELD = "mRoll getRollString()";
const rollSym = (s, h) => sym("roll", h, s.roll < 0 ? "flip" : "");

// Option A: numbers, as on every other page. The roll symbol leans to the low side.
const levelCells = s => `<div class="cells">` +
  `<span class="icell" data-field="${GRADE_FIELD}">${gradeSym(s, 36)}<span class="rv">${gradeText(s.grade)}<span class="u">%</span></span></span>` +
  `<span class="icell ${tiltState(s)}" data-field="${ROLL_FIELD}">${rollSym(s, 36)}<span class="rv">${Math.abs(s.roll)}<span class="u">°</span></span></span></div>`;

// Option B: the stock Ford truck images, a side view for the grade and a rear view for the roll, turned to the true angle
// over a dashed level line, each with one number. Past the tilt limits the rear view takes the state colour as a glow.
const truckPic = (n, a, cls = "") => `<span class="tpic ${n} ${cls}"><i class="lvl"></i><img src="${IMG}/common/gyro/ford/${n}.png" alt="" style="transform:rotate(${a.toFixed(1)}deg)"></span>`;
const levelArt = s => `<div class="cells">` +
  `<span class="icell art" data-field="${GRADE_FIELD}">${truckPic("pitch", Math.atan(s.grade / 100) * 180 / Math.PI)}` +
  `<span class="rv">${gradeText(s.grade)}<span class="u">%</span></span></span>` +
  `<span class="icell art ${tiltState(s)}" data-field="${ROLL_FIELD}">${truckPic("roll", s.roll, tiltState(s))}<span class="rv">${Math.abs(s.roll)}<span class="u">°</span></span></span></div>`;
SEC.level = levelCells;

// Steering bar: at crawl speed or in reverse the speed scale carries nothing, so the bar under the speed digits shows the
// wheel angle. The fill runs from the center line to the angle; a tall tick marks straight ahead. The knob is a tire seen
// from above, turned by the wheel angle. No number: the bar answers "where do the wheels point".
const STEER_MAX = 45;
const steerX = a => 960 + (SCALE.x1 - 960) * Math.max(-1, Math.min(1, a / STEER_MAX));
function steerBar(s, y = 362) {
  const x = steerX(s.steer), r = `stroke-linecap="round"`;
  let g = `<g data-field="angle getAngle() · MCU 0x26 trackInfoNotify (stock: Wheel angle display)">` +
    line(SCALE.x0, y, SCALE.x1, y, "#1d252e", 6, r) + line(960, y, x, y, ACC, 6, r);
  for (let a = -40; a <= 40; a += 10) g += line(steerX(a), y + 12, steerX(a), y + (a ? 20 : 32), a ? "#4a525c" : "#8a929c", a ? 2 : 3);
  g += `<rect x="${(x - 8).toFixed(1)}" y="${y - 17}" width="16" height="34" rx="6" fill="${ACC}" stroke="#05070a" stroke-width="3" transform="rotate(${s.steer} ${x.toFixed(1)} ${y})"/>`;
  layer(g + `</g>`);
}

// Top bar, in the quiet grey: a heading tape beside the clock, and the altitude beside the outside temperature.
//
// Heading tape. The stock CompassInfo is a bad reference here: the tape image moves by getGpsBearing(), which turns bearings
// over 315 into negative values, so a turn through NW sweeps the tape back across all 360 degrees. Each GPS fix also starts a
// 600 ms jump and then the tape stops, so the tape steps. And getCompassDir() ends NW at 332.5 instead of 337.5.
// This tape draws every mark by the angle difference modulo 360, so the tape has no ends and no seam. Firmware requirements:
// - Move the shown heading toward each new GPS bearing along the shorter way round (delta = (new - shown + 540) % 360 - 180).
// - Ease toward the bearing every frame (time constant about 0.8 s), so the tape glides between 1 Hz fixes and never steps.
// - At 5 mph and under the GPS bearing is noise: hold the last heading and dim the tape (HOLD_MPH). Do not jump on restart:
//   the first fixes ease in like any other.
// ?turn=1 runs a live demo: a steady turn through north with 1 Hz fixes and GPS noise.
const HDG = { w: 300, pxPerDeg: 2.5, x: 176, top: 20 }, HOLD_MPH = 5;
const PTS = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
function tapeSvg(h) {
  const cx = HDG.w / 2, span = HDG.w / 2 / HDG.pxPerDeg;
  let g = "";
  for (let a = 0; a < 360; a += 15) {
    const d = ((a - h + 540) % 360) - 180;
    if (Math.abs(d) > span) continue;
    const x = (cx + d * HDG.pxPerDeg).toFixed(1);
    if (a % 45) g += `<line x1="${x}" y1="36" x2="${x}" y2="42" stroke="#4a525c" stroke-width="2"/>`;
    else g += `<text x="${x}" y="28" class="${a % 90 ? "ic" : "card"}">${PTS[a / 45]}</text><line x1="${x}" y1="34" x2="${x}" y2="44" stroke="#8a929c" stroke-width="2"/>`;
  }
  return g + `<path d="M${cx} 48l-6 8h12Z" fill="#c9d1da"/>`;
}
const compass = s => `<div class="abs hdgtape${s.speed <= HOLD_MPH ? " held" : ""}" style="left:${HDG.x}px;top:${HDG.top}px;width:${HDG.w}px"
  data-field="gpsBearing (degrees): shorter-way easing between fixes; held and dimmed at ${HOLD_MPH} mph and under">
  <svg width="${HDG.w}" height="58" viewBox="0 0 ${HDG.w} 58">${tapeSvg(s.heading)}</svg></div>`;
// Live demo of the firmware behaviour: the truck turns at 12 degrees per second through north; a GPS fix with up to 4 degrees
// of noise arrives each second; the shown heading eases toward the latest fix along the shorter way round.
function turnDemo(s) {
  const svg = document.querySelector(".hdgtape svg");
  let truth = 300, fix = truth, shown = truth, last = performance.now(), nextFix = 0;
  const step = now => {
    const dt = (now - last) / 1000; last = now;
    truth = (truth + 12 * dt) % 360;
    if (now >= nextFix) { fix = (truth + (Math.random() - .5) * 8 + 360) % 360; nextFix = now + 1000; }
    shown = (shown + (((fix - shown + 540) % 360) - 180) * (1 - Math.exp(-dt / .8)) + 360) % 360;
    svg.innerHTML = tapeSvg(shown);
    requestAnimationFrame(step);
  };
  requestAnimationFrame(step);
}
const altitude = s => `<div class="abs tb alt" data-field="getAltitude(): GPS altitude with a fix, otherwise mAltitude (barometer); metres, shown in feet">${s.altFt.toLocaleString("en-US")}<small>ft</small></div>`;

// Clock. The cluster clock is the MCU clock (message 0x32), and the MCU clock stops when the relay cuts power. The firmware sets
// the clock from GPS time (UTC in the RMC sentence) with the time zone and daylight saving time, then writes the clock to the
// MCU (setRtc). Until the first GPS time after power-up, the clock shows dashes: a wrong time is worse than no time.
// After a time zone change, the zone shows beside the time for 10 seconds, so a clock that moves by an hour has a reason.
// ?clock=wait|zone overrides the clock state for any scene.
function clockState(s) {
  const st = params.get("clock") || s.clock;
  if (!st) return;
  const el = document.querySelector('.tb[data-field="native RTC clock"]');
  el.dataset.field = "MCU clock (0x32 rtcInfoNotify), set from GPS UTC (RMC) with the time zone and DST";
  // No GPS yet after power-up: no heading either, so the tape dims as when held.
  if (st === "wait") { el.innerHTML = `<span class="clkwait">--:--</span>`; document.querySelector(".hdgtape").classList.add("held"); }
  if (st === "zone") el.innerHTML = `9:42<small class="zone">CT</small>`;
}
