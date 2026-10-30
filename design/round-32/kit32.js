// Round 32 kit: cruise on the speed bar. Loads after round-31/kit31.js.
//
// User direction (2026-10-30): cruise shows a small arrow on the speed bar at the set speed. While the driver raises or
// lowers the set speed, the number shows above the arrow, then goes away quietly. A small cue near MPH shows that cruise
// is on, in place of the large cruise readout under MPH.
// - Arrow: green, on top of the bar, pointing down at the set speed (cruiseSpeedSet). The dark outline keeps the arrow
//   apart from the ticks. The limiter (cruiseLimState) keeps the white arrow from round 19.
// - Resume reference: while cruise is on but not set (after a cancel), an amber arrow marks the last set speed, the speed
//   that Resume returns to. With no earlier set speed (cruise just switched on), no arrow shows.
//   Truck check: whether cruiseSpeedSet keeps the last set speed after a cancel is unverified.
// - Cancel: when cruise goes from set to on (brake or Cancel), the arrow, the cruise symbol, and MPH turn red, hold 1 s, then
//   fade over 0.8 s into the resume state (amber arrow, amber symbol, grey MPH). kit32.css runs the change (cancel32).
//   The "cruisecancel" scene holds the red frame; ?cancel=1 runs a live demo that cancels and resumes every 4 s.
// - Number: green, above the arrow. A change of the set speed shows the number at once; the number holds for
//   SET_HOLD_MS after the last change, then fades over SET_FADE_MS. A new change restarts the hold.
// - ?cue=a|b, the steady cue while cruise is on. A: a small cruise symbol beside MPH (amber while cruise is on but not set,
//   green while set). B: the MPH label turns green while set; cruise on but not set shows no cue.
//   Locked (2026-10-30): both, the symbol and the green MPH label. Both is the default; ?cue=a or ?cue=b shows one alone.
// - ?adjust=1 runs a live demo: the set speed steps up three times and down twice. The "cruiseadj" scene holds the number.
// Truck check: the cruiseState values for on, set, and adjusting are unverified (shared-contracts cruise_contract).
const CUE = params.get("cue") || "ab";
const SET_HOLD_MS = 3000, SET_FADE_MS = 600;
const CRUISE_ICON = `${IMG}/common/acc/cruise.png`;
SCENES.cruiseadj = s => Object.assign(SCENES.cruise(s), { cruiseSet: 66, adjusting: true });
SCENES.cruiseon = s => Object.assign(s, { cruise: "available" });
SCENES.cruisefresh = s => Object.assign(s, { cruise: "available", cruiseSet: null });
SCENES.cruisecancel = s => Object.assign(s, { cruise: "available", cancelled: true });
const cruiseSetOn = s => ["set", "acc"].includes(s.cruise);

const setArrow = (x, y) => `M${x.toFixed(1)} ${y - 5} l-9 -15 h18 Z`;
const speedRuler26 = speedRuler;
speedRuler = function (s, y = barY()) {
  speedRuler26({ ...s, cruise: "off" }, y);
  const m = cruiseMark(s) || (s.cruise === "available" && s.cruiseSet ? [s.cruiseSet, "var(--caution)"] : null);
  if (!m) return;
  layer(`<path id="cset-arrow" data-field="cruiseSpeedSet" d="${setArrow(speedX(m[0]), y)}" fill="${m[1]}" stroke="#05070a" stroke-width="3" paint-order="stroke"/>`);
  place(`<div class="abs cset32${s.adjusting ? " hold" : ""}" style="left:${speedX(m[0])}px;top:${y - 60}px" data-field="cruiseSpeedSet (shows while the set speed changes)">${m[0]}</div>`);
};

const finish31 = finish;
finish = function (s) {
  finish31(s);
  document.querySelector(".row25 .cruise")?.remove();
  const unit = document.querySelector(".sunit");
  if (CUE.includes("a") && s.cruise !== "off") unit.insertAdjacentHTML("afterbegin", `<i class="cr32 ${cruiseSetOn(s) ? "on" : ""}" style="--src:url(${CRUISE_ICON})" data-field="cruiseState"></i>`);
  if (CUE.includes("b") && cruiseSetOn(s)) unit.classList.add("cr32b");
  if (s.cancelled) document.body.classList.add("cancel32", "hold");
  if (params.has("adjust") && cruiseSetOn(s)) cruiseDemo(s);
  if (params.has("cancel") && cruiseSetOn(s)) cancelDemo();
};

// Live demo of a cancel and a resume: set (green) for 4 s, cancel (red, then amber) for 4 s, and again.
function cancelDemo() {
  const arrow = document.getElementById("cset-arrow"), icon = document.querySelector(".cr32"), unit = document.querySelector(".sunit");
  let set = true;
  setInterval(() => {
    set = !set;
    arrow.setAttribute("fill", set ? "var(--ok)" : "var(--caution)");
    icon?.classList.toggle("on", set);
    if (CUE.includes("b")) unit.classList.toggle("cr32b", set);
    document.body.classList.remove("cancel32");
    void document.body.offsetWidth;
    if (!set) document.body.classList.add("cancel32");
  }, 4000);
}

// Live demo of a set-speed change: move the arrow, show the number, restart the hold.
function cruiseDemo(s) {
  const arrow = document.getElementById("cset-arrow"), num = document.querySelector(".cset32");
  let v = s.cruiseSet, i = 0;
  const steps = [0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, -1, -1, 0, 0, 0, 0, 0, 0, 0];
  setInterval(() => {
    const d = steps[i++ % steps.length];
    if (!d) return;
    v += d;
    arrow.setAttribute("d", setArrow(speedX(v), barY()));
    num.textContent = v;
    num.style.left = `${speedX(v)}px`;
    num.classList.remove("show");
    void num.offsetWidth;
    num.classList.add("show");
  }, 600);
}
