// Capture round 44: alert panel A with the padding fix, overspeed options A and B, set-speed direction options A and B.
// Serve the repository root first: python -m http.server 8731 --bind 127.0.0.1
// Then run this file through the Playwright MCP browser_run_code_unsafe tool (filename argument).
// The result lists page errors and any content inside the measured hidden areas or the 20 px margin (an empty list passes).
async (page) => {
  const root = "http://127.0.0.1:8731/design/round-44/";
  const out = "design/round-44/shots/";
  const errors = [];
  page.on("pageerror", e => errors.push(page.url() + ": " + e.message));
  page.on("response", r => { if (r.status() >= 400 && !r.url().endsWith("favicon.ico")) errors.push(r.url() + ": " + r.status()); });
  await page.setViewportSize({ width: 1920, height: 932 });
  const cdp = await page.context().newCDPSession(page);
  await cdp.send("Network.enable");
  await cdp.send("Network.setCacheDisabled", { cacheDisabled: true });
  await cdp.send("Network.clearBrowserCache");
  const shots = [];
  for (const [file, scene] of [["tow-a", "hottrans"], ["tow-a", "towhaul"], ["daily-a", "lowfuel"], ["daily-a", "notify"]])
    shots.push([file, `alert=a&still&scene=${scene}`, `alert-${file}-${scene}`]);
  for (const opt of ["a", "b"]) for (const file of ["daily-a", "tow-a"]) {
    shots.push([file, `over=${opt}&still&scene=overspeed`, `over-${opt}-${file}`]);
    for (const scene of ["setup", "setdown"]) shots.push([file, `dir=${opt}&still&scene=${scene}`, `dir-${opt}-${file}-${scene}`]);
  }
  for (const [file, q, name] of shots) {
    await page.goto(`${root}${file}.html?${q}`);
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: `${out}${name}.png` });
    for (const v of await page.evaluate(() => shroudViolations())) errors.push(`${name}: ${v}`);
  }
  return errors;
}
