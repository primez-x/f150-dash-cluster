// Round 17 kit: primary readings stay on screen; secondary readings page. Loads after round-16/kit16.js.
// Primary, always on screen: speed, gear, temperatures, both corner bands, and the fuel line.
// Secondary, one page at a time in the paged panel: trailer, tires, engine, trip. The steering wheel left / right keys change
// the page (drivingInfoIndex). A focus (kit15 focusOf) for a secondary reading jumps the panel to that page; a temperature
// focus shows every temperature value in place, because the temperatures are already on screen.
BASE.tow.pages = ["trailer", "tires", "engine", "trip"];
const SEC_FOCUS = { tires: "tires", brake: "trailer", climb: "engine", descent: "engine" };
const secPage = (s, F) => SEC_FOCUS[F] || s.pages[s.page];

const scell = (n, v, u, f, cls = "") => `<span class="icell ${cls}" data-field="${f}">${sym(n, 36)}<span class="rv">${v}<span class="u">${u}</span></span></span>`;
const SEC = {
  trailer: s => `<div class="cells">${scell("trailerBrake", (s.braking ? s.output : s.gain).toFixed(1), s.braking ? `of ${s.gain.toFixed(1)}` : "gain", BRAKE_FIELD, s.braking ? "on" : "")}` +
    `${scell("trailer", s.trailerMi, "mi", "trucksTrailerDistance getTrucksTrailerDistance()")}</div>` +
    `<div class="bmeter" data-field="trailer brake output · trucksTrailerGain"><i class="fill" style="width:${(s.braking ? s.output : 0) * 10}%"></i><i class="gain" style="left:${s.gain * 10}%"></i></div>`,
  tires: s => tires4(s, 132, "").replace('class="abs tp"', 'class="tp"'),
  engine: s => `<div class="cells">${scell("tach", s.rpm.toLocaleString("en-US"), "rpm", "tacho rpm")}${scell("turbo", boostText(s), "psi", "boost: no firmware field yet")}` +
    `<span class="icell" data-field="mPitch (grade = tan pitch)">${gradeSym(s, 36)}<span class="rv">${gradeText(s.grade)}<span class="u">%</span></span></span></div>`,
  trip: s => `<div class="cells">${scell("road", s.trip, "mi", "mTripA")}${scell("clock", "2:41", "h", "RunTimeInfo")}${scell("avg", s.avg, "mpg", "mAvgFuel")}</div>`,
};

// Each page holds three values at most, so every value keeps room around the symbol.
// Paged panel in the card frame. Dots sit under the content; a page off screen that needs attention shows the page symbol
// beside the dots in the state colour (pageState in kit16.js).
function secPanel(s, F, at) {
  const p = secPage(s, F);
  const alerts = s.pages.filter(k => k !== p && pageState(s, k)).map(k => `<span class="tab ${pageState(s, k)}">${sym(PAGE_SYM[k], 30)}</span>`).join("");
  return `<div class="abs card sec ${p}" style="${at}" data-field="drivingInfoIndex (steering wheel left / right) · page ${p}">
    <span class="chev l">‹</span><span class="chev r">›</span>
    <div class="body">${SEC[p](s)}</div>
    <div class="pnav"><span class="dots">${s.pages.map(k => `<i${k === p ? ' class="on"' : ""}></i>`).join("")}</span>${alerts}</div></div>`;
}
