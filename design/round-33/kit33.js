// Round 33 kit: the engine gauge frame on Towing A. Loads after round-32/kit32.js.
//
// Source (2026-10-30 library audit): JLY command 0x3B (vehicleInfoNotify) carries signed vacuum/boost, cylinder head
// temperature, intake air temperature, oil pressure, oil and transmission temperature, and battery voltage. The truck uses
// the JLY adapter, so the full 0x3B branch runs. Units and scales need the menu-v7 truck log.
// - Boost band: vacuumBoost (15-bit magnitude) with vacuumBoostDir (sign), so the band shows vacuum and boost from one
//   reading. The band keeps the psi scale from round 4 until the log gives the raw unit.
// - Head temperature (cylinderHeadTemp, raw - 60 °C). ?cht=a|b. A: a fifth column in the temperature card, between coolant
//   and oil. B: no column; a warm or hot head temperature raises an alert with the value. Both: a hot head temperature
//   raises the red alert and glow, as a hot transmission does.
// - CHT limits (warm 121 °C, hot 132 °C) are design values until checked against the truck.
// - Engine page: intake air temperature (inletAirTemp, raw - 128 °C) under rpm and boost.
const CHT = params.get("cht") === "b" ? "b" : "a";
const BOOST_FIELD = "vacuumBoost getVacuumBoost() + vacuumBoostDir getVacuumBoostDir() (JLY 0x3B, vehicleInfoNotify); unit and scale from the truck log";
const CHT_FIELD = "cylinderHeadTemp getCylinderHeadTemp() (JLY 0x3B: raw - 60 °C; 0xFE, 0xFF no data)";
const IAT_FIELD = "inletAirTemp getInletAirTemp() (JLY 0x3B: raw - 128 °C; 0xFE, 0xFF no data)";
CORNER_SYM[1][4] = BOOST_FIELD;

// Engine block with a thermometer: the head temperature.
SYM.cht = `<path d="M6 21h7l4-5h16l4 5h5v7h5v11h-5v6H17l-4-5H6Z"/><path d="M27 23v10"/><circle cx="27" cy="35" r="3" fill="#000"/>`;
TEMP.cht = { icon: "cht", label: "HEAD", field: CHT_FIELD, cold: 60, warm: 121, hot: 132, lo: 100, hi: 300 };
COLD.cht = 35;
BASE.tow.temps.cht = 104;
BASE.tow.iat = 38;

const stale27 = SCENES.stale;
SCENES.stale = s => { stale27(s); s.temps.cht = null; s.iat = null; return s; };
SCENES.warmcht = s => Object.assign(s, { speed: 54, gearNum: 4, rpm: 3200, grade: 7, boost: 13, iat: 52, temps: { ...s.temps, cht: 124 } });
SCENES.hotcht = s => Object.assign(s, { speed: 48, gearNum: 3, rpm: 3600, grade: 8, boost: 16, iat: 58, temps: { ...s.temps, cht: 134 },
  alert: ["warn", symSrc("cht"), "ENGINE HEAD TEMP HIGH", `${c2f(134)} °F · reduce load or speed`] });

// Option B: a warm head temperature has no column, so the value comes as a caution alert.
const state32 = state;
state = function (mode) {
  const s = state32(mode);
  if (CHT === "b" && s.T.cht?.state === "warm" && !s.alert)
    s.alert = ["caution", symSrc("cht"), "ENGINE HEAD TEMP", `${s.T.cht.f} °F · watch the load`];
  return s;
};

// Temperature card: option A adds the head temperature column; option B keeps the round 27 card.
const tempCard33 = (s, all) => CHT === "b" ? tempCard27(s, all) :
  `<div class="abs card t25 t33" style="left:${CARD.l}px;top:${CARD.top}px;width:${CARD.w}px;height:${CARD.h}px">` +
  ["trans", "coolant", "cht", "oil"].map(k => { const T = s.T[k], show = all || T.state !== "normal";
    return `<div class="tb13 temp ${T.state}" data-field="${T.field}">${show ? deg(T) : `<span class="rv slot"></span>`}${tempCol(T, CARD.bar)}${tSym(T, 42)}</div>`; }).join("") +
  oilpCol(s, CARD.bar) + `</div>`;

const iatText = s => s.iat == null ? "--" : c2f(s.iat);
SEC.engine = s => `<div class="cells">${scell("tach", s.rpm.toLocaleString("en-US"), "rpm", "tacho rpm")}${scell("turbo", boostText(s), "psi", BOOST_FIELD)}` +
  `${scell("thermo", iatText(s), s.iat == null ? "" : "°F", IAT_FIELD)}</div>`;
