// Capture the round 5 towing hybrid scenes and physical preview.
// Serve the repository root first: python -m http.server 8731 --bind 127.0.0.1
// Then run this file through the Playwright MCP browser_run_code_unsafe tool (filename argument).
async (page) => {
  const base = "http://127.0.0.1:8731/design/round-05/";
  const out = "design/round-05/shots/";
  const errors = [];
  page.on("pageerror", e => errors.push(page.url() + ": " + e.message));
  page.on("response", r => { if (r.status() >= 400 && !r.url().endsWith("favicon.ico")) errors.push(r.url() + ": " + r.status()); });
  const cdp = await page.context().newCDPSession(page);
  await cdp.send("Network.setCacheDisabled", { cacheDisabled: true });
  const shot = async (url, path, w, h) => {
    await page.setViewportSize({ width: w, height: h });
    await page.goto(base + url);
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: out + path });
  };
  for (const scene of ["normal", "braking", "hottrans", "turn", "lowtire"]) await shot(`tow.html?scene=${scene}&still=1`, `tow-${scene}.png`, 1920, 932);
  await shot("tow.html?view=physical&ruler=1", "tow-physical.png", 1920, 720);
  return errors;
}
