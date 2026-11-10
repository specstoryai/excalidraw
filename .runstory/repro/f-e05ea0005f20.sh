#!/bin/sh
# requires: env OSS_STATS_TOKEN
# Deleted frame child above the frame makes "Bring forward" (Ctrl+]) jump an
# unrelated element past other elements, up to the deleted child's slot.
APP_URL="${APP_URL:-http://[::1]:13001/}"; export APP_URL
if [ -z "$CHROMIUM" ]; then CHROMIUM="$(command -v chromium || command -v chromium-browser || true)"; fi
export CHROMIUM
MODE=fwd; export MODE
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/scene.excalidraw" <<'SCENE'
{"type": "excalidraw", "version": 2, "source": "test", "elements": [{"id": "ellipseE", "type": "ellipse", "x": 800, "y": 150, "width": 100, "height": 100, "angle": 0, "strokeColor": "#1971c2", "backgroundColor": "transparent", "fillStyle": "solid", "strokeWidth": 2, "strokeStyle": "solid", "roughness": 0, "opacity": 100, "groupIds": [], "frameId": null, "index": "a0", "roundness": null, "seed": 4, "version": 1, "versionNonce": 4, "isDeleted": false, "boundElements": null, "updated": 1, "link": null, "locked": false}, {"id": "childB", "type": "rectangle", "x": 120, "y": 250, "width": 60, "height": 60, "angle": 0, "strokeColor": "#1e1e1e", "backgroundColor": "transparent", "fillStyle": "solid", "strokeWidth": 2, "strokeStyle": "solid", "roughness": 0, "opacity": 100, "groupIds": [], "frameId": "frameF", "index": "a1", "roundness": null, "seed": 1, "version": 1, "versionNonce": 1, "isDeleted": false, "boundElements": null, "updated": 1, "link": null, "locked": false}, {"id": "frameF", "type": "frame", "x": 100, "y": 100, "width": 500, "height": 400, "angle": 0, "strokeColor": "#bbb", "backgroundColor": "transparent", "fillStyle": "solid", "strokeWidth": 2, "strokeStyle": "solid", "roughness": 0, "opacity": 100, "groupIds": [], "frameId": null, "index": "a2", "roundness": null, "seed": 2, "version": 1, "versionNonce": 2, "isDeleted": false, "boundElements": null, "updated": 1, "link": null, "locked": false, "name": "F"}, {"id": "rectX", "type": "rectangle", "x": 800, "y": 400, "width": 100, "height": 100, "angle": 0, "strokeColor": "#1971c2", "backgroundColor": "transparent", "fillStyle": "solid", "strokeWidth": 2, "strokeStyle": "solid", "roughness": 0, "opacity": 100, "groupIds": [], "frameId": null, "index": "a3", "roundness": null, "seed": 4, "version": 1, "versionNonce": 4, "isDeleted": false, "boundElements": null, "updated": 1, "link": null, "locked": false}, {"id": "childA", "type": "rectangle", "x": 450, "y": 350, "width": 80, "height": 80, "angle": 0, "strokeColor": "#e03131", "backgroundColor": "transparent", "fillStyle": "solid", "strokeWidth": 2, "strokeStyle": "solid", "roughness": 0, "opacity": 100, "groupIds": [], "frameId": "frameF", "index": "a4", "roundness": null, "seed": 3, "version": 1, "versionNonce": 3, "isDeleted": false, "boundElements": null, "updated": 1, "link": null, "locked": false}], "appState": {"viewBackgroundColor": "#ffffff"}, "files": {}}
SCENE
cat > "$tmp/run.cjs" <<'JS'
const { chromium } = require(process.env.TREE + "/node_modules/playwright");
const fs = require("fs");
const url = process.env.APP_URL || "http://[::1]:13001/";
const scene = fs.readFileSync(process.argv[2], "utf8");
(async () => {
  const opts = { headless: true };
  if (process.env.CHROMIUM) opts.executablePath = process.env.CHROMIUM;
  let browser; try { browser = await chromium.launch(opts); } catch (e) { console.error("browser launch failed: " + e.message); process.exit(2); }
  const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
  try {
    await page.goto(url, { waitUntil: "load", timeout: 60000 });
    await page.waitForSelector("canvas.interactive", { timeout: 60000 });
    await page.evaluate(() => localStorage.clear());
    await page.reload({ waitUntil: "load" });
    await page.waitForSelector("canvas.interactive", { timeout: 60000 });
    await page.waitForTimeout(1000);
    // drop the scene file onto the canvas
    await page.evaluate((text) => {
      const dt = new DataTransfer();
      dt.items.add(new File([text], "scene.excalidraw", { type: "application/vnd.excalidraw+json" }));
      const target = document.querySelector("canvas.interactive");
      for (const t of ["dragenter", "dragover", "drop"]) {
        target.dispatchEvent(new DragEvent(t, { bubbles: true, cancelable: true, dataTransfer: dt }));
      }
    }, scene);
    await page.waitForTimeout(1500);
    const read = async () => { await page.waitForTimeout(1200); return JSON.parse(await page.evaluate(() => localStorage.getItem("excalidraw")) || "[]"); };
    let els = await read();
    if (!els.find((e) => e.id === "childA")) { console.error("import step: scene not loaded, ids=" + els.map((e) => e.id).join(",")); process.exit(2); }
    const st = JSON.parse(await page.evaluate(() => localStorage.getItem("excalidraw-state")));
    const z = st.zoom?.value ?? 1;
    const toScreen = (x, y) => [(x + st.scrollX) * z, (y + st.scrollY) * z];
    // select frame child childA (above the frame) and delete it
    const [ax, ay] = toScreen(450, 390);
    await page.keyboard.press("Escape");
    await page.mouse.click(ax, ay);
    await page.waitForTimeout(300);
    await page.keyboard.press("Delete");
    els = await read();
    if (els.find((e) => e.id === "childA")) { console.error("delete step: childA still present"); process.exit(2); }
    // select ellipseE (bottom of stack) and Bring forward
    await page.keyboard.press("Escape"); const [ex,ey]=toScreen(800,200); await page.mouse.click(ex,ey); await page.waitForTimeout(300); await page.keyboard.press("Control+BracketRight"); els = await read(); const ids=els.map(e=>e.id); console.log("order after bring forward of ellipseE: "+ids.join(", ")); if (ids.indexOf("ellipseE") < 0) { console.error("bring-forward step: ellipseE missing"); process.exit(2);} if (ids.indexOf("ellipseE") > ids.indexOf("rectX")) { console.log("DEFECT: Bring forward moved ellipseE above unrelated rectX (deleted frame child counted in frame range)"); process.exit(1);} console.log("OK: ellipseE placed just above the frame"); process.exit(0);
  } catch (e) { console.error("browser step failed: " + e.message); process.exit(2); }
  finally { await browser.close().catch(()=>{}); }
})();
JS
TREE="$(pwd)"; export TREE
node "$tmp/run.cjs" "$tmp/scene.excalidraw"
