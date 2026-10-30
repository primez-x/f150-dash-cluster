// Round 15 kit: conditional focus. Loads after round-14/kit14.js.
// One rule picks the reading that matters most right now (the focus). The focus shows numbers and size; everything else stays
// quiet. Speed, gear, both corner bands, and the fuel line never move or resize.

// Calm towing: flat road at highway speed. Every other scene starts from this state.
Object.assign(BASE.tow, { grade: 1, boost: 3, rpm: 2100 });
// Climb: steep grade under load, transmission warm but below the warning line. Descent: steep downgrade on engine braking.
// Stack: live trailer braking during a hot transmission, to show which focus wins.
SCENES.climb = s => Object.assign(s, { speed: 52, gearNum: 3, rpm: 3400, grade: 8, boost: 15, temps: { ...s.temps, trans: 104, coolant: 104 } });
SCENES.descent = s => Object.assign(s, { speed: 52, gearNum: 3, rpm: 2800, grade: -7, boost: -9, temps: { ...s.temps, trans: 100 } });
SCENES.stack = s => Object.assign(SCENES.hottrans(s), { braking: true, output: 4, speed: 46 });

// Focus priority, highest first. The thresholds for climb and descent are design values.
// The firmware must hold a focus for a few seconds (hysteresis), so a grade near 4 % does not switch the screen back and forth.
const anyT = (s, st) => Object.values(s.T).some(T => T.state === st);
const FOCUS = [
  ["temps", s => anyT(s, "hot")],             // waterTemp gearBoxTemp oilTemp diffOilTemp
  ["tires", s => s.low >= 0],                 // mTpmsPressure
  ["fuel", s => fuelLight(s)],                // alarmTable[151] low-fuel light
  ["brake", s => !!s.braking],                // trucksTrailerBrakeState (JLY 0x1A)
  ["fuel", s => fuelLow(s)],                  // DTE at or under LOW_RANGE miles
  ["temps", s => anyT(s, "warm")],
  ["climb", s => s.grade >= 4 || s.boost >= 10], // mPitch; turbo / boostPercentage (JLY 0x40)
  ["descent", s => s.grade <= -4],            // mPitch
  ["warmup", s => anyT(s, "cold")],
];
const focusOf = s => (FOCUS.find(([, on]) => on(s)) || ["calm"])[0];

// Tire symbol (tread view) for the status strip. The stock icon set has none.
SYM.tire = `<rect x="15" y="5" width="24" height="44" rx="8"/><path d="M15 17h7M15 27h7M15 37h7M39 17h-7M39 27h-7M39 37h-7"/>`;
const gradeText = g => g > 0 ? `+${g}` : g < 0 ? `−${-g}` : "0";
const gradeSym = (s, h) => sym("grade", h, s.grade < 0 ? "flip" : "");

// Large symbol and value pair, the building block of every focus module. Values stay at or under the 80 px corner tier.
const big = (symHtml, v, u, f, cls = "") => `<div class="bigsv ${cls}" data-field="${f}">${symHtml}<span class="rv">${v}${u ? `<span class="u">${u}</span>` : ""}</span></div>`;
const tempBig = T => big(tSym(T, 52), T.f + (T.state === "nodata" ? "" : `<span class="dg">°</span>`), "", T.field, `temp ${T.state}`);

// Temperature bars with a chosen height. all: true shows every value; otherwise only values that leave normal.
const tBarsH = (s, h, all, dimNormal = false, at = "") => `<div class="abs tbars" style="${at}">${["trans", "coolant", "oil", "diff"].map(k => { const T = s.T[k];
  const show = all || T.state !== "normal";
  return `<div class="tb13 temp ${T.state}${dimNormal && T.state === "normal" ? " dim" : ""}" data-field="${T.field}">${show ? deg(T) : `<span class="rv slot"></span>`}${tempCol(T, h)}${tSym(T, 42)}</div>`; }).join("")}</div>`;

// Trailer brake meter: live output in the accent colour, the gain as a white marker on the same scale (0 to 10).
const brakeMeter = (s, at) => `<div class="abs bmeter" style="${at}" data-field="trailer brake output · trucksTrailerGain">
  <i class="fill" style="width:${(s.braking ? s.output : 0) * 10}%"></i><i class="gain" style="left:${s.gain * 10}%"></i></div>`;
