// Export the rendered geometry of the final layouts (Daily A option A, Towing A) as the QML build spec.
// Serve the repository root first: python -m http.server 8731 --bind 127.0.0.1
// Then run this file through the Playwright MCP browser_run_code_unsafe tool (filename argument).
// Output: design/round-42/geometry/<layout>-<scene>.json, one record per drawn element in canvas pixels (1920 x 932),
// and <layout>-<scene>.png, the same scene as a screenshot. Scenes page0 to page4 show each card page in order.
// The result lists page errors (an empty list passes).
async (page) => {
  const root = "http://127.0.0.1:8731/design/round-42/";
  const out = "design/round-42/geometry/";
  const errors = [];
  page.on("pageerror", e => errors.push(page.url() + ": " + e.message));
  await page.setViewportSize({ width: 1920, height: 932 });
  const cdp = await page.context().newCDPSession(page);
  await cdp.send("Network.enable");
  await cdp.send("Network.setCacheDisabled", { cacheDisabled: true });
  const scenes = [["stale", "scene=stale"], ["normal", ""], ["cruise", "scene=cruise"], ["busycruise", "scene=busycruise"],
    ["economy", "page=1"], ["hottrans", "scene=hottrans"], ["lowfuel", "scene=lowfuel"], ["crawl", "scene=crawl"],
    ["backing", "scene=backing"], ["turn", "turn=1"], ...[0, 1, 2, 3, 4].map(i => [`page${i}`, `page=${i}`])];
  const pages = [["daily-a", "daily-a.html", "opt=a"], ["tow-a", "tow-a.html", ""]];
  for (const [layout, file, opt] of pages) for (const [scene, q] of scenes) {
    await page.goto(`${root}${file}?${[opt, q].filter(Boolean).join("&")}`);
    await page.evaluate(() => document.fonts.ready);
    const json = await page.evaluate(() => {
      const canvas = document.getElementById("canvas");
      const c = canvas.getBoundingClientRect(), k = canvas.offsetWidth / c.width;
      const box = r => [r.left, r.top, r.width, r.height].map((v, i) => Math.round((v - (i === 0 ? c.left : i === 1 ? c.top : 0)) * k * 10) / 10);
      const keep = ["font-family", "font-size", "font-weight", "letter-spacing", "color", "opacity", "background-color",
        "border-top-width", "border-top-color", "border-radius", "text-align", "fill", "stroke", "stroke-width", "stroke-linecap",
        "stroke-dasharray", "transform", "visibility", "display"];
      const nodes = [];
      for (const e of canvas.querySelectorAll("*")) {
        const r = e.getBoundingClientRect();
        const s = getComputedStyle(e);
        if (s.display === "none" || (r.width === 0 && r.height === 0 && e.tagName !== "path")) continue;
        const n = { tag: e.tagName.toLowerCase(), cls: e.getAttribute("class") || "", box: box(r) };
        if (e.dataset.field) n.field = e.dataset.field;
        const own = [...e.childNodes].filter(t => t.nodeType === 3).map(t => t.textContent.trim()).join(" ").trim();
        if (own) n.text = own;
        if (e.tagName === "IMG") n.src = e.getAttribute("src");
        for (const a of ["d", "points", "cx", "cy", "r", "x1", "y1", "x2", "y2", "x", "y", "width", "height", "viewBox", "transform", "fill", "stroke"])
          if (e.namespaceURI === "http://www.w3.org/2000/svg" && e.hasAttribute(a)) (n.svg ??= {})[a] = e.getAttribute(a);
        const st = {};
        for (const p of keep) { const v = s.getPropertyValue(p); if (v && v !== "none" && v !== "normal" && v !== "auto" && v !== "0px" && v !== "rgba(0, 0, 0, 0)") st[p] = v; }
        n.style = st;
        nodes.push(n);
      }
      const s = state(LAYOUT === "tow" ? "tow" : "daily");
      return JSON.stringify({ url: location.pathname + location.search, canvas: [1920, 932], pages: s.pages, state: s, nodes }, null, 1);
    });
    const name = `${layout}-${scene}.json`;
    const dl = page.waitForEvent("download");
    await page.evaluate(([text, name]) => {
      const a = document.createElement("a");
      a.href = URL.createObjectURL(new Blob([text], { type: "application/json" }));
      a.download = name;
      document.body.appendChild(a);
      a.click();
    }, [json, name]);
    await (await dl).saveAs(out + name);
    await page.screenshot({ path: `${out}${layout}-${scene}.png` });
  }
  return errors;
}
