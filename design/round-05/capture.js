// Capture the round 5 towing hybrid scenes and physical preview.
// Serve the repository root first: python -m http.server 8731 --bind 127.0.0.1
// Then run this file through the Playwright MCP browser_run_code_unsafe tool (filename argument).
// The result lists page errors and any content inside the steering column shroud margin; an empty list passes.
async (page) => {
  const base = "http://127.0.0.1:8731/design/round-05/";
  const out = "design/round-05/shots/";
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
    if (h === 932) for (const v of await page.evaluate(() => shroudViolations())) errors.push(`${url}: shroud ${v}`);
  };
  for (const scene of ["normal", "cruise", "braking", "warmcoolant", "hottrans", "lowfuel", "reserve", "turn", "lowtire", "stale"]) await shot(`tow.html?scene=${scene}&still=1`, `tow-${scene}.png`, 1920, 932);
  await shot("tow.html?view=physical&ruler=1", "tow-physical.png", 1920, 720);
  await shot("tow.html?night=1&still=1", "tow-night.png", 1920, 932);
  for (const p of [1, 2, 3]) await shot(`tow.html?page=${p}&still=1`, `tow-page${p}.png`, 1920, 932);
  for (const accent of ["teal", "ice", "blue", "slate"]) {
    await shot(`tow.html?accent=${accent}&still=1`, `accent-${accent}-tow.png`, 1920, 932);
    await shot(`../round-04/daily-a.html?accent=${accent}&still=1`, `accent-${accent}-daily-a.png`, 1920, 932);
    await shot(`../round-04/daily-b.html?accent=${accent}&still=1`, `accent-${accent}-daily-b.png`, 1920, 932);
  }
  return errors;
}
