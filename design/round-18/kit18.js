// Round 18 kit: visual balance. Loads after round-17/kit17.js.
// The paged panel moves to the center line under the hero row, and the temperature bars gain weight to answer the speed.
// Every layout uses the same rows: hero row (speed, gear, temperatures) from y 186 to 396, panel from y 440 to 600,
// then the corners and the fuel line.
const PANEL_C = "left:610px;top:440px;width:700px;height:160px";
// Temperature bars for a chosen set of readings. all: true shows every value; otherwise only values that leave normal.
const tBarsK = (s, keys, all, at) => `<div class="abs tbars" style="${at}">${keys.map(k => { const T = s.T[k], show = all || T.state !== "normal";
  return `<div class="tb13 temp ${T.state}" data-field="${T.field}">${show ? deg(T) : `<span class="rv slot"></span>`}${tempCol(T, 100)}${tSym(T, 42)}</div>`; }).join("")}</div>`;
