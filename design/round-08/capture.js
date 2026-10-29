// Capture the round 8 layouts and measure visual competition against round 7 at the normal scene.
// Serve the repository root first: python -m http.server 8731 --bind 127.0.0.1
// Then run this file through the Playwright MCP browser_run_code_unsafe tool (filename argument).
// The result lists page errors and any content inside the shroud or screen-edge margin (an empty errors list passes),
// and for each layout in round 7 and round 8:
//   accent   percent of the canvas in the accent colour (bright pixels only)
//   warning  percent of the canvas in bright red or amber (zero is the target at rest, apart from the RPM redline)
//   sizes    the number of distinct font sizes
//   repeats  values shown in more than one place (tire pressures and the speed digits excluded)
//   corner   corner use, left / right (cornerUse in kit4.js)
async (page) => {
  const root = "http://127.0.0.1:8731/design/";
  const out = "design/round-08/shots/";
  const shots = [
    ["daily-a-a", ["normal", "turn", "lowfuel", "stale"]],
    ["daily-a-b", ["normal", "turn", "lowfuel", "stale"]],
    ["daily-b-a", ["normal", "reserve", "warmcoolant", "stale"]],
    ["daily-b-b", ["normal", "reserve", "warmcoolant", "stale"]],
    ["tow-a", ["normal", "braking", "hottrans", "stale"]],
    ["tow-b", ["normal", "braking", "hottrans", "stale"]],
  ];
  const errors = [], metrics = {};
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
  const measure = async () => page.evaluate(async png => {
    const img = new Image(); img.src = `data:image/png;base64,${png}`; await img.decode();
    const c = document.createElement("canvas"); c.width = img.width; c.height = img.height;
    const ctx = c.getContext("2d"); ctx.drawImage(img, 0, 0);
    const d = ctx.getImageData(0, 0, img.width, img.height).data;
    let n = 0, accent = 0, warning = 0;
    for (let i = 0; i < d.length; i += 16) {
      const r = d[i], g = d[i + 1], b = d[i + 2]; n++;
      if (Math.max(r, g, b) <= 90) continue;
      if (g - r > 50 && b - r > 40) accent++;
      if (r - Math.max(g, b) > 50) warning++;
    }
    const sizes = new Set(), values = {};
    for (const el of document.querySelectorAll("#canvas *")) {
      if (el.closest("#physical-label, .turn")) continue;
      const own = [...el.childNodes].some(t => t.nodeType === 3 && t.textContent.trim());
      if (!own || !el.getClientRects().length || getComputedStyle(el).visibility === "hidden") continue;
      sizes.add(Math.round(parseFloat(getComputedStyle(el).fontSize)));
      const v = [...el.childNodes].filter(t => t.nodeType === 3).map(t => t.textContent.trim()).join("");
      if (/^[−-]?\d[\d.,:]*$/.test(v) && !el.closest("svg, .tp, .speed")) values[v] = (values[v] || 0) + 1;
    }
    return { accent: +(100 * accent / n).toFixed(2), warning: +(100 * warning / n).toFixed(2), sizes: sizes.size,
      repeats: Object.entries(values).filter(([, k]) => k > 1).map(([v, k]) => `${v} ×${k}`), corner: await cornerUse(png) };
  }, (await page.screenshot()).toString("base64"));
  for (const [name, scenes] of shots) {
    for (const scene of scenes) {
      await open(`round-08/${name}.html?scene=${scene}&still=1`, 1920, 932);
      await page.screenshot({ path: `${out}${name}-${scene}.png` });
      for (const v of await page.evaluate(() => shroudViolations())) errors.push(`${name} ${scene}: shroud ${v}`);
      if (scene === "normal") metrics[name] = { round8: await measure() };
    }
    await open(`round-08/${name}.html?view=physical&ruler=1`, 1920, 720);
    await page.screenshot({ path: `${out}${name}-physical.png` });
    await open(`round-07/${name}.html?still=1`, 1920, 932);
    metrics[name].round7 = await measure();
  }
  return { errors, metrics };
}
