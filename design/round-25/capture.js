// Capture round 25: Towing A with two equal cards, gear option A and B.
// Serve the repository root first: python -m http.server 8731 --bind 127.0.0.1
// Then run this file through the Playwright MCP browser_run_code_unsafe tool (filename argument).
// The result lists page errors and any content inside the measured hidden areas or the 20 px margin (an empty list passes).
async (page) => {
  const root = "http://127.0.0.1:8731/design/round-25/";
  const out = "design/round-25/shots/";
  const errors = [];
  page.on("pageerror", e => errors.push(page.url() + ": " + e.message));
  page.on("response", r => { if (r.status() >= 400 && !r.url().endsWith("favicon.ico")) errors.push(r.url() + ": " + r.status()); });
  await page.setViewportSize({ width: 1920, height: 932 });
  // Load the kits from disk on every run: a cached kit would test old code.
  const cdp = await page.context().newCDPSession(page);
  await cdp.send("Network.enable");
  await cdp.send("Network.setCacheDisabled", { cacheDisabled: true });
  await cdp.send("Network.clearBrowserCache");
  const scenes = [["normal", ""], ["cruise", "scene=cruise"], ["busycruise", "scene=busycruise"], ["braking", "scene=braking"],
    ["hottrans", "scene=hottrans"], ["crawl", "scene=crawl"], ["tires", "page=1"], ["engine", "page=2"], ["level", "page=3"],
    ["levelb", "page=3&level=b"], ["trip", "page=4"], ["lowtire", "scene=lowtire"], ["d4l", "scene=d4l"]];
  for (const gear of ["a", "b"]) for (const [tag, q] of scenes) {
    await page.goto(`${root}tow-a.html?gear=${gear}&${q}&still=1`);
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: `${out}tow-a-${gear}-${tag}.png` });
    for (const v of await page.evaluate(() => shroudViolations())) errors.push(`${gear} ${tag}: ${v}`);
  }
  return errors;
}
