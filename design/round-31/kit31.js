// Round 31 kit: the gear grows in reverse. Loads after round-30/kit30.js.
//
// User direction (2026-10-30): the gear and the drive mode stay small in the bottom-right corner (round 30 B), with dynamic
// sizing: in reverse the gear moves to the center, large, under MPH (where the cruise readout sits; cruise is off in
// reverse). The drive mode chip stays in the corner. Every other gear stays small in the corner.
const REVERSE_SIZE = 96;
const finish30 = finish;
finish = function (s) {
  finish30(s);
  if (s.gear !== "R") return;
  const g = document.querySelector(".drv30 .gear4");
  g.style.fontSize = `${REVERSE_SIZE}px`;
  g.classList.add("rev31");
  document.querySelector(".row25").replaceChildren(g);
};
