// Capture round 42: Daily A and Daily B, options A and B, and the final Towing A.
// Serve the repository root first: python -m http.server 8731 --bind 127.0.0.1
// Then run this file through the Playwright MCP browser_run_code_unsafe tool (filename argument).
// The result lists page errors and any content inside the measured hidden areas or the 20 px margin (an empty list passes).
async (page) => {
  const root = "http://127.0.0.1:8731/design/round-42/";
  const out = "design/round-42/shots/";
  const errors = [];
  page.on("pageerror", e => errors.push(page.url() + ": " + e.message));
  page.on("response", r => { if (r.status() >= 400 && !r.url().endsWith("favicon.ico")) errors.push(r.url() + ": " + r.status()); });
  await page.setViewportSize({ width: 1920, height: 932 });
  // Load the kits from disk on every run: a cached kit would test old code.
  const cdp = await page.context().newCDPSession(page);
  await cdp.send("Network.enable");
  await cdp.send("Network.setCacheDisabled", { cacheDisabled: true });
  await cdp.send("Network.clearBrowserCache");
  // Daily scenes: highway, cruise set, six warning lights with cruise, the economy page, a hot transmission, low fuel,
  // crawl with the wheel turned, reversing, and no data. Option B is one page on both daily layouts (daily-a.html?opt=b).
  const daily = [["normal", ""], ["cruise", "scene=cruise"], ["busycruise", "scene=busycruise"], ["economy", "page=1"], ["hottrans", "scene=hottrans"],
    ["lowfuel", "scene=lowfuel"], ["crawl", "scene=crawl"], ["backing", "scene=backing"], ["stale", "scene=stale"]];
  const shots = [
    ...daily.map(([n, q]) => ["daily-a", "opt=a", `daily-a-a-${n}`, q]),
    ...daily.map(([n, q]) => ["daily-b", "opt=a", `daily-b-a-${n}`, q]),
    ...daily.map(([n, q]) => ["daily-a", "opt=b", `daily-ab-b-${n}`, q]),
    ...[["normal", ""], ["crawl", "scene=crawl"], ["backing", "scene=backing"]].map(([n, q]) => ["tow-a", "", `tow-a-${n}`, q]),
  ];
  for (const [file, opt, name, q] of shots) {
    await page.goto(`${root}${file}.html?${[opt, q].filter(Boolean).join("&")}`);
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: `${out}${name}.png` });
    for (const v of await page.evaluate(() => shroudViolations())) errors.push(`${name}: ${v}`);
  }
  return errors;
}
