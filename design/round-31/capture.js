// Capture round 31: Towing A with the gear in the corner (round 30 B) and the reverse gear large in the center.
// The gear and the drive mode use the locked corner place (round 30 B, the default).
// Serve the repository root first: python -m http.server 8731 --bind 127.0.0.1
// Then run this file through the Playwright MCP browser_run_code_unsafe tool (filename argument).
// The result lists page errors and any content inside the measured hidden areas or the 20 px margin (an empty list passes).
async (page) => {
  const root = "http://127.0.0.1:8731/design/round-31/";
  const out = "design/round-31/shots/";
  const errors = [];
  page.on("pageerror", e => errors.push(page.url() + ": " + e.message));
  page.on("response", r => { if (r.status() >= 400 && !r.url().endsWith("favicon.ico")) errors.push(r.url() + ": " + r.status()); });
  await page.setViewportSize({ width: 1920, height: 932 });
  // Load the kits from disk on every run: a cached kit would test old code.
  const cdp = await page.context().newCDPSession(page);
  await cdp.send("Network.enable");
  await cdp.send("Network.setCacheDisabled", { cacheDisabled: true });
  await cdp.send("Network.clearBrowserCache");
  // Scenes that change the gear, the drive mode, or the bottom right: reverse, cruise, braking (BRAKING label), 4L, rear locker, crawl.
  const scenes = [["normal", ""], ["backing", "scene=backing"], ["busycruise", "scene=busycruise"], ["braking", "scene=braking"], ["d4l", "scene=d4l"],
    ["locker", "scene=locker"], ["crawl", "scene=crawl"], ["hottrans", "scene=hottrans"], ["tires", "page=1"]];
  for (const [tag, q] of scenes) {
    await page.goto(`${root}tow-a.html?${q}&still=1`);
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: `${out}tow-a-${tag}.png` });
    for (const v of await page.evaluate(() => shroudViolations())) errors.push(`${tag}: ${v}`);
  }
  return errors;
}
