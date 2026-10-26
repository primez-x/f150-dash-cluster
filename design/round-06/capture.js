// Capture the round 6 corner options and the usable-area diagram.
// Serve the repository root first: python -m http.server 8731 --bind 127.0.0.1
// Then run this file through the Playwright MCP browser_run_code_unsafe tool (filename argument).
// The result lists page errors and any content inside the shroud or screen-edge margin; an empty list passes.
async (page) => {
  const base = "http://127.0.0.1:8731/design/round-06/";
  const out = "design/round-06/shots/";
  const shots = [
    ["daily-a-a", ["normal", "turn", "lowfuel", "lowtire", "stale"]],
    ["daily-a-b", ["normal", "turn", "lowfuel", "lowtire", "stale"]],
    ["daily-b-a", ["normal", "turn", "reserve", "stale"]],
    ["daily-b-b", ["normal", "turn", "reserve", "stale"]],
    ["tow-a", ["normal", "turn", "braking", "hottrans", "stale"]],
    ["tow-b", ["normal", "turn", "braking", "hottrans", "stale"]],
  ];
  const errors = [];
  page.on("pageerror", e => errors.push(page.url() + ": " + e.message));
  page.on("response", r => { if (r.status() >= 400 && !r.url().endsWith("favicon.ico")) errors.push(r.url() + ": " + r.status()); });
  const cdp = await page.context().newCDPSession(page);
  await cdp.send("Network.enable");
  await cdp.send("Network.setCacheDisabled", { cacheDisabled: true });
  const shot = async (url, path, w, h, check = true) => {
    await page.setViewportSize({ width: w, height: h });
    await page.goto(base + url);
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: out + path });
    if (check && h === 932) for (const v of await page.evaluate(() => shroudViolations())) errors.push(`${url}: shroud ${v}`);
  };
  await shot("usable.html", "usable.png", 1920, 932, false);
  for (const [name, scenes] of shots) {
    for (const scene of scenes) await shot(`${name}.html?scene=${scene}&still=1`, `${name}-${scene}.png`, 1920, 932);
    await shot(`${name}.html?view=physical&ruler=1`, `${name}-physical.png`, 1920, 720);
  }
  return errors;
}
