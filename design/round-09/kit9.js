// Round 9 kit: fuel in the bottom-right corner on every layout. Loads after round-08/kit8.js.
// Fuel module: a band along the shroud (E at the corner, F toward the center) and the level with the range in the corner pocket.
const fuelBand = s => band2({ side: "r", value: (s.fuel ?? 0) / 100, color: fuelColor(s, QUIET), warnTo: lowPct(s) / 100, ends: ["E", "F"], field: "fuelPercentage" });
const fuelRead = s => cornerRead({ side: "r", at: "right:48px;top:628px", label: `FUEL${fuelIcon}`, value: dash(s.fuel), unit: "%",
  sub: `${dash(s.range)}<span class="u">mi to empty</span>`, cls: `xl ${fuelState(s)}`, field: "fuelPercentage DTE" });

// Trailer brake bar (towing, upper right, where fuel sat before): the gain as a grey range with a marker,
// live output lit in the accent colour while braking.
function brakeBar(s, at) {
  const n = 20, on = !!s.braking;
  const segs = Array.from({ length: n }, (_, i) => {
    const c = (i + .5) * 10 / n;
    return `<i${on && c <= s.output ? ' class="lit"' : c <= s.gain ? ' class="avail"' : ""}></i>`;
  }).join("");
  return `<div class="abs brake ${on ? "on" : "idle"}" style="${at}" data-field="trucksTrailerGain (setting); live output: no firmware field yet (brake pedal + controller output needed)">
    <div class="top"><span class="k">${on ? `<span class="state">BRAKING</span>` : "TRAILER BRAKE"}</span>
      <span class="rv">${(on ? s.output : s.gain).toFixed(1)}<span class="u">${on ? `of ${s.gain.toFixed(1)}` : "gain"}</span></span></div>
    <div class="bseg">${segs}<b style="left:${s.gain * 10}%"></b></div></div>`;
}
