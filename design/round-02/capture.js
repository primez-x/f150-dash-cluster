// Capture every round 2 mock, physical preview, and state strips.
// Serve the repository root first: python -m http.server 8731 --bind 127.0.0.1
// Then run this file through the Playwright MCP browser_run_code_unsafe tool (filename argument).
async (page) => {
  const base = "http://127.0.0.1:8731/design/round-02/";
  const out = "design/round-02/shots/";
  const mocks = ["daily-a", "daily-b", "tow-a", "tow-b", "sport-a", "sport-b", "race-a", "race-b", "offroad"];
  const errors = [];
  page.on("pageerror", e => errors.push(page.url() + ": " + e.message));
  const cdp = await page.context().newCDPSession(page);
  await cdp.send("Network.enable");
  await cdp.send("Network.setCacheDisabled", { cacheDisabled: true });
  const shot = async (url, path, w, h) => {
    await page.setViewportSize({ width: w, height: h });
    const r = await page.goto(base + url);
    if (!r || !r.ok()) { errors.push(url + ": missing"); return; }
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: out + path });
  };
  for (const m of mocks) {
    await shot(m + ".html", m + ".png", 1920, 932);
    await shot(m + ".html?view=physical", m + "-physical.png", 1920, 720);
  }
  await shot("tow-b.html?fuel=9", "tow-b-lowfuel.png", 1920, 932);
  await shot("drivetrain.html", "drivetrain.png", 1920, 420);
  return errors;
}
