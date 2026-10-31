// Capture round 38: Towing A with the speed rail at bottom center and fuel bottom right; trailer brake options A, B, C.
// Serve the repository root first: python -m http.server 8731 --bind 127.0.0.1
// Then run this file through the Playwright MCP browser_run_code_unsafe tool (filename argument).
// The result lists page errors and any content inside the measured hidden areas or the 20 px margin (an empty list passes).
async (page) => {
  const root = "http://127.0.0.1:8731/design/round-38/";
  const out = "design/round-38/shots/";
  const errors = [];
  page.on("pageerror", e => errors.push(page.url() + ": " + e.message));
  page.on("response", r => { if (r.status() >= 400 && !r.url().endsWith("favicon.ico")) errors.push(r.url() + ": " + r.status()); });
  await page.setViewportSize({ width: 1920, height: 932 });
  // Load the kits from disk on every run: a cached kit would test old code.
  const cdp = await page.context().newCDPSession(page);
  await cdp.send("Network.enable");
  await cdp.send("Network.setCacheDisabled", { cacheDisabled: true });
  await cdp.send("Network.clearBrowserCache");
  // Shared scenes with brake A: cruise off, set, adjusting (number over the arrow), on after a cancel (amber resume arrow),
  // crawl with the wheel turned, reversing, an alert, and low fuel. Then each brake option at rest, braking, and braking at speed.
  const shared = [["off", ""], ["set", "scene=cruise"], ["adjust", "scene=cruiseadj"], ["resume", "scene=cruiseon"], ["crawl", "scene=crawl"],
    ["backing", "scene=backing"], ["alert", "scene=hotcht"], ["lowfuel", "scene=lowfuel"]].map(([t, q]) => ["a", t, q]);
  const brake = ["a", "b", "c"].flatMap(b => [[b, "rest", "scene=cruise"], [b, "braking", "scene=braking"], [b, "brakefast", "scene=brakefast"]]);
  for (const [b, tag, q] of [...shared, ...brake]) {
    await page.goto(`${root}tow-a.html?brake=${b}&${q}&still=1`);
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: `${out}tow-a-${b}-${tag}.png` });
    for (const v of await page.evaluate(() => shroudViolations())) errors.push(`${b} ${tag}: ${v}`);
  }
  return errors;
}
