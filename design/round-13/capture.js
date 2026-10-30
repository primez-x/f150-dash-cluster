// Capture the round 13 Towing A bar options.
// Serve the repository root first: python -m http.server 8731 --bind 127.0.0.1
// Then run this file through the Playwright MCP browser_run_code_unsafe tool (filename argument).
// The result lists page errors and any content inside the shroud or screen-edge margin (an empty errors list passes).
async (page) => {
  const root = "http://127.0.0.1:8731/design/";
  const out = "design/round-13/shots/";
  const errors = [];
  page.on("pageerror", e => errors.push(page.url() + ": " + e.message));
  page.on("response", r => { if (r.status() >= 400 && !r.url().endsWith("favicon.ico")) errors.push(r.url() + ": " + r.status()); });
  const open = async (url, w, h) => {
    await page.setViewportSize({ width: w, height: h });
    await page.goto(root + url);
    await page.evaluate(() => document.fonts.ready);
  };
  for (const name of ["tow-a", "tow-b"]) {
    for (const scene of ["normal", "braking", "hottrans", "lowtire"]) {
      await open(`round-13/${name}.html?scene=${scene}&still=1`, 1920, 932);
      await page.screenshot({ path: `${out}${name}-${scene}.png` });
      for (const v of await page.evaluate(() => shroudViolations())) errors.push(`${name} ${scene}: shroud ${v}`);
    }
    await open(`round-13/${name}.html?view=physical&ruler=1`, 1920, 720);
    await page.screenshot({ path: `${out}${name}-physical.png` });
  }
  for (const p of [1, 2, 3]) {
    await open(`round-13/tow-a.html?page=${p}&still=1`, 1920, 932);
    await page.screenshot({ path: `${out}tow-a-page${p}.png` });
  }
  return errors;
}
