// Round 22 kit: the measured visible area. Loads after the kit of the round that the page builds on.
//
// The hidden areas come from the truck photos of Factory > Screen grid (2026-10-30), checked by tools/check_visible_area.py.
// The same polygons are in handoff/claude-dashboard/shared-contracts.json (measurement.visible_area.hidden_polygons).
// - Bezel arch: the top frame hides y < 3 + (x - 960)^2 / 9000 (3 px at the center, 106 px at the side edges).
// - Steering column shroud: from y 776 at x 572 to 1348, widening to x 180 to 1710 at the bottom row.
// - Wheel rim (driver eye, wheel straight ahead): the top corners, down to y 158 at x 0 and y 177 at x 1920.
// This kit replaces the guessed round 4 arch (top y 752, no top arch) in the drawing and in the margin check.
const MASK_MARGIN = 20;
const bezelTop = x => Math.ceil(3 + (x - 960) ** 2 / 9000);
const MASK = {
  bezel: [[0, 0], [1920, 0], ...Array.from({ length: 49 }, (_, i) => 1920 - i * 40).map(x => [x, bezelTop(x)])],
  shroud: [[180, 932], [272, 862], [300, 845], [380, 815], [480, 792], [572, 776], [1348, 776], [1460, 797], [1620, 854], [1710, 932]],
  rimLeft: [[0, 0], [160, 0], [160, 70], [0, 158]],
  rimRight: [[1725, 0], [1920, 0], [1920, 177], [1725, 63]],
};
const MASK_SVG = `<svg class="abs bezel mask22" width="1920" height="932" aria-hidden="true">` +
  Object.entries(MASK).map(([k, p]) => `<path class="${k}" d="M${p.join(" L")} Z"/>`).join("") + `</svg>`;

// Shroud top edge for each canvas x (932 where the shroud does not reach), for cornerUse().
function archTop() {
  const top = new Array(1921).fill(932), p = MASK.shroud;
  for (let i = 0; i + 1 < p.length; i++) {
    const [x0, y0] = p[i], [x1, y1] = p[i + 1];
    for (let x = Math.min(x0, x1); x <= Math.max(x0, x1); x++) top[x] = Math.min(top[x], y0 + (y1 - y0) * (x - x0) / ((x1 - x0) || 1));
  }
  return top;
}

const insidePoly = (p, x, y) => {
  let c = false;
  for (let i = 0, j = p.length - 1; i < p.length; j = i++) {
    const [xi, yi] = p[i], [xj, yj] = p[j];
    if ((yi > y) !== (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) c = !c;
  }
  return c;
};
const segDist = (x, y, [ax, ay], [bx, by]) => {
  const dx = bx - ax, dy = by - ay, t = Math.max(0, Math.min(1, ((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy || 1)));
  return Math.hypot(x - ax - t * dx, y - ay - t * dy);
};
// How far a point reaches into a hidden area plus the margin, in canvas px (0 = clear). The screen sides count as edges too.
function maskOver(x, y) {
  let over = Math.max(0, MASK_MARGIN - x, x - 1920 + MASK_MARGIN, y - 932 + MASK_MARGIN);
  for (const [k, p] of Object.entries(MASK)) {
    // Edges that run along the screen border are not mask edges: only the inner edges count.
    const inner = (a, b) => !((a[0] === b[0] && (a[0] === 0 || a[0] === 1920)) || (a[1] === b[1] && (a[1] === 0 || a[1] === 932)));
    let d = Infinity;
    for (let i = 0, j = p.length - 1; i < p.length; j = i++) if (inner(p[j], p[i])) d = Math.min(d, segDist(x, y, p[j], p[i]));
    over = Math.max(over, insidePoly(p, x, y) ? MASK_MARGIN + d : MASK_MARGIN - d);
  }
  return over;
}
const maskRegion = (x, y) => y < 300 ? (x < 400 ? "top-left" : x > 1520 ? "top-right" : "top") : y > 700 && x > 150 && x < 1770 ? "shroud" : "side";

// Captures call this: every drawn element that reaches into a hidden area or the 20 px margin, with the overlap in canvas px.
// Text boxes use the glyph run (a Range), not the line box, so line spacing does not count.
function shroudViolations() {
  const c = document.getElementById("canvas").getBoundingClientRect(), k = 1920 / c.width;
  const name = el => `${el.tagName.toLowerCase()}${el.classList.length ? "." + [...el.classList].join(".") : ""}${el.closest("[data-field]") ? ` [${el.closest("[data-field]").dataset.field.slice(0, 40)}]` : ""}`;
  const out = new Map();
  for (const el of document.querySelectorAll("#canvas *")) {
    if (el.closest("svg[aria-hidden], defs, .turn, #physical-label") || ["svg", "g", "defs", "stop", "filter", "lineargradient", "radialgradient", "clippath", "mask"].includes(el.tagName.toLowerCase())) continue;
    const cs = getComputedStyle(el);
    if (cs.display === "none" || cs.visibility === "hidden" || +cs.opacity === 0) continue;
    const pts = [];
    if (el instanceof SVGGeometryElement) {
      const m = el.getScreenCTM(), n = el.getTotalLength(), sw = (parseFloat(cs.strokeWidth) || 0) / 2;
      if (!n || cs.stroke === "none" && cs.fill === "none") continue;
      for (let l = 0; l <= n; l += 2) {
        const q = el.getPointAtLength(l), p = new DOMPoint(q.x, q.y).matrixTransform(m), x = (p.x - c.left) * k, y = (p.y - c.top) * k;
        pts.push([x, y - sw], [x, y + sw], [x - sw, y], [x + sw, y]);
      }
    } else {
      let r = el.getBoundingClientRect();
      if ([...el.childNodes].every(n => n.nodeType === 3) && el.textContent.trim()) {
        const range = document.createRange(); range.selectNodeContents(el); r = range.getBoundingClientRect();
      } else if (el.children.length) continue;   // a container: the children carry the drawing
      if (!r.width || !r.height || r.width * k > 1800) continue;
      const x0 = (r.left - c.left) * k, x1 = (r.right - c.left) * k, y0 = (r.top - c.top) * k, y1 = (r.bottom - c.top) * k;
      for (let x = x0; x <= x1 + .1; x += Math.max(2, (x1 - x0) / 40)) pts.push([x, y0], [x, y1]);
      for (let y = y0; y <= y1 + .1; y += Math.max(2, (y1 - y0) / 20)) pts.push([x0, y], [x1, y]);
    }
    let worst = 0, at = null;
    for (const [x, y] of pts) { const o = maskOver(x, y); if (o > worst) { worst = o; at = [x, y]; } }
    if (worst >= 1) {
      const key = `${name(el)} ${maskRegion(...at)}`;
      if (!out.has(key) || out.get(key)[0] < worst) out.set(key, [worst, at]);
    }
  }
  return [...out].map(([n, [o, [x, y]]]) => `${n} +${Math.round(o)}px at ${Math.round(x)},${Math.round(y)}`);
}

// The round 4 finish() draws the guessed arch and the true-size label (the true-size view used an unmeasured scale).
// Round 22 swaps both: the measured mask, and no true-size view.
const finish4 = finish;
finish = function (s) {
  finish4(s);
  document.querySelector(".bezel:not(.mask22)")?.remove();
  document.getElementById("physical-label")?.remove();
  document.getElementById("ruler")?.remove();
  place(MASK_SVG);
  if (params.has("mask")) place(maskOverlay());
};
// ?mask=1 draws the 20 px margin as a dashed line, for review.
const maskOverlay = () => {
  const arch = Array.from({ length: 97 }, (_, i) => i * 20).map(x => `${x},${bezelTop(x) + MASK_MARGIN}`).join(" ");
  const off = (p, dy) => p.map(([x, y]) => `${x},${y + dy}`).join(" ");
  return `<svg class="abs" width="1920" height="932" aria-hidden="true" style="left:0;top:0;pointer-events:none">
    <polyline points="${arch}" fill="none" stroke="#ff5050" stroke-width="2" stroke-dasharray="8 6"/>
    <polyline points="${off(MASK.shroud, -MASK_MARGIN)}" fill="none" stroke="#ff5050" stroke-width="2" stroke-dasharray="8 6"/>
    <polyline points="${off(MASK.rimLeft.slice(1), MASK_MARGIN)}" fill="none" stroke="#ff5050" stroke-width="2" stroke-dasharray="8 6"/>
    <polyline points="${off(MASK.rimRight.slice(1), MASK_MARGIN)}" fill="none" stroke="#ff5050" stroke-width="2" stroke-dasharray="8 6"/></svg>`;
};

// Top bar. From the driver eye the bezel arch and the wheel rim hide both top corners, so the round 4 places (clock at x 64,
// outside temperature at x 1856, both at y 28) are hidden. ?top=a|b picks one of two fixes:
// A · One line: every top-bar item on one straight line at y 60, moved in to x 400 to 1520, where the line clears the arch.
// B · Center group: the clock and the outside temperature sit beside the telltale row, on the telltale line. On Towing, the
//     heading tape and the altitude sit outside them, each lower, where the arch leaves room.
// Both: the telltale row moves down to y 30 and holds at most 480 px (x 720 to 1200, six wide telltales such as TOW and
// A/T OIL TEMP): at y 30 the arch plus the margin reaches y 30 at x 715 and x 1205. kit22.css places the altitude.
const TOP = params.get("top") === "b" ? "b" : "a";
const TOPBAR = {
  a: { clock: "left:400px;top:60px", temp: "right:400px;top:60px", tape: { x: 530, top: 60 } },
  b: { clock: "right:1220px;top:40px", temp: "left:1220px;top:40px", tape: { x: 330, top: 61 } },
}[TOP];
if (typeof HDG !== "undefined") Object.assign(HDG, { x: TOPBAR.tape.x, top: TOPBAR.tape.top, w: 260 });
const frame4 = frame;
frame = function (s, opts) {
  frame4(s, opts);
  document.body.classList.add(`top-${TOP}`);
  document.querySelector('.tb[data-field="native RTC clock"]').style.cssText = TOPBAR.clock;
  document.querySelector('.tb[data-field^="outSideTemp"]').style.cssText = TOPBAR.temp;
  document.querySelector(".telltales").style.top = "30px";
};
// Six telltales at once (low tire, hot transmission, and four more), to show the room beside the telltales. The scene keeps
// the low-fuel light (151) off, because that light also turns the fuel module red.
SCENES.busy = s => Object.assign(s, { telltales: [...s.telltales, 24, 8, 3, 12, 30, 40].slice(0, 6) });
