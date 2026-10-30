// Round 13 kit: temperature bars in place of the round 12 rings. Loads after round-12/kit12.js.
// Each bar shows the value on top, the vertical zone bar (tempCol), and the symbol under the bar. The four bars span x 1060 to 1720.
const tBars = (s, keys = ["trans", "coolant", "oil", "diff"]) => `<div class="abs tbars">${keys.map(k => { const T = s.T[k];
  return `<div class="tb13 temp ${T.state}" data-field="${T.field}">${deg(T)}${tempCol(T, 100)}${tSym(T, 42)}</div>`; }).join("")}</div>`;
