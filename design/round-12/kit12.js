// Round 12 kit: symbols in place of text labels. Loads after round-10/kit10.js.
// Stock icons (assets .../common/icon) cover fuel, coolant (water), oil, oil temperature, transmission (gearBoxTemp), battery,
// and range. The kit draws the missing symbols on the same 54 x 54 box and line weight: trailer, trailer brake, boost (turbo),
// differential temperature, grade, tach, road, clock, average, instant economy, and service.
// sym() draws stock and drawn symbols the same way, as a mask in the current text colour, so state colours recolour every symbol.
const SYM = (() => {
  // Turbo housing: an open spiral around the hub, with the outlet to the right.
  const sp = Array.from({ length: 41 }, (_, i) => {
    const t = i / 40 * 1.8 * Math.PI, r = 5 + 15 * t / (1.8 * Math.PI);
    return `${(22 + r * Math.sin(t)).toFixed(1)} ${(32 - r * Math.cos(t)).toFixed(1)}`;
  });
  return {
    trailer: `<rect x="4" y="11" width="35" height="22" rx="3"/><path d="M39 29h10"/><circle cx="50" cy="29" r="1.5" fill="#000"/><circle cx="19" cy="40" r="6" fill="#000"/>`,
    trailerBrake: `<rect x="4" y="5" width="35" height="20" rx="3"/><path d="M39 21h10"/><circle cx="21" cy="40" r="6"/>` +
      `<path d="M13.3 31.4A11.5 11.5 0 0 0 13.3 48.6M28.7 31.4A11.5 11.5 0 0 1 28.7 48.6"/>`,
    turbo: `<path d="M${sp.join("L")}"/><path d="M22 12h24v9h-6"/><circle cx="22" cy="32" r="2.5" fill="#000"/>`,
    diff: `<circle cx="27" cy="31" r="13"/><path d="M3 31h11M40 31h11M4 23v16M50 23v16M27 18v-8M21 9h12M27 25v7"/><circle cx="27" cy="35" r="3.5" fill="#000"/>`,
    grade: `<path d="M5 45H49V12Z" fill="#000" fill-opacity=".3"/>`,
    tach: `<path d="M10.7 41.6A19 19 0 1 1 43.3 41.6"/><path d="M27 32L37 20"/><circle cx="27" cy="32" r="3.5" fill="#000"/>`,
    road: `<path d="M18 8L8 46M36 8L46 46M27 10v6M27 23v7M27 37v8"/>`,
    clock: `<circle cx="27" cy="27" r="20"/><path d="M27 15v12l8 6"/>`,
    avg: `<circle cx="27" cy="27" r="15"/><path d="M10 44L44 10"/>`,
    now: `<path d="M8 38A19 19 0 0 1 46 38"/><path d="M27 38L38 24"/><circle cx="27" cy="38" r="3.5" fill="#000"/><path d="M8 46h38"/>`,
    service: `<path d="M33.5 7a10 10 0 0 0-9.8 13.6L8 36.3a4 4 0 0 0 5.7 5.7l15.7-15.7A10 10 0 0 0 43 16.5l-6 6-5.5-1.5L30 15.5l6-6A10 10 0 0 0 33.5 7Z"/>`,
  };
})();
const symSrc = n => SYM[n]
  ? "data:image/svg+xml," + encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 54 54" fill="none" stroke="#000" stroke-width="4.2" stroke-linecap="round" stroke-linejoin="round">${SYM[n]}</svg>`)
  : ICON(n);
// Stock range icon is 66 x 46; every other symbol is square. Stock glyphs carry more padding, so they draw 15 % larger.
const sym = (n, h = 40, cls = "") => { const k = SYM[n] ? h : Math.round(h * 1.15);
  return `<i class="sym ${cls}" style="--src:url('${symSrc(n)}');width:${Math.round(n === "range" ? k * 66 / 46 : k)}px;height:${k}px"></i>`; };
const tSym = (T, h) => sym(T.icon || "diff", h);
const deg = T => `<span class="rv">${T.f}${T.state === "nodata" ? "" : `<span class="dg">°</span>`}</span>`;

// Temperature ring: a 270 degree gauge open at the bottom, with the zone tints of tempArc, a knob at the reading,
// the value in the middle, and the symbol in the gap.
function tRing(T, cx, cy, r = 64) {
  const [kx, ky] = polar(cx, cy, r, -135 + 270 * T.pct);
  layer(tempArc({ cx, cy, r, from: -135, to: 135, T, w: 8 }) +
    (T.state === "nodata" ? "" : `<circle cx="${kx.toFixed(1)}" cy="${ky.toFixed(1)}" r="8" fill="${T.state === "normal" ? "#c9d1da" : TCOL[T.state]}"/>`));
  return `<div class="abs tring temp ${T.state}" style="left:${cx}px;top:${cy}px" data-field="${T.field}">${deg(T)}${tSym(T, 42)}</div>`;
}

// Paged info card on one line: the first symbol names the page, and units carry the rest. No titles and no cell labels.
// The steering wheel left / right keys still change the page (drivingInfoIndex).
const icell = (n, v, u, f) => `<span class="icell" data-field="${f}">${sym(n, 36)}<span class="rv">${v}<span class="u">${u}</span></span></span>`;
const ICON_PAGES = {
  trailer: s => [icell("trailer", s.trailerMi, "mi", "trucksTrailerDistance getTrucksTrailerDistance()")],
  trip: s => [icell("road", s.trip, "mi", "mTripA"), icell("clock", "2:41", "h", "RunTimeInfo"), icell("avg", s.avg, "mpg", "mAvgFuel")],
  economy: s => [icell("now", s.mpgNow, "mpg", "instant mpg"), icell("avg", s.avg, "mpg", "mAvgFuel"), icell("range", dash(s.range), "mi", "DTE")],
  // Oil pressure: trucksOilPressure arrives in bar; shown in psi. Values on this truck are unverified.
  vehicle: s => [icell("oil", Math.round(2.9 * 14.5), "psi", "trucksOilPressure (bar)"), icell("service", "72", "%", "trucksOilLifePercentage"), icell("battery", "14.2", "V", "batterVoltage")],
};
function icard(s, at) {
  return `<div class="abs card line" style="${at}" data-field="drivingInfoIndex (steering wheel left / right)">
    <span class="chev l">‹</span><span class="chev r">›</span>
    <div class="cells">${ICON_PAGES[s.pages[s.page]](s).join("")}</div>
    <span class="dots">${s.pages.map((_, i) => `<i${i === s.page ? ' class="on"' : ""}></i>`).join("")}</span></div>`;
}
