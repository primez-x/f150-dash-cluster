// Round 30 kit: the gear and the drive mode leave the center. Loads after round-28/kit28.js.
//
// User direction (2026-10-30): the gear and the drive mode are too prominent in the middle; both change rarely and are a
// secondary reading, so they move to the side, bottom right.
// - The center keeps the speed bar, the digits, MPH, and the cruise row under MPH.
// - The gear (D with the gear number) and the drive mode chip sit together, smaller: gear 40 px (was 60 px).
//   A drive mode other than 2H keeps the filled chip, and the rear locker keeps the amber chip, so a change still shows.
// - ?side=a|b is taken by round 23 (fixed to b here), so the pick uses ?drv=a|b.
//   A: under the right card, centered on the card, 24 px below the card.
//   B: in the bottom-right corner, right-aligned with the screen margin, above the trailer brake band.
// This replaces the open round 25 gear pick (beside the digits or in the row): neither place stays.
const DRV = params.get("drv") === "b" ? "b" : "a";
const DRV_SIZE = 40;
const finish28 = finish;
finish = function (s) {
  finish28(s);
  const at = DRV === "a" ? `left:${CARD.r + CARD.w / 2}px;top:${CARD.top + CARD.h + 24}px;transform:translateX(-50%)` : "right:40px;top:640px";
  place(`<div class="abs drv30 ${DRV}" style="${at}"></div>`);
  const box = document.querySelector(".drv30"), g = document.querySelector(".gear4");
  g.style.fontSize = `${DRV_SIZE}px`;
  box.append(g, document.querySelector(".drow"));
  document.querySelector(".gblk")?.remove();
};
