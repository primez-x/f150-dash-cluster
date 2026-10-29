// Round 8 kit: one visual hierarchy for every layout. Loads after round-07/kit7.js.
// Speed is the one hero. The accent colour marks the primary gauges only: the speed and RPM scales, the RPM halo, and the RPM band.
// Secondary gauges (fuel, economy, boost, trailer brake, temperatures) fill in quiet grey with no glow.
// Amber and red still mark a warning, so a change of state becomes the brightest thing on the screen.
const QUIET = "#8a929c", VACUUM = "#5d6670";

// Temperature warning zones stay faint at rest. The fill and the value take the warning colour when a reading enters a zone.
Object.assign(ZONE_TINT, { cold: .1, warm: .1, hot: .14 });
TCOL.normal = QUIET;

// Secondary corner band: quiet grey fill, no head glow. Pass color for a warning state (fuelColor(s, QUIET)).
const band2 = (o, ring = 0) => band({ color: QUIET, glow: false, ...o }, ring);
const boostTint = s => s.boost < 0 ? VACUUM : QUIET;

// Slate is the neutral accent. At the round 5 value (148, 163, 184) slate matches the quiet grey, so the primary gauges and
// live braking lose their lead over the secondary gauges. A lighter slate keeps the accent brighter than the quiet grey.
ACCENTS.slate = "200, 212, 226";
