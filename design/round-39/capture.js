// Capture round 39: Towing A speed gauge designs A (continuous bar) and B (tick comb).
// Serve the repository root first: python -m http.server 8731 --bind 127.0.0.1
// Then run this file through the Playwright MCP browser_run_code_unsafe tool (filename argument).
// The result lists page errors and any content inside the measured hidden areas or the 20 px margin (an empty list passes).
async (page) => {
  const root = "http://127.0.0.1:8731/design/round-39/";
  const out = "design/round-39/shots/";
  const errors = [];
  page.on("pageerror", e => errors.push(page.url() + ": " + e.message));
  page.on("response", r => { if (r.status() >= 400 && !r.url().endsWith("favicon.ico")) errors.push(r.url() + ": " + r.status()); });
  await page.setViewportSize({ width: 1920, height: 932 });
  // Load the kits from disk on every run: a cached kit would test old code.
  const cdp = await page.context().newCDPSession(page);
  await cdp.send("Network.enable");
  await cdp.send("Network.setCacheDisabled", { cacheDisabled: true });
  await cdp.send("Network.clearBrowserCache");
  // Each gauge: cruise off, set, adjusting (number over the arrow), on after a cancel (amber resume arrow), crawl, reversing,
  // braking, and 104 mph past the end of the scale.
  const scenes = [["off", ""], ["set", "scene=cruise"], ["adjust", "scene=cruiseadj"], ["resume", "scene=cruiseon"], ["crawl", "scene=crawl"],
    ["backing", "scene=backing"], ["braking", "scene=braking"], ["fast", "scene=fast"]];
  for (const g of ["a", "b"]) for (const [tag, q] of scenes) {
    await page.goto(`${root}tow-a.html?gauge=${g}&${q}&still=1`);
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: `${out}tow-a-${g}-${tag}.png` });
    for (const v of await page.evaluate(() => shroudViolations())) errors.push(`${g} ${tag}: ${v}`);
  }
  return errors;
}
