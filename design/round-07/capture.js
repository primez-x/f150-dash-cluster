// Capture the round 7 corner options and measure how much of each bottom corner holds visible content.
// Serve the repository root first: python -m http.server 8731 --bind 127.0.0.1
// Then run this file through the Playwright MCP browser_run_code_unsafe tool (filename argument).
// The result lists page errors and any content inside the shroud or screen-edge margin (an empty errors list passes),
// and the corner use (percent of the corner area, left / right) for each round 7 layout and its round 6 predecessor.
async (page) => {
  const root = "http://127.0.0.1:8731/design/";
  const out = "design/round-07/shots/";
  const shots = [
    ["daily-a-a", ["normal", "turn", "lowfuel", "stale"]],
    ["daily-a-b", ["normal", "turn", "lowfuel", "stale"]],
    ["daily-b-a", ["normal", "reserve", "warmcoolant", "stale"]],
    ["daily-b-b", ["normal", "reserve", "warmcoolant", "stale"]],
    ["tow-a", ["normal", "braking", "hottrans", "stale"]],
    ["tow-b", ["normal", "braking", "hottrans", "stale"]],
  ];
  const errors = [], use = {};
  page.on("pageerror", e => errors.push(page.url() + ": " + e.message));
  page.on("response", r => { if (r.status() >= 400 && !r.url().endsWith("favicon.ico")) errors.push(r.url() + ": " + r.status()); });
  const cdp = await page.context().newCDPSession(page);
  await cdp.send("Network.enable");
  await cdp.send("Network.setCacheDisabled", { cacheDisabled: true });
  const open = async (url, w, h) => {
    await page.setViewportSize({ width: w, height: h });
    await page.goto(root + url);
    await page.evaluate(() => document.fonts.ready);
  };
  const measure = async () => page.evaluate(b => cornerUse(b), (await page.screenshot()).toString("base64"));
  for (const [name, scenes] of shots) {
    for (const scene of scenes) {
      await open(`round-07/${name}.html?scene=${scene}&still=1`, 1920, 932);
      await page.screenshot({ path: `${out}${name}-${scene}.png` });
      for (const v of await page.evaluate(() => shroudViolations())) errors.push(`${name} ${scene}: shroud ${v}`);
      if (scene === "normal") use[name] = { round7: await measure() };
    }
    await open(`round-07/${name}.html?still=1&usable=1`, 1920, 932);
    await page.screenshot({ path: `${out}${name}-usable.png` });
    await open(`round-07/${name}.html?view=physical&ruler=1`, 1920, 720);
    await page.screenshot({ path: `${out}${name}-physical.png` });
    // The round 6 layout with the same name is the option this one replaces.
    await open(`round-06/${name}.html?still=1`, 1920, 932);
    use[name].round6 = await measure();
  }
  return { errors, use };
}
