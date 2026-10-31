// Round 42 kit: the final layout set on the locked system. Loads after round-40/kit40.js (round-41/kit41.js, the motion
// player, loads after this kit on tow-motion.html).
//
// User direction (2026-10-31): lock the card page slide (round 41 A) and finalize the remaining layouts.
// Every layout keeps the locked Towing A system: the top bar (round 25 side: clock stack left with the odometer, compass,
// warning lights right), the steering arc, MPH under the digits with both cruise cues, the bottom-right fuel corner with the
// gear, drive mode, and range rows (round 40 grid), the paged card with the slide, and the round 41 motion tokens.
// User direction (2026-10-30): boost and rpm stay on at all speeds. The round 34 crawl hide no longer applies.
// Daily content: no TOW label, trailer page, or trailer brake. Card pages: trip, economy, tires, engine, level.
// - Daily A, ?opt=a|b. A: the speed and rpm crescents (round 24) take the sides in place of the cards; the paged card takes
//   the bottom center in place of the speed bar. B: the Towing A frame with daily content.
// - Daily B, ?opt=a|b. A: the rpm halo (round 24) rings the digits in place of the steering arc; the Towing A cards and speed
//   bar stay. B: the Towing A frame with daily content (the same page as Daily A option B).
// Picks (2026-10-31): Daily A option A is locked; Daily B is dropped (both options are the Towing A frame). The final set is
// Towing A and Daily A. The other options stay here as the round record.
// - Option A on both layouts moves rpm out of the bottom-left corner, so instant economy takes that corner (round 9); boost
//   stays on the engine page.
const OPT = params.get("opt") === "b" ? "b" : "a";
const DAILY = LAYOUT !== "tow";
const ECON = DAILY && OPT === "a";
const CRESCENTS = ECON && LAYOUT === "daily-a", HALO = ECON && LAYOUT === "daily-b";

Object.assign(BASE.daily, { boost: -4, grade: 1, steer: 0, roll: 1, heading: 48, altFt: 1840, oilp: 58, iat: 30,
  temps: { trans: 82, coolant: 96, cht: 98, oil: 104 }, pages: ["trip", "economy", "tires", "engine", "level"] });
SEC.economy = s => `<div class="cells">${scell("now", s.mpgNow, "mpg", "instant mpg")}${scell("avg", s.avg, "mpg", "mAvgFuel")}</div>`;
PAGE_SYM.economy = "avg";
PAGE_SYM.level = "level";

// Bottom-left corner on option A: the instant economy band in the rpm band place, quiet grey (a secondary gauge, round 8),
// with one number on the bottom row of the round 40 grid, level with the range.
const econBand = s => band2({ x1: CORNER_X1, n: 20, value: s.mpgNow / 30, field: "instant mpg" });
const econNum = s => `<div class="abs num34 a econ42" style="left:40px;top:${ROWS40.top + ROWS40.row}px"><span class="n34" data-field="instant mpg"><b>${s.mpgNow}</b><i>mpg</i></span></div>`;

const finish41 = finish;
finish = function (s) {
  finish41(s);
  if (!ECON) {
    if (crawl(s)) place(stack34(s));
    return;
  }
  if (CRESCENTS) {
    // The crescent scale labels fill the sides above y 230, so both top stacks move in to x 400 (round 24 Daily A).
    document.querySelector(".stack23.left").style.left = "400px";
    document.querySelector(".stack23.right").style.right = "400px";
    // Reverse: the large R takes the bottom center under MPH, so the card steps aside (the speed bar place on Towing A).
    if (s.gear === "R") document.querySelector(".card.wide42").remove();
  }
  document.querySelector(".num34.a:not(.fuel38)")?.remove();
  for (const e of document.querySelectorAll(".csym")) if (!e.classList.contains("state")) e.remove();
  place(econNum(s) + `<div class="abs csym" style="left:${CORNER_SYM[0][2] - 22}px;top:${CORNER_SYM[0][3] - 22}px" data-field="instant mpg">${sym("now", 44)}</div>`);
};

// Option A on Daily A: the paged card at bottom center, values in one row; coolant and oil read beside the crescents (round 24).
const WIDE42 = "left:640px;top:536px;width:640px;height:176px";
const crescentTemps = s => ["coolant", "oil"].map((k, i) => { const T = s.T[k];
  return `<div class="abs tread temp ${T.state}" style="${i ? "right" : "left"}:400px">${i ? tempText(T) + tIcon(T) : tIcon(T) + tempText(T)}</div>`; }).join("");
// Option A on Daily B: the rpm halo around the digits, open at the bottom over MPH.
const HALO42 = { cy: 400, r: 226 };

// One draw for every layout: Towing A, and both options of Daily A and Daily B.
function draw42(s) {
  const F = focusOf(s), allT = F === "temps" || F === "warmup";
  if (params.has("cruise")) s.cruise = params.get("cruise");
  document.body.classList.add(`focus-${F}`, `opt42-${DAILY ? OPT : "tow"}`);
  frame(s);
  if (HALO) halo(s, { cy: HALO42.cy, r: HALO42.r, fuel: false }); else steerArc(s);
  if (!CRESCENTS) speedRail(s);
  layer((CRESCENTS ? crescents(s, { a0: 252, t: [252, 296] }) : "") + (ECON ? econBand(s) :
    band({ x1: CORNER_X1, n: 20, value: s.rpm / TACHO_MAX, redFrom: REDLINE / TACHO_MAX, field: "tacho rpm" }) +
    band2({ x1: CORNER_X1, n: 24, len: 14, w: 6, from: boostAt(0), value: boostAt(s.boost), color: boostTint(s), mark: boostAt(0), field: BOOST_FIELD }, 1)) +
    fuelCorner(s));
  place(`
    ${compass(s)}${altitude(s)}
    <div class="abs big speed" data-field="speed">${digits(s.speed)}</div>
    <div class="abs sunit" data-field="speed unit (vehicleSpeedUnit)">MPH</div>
    <div class="abs gblk">${gear(s, GEAR_SIZE)}<div class="drow">${driveChip(s)}</div></div>
    <div class="abs row25"></div>
    ${CRESCENTS ? crescentTemps(s) + secPanel(s, F, WIDE42).replace('class="abs card sec', 'class="abs card sec wide42') : tempCard33(s, allT) + panelCard(s, F)}
    ${engineMarks("left:48px;top:640px")}
    ${fuelMark(s)}${rangeNum(s)}
  `);
  clockState(s);
  if (params.has("turn")) turnDemo(s);
  finish(s);
}
