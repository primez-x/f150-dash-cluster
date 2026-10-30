// Round 25 kit: Towing A with two equal cards. Loads after round-24/kit24.js.
//
// User direction (2026-10-30): the four temperatures in one square card on the left, the speed in the center, the paged panel
// in a card of the same size on the right; the warning lights top right and the clock top left; speed numbers under the speed
// scale; cruise and the drive mode under the numbers.
// - Cards: 380 x 364 px at x 150 and x 1390, y 236 to 600. Both cards start under the top stacks (six warning lights end at y 216).
// - Top stacks: outer edge x 150 and x 1770, from y 114 (the arch and the wheel rim plus the margin reach y 112 at x 1770).
//   The clock stack sits left and the warning lights right (round 23 side B); the odometer takes the top-left corner.
// - Speed scale numbers every 20 mph under the scale (hidden at crawl speed, where the steering bar replaces the scale).
// - ?gear=a|b. A: the gear stays beside the digits; the row under the numbers holds cruise and the drive mode.
//   B: the gear joins the row (cruise, gear, drive mode), so the digits stand alone on the center line.
// - ?level=b shows the round 20 option B level page (truck images); the default is option A (numbers).
const GEAR_ROW = params.get("gear") === "b";
const CARD = { w: 380, h: 364, top: 236, l: 150, r: 1390 };
Object.assign(STACK, { outer: 150, top: 114 });
if (params.get("level") === "b") SEC.level = levelArt;

// Temperature card: the four temperature columns of the locked Towing A (values show when a temperature leaves normal, or for
// every temperature during a temperature focus), with taller bars.
const tempCard = (s, all) => `<div class="abs card t25" style="left:${CARD.l}px;top:${CARD.top}px;width:${CARD.w}px;height:${CARD.h}px">` +
  ["trans", "coolant", "oil", "diff"].map(k => { const T = s.T[k], show = all || T.state !== "normal";
    return `<div class="tb13 temp ${T.state}" data-field="${T.field}">${show ? deg(T) : `<span class="rv slot"></span>`}${tempCol(T, 190)}${tSym(T, 42)}</div>`; }).join("") + `</div>`;
const panelCard = (s, F) => secPanel(s, F, `left:${CARD.r}px;top:${CARD.top}px;width:${CARD.w}px;height:${CARD.h}px`).replace('class="abs card sec', 'class="abs card sec sq');

// Speed numbers under the speed scale, with the unit after the last number.
const scaleNumbers = s => crawl(s) ? "" : `<div class="abs snum" data-field="speed scale (vehicleSpeedUnit)">` +
  [0, 20, 40, 60, 80, 100].map(v => `<span style="left:${speedX(v)}px">${v}</span>`).join("") + `<span class="u" style="left:${SCALE.x1 + 44}px">MPH</span></div>`;

// Row under the numbers: cruise, (gear,) drive mode, centered. Cruise keeps the place while off, so the row does not shift.
const finish24 = finish;
finish = function (s) {
  finish24(s);
  const row = document.querySelector(".row25"), cruise = document.querySelector(".cruise");
  cruise.classList.remove("abs"); cruise.removeAttribute("style");
  row.append(cruise);
  if (GEAR_ROW) row.append(document.querySelector(".gblk .gear4"));
  row.append(document.querySelector(".gblk .drow"));
  if (GEAR_ROW) document.querySelector(".gblk").remove();
  cornerIcons(s);
};

// Bottom corners: each symbol sits beside the corner end of the band that the symbol names (user direction, 2026-10-30).
// The bands meet the screen corner at about (153, 869) for rpm and (125, 844) for boost; the trailer brake band mirrors rpm.
// Each symbol sits on the screen-edge side of the band end, inside the 20 px margin. BRAKING moves above the brake symbol.
const CORNER_SYM = [["tach", 44, 100, 884, "tacho rpm"], ["turbo", 34, 84, 828, "boost: no firmware field yet (new vehicle signal needed)"]];
function cornerIcons(s) {
  document.querySelector(".emarks").remove();
  place(CORNER_SYM.map(([n, h, x, y, f]) => `<div class="abs csym" style="left:${x - h / 2}px;top:${y - h / 2}px" data-field="${f}">${sym(n, h)}</div>`).join(""));
  const brake = document.querySelector(".corner.r"), state = brake.querySelector(".state");
  brake.style.cssText = `right:${CORNER_SYM[0][2] - 22}px;top:${CORNER_SYM[0][3] - 22}px`;
  if (state) { state.remove(); place(`<div class="abs csym state" style="right:20px;top:800px">BRAKING</div>`); }
}
