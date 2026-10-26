// Round 7 kit: modules that fill the bottom corners. Loads after round-06/kit6.js.
// The corner area is the strip from y 740 down to the shroud margin plus the pocket at the screen edge (see ?usable=1).

// Corner band: a thick shroud rail from the corner pocket to x 620. Concentric bands step out by BAND.len + 12.
const BAND = { x0: 182, x1: 620, d: 30, len: 38, w: 12 };
const band = (o, ring = 0) => rail({ ...BAND, n: 26, ...o, d: BAND.d + ring * (BAND.len + 12) });

// Points around a circle (0 = up, clockwise) with the outward normal, for a corner dial drawn by rail().
const arcPts = (cx, cy, r, a0, a1, n) => Array.from({ length: n }, (_, i) => {
  const a = (a0 + (a1 - a0) * (i + .5) / n) * Math.PI / 180;
  return { x: cx + r * Math.sin(a), y: cy - r * Math.cos(a), nx: Math.sin(a), ny: -Math.cos(a) };
});

// Boost on a center-zero scale: the fraction of the scale for a psi value, and the colour (accent for boost, quiet grey for vacuum).
const boostAt = v => (Math.min(BOOST_MAX, Math.max(BOOST_MIN, v ?? 0)) - BOOST_MIN) / (BOOST_MAX - BOOST_MIN);
const boostColor = s => s.boost < 0 ? "#8a929c" : ACC;
const boostText = s => s.boost == null ? "--" : s.boost < 0 ? `−${-s.boost}` : s.boost;
