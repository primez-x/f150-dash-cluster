// Round 1 shared behavior: stage scale, physical preview, cruise states, and SVG arc helpers.
// Query options: ?view=physical  ?cruise=off|available|active|set|acc|lim
const ASSETS = "../../handoff/claude-dashboard/assets";
const IMG = ASSETS + "/launcher/Trucks/images";
const params = new URLSearchParams(location.search);

function fitStage() {
  const stage = document.getElementById("stage");
  const physical = document.body.classList.contains("physical");
  const w = 1920, h = physical ? 720 : 932;
  stage.style.width = w + "px";
  stage.style.height = h + "px";
  const s = Math.min(innerWidth / w, innerHeight / h);
  stage.style.transform = `translate(${(innerWidth - w * s) / 2}px, ${(innerHeight - h * s) / 2}px) scale(${s})`;
}

// Cruise region states. Fields: cruiseState, cruiseSpeedSet, cruiseAccInterfaceState,
// cruiseLimState, getCruiseLimSpeed(), getCruiseLimSpeedColor(). Values are samples.
const CRUISE = {
  off:       { ico: null,               tag: "",       set: "" },
  available: { ico: "common/acc/cruise.png", tag: "CRUISE", set: "– –" },
  active:    { ico: "common/acc/cruise.png", tag: "CRUISE", set: "– –" },
  set:       { ico: "common/acc/cruise.png", tag: "SET",    set: "65" },
  acc:       { ico: "common/acc/acc1.png",   tag: "ACC",    set: "65" },
  lim:       { ico: null,               tag: "LIM",    set: "70" },
};

function renderCruise(el, state, unit) {
  const c = CRUISE[state];
  el.dataset.state = state;
  el.setAttribute("data-field", state === "lim" ? "cruiseLimState getCruiseLimSpeed()" :
    state === "acc" ? "cruiseAccInterfaceState cruiseSpeedSet" : "cruiseState cruiseSpeedSet");
  el.innerHTML = state === "off" ? "" :
    (c.ico ? `<img class="ico" src="${IMG}/${c.ico}" alt="">` : "") +
    `<span class="tag">${c.tag}</span><span class="val"><span class="set">${c.set}</span><span class="unit">${unit || "MPH"}</span></span>`;
}

// SVG arc path on a circle; angles in degrees, 0 = 12 o'clock, clockwise.
function arc(cx, cy, r, a0, a1) {
  const p = a => [cx + r * Math.sin(a * Math.PI / 180), cy - r * Math.cos(a * Math.PI / 180)];
  const [x0, y0] = p(a0), [x1, y1] = p(a1);
  return `M${x0.toFixed(1)} ${y0.toFixed(1)} A${r} ${r} 0 ${a1 - a0 > 180 ? 1 : 0} 1 ${x1.toFixed(1)} ${y1.toFixed(1)}`;
}
function polar(cx, cy, r, a) {
  return [cx + r * Math.sin(a * Math.PI / 180), cy - r * Math.cos(a * Math.PI / 180)];
}

addEventListener("DOMContentLoaded", () => {
  if (params.get("view") === "physical") document.body.classList.add("physical");
  const cruise = document.querySelector(".cruise");
  if (cruise) renderCruise(cruise, params.get("cruise") || cruise.dataset.state, cruise.dataset.unit);
  fitStage();
});
addEventListener("resize", fitStage);
