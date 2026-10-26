// Capture every round 4 design, scene, and physical preview.
// Serve the repository root first: python -m http.server 8731 --bind 127.0.0.1
// Then run this file through the Playwright MCP browser_run_code_unsafe tool (filename argument).
// The result lists page errors and any daily content inside the steering column shroud margin; an empty list passes.
// Towing A and B are superseded by round 5 and keep the pre-shroud layout.
async (page) => {
  const base = "http://127.0.0.1:8731/design/round-04/";
  const out = "design/round-04/shots/";
  const shots = [
    ["daily-a", ["normal", "cold", "turn", "lowtire", "warmcoolant", "hottrans"]],
    ["daily-b", ["normal", "cold", "turn", "lowfuel", "reserve", "warmcoolant", "hottrans"]],
    ["tow-a", ["normal", "hottrans", "turn"]],
    ["tow-b", ["normal", "hottrans", "turn"]],
  ];
  const errors = [];
  page.on("pageerror", e => errors.push(page.url() + ": " + e.message));
  page.on("response", r => { if (r.status() >= 400 && !r.url().endsWith("favicon.ico")) errors.push(r.url() + ": " + r.status()); });
  const cdp = await page.context().newCDPSession(page);
  await cdp.send("Network.enable");
  await cdp.send("Network.setCacheDisabled", { cacheDisabled: true });
  const shot = async (url, path, w, h) => {
    await page.setViewportSize({ width: w, height: h });
    await page.goto(base + url);
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: out + path });
    if (h === 932 && url.startsWith("daily")) for (const v of await page.evaluate(() => shroudViolations())) errors.push(`${url}: shroud ${v}`);
  };
  for (const [name, scenes] of shots) {
    for (const scene of scenes) await shot(`${name}.html?scene=${scene}&still=1`, `${name}-${scene}.png`, 1920, 932);
    await shot(`${name}.html?view=physical&ruler=1`, `${name}-physical.png`, 1920, 720);
  }
  for (const p of [1, 2, 3]) await shot(`daily-a.html?page=${p}`, `daily-a-page${p}.png`, 1920, 932);
  return errors;
}
