// Capture the round 10 layouts: fuel at bottom center on every layout.
// Serve the repository root first: python -m http.server 8731 --bind 127.0.0.1
// Then run this file through the Playwright MCP browser_run_code_unsafe tool (filename argument).
// The result lists page errors and any content inside the shroud or screen-edge margin (an empty errors list passes),
// and the corner use (left / right, cornerUse in kit4.js) for each layout at the normal scene.
async (page) => {
  const root = "http://127.0.0.1:8731/design/";
  const out = "design/round-10/shots/";
  const daily = ["normal", "lowfuel", "reserve", "stale"], tow = ["normal", "braking", "reserve", "stale"];
  const shots = [["daily-a-a", daily], ["daily-a-b", daily], ["daily-b-a", daily], ["daily-b-b", daily], ["tow-a", tow], ["tow-b", tow]];
  const errors = [], corner = {};
  page.on("pageerror", e => errors.push(page.url() + ": " + e.message));
  page.on("response", r => { if (r.status() >= 400 && !r.url().endsWith("favicon.ico")) errors.push(r.url() + ": " + r.status()); });
  const cdp = await page.context().newCDPSession(page);
  await cdp.send("Network.enable");
  await cdp.send("Network.setCacheDisabled", { cacheDisabled: true });
  const open = async (url, w, h) => {
    await page.setViewportSize({ width: w, height: h });
    await page.goto(root + url);
    await page.evaluate(() => document.fonts.ready);
  };
  for (const [name, scenes] of shots) {
    for (const scene of scenes) {
      await open(`round-10/${name}.html?scene=${scene}&still=1`, 1920, 932);
      await page.screenshot({ path: `${out}${name}-${scene}.png` });
      for (const v of await page.evaluate(() => shroudViolations())) errors.push(`${name} ${scene}: shroud ${v}`);
      if (scene === "normal") corner[name] = await page.evaluate(b => cornerUse(b), (await page.screenshot()).toString("base64"));
    }
    await open(`round-10/${name}.html?view=physical&ruler=1`, 1920, 720);
    await page.screenshot({ path: `${out}${name}-physical.png` });
  }
  return { errors, corner };
}
