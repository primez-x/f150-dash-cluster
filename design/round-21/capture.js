// Capture the round 21 settings menu options.
// Serve the repository root first: python -m http.server 8731 --bind 127.0.0.1
// Then run this file through the Playwright MCP browser_run_code_unsafe tool (filename argument).
// The result lists page errors and any content inside the shroud or screen-edge margin (an empty errors list passes).
async (page) => {
  const root = "http://127.0.0.1:8731/design/round-21/menu.html?still=1&";
  const out = "design/round-21/shots/";
  const errors = [];
  page.on("pageerror", e => errors.push(page.url() + ": " + e.message));
  page.on("response", r => { if (r.status() >= 400 && !r.url().endsWith("favicon.ico")) errors.push(r.url() + ": " + r.status()); });
  await page.setViewportSize({ width: 1920, height: 932 });
  const shots = [];
  // Pick 1, layout: the same scenes with text values and press-twice confirm.
  for (const L of ["a", "b"]) for (const sc of ["home", "assist", "units"]) shots.push([`layout-${L}-${sc}`, `layout=${L}&scene=${sc}`]);
  // Pick 2, values: layout A, text values or controls.
  for (const V of ["a", "b"]) for (const sc of ["assist", "units"]) shots.push([`values-${V}-${sc}`, `values=${V}&scene=${sc}`]);
  // Pick 3, confirm: layout A on Reset > Oil life, armed and sent.
  for (const C of ["a", "b"]) for (const sc of ["confirm", "done"]) shots.push([`confirm-${C}-${sc}`, `confirm=${C}&scene=${sc}`]);
  for (const [name, q] of shots) {
    await page.goto(root + q);
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: `${out}${name}.png` });
    for (const v of await page.evaluate(() => shroudViolations())) errors.push(`${name}: shroud ${v}`);
  }
  await page.setViewportSize({ width: 1920, height: 720 });
  await page.goto(root + "scene=assist&view=physical&ruler=1");
  await page.evaluate(() => document.fonts.ready);
  await page.screenshot({ path: `${out}layout-a-physical.png` });
  return errors;
}
