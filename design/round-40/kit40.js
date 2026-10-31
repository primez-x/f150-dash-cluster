// Round 40 kit: the locked Towing A, with the bottom corner stacks aligned. Loads after round-39/kit39.js.
//
// Locked (user picks, 2026-10-30): round 39 A (continuous speed bar), round 38 C (trailer brake on the trailer page of the
// right card only), round 37 A (MPH under the digits), round 34 A (boost and rpm stack in the bottom-left corner).
//
// User direction: align the left and right corner elements. Measured in round 39: the left stack rows start at y 690 and
// y 734 (40 px type, 4 px gap); the right side had the drive chips at y 640 and the range number at y 700, on neither row.
// The right side now mirrors the left rows at the 40 px line: the drive chips on the boost row, the range number on the rpm
// row. The fuel symbol already mirrors the rpm symbol (centres x 100 and x 1820, y 884).
const ROWS40 = { top: 690, row: 44 };

const finish39 = finish;
finish = function (s) {
  finish39(s);
  document.querySelector(".drv30").style.top = `${ROWS40.top}px`;
  document.querySelector(".num34.fuel38").style.top = `${ROWS40.top + ROWS40.row}px`;
};
