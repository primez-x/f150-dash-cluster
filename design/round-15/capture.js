// Capture the round 15 Towing A focus options across every condition.
// Serve the repository root first: python -m http.server 8731 --bind 127.0.0.1
// Then run this file through the Playwright MCP browser_run_code_unsafe tool (filename argument).
// The result lists page errors and any content inside the shroud or screen-edge margin (an empty errors list passes).
async (page) => {
  const root = "http://127.0.0.1:8731/design/";
  const out = "design/round-15/shots/";
  const errors = [];
  page.on("pageerror", e => errors.push(page.url() + ": " + e.message));
  page.on("response", r => { if (r.status() >= 400 && !r.url().endsWith("favicon.ico")) errors.push(r.url() + ": " + r.status()); });
  const open = async (url, w, h) => {
    await page.setViewportSize({ width: w, height: h });
    await page.goto(root + url);
    await page.evaluate(() => document.fonts.ready);
  };
  for (const name of ["tow-a", "tow-b"]) {
    for (const scene of ["normal", "climb", "descent", "braking", "hottrans", "stack", "lowtire", "lowfuel", "cold"]) {
      await open(`round-15/${name}.html?scene=${scene}&still=1`, 1920, 932);
      await page.screenshot({ path: `${out}${name}-${scene}.png` });
      for (const v of await page.evaluate(() => shroudViolations())) errors.push(`${name} ${scene}: shroud ${v}`);
    }
    await open(`round-15/${name}.html?view=physical&ruler=1`, 1920, 720);
    await page.screenshot({ path: `${out}${name}-physical.png` });
  }
  return errors;
}
