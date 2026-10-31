// Round 43 kit: the alert panel from the top edge. Loads after round-42/kit42.js.
//
// User direction (2026-10-31): the warning pop-ups become a panel that extends from the top edge, like the side glass
// panels (flush with the screen edge, inner corners rounded), but more prominent in colour and distinction.
// Every alert keeps the OK chip (2026-10-31): a short OK acknowledges the alert.
// - ?alert=a|b. A: tinted glass. The side-panel glass with a strong severity tint, a severity edge, and a severity kicker.
//   B: solid placard. A solid severity panel with dark text, the strongest contrast on the screen.
// - Both: 960 x 136 px at top center, flush with the top edge (the rounded corners face the screen). The panel ends at
//   y 136, above both top stacks (y 140), and covers the heading tape while shown. The text starts at y 40, below the
//   bezel arch.
// - Motion: slides down from behind the top edge in 280 ms (OutCubic) and back up in 200 ms (InCubic). A warning pulses once.
// - ?slide=0..1 freezes the slide-in at that progress, for the motion strip.
// - ?scene=notify shows an adapter message (one text, no subtitle): the kicker reads VEHICLE MESSAGE, and the text
//   takes up to two lines at 26 px.
const ALERT43 = params.get("alert") === "b" ? "b" : "a";
const PANEL43 = { l: 480, w: 960, h: 136 };
SCENES.notify = s => Object.assign(s, { alert: ["caution", symSrc("info"),
  "Light Electric Trailer Brake 5.5 · Check the trailer connector and the brake controller wiring before you continue towing", "", false, "msg"] });
SCENES.towhaul = s => Object.assign(s, { alert: ["caution", symSrc("info"), "Tow/Haul Mode Active", "", false, "msg"] });

// Adapter messages carry no symbol; the panel shows an information mark on the same 54 x 54 box.
SYM.info = `<circle cx="27" cy="27" r="21"/><path d="M27 24v14"/><circle cx="27" cy="16.5" r="1.5" fill="#000"/>`;
const KICKER43 = a => a[5] === "msg" ? "VEHICLE MESSAGE" : a[0] === "warn" ? "WARNING" : "CAUTION";
const easeOut43 = p => 1 - Math.pow(1 - p, 3);

function alert43(s) {
  document.querySelector(".alert4")?.remove();
  if (!s.alert) return;
  const [sev, src, title, sub] = s.alert;
  const p = params.has("slide") ? Math.min(1, Math.max(0, +params.get("slide"))) : 1;
  const y = Math.round(-(1 - easeOut43(p)) * PANEL43.h);
  const icon = `<i class="ic" style="--src:url('${src}')"></i>`;
  place(`<div class="abs alert43 ${ALERT43} ${sev}${s.alert[5] === "msg" ? " msg" : ""}${p < 1 ? " moving" : ""}" data-field="alarmTable · notifyText"
      style="left:${PANEL43.l}px;width:${PANEL43.w}px;height:${PANEL43.h}px;transform:translateY(${y}px)">
    <div class="badge">${icon}</div>
    <div class="txt"><span class="k">${KICKER43(s.alert)}</span><span class="t">${title}</span>${sub ? `<span class="s">${sub}</span>` : ""}</div>
    <span class="ok">OK</span>
  </div>`);
}
