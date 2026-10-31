// Capture round 36: Towing A with one outer alignment line; round 35 B (before) beside round 36 (after).
// Serve the repository root first: python -m http.server 8731 --bind 127.0.0.1
// Then run this file through the Playwright MCP browser_run_code_unsafe tool (filename argument).
// The result lists page errors and any content inside the measured hidden areas or the 20 px margin (an empty list passes).
async (page) => {
  const root = "http://127.0.0.1:8731/design/";
  const out = "design/round-36/shots/";
  const errors = [];
  page.on("pageerror", e => errors.push(page.url() + ": " + e.message));
  page.on("response", r => { if (r.status() >= 400 && !r.url().endsWith("favicon.ico")) errors.push(r.url() + ": " + r.status()); });
  await page.setViewportSize({ width: 1920, height: 932 });
  // Load the kits from disk on every run: a cached kit would test old code.
  const cdp = await page.context().newCDPSession(page);
  await cdp.send("Network.enable");
  await cdp.send("Network.setCacheDisabled", { cacheDisabled: true });
  await cdp.send("Network.clearBrowserCache");
  // Cruise, a hot head temperature (every temperature shown), cold start, the engine page, the tire page, and reversing.
  const scenes = [["normal", ""], ["hotcht", "scene=hotcht"], ["cold", "scene=cold"], ["engine", "page=2"], ["tires", "page=1"], ["backing", "scene=backing"]];
  for (const [ver, dir] of [["before", "round-35"], ["after", "round-36"]]) for (const [tag, q] of scenes) {
    await page.goto(`${root}${dir}/tow-a.html?fit=b&${q}&still=1`);
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: `${out}tow-a-${ver}-${tag}.png` });
    for (const v of await page.evaluate(() => shroudViolations())) errors.push(`${ver} ${tag}: ${v}`);
  }
  return errors;
}
