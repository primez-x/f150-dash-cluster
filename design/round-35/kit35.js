// Round 35 kit: the two cards run off the screen edge. Loads after round-34/kit34.js.
//
// User direction (2026-10-30): the cards extend from the screen edge, so they overflow the page; only the visible inner
// edge has the rounded corners. The outer edge has no border and no radius.
// - ?fit=a|b. A: the content keeps the round 33 place, in line with the clock stack (x 150) and the warning lights (x 1770);
//   the card only grows outward. B: the content centers in the visible card, 75 px closer to the screen edge.
// - The inner edges stay at x 530 and x 1390, so the speed area keeps the same room.
// - Round 34 numbers: option A (corner stack) shows until the pick; ?num=b shows option B.
const FIT = params.get("fit") === "b" ? "b" : "a";
const BLEED = CARD.l;

const finish34 = finish;
finish = function (s) {
  finish34(s);
  document.body.classList.add(`fit35-${FIT}`);
  const w = CARD.w + BLEED, l = document.querySelector(".card.t25"), r = document.querySelector(".card.sec.sq");
  if (l) Object.assign(l.style, { left: "0px", width: `${w}px` });
  if (r) Object.assign(r.style, { left: `${CARD.r}px`, width: `${w}px` });
};
