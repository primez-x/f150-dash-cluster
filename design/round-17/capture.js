// Capture the round 17 Towing A options: every secondary page on a calm drive, then the conditions that change the screen.
// Serve the repository root first: python -m http.server 8731 --bind 127.0.0.1
// Then run this file through the Playwright MCP browser_run_code_unsafe tool (filename argument).
// The result lists page errors and any content inside the shroud or screen-edge margin (an empty errors list passes).
async (page) => {
  const root = "http://127.0.0.1:8731/design/";
  const out = "design/round-17/shots/";
  const errors = [];
  page.on("pageerror", e => errors.push(page.url() + ": " + e.message));
  page.on("response", r => { if (r.status() >= 400 && !r.url().endsWith("favicon.ico")) errors.push(r.url() + ": " + r.status()); });
  const open = async (url, w, h) => {
    await page.setViewportSize({ width: w, height: h });
    await page.goto(root + url);
    await page.evaluate(() => document.fonts.ready);
  };
  const shots = [["page0", "page=0"], ["page1", "page=1"], ["page2", "page=2"], ["page3", "page=3"],
    ["hottrans", "scene=hottrans"], ["lowtire", "scene=lowtire"], ["braking", "scene=braking"], ["climb", "scene=climb"],
    ["lowfuel", "scene=lowfuel"], ["cold", "scene=cold"], ["stack", "scene=stack&page=3"]];
  for (const name of ["tow-a", "tow-b"]) {
    for (const [tag, q] of shots) {
      await open(`round-17/${name}.html?${q}&still=1`, 1920, 932);
      await page.screenshot({ path: `${out}${name}-${tag}.png` });
      for (const v of await page.evaluate(() => shroudViolations())) errors.push(`${name} ${tag}: shroud ${v}`);
    }
    await open(`round-17/${name}.html?view=physical&ruler=1`, 1920, 720);
    await page.screenshot({ path: `${out}${name}-physical.png` });
  }
  return errors;
}
