// Capture round 43: the alert panel from the top edge, options A and B, on Daily A and Towing A.
// Serve the repository root first: python -m http.server 8731 --bind 127.0.0.1
// Then run this file through the Playwright MCP browser_run_code_unsafe tool (filename argument).
// The result lists page errors and any content inside the measured hidden areas or the 20 px margin (an empty list passes).
async (page) => {
  const root = "http://127.0.0.1:8731/design/round-43/";
  const out = "design/round-43/shots/";
  const errors = [];
  page.on("pageerror", e => errors.push(page.url() + ": " + e.message));
  page.on("response", r => { if (r.status() >= 400 && !r.url().endsWith("favicon.ico")) errors.push(r.url() + ": " + r.status()); });
  await page.setViewportSize({ width: 1920, height: 932 });
  const cdp = await page.context().newCDPSession(page);
  await cdp.send("Network.enable");
  await cdp.send("Network.setCacheDisabled", { cacheDisabled: true });
  await cdp.send("Network.clearBrowserCache");
  // Scenes: a derived warning (hot transmission), a derived caution (low fuel), a short and a long adapter message.
  const scenes = [["hottrans", "scene=hottrans"], ["lowfuel", "scene=lowfuel"], ["towhaul", "scene=towhaul"], ["notify", "scene=notify"]];
  const shots = [];
  for (const opt of ["a", "b"]) for (const file of ["daily-a", "tow-a"]) for (const [n, q] of scenes)
    shots.push([file, `alert=${opt}&still&${q}`, `${file}-${opt}-${n}`]);
  // Slide-in strip on Towing A, hot transmission: 0, 70, 140, 210, 280 ms of the 280 ms OutCubic motion.
  for (const opt of ["a", "b"]) for (const [i, p] of [0, .25, .5, .75, 1].entries())
    shots.push(["tow-a", `alert=${opt}&still&scene=hottrans&slide=${p}`, `slide-${opt}-${i}`]);
  for (const [file, q, name] of shots) {
    await page.goto(`${root}${file}.html?${q}`);
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: `${out}${name}.png` });
    // The slide frames show the panel part-way behind the top edge on purpose.
    if (!name.startsWith("slide-") || name.endsWith("-4"))
      for (const v of await page.evaluate(() => shroudViolations())) errors.push(`${name}: ${v}`);
  }
  return errors;
}
