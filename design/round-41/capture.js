// Capture round 41: frame strips of each motion on the locked Towing A, held on the loop clock (kit41.js at41).
// Serve the repository root first: python -m http.server 8731 --bind 127.0.0.1
// Then run this file through the Playwright MCP browser_run_code_unsafe tool (filename argument).
// The result lists page errors and any content inside the measured hidden areas or the 20 px margin (an empty list passes).
async (page) => {
  const root = "http://127.0.0.1:8731/design/round-41/";
  const out = "design/round-41/shots/";
  const errors = [];
  page.on("pageerror", e => errors.push(page.url() + ": " + e.message));
  page.on("response", r => { if (r.status() >= 400 && !r.url().endsWith("favicon.ico")) errors.push(r.url() + ": " + r.status()); });
  await page.setViewportSize({ width: 1920, height: 932 });
  // Load the kits from disk on every run: a cached kit would test old code.
  const cdp = await page.context().newCDPSession(page);
  await cdp.send("Network.enable");
  await cdp.send("Network.setCacheDisabled", { cacheDisabled: true });
  await cdp.send("Network.clearBrowserCache");
  const card = { x: 1380, y: 250, width: 540, height: 334 }, bar = { x: 860, y: 440, width: 380, height: 300 };
  // [name, page change option, event time (ms), frame ages (ms), clip]
  const strips = [
    ["page-a", "a", 1200, [0, 60, 120, 200, 320], card],
    ["page-b", "b", 1200, [0, 60, 120, 200, 320], card],
    ["brake-jump", "a", 6000, [0, 60, 120, 200, 320], card],
    ["set", "a", 3000, [0, 40, 80, 120, 500], bar],
    ["set-fade", "a", 3500, [3000, 3150, 3300, 3450, 3600], bar],
    ["cancel", "a", 6000, [0, 500, 1000, 1400, 1800], bar],
    ["alert-in", "a", 13000, [0, 30, 60, 90, 120], { x: 520, y: 70, width: 880, height: 100 }],
    ["alert-out", "a", 17000, [0, 50, 100, 150, 200], { x: 520, y: 70, width: 880, height: 100 }],
    ["drive", "a", 18000, [0, 50, 100, 150, 200], { x: 1700, y: 680, width: 200, height: 60 }],
    ["steer", "a", 19000, [0, 500, 1000, 1500, 2000], { x: 700, y: 170, width: 520, height: 100 }],
  ];
  for (const pg of ["b", "a"]) {
    await page.goto(`${root}tow-motion.html?pg=${pg}&t=0`);
    await page.evaluate(() => document.fonts.ready);
    for (const [name, p, t0, ages, clip] of strips.filter(x => x[1] === pg))
      for (const [i, age] of ages.entries()) {
        await page.evaluate(t => at41(t), t0 + age);
        await page.screenshot({ path: `${out}m41-${name}-${i}.png`, clip });
        for (const v of await page.evaluate(() => shroudViolations())) errors.push(`${name} +${age}: ${v}`);
      }
  }
  // Full frames (page change A): the page slide, the trailer brake jump with the cruise cancel, the alert with the glow,
  // and the crawl turn with the boost and rpm stack on.
  for (const t of [1300, 6100, 13300, 23000]) {
    await page.evaluate(t => at41(t), t);
    await page.screenshot({ path: `${out}m41-full-${t}.png` });
  }
  return errors;
}
