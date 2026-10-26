// Capture every round 1 mock, physical preview, and cruise state.
// Serve the repository root first: python -m http.server 8731 --bind 127.0.0.1
// Then run this file through the Playwright MCP browser_run_code_unsafe tool (filename argument).
async (page) => {
  const base = "http://127.0.0.1:8731/design/round-01/";
  const out = "design/round-01/shots/";
  const mocks = ["driving-a", "driving-b", "offroad-a", "offroad-b"];
  const states = ["available", "active", "set", "acc", "lim"];
  const done = [];
  const cdp = await page.context().newCDPSession(page);
  await cdp.send("Network.setCacheDisabled", { cacheDisabled: true });
  for (const m of mocks) {
    await page.setViewportSize({ width: 1920, height: 932 });
    await page.goto(base + m + ".html");
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: out + m + ".png" });
    done.push(m);
    await page.setViewportSize({ width: 1920, height: 720 });
    await page.goto(base + m + ".html?view=physical");
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: out + m + "-physical.png" });
    done.push(m + "-physical");
  }
  await page.setViewportSize({ width: 1920, height: 932 });
  for (const letter of ["a", "b"]) {
    for (const s of states) {
      await page.goto(base + "driving-" + letter + ".html?cruise=" + s);
      await page.evaluate(() => document.fonts.ready);
      await page.locator(".cruise").screenshot({ path: out + "cruise-" + letter + "-" + s + ".png" });
      done.push("cruise-" + letter + "-" + s);
    }
  }
  return done;
}
