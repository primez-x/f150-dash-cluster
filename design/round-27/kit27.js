// Round 27 kit: the left card holds the transmission, coolant, and oil temperatures and the oil pressure. Loads after round-26/kit26.js.
//
// User direction (2026-10-30): the truck has no differential temperature; the card needs the coolant, engine oil, and
// transmission temperatures, and the oil pressure.
// - The differential column goes. The oil pressure column takes the place, beside the oil temperature.
// - Oil pressure: oilPressurePercentage from getOilPressure() (vehicleInfoNotify), the value that the stock Ford oil meter
//   draws as a 0 to 100 % bar (ui1 bar width = percentage x 2). 0xFF means not available: the firmware hides the reading.
//   The value is a gauge position, not psi, so the column shows a bar only. A low reading turns the column red and shows LOW.
// - OILP_LOW (20 %) is a design value until checked against the truck. Truck readings for all four columns are unverified.
const OILP_LOW = 20;
Object.assign(CARD, { bar: 190 });
const OILP_FIELD = "oilPressurePercentage getOilPressure() (stock oil meter %, 0xFF hidden)";
delete BASE.tow.temps.diff;
BASE.tow.oilp = 62;
const hottrans4 = SCENES.hottrans;
SCENES.hottrans = s => { hottrans4(s); delete s.temps.diff; return s; };
const stale4 = SCENES.stale;
SCENES.stale = s => Object.assign(stale4(s), { oilp: null });
SCENES.lowoil = s => Object.assign(s, { oilp: 8, speed: 52, rpm: 1700,
  alert: ["warn", ICON("oil"), "OIL PRESSURE LOW", "stop safely and switch the engine off"] });

const oilpState = s => s.oilp == null ? "nodata" : s.oilp < OILP_LOW ? "hot" : "normal";
const oilpCol = (s, h) => {
  const st = oilpState(s), zone = `linear-gradient(0deg, rgba(255, 59, 48, ${ZONE_TINT.hot}) 0 ${OILP_LOW}%, rgba(255, 255, 255, .05) ${OILP_LOW}% 100%)`;
  const v = st === "hot" ? `<span class="rv">LOW</span>` : st === "nodata" ? `<span class="rv">--</span>` : `<span class="rv slot"></span>`;
  return `<div class="tb13 temp ${st}" data-field="${OILP_FIELD}">${v}<div class="zcol" style="height:${h}px;background:${zone}"><i style="height:${s.oilp || 0}%"></i></div>${sym("oil", 42)}</div>`;
};

// Temperature card (kit25) with oil pressure in the fourth column.
const tempCard27 = (s, all) => `<div class="abs card t25" style="left:${CARD.l}px;top:${CARD.top}px;width:${CARD.w}px;height:${CARD.h}px">` +
  ["trans", "coolant", "oil"].map(k => { const T = s.T[k], show = all || T.state !== "normal";
    return `<div class="tb13 temp ${T.state}" data-field="${T.field}">${show ? deg(T) : `<span class="rv slot"></span>`}${tempCol(T, CARD.bar)}${tSym(T, 42)}</div>`; }).join("") +
  oilpCol(s, CARD.bar) + `</div>`;

// Low oil pressure takes the red glow, as a hot temperature does.
const frame26 = frame;
frame = function (s, opts) {
  frame26(s, opts);
  if (oilpState(s) === "hot") document.body.classList.add("glow-hot");
};
