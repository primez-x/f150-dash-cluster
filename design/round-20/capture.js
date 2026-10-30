// Capture the round 20 Towing A options: wheel angle, level page, compass heading, and altitude.
// Serve the repository root first: python -m http.server 8731 --bind 127.0.0.1
// Then run this file through the Playwright MCP browser_run_code_unsafe tool (filename argument).
// The result lists page errors and any content inside the shroud or screen-edge margin (an empty errors list passes).
async (page) => {
  const root = "http://127.0.0.1:8731/design/";
  const out = "design/round-20/shots/";
  const errors = [];
  page.on("pageerror", e => errors.push(page.url() + ": " + e.message));
  page.on("response", r => { if (r.status() >= 400 && !r.url().endsWith("favicon.ico")) errors.push(r.url() + ": " + r.status()); });
  const open = async (url, w, h) => {
    await page.setViewportSize({ width: w, height: h });
    await page.goto(root + url);
    await page.evaluate(() => document.fonts.ready);
  };
  const shots = [["normal", "scene=normal"], ["level", "scene=normal&page=3"], ["pass", "scene=pass"], ["crawl", "scene=crawl"],
    ["backing", "scene=backing"], ["tilt", "scene=tilt"], ["tilthot", "scene=tilthot"], ["tiltstack", "scene=tiltstack"], ["d4l", "scene=d4l"]];
  for (const name of ["tow-a", "tow-b"]) {
    for (const [tag, q] of shots) {
      await open(`round-20/${name}.html?${q}&still=1`, 1920, 932);
      await page.screenshot({ path: `${out}${name}-${tag}.png` });
      for (const v of await page.evaluate(() => shroudViolations())) errors.push(`${name} ${tag}: shroud ${v}`);
    }
    await open(`round-20/${name}.html?view=physical&ruler=1`, 1920, 720);
    await page.screenshot({ path: `${out}${name}-physical.png` });
  }
  return errors;
}
