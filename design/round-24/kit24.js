// Round 24 kit: wider spacing and the odometer in a top corner. Loads after round-23/kit23.js.
//
// User direction (2026-10-30): use more of the screen width for better spacing; put the odometer in a top corner, quiet,
// because the odometer is not a driving reading.
// - Side stacks move out to x 200 (left) and x 1720 (right), from y 92 (the arch plus the margin reaches y 87 at x 200; the
//   wheel rim corner ends 45 px away). Daily A keeps x 400 and y 62: the crescent scale labels fill the sides below y 100.
// - Towing A, ?spread=a|b: A moves the temperature bar pairs out to x 120 to 350 and x 1570 to 1800. B does the same and
//   grows the speed digits from 210 to 250 px, with a wider speed scale; the gear and cruise keep 119 px from the digits.
// - Odometer: in the top corner on the clock stack side, at 55 % strength. From the driver eye the wheel rim hides this
//   corner while driving (the rim reaches y 153 at x 1880); the odometer shows when parked or with the wheel turned.
//   The corner sits below the arch plus the 20 px margin (y 121 at x 1900), so the margin check skips only the rim for the odometer.
const LAYOUT = location.pathname.match(/(daily-a|daily-b|tow)/)[1];
const SPREAD = LAYOUT === "tow" ? (params.get("spread") === "b" ? "b" : "a") : "";
if (LAYOUT !== "daily-a") Object.assign(STACK, { outer: 200, top: 92 });
if (SPREAD === "b") Object.assign(SCALE, { x0: 680, x1: 1240 });
const ODO_FIELD = "odo getOdo() (MCU odometer), in the distance unit setting";

const frame23 = frame;
frame = function (s, opts) {
  frame23(s, opts);
  if (SPREAD) document.body.classList.add(`spread-${SPREAD}`);
  const side = SIDE === "a" ? "right" : "left";
  place(`<div class="abs odo24 rimok ${side}" style="${side}:20px;top:122px" data-field="${ODO_FIELD}"><span class="k">ODO</span><span>48,213<small>mi</small></span></div>`);
};

const finish23 = finish;
finish = function (s) {
  if (SPREAD) for (const b of document.querySelectorAll(".tbars")) b.style.left = parseFloat(b.style.left) < 960 ? "120px" : "1570px";
  finish23(s);
};

// Margin check: the odometer may sit behind the wheel rim (by design), but not in the arch, the shroud, or the screen margin.
const shroudViolations22 = shroudViolations;
shroudViolations = function () {
  const ok = [...document.querySelectorAll(".rimok")];
  ok.forEach(e => e.style.visibility = "hidden");
  const out = shroudViolations22();
  ok.forEach(e => e.style.visibility = "");
  const rims = { rimLeft: MASK.rimLeft, rimRight: MASK.rimRight };
  delete MASK.rimLeft; delete MASK.rimRight;
  const own = shroudViolations22().filter(v => v.includes(ODO_FIELD.slice(0, 40)));
  Object.assign(MASK, rims);
  return [...out, ...own];
};
