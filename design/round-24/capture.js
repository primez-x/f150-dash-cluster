// Capture round 24: wider spacing and the odometer in a top corner, with side stacks A and B.
// Serve the repository root first: python -m http.server 8731 --bind 127.0.0.1
// Then run this file through the Playwright MCP browser_run_code_unsafe tool (filename argument).
// The result lists page errors and any content inside the measured hidden areas or the 20 px margin (an empty list passes).
// The odometer may sit behind the wheel rim (kit24.js), but not in the arch or the margin.
async (page) => {
  const root = "http://127.0.0.1:8731/design/round-24/";
  const out = "design/round-24/shots/";
  const errors = [];
  page.on("pageerror", e => errors.push(page.url() + ": " + e.message));
  page.on("response", r => { if (r.status() >= 400 && !r.url().endsWith("favicon.ico")) errors.push(r.url() + ": " + r.status()); });
  await page.setViewportSize({ width: 1920, height: 932 });
  // Load the kits from disk on every run: a cached kit would test old code.
  const cdp = await page.context().newCDPSession(page);
  await cdp.send("Network.enable");
  await cdp.send("Network.setCacheDisabled", { cacheDisabled: true });
  await cdp.send("Network.clearBrowserCache");
  const shots = [];
  for (const side of ["a", "b"]) {
    for (const spread of ["a", "b"]) for (const [tag, q] of [["normal", ""], ["busycruise", "scene=busycruise"], ["crawl", "scene=crawl"], ["level", "page=3"]])
      shots.push([`tow-a-${side}${spread}-${tag}`, `tow-a.html?side=${side}&spread=${spread}&${q}`]);
    shots.push([`tow-b-${side}a-level`, `tow-b.html?side=${side}&spread=a&page=3`]);
    for (const name of ["daily-a-a", "daily-a-b", "daily-b-a", "daily-b-b"]) shots.push([`${name}-${side}-normal`, `${name}.html?side=${side}`]);
    shots.push([`daily-a-a-${side}-busycruise`, `daily-a-a.html?side=${side}&scene=busycruise`]);
    shots.push([`daily-b-a-${side}-busycruise`, `daily-b-a.html?side=${side}&scene=busycruise`]);
  }
  for (const [name, url] of shots) {
    await page.goto(`${root}${url}&still=1`);
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: `${out}${name}.png` });
    for (const v of await page.evaluate(() => shroudViolations())) errors.push(`${name}: ${v}`);
  }
  return errors;
}
