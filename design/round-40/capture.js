// Capture round 40: the locked Towing A, before (round 39 A) and after the corner stack alignment.
// Serve the repository root first: python -m http.server 8731 --bind 127.0.0.1
// Then run this file through the Playwright MCP browser_run_code_unsafe tool (filename argument).
// The result lists page errors and any content inside the measured hidden areas or the 20 px margin (an empty list passes).
async (page) => {
  const root = "http://127.0.0.1:8731/design/round-40/";
  const out = "design/round-40/shots/";
  const errors = [];
  page.on("pageerror", e => errors.push(page.url() + ": " + e.message));
  page.on("response", r => { if (r.status() >= 400 && !r.url().endsWith("favicon.ico")) errors.push(r.url() + ": " + r.status()); });
  await page.setViewportSize({ width: 1920, height: 932 });
  // Load the kits from disk on every run: a cached kit would test old code.
  const cdp = await page.context().newCDPSession(page);
  await cdp.send("Network.enable");
  await cdp.send("Network.setCacheDisabled", { cacheDisabled: true });
  await cdp.send("Network.clearBrowserCache");
  // Before (round 39 A) and after: cruise set, trailer braking, low fuel, crawl (no left stack), reversing, 4H, and 4L with the rear locker.
  const scenes = [["set", "scene=cruise"], ["braking", "scene=braking"], ["lowfuel", "scene=lowfuel"], ["crawl", "scene=crawl"],
    ["backing", "scene=backing"], ["4h", "scene=d4h"], ["locker", "scene=locker"]];
  for (const [tag, q] of scenes) for (const [g, url] of [["before", `${root}../round-39/tow-a.html?gauge=a&${q}&still=1`], ["after", `${root}tow-a.html?${q}&still=1`]]) {
    await page.goto(url);
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: `${out}tow-a-${g}-${tag}.png` });
    for (const v of await page.evaluate(() => shroudViolations())) errors.push(`${g} ${tag}: ${v}`);
  }
  return errors;
}
