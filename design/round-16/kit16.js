// Round 16 kit: paged towing panel. Loads after round-15/kit15.js.
// One panel on the right (x 1060 to 1720) shows one page at a time. The steering wheel left / right keys change the page
// (drivingInfoIndex). Temperatures and tires no longer share the screen: each reading group has a page.
// A focus from kit15 (focusOf) jumps the panel to the page for that reading. When the focus clears, the panel returns to the
// page the driver chose. Fuel has no page: the fuel line at bottom center grows the range readout instead.
BASE.tow.pages = ["trailer", "temps", "tires", "engine", "trip"];
const FOCUS_PAGE = { temps: "temps", warmup: "temps", tires: "tires", brake: "trailer", climb: "engine", descent: "engine" };
const PANEL = { x: 1060, w: 660, top: 262 };
SYM.thermo = `<path d="M22 31V11a5 5 0 0 1 10 0v20a10 10 0 1 1-10 0Z"/><path d="M27 18v18"/><circle cx="27" cy="39" r="4" fill="#000"/><path d="M38 14h6M38 22h6"/>`;
const PAGE_SYM = { trailer: "trailer", temps: "thermo", tires: "tire", engine: "tach", trip: "road" };
const BRAKE_FIELD = "trailer brake: trucksTrailerOutput, trucksTrailerBrakeState, trucksTrailerOutputState, trucksTrailerGain (JLY 0x1A, trucksTrailerInfoNotify); output scale from the truck log";

// Page state for the navigation: the state colour a page needs while the page is not on screen.
const worstT = s => ["hot", "warm", "cold", "nodata"].find(st => anyT(s, st)) || "";
// Later kits add pages to PAGE_STATE.
const PAGE_STATE = { temps: worstT, tires: s => s.low >= 0 ? "low" : "", trailer: s => s.braking ? "live" : "" };
const pageState = (s, p) => PAGE_STATE[p] ? PAGE_STATE[p](s) : "";

const grid2 = cells => `<div class="abs fgrid" style="left:${PANEL.x}px;top:${PANEL.top}px;width:${PANEL.w}px">${cells.join("")}</div>`;
const PAGE_VIEW = {
  trailer: s => `<div class="abs fslot pair" style="left:${PANEL.x}px;top:${PANEL.top}px;width:${PANEL.w}px;height:200px">` +
    big(sym("trailerBrake", 60), (s.braking ? s.output : s.gain).toFixed(1), s.braking ? `of ${s.gain.toFixed(1)}` : "gain", BRAKE_FIELD, s.braking ? "on" : "") +
    big(sym("trailer", 60), s.trailerMi, "mi", "trucksTrailerDistance getTrucksTrailerDistance()") + `</div>` +
    brakeMeter(s, `left:${PANEL.x + 50}px;top:${PANEL.top + 230}px;width:${PANEL.w - 100}px`),
  temps: s => tBarsH(s, 150, true, false, `top:${PANEL.top}px`),
  tires: s => tires4(s, 230, `left:${PANEL.x + 110}px;top:${PANEL.top + 10}px;width:${PANEL.w - 220}px`).replace('class="abs tp"', 'class="abs tp bigtp"'),
  engine: s => grid2([big(sym("tach", 52), s.rpm.toLocaleString("en-US"), "rpm", "tacho rpm"), big(sym("turbo", 52), boostText(s), "psi", "boost: turbo, boostPercentage (JLY 0x40, vehicleInfoNotify); scale from the truck log"),
    big(gradeSym(s, 52), gradeText(s.grade), "%", "mPitch (grade = tan pitch)"), big(sym("oil", 52), Math.round(2.9 * 14.5), "psi", "trucksOilPressure (bar)")]),
  trip: s => grid2([big(sym("road", 52), s.trip, "mi", "mTripA"), big(sym("clock", 52), "2:41", "h", "RunTimeInfo"),
    big(sym("avg", 52), s.avg, "mpg", "mAvgFuel"), big(sym("now", 52), s.mpgNow, "mpg", "instant mpg")]),
};

// The page on screen: the focus page when a focus has one, otherwise the page the driver chose.
const shownPage = (s, F) => FOCUS_PAGE[F] || s.pages[s.page];
const pageView = (s, p) => `<div data-field="drivingInfoIndex (steering wheel left / right) · page ${p}">${PAGE_VIEW[p](s)}</div>`;

// Option A navigation: a row of page symbols above the panel. The page on screen is bright with a bar under the symbol;
// a page off screen that needs attention takes the state colour.
const navTabs = (s, p) => `<div class="abs tabs" style="left:${PANEL.x}px;top:186px;width:${PANEL.w}px" data-field="drivingInfoIndex">${s.pages.map(k =>
  `<span class="tab ${k === p ? "on" : ""} ${k === p ? "" : pageState(s, k)}">${sym(PAGE_SYM[k], 40)}</span>`).join("")}</div>`;
// Option B navigation: page dots under the panel and the page symbol at the panel top. A page off screen that needs attention
// shows the page symbol beside the dots in the state colour; otherwise nothing shows beside the dots.
const navDots = (s, p) => {
  const alerts = s.pages.filter(k => k !== p && pageState(s, k)).map(k => `<span class="tab ${pageState(s, k)}">${sym(PAGE_SYM[k], 34)}</span>`).join("");
  return `<div class="abs ptitle" style="left:${PANEL.x}px;top:192px">${sym(PAGE_SYM[p], 40)}</div>` +
    `<div class="abs pnav" style="left:${PANEL.x}px;top:566px;width:${PANEL.w}px" data-field="drivingInfoIndex"><span class="dots">${s.pages.map(k => `<i${k === p ? ' class="on"' : ""}></i>`).join("")}</span>${alerts}</div>`;
};

// Gear size for every layout from round 16 on: a secondary reading beside the speed. Rounds 9 to 15 used 72 to 120 px.
const GEAR_SIZE = 60;
