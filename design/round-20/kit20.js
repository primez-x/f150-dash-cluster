// Round 20 kit: steering angle, vehicle attitude (pitch and roll), and compass heading on the locked Towing A
// (round 19 A, ruler). Loads after round-19/kit19.js.
//
// Firmware fields (capture-04 etc/common). None of these is verified on the truck yet.
// - Steering: angle, from MCU message 0x26 trackInfoNotify (the reverse camera guide lines): angle = -getTrackAngel().
//   getAngle() = angle x 45 / 128 degrees, so full scale is 45 degrees each way. Sign assumed: positive = right.
//   angle has no "no data" value, so a missing message reads as straight ahead. The MCU may send 0x26 only in reverse;
//   the crawl state needs 0x26 in every gear.
// - Pitch and roll: mPitch and mRoll from the motion sensor inside the cluster (gyroVendor LIS), zeroed on level ground
//   (mGyroCalibration). 0xFFFF = no data: show "--". Roll sign assumed: positive = right side down.
// - Heading: gpsBearing and getCompassDir() (8 points). The firmware updates the bearing only above 5 (vehicleSpeed > 5).
//
// The motion sensor reads acceleration as tilt: hard braking reads as a descent, and a fast corner reads as roll. So roll and
// the tilt focus show only at crawl speed (CRAWL_MPH and under) or in reverse. Above crawl speed the engine page keeps the
// grade for load, as before. The firmware must hold the tilt focus for a few seconds (hysteresis), as for the grade.
Object.assign(BASE.tow, { steer: 0, roll: 1, heading: "NE" });
SCENES.crawl = s => Object.assign(s, { speed: 3, gearNum: 1, rpm: 900, boost: -8, grade: 3, roll: 4, steer: -22 });
SCENES.backing = s => Object.assign(s, { speed: 2, gear: "R", gearNum: "", rpm: 800, boost: -8, grade: -1, roll: 2, steer: 18 });
SCENES.tilt = s => Object.assign(s, { speed: 4, gearNum: 1, rpm: 1000, boost: -6, grade: 5, roll: 13, steer: 8 });
SCENES.tilthot = s => Object.assign(SCENES.tilt(s), { roll: -21, steer: -6 });
// A hot transmission outranks the tilt focus: the level page stays off screen and shows an amber symbol beside the dots.
SCENES.tiltstack = s => SCENES.tilt(SCENES.hottrans(s));

const CRAWL_MPH = 8, TILT = { warn: 10, hot: 20 };   // design values, to tune on the truck
const crawl = s => s.speed <= CRAWL_MPH || s.gear === "R";
const tiltState = s => !crawl(s) ? "" : Math.abs(s.roll) >= TILT.hot ? "hot" : Math.abs(s.roll) >= TILT.warn ? "warm" : "";
FOCUS.splice(FOCUS.findIndex(([k]) => k === "tires") + 1, 0, ["tilt", s => !!tiltState(s)]);   // mRoll, crawl only

// Level page: grade and roll, from the motion sensor. At crawl speed the level page takes the place of the engine page, and
// the climb, descent, and tilt focus jump to the level page.
SYM.roll = `<g transform="rotate(14 27 30)"><path d="M17 19l3-7h14l3 7"/><rect x="8" y="19" width="38" height="13" rx="3"/><path d="M13 32v7M41 32v7M3 44h48"/></g>`;
PAGE_SYM.level = "roll";
PAGE_STATE.level = tiltState;
function applyCrawl(s) {
  if (!crawl(s)) return;
  s.pages = s.pages.map(p => p === "engine" ? "level" : p);
  Object.assign(SEC_FOCUS, { climb: "level", descent: "level", tilt: "level" });
}
const ROLL_FIELD = "mRoll getRollString() · cluster motion sensor, crawl only";
const rollText = r => Math.abs(r);
const rollSym = (s, h) => sym("roll", h, s.roll < 0 ? "flip" : "");

// Option A: numbers, as on every other page. The roll symbol leans to the low side.
const levelCells = s => `<div class="cells">` +
  `<span class="icell" data-field="mPitch (grade = tan pitch)">${gradeSym(s, 36)}<span class="rv">${gradeText(s.grade)}<span class="u">%</span></span></span>` +
  `<span class="icell ${tiltState(s)}" data-field="${ROLL_FIELD}">${rollSym(s, 36)}<span class="rv">${rollText(s.roll)}<span class="u">°</span></span></span></div>`;

// Option B: two truck outlines at the true angle over a dashed level line, a side view for the grade and a rear view for the roll.
const TRUCK_SIDE = `<path d="M6 44V26H50V8H76L88 24L110 26Q113 27 113 30V44Z"/><circle cx="26" cy="46" r="8" fill="#14191f"/><circle cx="92" cy="46" r="8" fill="#14191f"/>`;
const TRUCK_REAR = `<path d="M30 22l6-12h28l6 12"/><rect x="16" y="22" width="68" height="20" rx="4"/><rect x="22" y="42" width="12" height="12" rx="3"/><rect x="66" y="42" width="12" height="12" rx="3"/>`;
const tiltArt = (body, w, a) => `<svg class="tart" width="${w}" height="76" viewBox="0 0 ${w} 76">` +
  `<path d="M-10 56H${w + 10}" stroke="#4a525c" stroke-width="2" stroke-dasharray="5 7"/>` +
  `<g transform="rotate(${a.toFixed(1)} ${w / 2} 56)" fill="none" stroke="currentColor" stroke-width="4" stroke-linejoin="round">${body}</g></svg>`;
const levelArt = s => `<div class="cells">` +
  `<span class="icell art" data-field="mPitch (grade = tan pitch)">${tiltArt(TRUCK_SIDE, 120, -Math.atan(s.grade / 100) * 180 / Math.PI)}` +
  `<span class="rv">${gradeText(s.grade)}<span class="u">%</span></span></span>` +
  `<span class="icell art ${tiltState(s)}" data-field="${ROLL_FIELD}">${tiltArt(TRUCK_REAR, 100, s.roll)}<span class="rv">${rollText(s.roll)}<span class="u">°</span></span></span></div>`;
SEC.level = levelCells;

// Steering bar: at crawl speed the speed scale carries nothing, so the bar under the speed digits shows the steering angle.
// The fill runs from the center line to the angle; a tall tick marks straight ahead. The knob is a tire seen from above, turned
// by the steering angle. No number: the bar answers "where do the wheels point".
const STEER_MAX = 45;
const steerX = a => 960 + (SCALE.x1 - 960) * Math.max(-1, Math.min(1, a / STEER_MAX));
function steerBar(s, y = 362) {
  const x = steerX(s.steer), r = `stroke-linecap="round"`;
  let g = `<g data-field="angle getAngle() · MCU 0x26 trackInfoNotify, unverified on the truck">` +
    line(SCALE.x0, y, SCALE.x1, y, "#1d252e", 6, r) + line(960, y, x, y, ACC, 6, r);
  for (let a = -40; a <= 40; a += 10) g += line(steerX(a), y + 12, steerX(a), y + (a ? 20 : 32), a ? "#4a525c" : "#8a929c", a ? 2 : 3);
  g += `<rect x="${(x - 8).toFixed(1)}" y="${y - 17}" width="16" height="34" rx="6" fill="${ACC}" stroke="#05070a" stroke-width="3" transform="rotate(${s.steer} ${x.toFixed(1)} ${y})"/>`;
  layer(g + `</g>`);
}

// Compass: the heading in letters beside the clock, in the quiet grey. Hidden at 5 mph and under, where the firmware stops
// updating the bearing.
const compass = s => s.speed > 5 ? `<div class="abs tb hdg" data-field="gpsBearing getCompassDir()">${s.heading}</div>` : "";
