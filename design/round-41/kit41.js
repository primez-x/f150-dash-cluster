// Round 41 kit: the motion system on the locked Towing A (round 40). Loads after round-40/kit40.js.
//
// User direction (2026-10-30): use modern transitions and transform animations throughout, for a clean, smooth UI.
// The tokens and rules live in kit41.css (one source for the mock and the QML spec). This kit plays a 28 s drive on the
// locked layout and draws every frame as a pure function of the loop time, so a capture can stop at any time:
//   tow-motion.html        plays the loop live
//   tow-motion.html?t=6140 holds the frame at 6.14 s
//   tow-motion.html?pg=b   card page change B (crossfade) in place of A (slide); A is locked (2026-10-31)
// Data model: the truth of each continuous reading changes along straight segments; the cluster receives a sample every
// 100 ms (TICK, the CAN rate on the mock). Numbers show the last sample. Gauges follow the samples with --m-smooth.
// Motions:
// - Speed bar, rpm and boost bands, steering arc, cruise arrow, trailer brake meter: continuous, --m-smooth.
// - Right card page change: A slides the old page out and the new page in, in the direction of the page order;
//   B crossfades. A trailer brake or a climb jumps the card to the matching page (round 17), with the same motion.
// - Alert banner: in within --m-fast from 12 px above; out over --m-base. The background glow fades over --m-slow.
// - Set-speed number: in over --m-fast from 6 px below, holds 3 s, fades over 0.6 s (round 32 timing).
// - Cruise cancel: the round 32 red hold and fade, on the loop clock.
// - Drive chip change: scale 0.85 to 1 with a fade, --m-base.
// User direction (2026-10-30): the boost and rpm stack stays on at all speeds. The round 34 crawl hide no longer applies.
const PG = params.get("pg") === "b" ? "b" : "a";
const finish40 = finish;
finish = function (s) {
  finish40(s);
  if (crawl(s)) place(stack34(s));
};
const TOK = (() => {
  const cs = getComputedStyle(document.documentElement), v = n => cs.getPropertyValue(n).trim();
  return { fast: parseFloat(v("--m-fast")), base: parseFloat(v("--m-base")), slow: parseFloat(v("--m-slow")), smooth: parseFloat(v("--m-smooth")),
    slide: parseFloat(v("--m-slide")), out: v("--ease-out"), in: v("--ease-in") };
})();
const LOOP = 28000, TICK = 100, N41 = LOOP / TICK, SET_HOLD = 3000, SET_FADE = 600;
const mod = (x, m) => ((x % m) + m) % m;

// Truth of the continuous readings: [ms, value] corners.
const CH = {
  speed: [[0, 64], [3000, 64], [5000, 66], [6000, 66], [10000, 46], [11000, 46], [13000, 58], [19000, 58], [22000, 7], [24000, 7], [27000, 64], [28000, 64]],
  rpm: [[0, 1900], [6000, 1950], [6300, 1500], [10000, 1400], [11000, 1500], [11400, 3600], [13000, 3400], [15000, 2400], [19000, 2400], [19400, 1200],
    [22000, 1000], [24000, 1100], [24400, 2600], [27000, 2000], [28000, 1900]],
  boost: [[0, 4], [6000, 4], [6300, -9], [11000, -9], [11400, 16], [13000, 14], [15000, 6], [19000, 6], [19400, -8], [24000, -6], [24400, 10], [27000, 5], [28000, 4]],
  steer: [[0, 0], [1500, 3], [3000, -2], [4500, 0], [19000, 0], [21000, -27], [23500, -27], [25000, 0], [28000, 0]],
  output: [[0, 0], [6000, 0], [6600, 4], [9500, 4], [10000, 0], [28000, 0]],
};
const truth = (c, t) => {
  const k = CH[c], i = k.findIndex(([x]) => x > t);
  if (i <= 0) return k[i < 0 ? k.length - 1 : 0][1];
  const [x0, y0] = k[i - 1], [x1, y1] = k[i];
  return y0 + (y1 - y0) * (t - x0) / (x1 - x0);
};
const sample = (c, k) => truth(c, mod(k, N41) * TICK);
const shown = { speed: v => Math.round(v), rpm: v => Math.round(v / 10) * 10, boost: v => Math.round(v), steer: v => v, output: v => Math.round(v * 10) / 10 };

// Discrete events, applied in order on the towing base state.
const ALERT41 = SCENES.hotcht(structuredClone(BASE.tow)).alert, CHT41 = SCENES.hotcht(structuredClone(BASE.tow)).temps.cht;
const EVENTS = [
  [0, s => Object.assign(s, { cruise: "set", cruiseSet: 64, sel: 0 })],
  [1200, s => { s.sel = 1; }],                                                  // the driver pages right: trailer to tires
  [3000, s => { s.cruiseSet = 65; }],                                           // set speed up, twice
  [3500, s => { s.cruiseSet = 66; }],
  [6000, s => Object.assign(s, { braking: true, cruise: "available", cancelled: true })],   // trailer brake: cruise cancels
  [7800, s => { s.cancelled = false; }],
  [10000, s => { s.braking = false; }],
  [13000, s => Object.assign(s, { alert: ALERT41, cht0: s.temps.cht, temps: { ...s.temps, cht: CHT41 } })],
  [17000, s => { delete s.alert; s.temps = { ...s.temps, cht: s.cht0 }; }],
  [18000, s => { s.drive = "4H"; }],
  [26000, s => { s.drive = "2H"; }],
  [27000, s => Object.assign(s, { cruise: "set", cruiseSet: 64 })],
];

const BODY41 = document.body.className;
function stateAt(t) {
  t = mod(t, LOOP);
  const k = Math.floor(t / TICK);
  SCENES.m41 = s => {
    for (const [et, f] of EVENTS) if (et <= t) f(s);
    for (const c in CH) s[c] = shown[c](sample(c, k));
    return s;
  };
  params.set("scene", "m41");
  document.body.className = BODY41;
  const s = state("tow");
  s.page = s.sel;
  return s;
}

// Discrete keys on the sample grid; a transition starts where a key changes.
const GRID = Array.from({ length: N41 }, (_, i) => {
  const s = stateAt(i * TICK), b = document.body.classList;
  return { page: secPage(s, focusOf(s)), alert: s.alert ? s.alert[2] : "", drive: s.drive, cset: s.cruiseSet,
    cancel: !!s.cancelled, glow: b.contains("glow-hot") ? "glow-hot" : b.contains("glow-warm") ? "glow-warm" : "" };
});
function lastChange(key, t) {
  const i = Math.floor(t / TICK);
  for (let n = 0; n < N41; n++) {
    const j = i - n;
    if (GRID[mod(j, N41)][key] !== GRID[mod(j - 1, N41)][key])
      return { age: t - j * TICK, at: j * TICK, from: GRID[mod(j - 1, N41)][key], to: GRID[mod(j, N41)][key] };
  }
  return { age: Infinity };
}

// Exponential approach to each 100 ms sample (time constant tau), from a settled start 3 s back.
function smooth(g, t, tau) {
  const K = Math.floor(t / TICK), a = Math.exp(-TICK / tau);
  let v = g(K - 30);
  for (let k = K - 30; k < K; k++) { const x = g(k); v = x + (v - x) * a; }
  const x = g(K);
  return x + (v - x) * Math.exp(-(t - K * TICK) / tau);
}

// One animation, held at a given time on the loop clock.
function hold(el, frames, { dur, delay = 0, easing = "linear" }, age) {
  if (!el) return;
  const a = el.animate(frames, { duration: dur, delay, easing, fill: "both" });
  a.pause();
  a.currentTime = Math.max(0, Math.min(age, delay + dur));
}

// Elements of an earlier frame, for an exit: draw the earlier frame and keep the markup.
function ghost(draw, t, sels) {
  render41(draw, t, false);
  return Object.fromEntries(sels.map(q => [q, document.querySelector(q)?.outerHTML || ""]));
}

function clear41() {
  document.getElementById("canvas").innerHTML = "";
  document.getElementById("ruler")?.remove();
  document.body.style.removeProperty("--ambient-o");
}

function render41(draw, t, motion = true) {
  t = mod(t, LOOP);
  const ch = Object.fromEntries(["page", "alert", "drive", "cset", "cancel", "glow"].map(k => [k, lastChange(k, t)]));
  const pageGo = motion && ch.page.age < TOK.slow + 40, alertOut = motion && ch.alert.to === "" && ch.alert.age < TOK.base;
  const old = {};
  if (pageGo) Object.assign(old, ghost(draw, ch.page.at - 1, [".card.sec .body"]));
  if (alertOut) Object.assign(old, ghost(draw, ch.alert.at - 1, [".alert4"]));

  const s = stateAt(t);
  const v = Object.fromEntries(Object.keys(CH).map(c => [c, smooth(j => sample(c, j), t, TOK.smooth)]));
  v.cset = smooth(j => GRID[mod(j, N41)].cset, t, TOK.smooth);
  clear41();
  draw(s, v);
  if (!motion) return;

  // Set speed: the number snaps; the arrow follows v.cset.
  const num = document.querySelector(".cset32");
  if (num) {
    num.textContent = s.cruiseSet;
    // A press while the number shows updates the number in place: no second enter.
    const T = SET_HOLD + SET_FADE, onScreen = lastChange("cset", mod(ch.cset.at - 1, LOOP)).age + 1 < T;
    hold(num, [{ opacity: 0, transform: "translate(-50%, 6px)" }, { opacity: 1, transform: "translate(-50%, 0)", offset: TOK.fast / T },
      { opacity: 1, offset: SET_HOLD / T }, { opacity: 0, transform: "translate(-50%, 0)" }], { dur: T }, onScreen ? Math.max(ch.cset.age, TOK.fast) : ch.cset.age);
  }
  // Trailer brake meter: the fill scales from the left edge (QML: transform Scale { origin.x: 0; xScale }).
  const fill = document.querySelector(".bmeter .fill");
  if (fill) Object.assign(fill.style, { width: "100%", transformOrigin: "0 50%", transform: `scaleX(${(v.output / 10).toFixed(3)})` });

  // Card page change.
  if (pageGo && old[".card.sec .body"]) {
    const card = document.querySelector(".card.sec"), body = card.querySelector(".body");
    const box = { position: "absolute", left: `${body.offsetLeft}px`, top: `${body.offsetTop}px`, width: `${body.offsetWidth}px`, height: `${body.offsetHeight}px` };
    card.insertAdjacentHTML("beforeend", old[".card.sec .body"]);
    const out = card.lastElementChild;
    Object.assign(out.style, box);
    const dir = Math.sign(s.pages.indexOf(ch.page.to) - s.pages.indexOf(ch.page.from)) || 1, d = TOK.slide * dir;
    if (PG === "a") {
      hold(out, [{ opacity: 1, transform: "none" }, { opacity: 0, transform: `translateX(${-d}px)` }], { dur: TOK.fast, easing: TOK.in }, ch.page.age);
      hold(body, [{ opacity: 0, transform: `translateX(${d}px)` }, { opacity: 1, transform: "none" }], { dur: TOK.slow, delay: 40, easing: TOK.out }, ch.page.age);
    } else {
      hold(out, [{ opacity: 1 }, { opacity: 0 }], { dur: TOK.fast, easing: TOK.in }, ch.page.age);
      hold(body, [{ opacity: 0 }, { opacity: 1 }], { dur: TOK.base, delay: 40, easing: TOK.out }, ch.page.age);
    }
  }
  // Alert banner in and out; the pulse ring keeps the round 4 timing on the loop clock.
  if (ch.alert.to && ch.alert.age < TOK.fast)
    hold(document.querySelector(".alert4"), [{ opacity: 0, transform: "translateX(-50%) translateY(-12px)" }, { opacity: 1, transform: "translateX(-50%)" }],
      { dur: TOK.fast, easing: TOK.out }, ch.alert.age);
  if (alertOut && old[".alert4"]) {
    document.getElementById("canvas").insertAdjacentHTML("beforeend", old[".alert4"]);
    hold(document.getElementById("canvas").lastElementChild, [{ opacity: 1, transform: "translateX(-50%)" }, { opacity: 0, transform: "translateX(-50%) translateY(-8px)" }],
      { dur: TOK.base, easing: TOK.in }, ch.alert.age);
  }
  // Drive chip change.
  if (ch.drive.age < TOK.base)
    hold(document.querySelector(".drv30 .dchip"), [{ opacity: .3, transform: "scale(.85)" }, { opacity: 1, transform: "none" }], { dur: TOK.base, easing: TOK.out }, ch.drive.age);
  // Background glow: fades in and out over --m-slow.
  if (ch.glow.age < TOK.slow) {
    const o = c => { document.body.classList.remove("glow-hot", "glow-warm"); if (c) document.body.classList.add(c); return parseFloat(getComputedStyle(document.body).getPropertyValue("--ambient-o")) || 0; };
    const o0 = o(ch.glow.from), o1 = o(ch.glow.to), p = ch.glow.age / TOK.slow;
    if (!ch.glow.to) document.body.classList.add(ch.glow.from);
    document.body.style.setProperty("--ambient-o", (o0 + (o1 - o0) * p).toFixed(3));
  }
  // CSS keyframe animations (cruise cancel, alert pulse) follow the loop clock.
  document.body.classList.remove("hold");
  for (const a of document.getAnimations()) {
    if (!(a instanceof CSSAnimation)) continue;
    const age = a.animationName.startsWith("cancel32") ? (ch.cancel.to ? ch.cancel.age : Infinity) : a.animationName === "pulse" ? ch.alert.age : null;
    if (age == null) continue;
    a.pause();
    a.currentTime = Math.min(age, a.effect.getComputedTiming().endTime);
  }
  document.getElementById("m41-clock").textContent = `t = ${(t / 1000).toFixed(2)} s · page change ${PG.toUpperCase()}`;
}

// Live loop, or one held frame with ?t=.
function motion41(draw) {
  document.body.insertAdjacentHTML("beforeend", `<div id="m41-clock"></div>`);
  window.at41 = t => render41(draw, t);
  if (params.has("t")) return render41(draw, +params.get("t"));
  const t0 = performance.now();
  const step = () => { render41(draw, performance.now() - t0); requestAnimationFrame(step); };
  requestAnimationFrame(step);
}
