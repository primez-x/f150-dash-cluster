// Round 23 kit: side stacks, a center compass, and cruise beside the speed. Loads after round-22/kit22.js (and round-20/kit20.js,
// which draws the heading tape; the daily pages load kit20 for the tape only).
//
// User direction (2026-10-30): the warning lights stack on one side, the clock, date, and outside temperature stack on the
// other side, and the compass sits top center. Cruise moves left of the speed digits, as far from the digits as the gear is
// on the right. ?side=a|b picks the side:
// A · Warning lights left, clock stack right.
// B · Clock stack left, warning lights right.
// Each stack hangs from y 62 between x 400 and 700 (or x 1220 and 1520): the arch plus the 20 px margin reaches y 60 at x 380 and x 1540.
// The stacks align to the outer edge, so a short stack (one telltale, or the clock alone) sits at the same place every time.
const SIDE = params.get("side") === "b" ? "b" : "a";
const STACK = { outer: 400, top: 62, width: 300 };
// Heading tape: 300 px, centered, top 20 (the tape letters start 6 px down; the arch plus the margin reaches y 26 at x 810).
Object.assign(HDG, { x: 810, top: 20, w: 300 });
BASE.daily.heading ??= 48;
// Date: rtcDate from the MCU clock (message 0x32 rtcInfoNotify: getRtc() "date time", the date part). Shown as "Thu, Oct 30".
const DATE_FIELD = "rtcDate (MCU clock 0x32 rtcInfoNotify, date part of getRtc()), set from GPS UTC with the time zone";

const frame22 = frame;
frame = function (s, opts) {
  frame22(s, opts);
  const near = SIDE === "a" ? "right" : "left", far = SIDE === "a" ? "left" : "right";
  const clock = document.querySelector('.tb[data-field="native RTC clock"]'), temp = document.querySelector('.tb[data-field^="outSideTemp"]');
  place(`<div class="abs stack23 info ${near}" style="${near}:${STACK.outer}px;top:${STACK.top}px;width:${STACK.width}px">
    <div class="tb">${clock.innerHTML}</div><div class="date23" data-field="${DATE_FIELD}">Thu, Oct 30</div>
    <div class="row23"><div class="tb">${temp.innerHTML}</div></div></div>`);
  const stack = document.querySelector(".stack23.info");
  stack.children[0].dataset.field = clock.dataset.field;
  stack.querySelector(".row23 .tb").dataset.field = temp.dataset.field;
  clock.remove(); temp.remove();
  const tt = document.querySelector(".telltales");
  tt.classList.add("stack23", far);
  tt.style.cssText = `${far}:${STACK.outer}px;top:${STACK.top}px;width:${STACK.width}px`;
  if (s.mode === "daily") place(compass(s));
};

// Cruise: left of the speed digits, the same distance from the digits as the gear block on the right (Towing A: 119 px), level
// with the gear. Daily A has the gear under the digits, so cruise takes the Towing A distance and the gear height (44 px under
// the digit box top). Daily B rings the digits with the speed arc and puts the gear above the digits, so cruise sits left of
// the gear row, 50 px outside the arc (the arc reaches x 740 at the gear height), clear of the temperature list.
// On every layout the readout shows the symbol and the set speed only, as on the locked Towing A (round 19): the MPH label sits beside.
const CRUISE_GAP = 119, DAILY_B_CRUISE_RIGHT = 690;
const finish22 = finish;
finish = function (s) {
  const alt = document.querySelector(".alt");
  if (alt) { alt.classList.remove("abs"); alt.removeAttribute("style"); document.querySelector(".stack23.info .row23").append(alt); }
  const box = el => el.getBoundingClientRect(), c = box(document.getElementById("canvas")), k = 1920 / c.width;
  const speed = box(document.querySelector(".speed")), gear = box(document.querySelector(".gear4"));
  const px = (v, o) => (v - o) * k;
  let right, cy;
  if (gear.left > speed.right) {
    right = px(speed.left, c.left) - (px(gear.left, c.left) - px(speed.right, c.left));
    cy = px((gear.top + gear.bottom) / 2, c.top);
  } else if (gear.top > speed.bottom - 20) {
    right = px(speed.left, c.left) - CRUISE_GAP;
    cy = px(speed.top, c.top) + 44 + 30;
  } else {
    right = DAILY_B_CRUISE_RIGHT;
    cy = px((gear.top + gear.bottom) / 2, c.top);
  }
  document.querySelector(".cruise").style.cssText = `left:auto;right:${Math.round(1920 - right)}px;top:${Math.round(cy - 40)}px;width:auto;height:80px;justify-content:flex-end`;
  finish22(s);
};
// Six telltales with cruise set: the fullest the left side gets (telltale stack over the cruise readout in option A).
SCENES.busycruise = s => SCENES.busy(SCENES.cruise(s));
