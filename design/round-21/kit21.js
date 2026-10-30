// Round 21: settings menu mock. Rows and values follow the firmware for the 2011-2014 F150 profile (truck model 1, vehicle model 1).
// Values marked "sample" are examples; the truck sends the real values (fordSetupInfo from the CAN box).
// ?layout=a|b (A columns, B one list), ?values=a|b (A text, B controls), ?confirm=a|b (A press twice, B hold), ?scene=...
const MENU = {
  home: { title: "Settings", rows: [["Vehicle", ">"], ["System", ">"], ["Service", ">"]] },
  vehicle: { title: "Vehicle", rows: [["Lighting", ">"], ["Locks", ">"], ["Driver assist", ">"], ["Remote start", ">"], ["Reset", ">"], ["G-force", ">"]] },
  assist: { title: "Driver assist", rows: [
    ["Trailer brake mode", { seg: ["Electric", "Electric over hydraulic"], on: 0 }],
    ["Trailer sway control", { sw: 1 }],
    ["Range calculation", { seg: ["Normal", "Towing"], on: 1 }],
    ["Easy entry and exit", { sw: 0 }],
    ["Oil life start value", { pct: 100 }],
    ["Off-road camera", { sw: 0 }]] },
  reset: { title: "Reset", rows: [["Trip A", "act"], ["Trip B", "act"], ["Trip info", "act"], ["Tire pressure monitor", "act"], ["Factory settings", "act"], ["Oil life", "act"]] },
  system: { title: "System", rows: [["Language", "English"], ["Date and time", "GPS · 10:42"], ["Units", ">"], ["Display", ">"], ["Version", ">"], ["Factory", ">"]] },
  units: { title: "Units", rows: [
    ["Fuel economy", { seg: ["L/100km", "km/L", "MPG"], on: 2 }],
    ["Speed and distance", { seg: ["km/h", "mph"], on: 1, note: "Follow" }],
    ["Temperature", { seg: ["°C", "°F"], on: 1, note: "Manual" }],
    ["Tire pressure", { seg: ["kPa", "bar", "kg/cm²", "psi"], on: 3 }],
    ["Follow vehicle units", "act"]] },
};
// Scene: the open path (menu keys) and the focus row in the last page; arm = the confirm state on the focus row.
const SCENES21 = {
  home: { path: ["home"], focus: 0 },
  assist: { path: ["home", "vehicle", "assist"], sel: [0, 2], focus: 4 },
  assistsw: { path: ["home", "vehicle", "assist"], sel: [0, 2], focus: 1 },
  reset: { path: ["home", "vehicle", "reset"], sel: [0, 4], focus: 5 },
  confirm: { path: ["home", "vehicle", "reset"], sel: [0, 4], focus: 5, arm: .6 },
  done: { path: ["home", "vehicle", "reset"], sel: [0, 4], focus: 5, done: 1 },
  units: { path: ["home", "system", "units"], sel: [1, 2], focus: 2 },
};
const sc = SCENES21[params.get("scene")] || SCENES21.assist;
const L = params.get("layout") || "a", V = params.get("values") || "a", C = params.get("confirm") || "a";

function valueHtml(v, focus) {
  if (v === ">") return `<i class="chev"></i>`;
  if (v === "act") return "";
  if (typeof v === "string") return v;
  const note = v.note ? `<span style="font-size:22px;color:var(--mute)">${v.note}</span>` : "";
  if (V === "a") {
    const text = v.seg ? v.seg[v.on] : v.sw !== undefined ? (v.sw ? "On" : "Off") : `${v.pct}%`;
    return focus ? `${note}<span class="arr">‹</span>${text}<span class="arr">›</span>` : `${note}${text}`;
  }
  if (v.seg) return `${note}<span class="seg">${v.seg.map((t, i) => `<span class="${i === v.on ? "on" : ""}">${t}</span>`).join("")}</span>`;
  if (v.sw !== undefined) return `<span class="sw${v.sw ? " on" : ""}"></span>`;
  return `<span class="pmeter"><i style="width:${v.pct}%"></i></span>${v.pct}%`;
}
function rowHtml(r, i, { focus, path }) {
  const [t, v] = r;
  let cls = "mrow", val = valueHtml(v, focus), extra = "";
  if (focus) cls += " focus";
  if (path) cls += " path";
  if (focus && sc.arm !== undefined) {
    cls = "mrow arm";
    val = C === "a" ? "Press OK again to reset" : "Hold OK to reset";
    extra = `<span class="cbar"><i style="width:${(C === "a" ? 1 - sc.arm : sc.arm) * 100}%"></i></span>`;
  }
  if (focus && sc.done) { cls += " done"; val = "Reset sent"; }
  return `<div class="${cls}"><span class="t">${t}</span><span class="v">${val}</span>${extra}</div>`;
}
const hint = () => `<div class="hint"><span><b>▲ ▼</b>Select</span><span><b>OK</b>${sc.arm !== undefined && C === "b" ? "Hold to confirm" : "Open or change"}</span><span><b>◀</b>Back</span><span><b>Hold BACK</b>Close menu</span></div>`;

function columnsMenu() {
  const widths = ["340px", "470px"];
  const cols = sc.path.map((key, level) => {
    const page = MENU[key], last = level === sc.path.length - 1;
    const rows = page.rows.map((r, i) => rowHtml(r, i, { focus: last && i === sc.focus, path: !last && sc.sel && sc.sel[level] === i })).join("");
    return `<div class="col ${last ? "" : "parent"}" style="${last ? "" : `width:${widths[level]}`}"><div class="head">${page.title}</div>${rows}</div>`;
  });
  return `<div class="abs menu" data-field="menu: owned QML"><div class="cols">${cols.join("")}</div>${hint()}</div>`;
}
function drillMenu() {
  const key = sc.path[sc.path.length - 1], page = MENU[key];
  const crumb = sc.path.map((k, i) => i === sc.path.length - 1 ? `<em>${MENU[k].title}</em>` : MENU[k].title).join("  ›  ");
  const rows = page.rows.map((r, i) => rowHtml(r, i, { focus: i === sc.focus })).join("");
  const parent = sc.path.length > 1 ? MENU[sc.path[sc.path.length - 2]] : null;
  const side = parent ? `<div class="side">${parent.rows.map((r, i) => `<span class="${sc.sel[sc.path.length - 2] === i ? "on" : ""}">${r[0]}</span>`).join("")}</div>` : "";
  return `<div class="abs menu" data-field="menu: owned QML"><div class="drill"><div class="crumb">${crumb}</div>
    <div class="list">${side}${rows}</div></div>${hint()}</div>`;
}
function menu21() { place(L === "b" ? drillMenu() : columnsMenu()); }
