// Round 14 kit: fewer numbers. Loads after round-13/kit13.js.
// Secondary readings show a number only when the reading needs attention. At rest the bars, bands, and symbols carry the state.
// Temperature bars: the value appears over a warm, hot, cold, or missing reading. The empty slot keeps the bars from moving.
const tBarsQuiet = (s, keys = ["trans", "coolant", "oil", "diff"]) => `<div class="abs tbars">${keys.map(k => { const T = s.T[k];
  return `<div class="tb13 temp ${T.state}" data-field="${T.field}">${T.state === "normal" ? `<span class="rv slot"></span>` : deg(T)}${tempCol(T, 100)}${tSym(T, 42)}</div>`; }).join("")}</div>`;
// Tire diagram: hidden while every tire is normal. A low tire brings back the diagram with the low pressure only.
const tiresLow = (s, h, at) => s.low < 0 ? "" : `<div class="abs tp" style="${at}">${[0, 1, 2, 3].map(i => `<span class="rv${i === s.low ? " low" : ""}" data-field="mTpmsPressure ${["LF", "RF", "LR", "RR"][i]}">${i === s.low ? s.tires[i] : ""}</span>`)
  .reduce((a, c, i) => a + c + (i === 0 ? `<img src="${TRUCK_TOP}" style="height:${h}px" alt="">` : ""), "")}</div>`;
// Engine corner: the tach and turbo symbols name the RPM band and the boost band. No RPM or boost number.
const engineMarks = at => `<div class="abs emarks" style="${at}" data-field="tacho rpm · boost">${sym("tach", 44)}${sym("turbo", 34)}</div>`;
