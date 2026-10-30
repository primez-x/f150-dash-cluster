// Capture round 22: every open Daily and Towing option on the measured visible area, with top bar A and B.
// Serve the repository root first: python -m http.server 8731 --bind 127.0.0.1
// Then run this file through the Playwright MCP browser_run_code_unsafe tool (filename argument).
// The result lists page errors and any content inside the measured hidden areas or the 20 px margin (an empty list passes).
async (page) => {
  const root = "http://127.0.0.1:8731/design/round-22/";
  const out = "design/round-22/shots/";
  const errors = [];
  page.on("pageerror", e => errors.push(page.url() + ": " + e.message));
  page.on("response", r => { if (r.status() >= 400 && !r.url().endsWith("favicon.ico")) errors.push(r.url() + ": " + r.status()); });
  await page.setViewportSize({ width: 1920, height: 932 });
  const shots = {
    "daily-a-a": [["normal", ""], ["cruise", "scene=cruise"], ["busy", "scene=busy"]],
    "daily-a-b": [["normal", ""]],
    "daily-b-a": [["normal", ""]],
    "daily-b-b": [["normal", ""]],
    "tow-a": [["normal", ""], ["level", "page=3"], ["crawl", "scene=crawl"], ["cruise", "scene=cruise"], ["busy", "scene=busy"], ["clockzone", "clock=zone"]],
    "tow-b": [["level", "page=3"]],
  };
  for (const [name, list] of Object.entries(shots)) for (const top of ["a", "b"]) for (const [tag, q] of list) {
    await page.goto(`${root}${name}.html?top=${top}&${q}&still=1`);
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: `${out}${name}-${top}-${tag}.png` });
    for (const v of await page.evaluate(() => shroudViolations())) errors.push(`${name} ${top} ${tag}: ${v}`);
  }
  return errors;
}
