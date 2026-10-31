// Round 34 kit: rpm and boost numbers by the bottom-left bands. Loads after round-33/kit33.js.
//
// User direction (2026-10-30): show boost psi and rpm as numbers near the bottom-left bands.
// - ?num=a|b. A: a two-row stack in the corner, above the band ends: boost on top (the inner band), rpm below (the outer
//   band), the same order as the bands and the symbols. B: one row in the open space above the middle of the bands.
// - rpm turns red from REDLINE. Boost shows vacuum as a negative number in the vacuum grey and boost in white.
// - Boost unit and scale come from the menu-v7 truck log (vacuumBoost); the mock keeps psi.
const NUM = params.get("num") === "b" ? "b" : "a";
const stale33 = SCENES.stale;
SCENES.stale = s => Object.assign(stale33(s), { boost: null });
SCENES.pull = s => Object.assign(s, { speed: 47, gearNum: 2, rpm: 6100, grade: 3, boost: 18 });

const rpmCls = s => s.rpm >= REDLINE ? " hot" : "";
const boostCls = s => s.boost == null ? " nodata" : s.boost < 0 ? " vac" : "";
const rpmNum = s => `<span class="n34${rpmCls(s)}" data-field="tacho rpm"><b>${s.rpm.toLocaleString("en-US")}</b><i>rpm</i></span>`;
const boostNum = s => `<span class="n34${boostCls(s)}" data-field="${BOOST_FIELD}"><b>${boostText(s)}</b><i>psi</i></span>`;

const finish33 = finish;
finish = function (s) {
  finish33(s);
  if (crawl(s)) return;
  place(NUM === "a"
    ? `<div class="abs num34 a" style="left:40px;top:690px">${boostNum(s)}${rpmNum(s)}</div>`
    : `<div class="abs num34 b" style="left:${CARD.l}px;top:620px">${rpmNum(s)}${boostNum(s)}</div>`);
};
