// Round 6 kit: the bottom corners beside the steering column shroud. Loads after round-04/kit4.js.
// Below y 740 the usable corner narrows along the shroud (20 px margin): content reaches x 410 at y 780,
// x 290 at y 820, x 215 at y 860, and x 180 at y 900. The right corner mirrors the left.

// n points evenly spaced along the arch between canvas x0 (corner side) and x1, moved d px away from the shroud.
// Each point keeps the unit normal (nx, ny) for ticks that stand off the shroud edge.
function shroudRail(x0, x1, n, d) {
  const tAt = x => { let lo = 0, hi = 1; for (let i = 0; i < 40; i++) { const m = (lo + hi) / 2; if (shroudAt(m).x < x) lo = m; else hi = m; } return lo; };
  const t0 = tAt(x0), t1 = tAt(x1), K = 400, cum = [0];
  for (let i = 1; i <= K; i++) {
    const a = shroudAt(t0 + (t1 - t0) * (i - 1) / K), b = shroudAt(t0 + (t1 - t0) * i / K);
    cum.push(cum[i - 1] + Math.hypot(b.x - a.x, b.y - a.y));
  }
  return Array.from({ length: n }, (_, j) => {
    const p = shroudAt(t0 + (t1 - t0) * cum.findIndex(c => c >= cum[K] * (j + .5) / n) / K);
    return { ...p, x: p.x + p.nx * d, y: p.y + p.ny * d };
  });
}

// Segment gauge that follows the shroud edge. The first segment sits at the corner; the value grows toward the center.
// value, redFrom, warnTo, avail, and mark are fractions of the scale. warnTo tints the low band amber; avail lights a dim range.
function rail({ side = "l", x0 = 190, x1 = 640, n, value, color = ACC, redFrom = null, warnTo = 0, avail = 0, mark = null, ends = null, d = 30, len = 24, w = 7, field }) {
  const pts = shroudRail(x0, x1, n, d), last = Math.floor(value * n - .5), fx = x => side === "r" ? 1920 - x : x;
  let g = `<g data-field="${field}">`;
  pts.forEach((p, i) => {
    const t = (i + .5) / n, lit = t <= value, red = redFrom != null && t >= redFrom;
    const col = lit ? (red ? "#ff3b30" : color) : red ? "#3a1814" : t < warnTo ? "#3a2e12" : t <= avail ? "var(--accent-dim)" : "#1d252e";
    const op = lit ? .25 + .75 * Math.pow((i + 1) / (last + 1), 1.4) : 1, head = lit && i >= last - 1;
    g += line(fx(p.x), p.y, fx(p.x + p.nx * len), p.y + p.ny * len, col, w, `stroke-linecap="round" stroke-opacity="${op.toFixed(2)}"${head ? ' filter="url(#glow)"' : ""}`);
  });
  if (mark != null) {
    const p = pts[Math.min(n - 1, Math.max(0, Math.round(mark * n - .5)))];
    g += line(fx(p.x - p.nx * 4), p.y - p.ny * 4, fx(p.x + p.nx * (len + 8)), p.y + p.ny * (len + 8), "#fff", 2, `stroke-opacity=".6"`);
  }
  if (ends) [[pts[0], ends[0]], [pts[n - 1], ends[1]]].forEach(([p, s]) => {
    g += text(fx(p.x + p.nx * (len + 22)), p.y + p.ny * (len + 22) + 8, s, 20, "#6b7480");
  });
  return g + `</g>`;
}

// Corner readout: small label row over one large value, an optional sub line, then optional raw HTML. side "r" right-aligns the stack.
const cornerRead = ({ side = "l", at, label, value, unit = "", sub = "", after = "", cls = "", field = "" }) =>
  `<div class="abs corner ${side} ${cls}" style="${at}" data-field="${field}"><span class="k">${label}</span>` +
  `<span class="big">${value}${unit ? `<span class="u">${unit}</span>` : ""}</span>${sub ? `<span class="sub">${sub}</span>` : ""}${after}</div>`;
const fuelIcon = `<i class="ic" style="--src:url(${ICON("fuel")})"></i>`;
