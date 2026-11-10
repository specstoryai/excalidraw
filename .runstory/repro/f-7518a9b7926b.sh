#!/bin/sh
# requires: env OSS_STATS_TOKEN
# Alt+arrow flowchart navigation selects a locked node, which Delete then removes.
APP_URL="${APP_URL:-http://[::1]:13001/}"
export APP_URL
CHROME="${CHROMIUM_PATH:-$(command -v chromium || command -v chromium-browser || command -v google-chrome || true)}"
export CHROME
cat > ./.repro-locked-$$.mjs <<'JS'
import { createRequire } from "module";
const require = createRequire(process.cwd() + "/package.json");
let chromium;
try { ({ chromium } = require("playwright")); } catch (e) { console.error("setup: playwright not installed in tree: " + e.message); process.exit(2); }
const R = (id,x,y,extra={}) => ({id,type:"rectangle",x,y,width:200,height:80,...extra});
const L = (id,from,to) => ({id,type:"arrow",x:0,y:0,width:1,height:1,points:[[0,0],[1,1]],elbowed:true,
  startBinding:{elementId:from,fixedPoint:[0.5,0.5],mode:"orbit"},endBinding:{elementId:to,fixedPoint:[0.5,0.5],mode:"orbit"}});
// A (selected), locked B in A's row, C below A; A -> C -> B
const scene = [R("nodeA",0,0), R("lockedB",300,0,{locked:true}), R("nodeC",0,300), L("ac","nodeA","nodeC"), L("cb","nodeC","lockedB")];
let browser;
try {
  browser = await chromium.launch({ executablePath: process.env.CHROME || undefined, args: ["--no-sandbox"] });
} catch (e) { console.error("setup: cannot launch chromium: " + e.message.split("\n")[0]); process.exit(2); }
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
  await page.addInitScript((els) => { if (!sessionStorage.getItem("seeded")) { sessionStorage.setItem("seeded","1"); localStorage.setItem("excalidraw", JSON.stringify(els)); } }, scene);
  try { await page.goto(process.env.APP_URL); } catch (e) { console.error("setup: app did not load: " + e.message.split("\n")[0]); process.exit(2); }
  try {
    await page.waitForFunction(() => window.h && window.h.app && window.h.state && window.h.elements && window.h.elements.length >= 5, null, { timeout: 60000 });
  } catch (e) { console.error("setup: scene not restored from local storage (window.h test hook missing or elements absent)"); process.exit(2); }
  const lockedState = await page.evaluate(() => window.h.elements.find(e => e.id === "lockedB")?.locked);
  if (!lockedState) { console.error("setup: lockedB not restored as locked"); process.exit(2); }
  await page.evaluate(() => window.h.setState({ selectedElementIds: { nodeA: true } }));
  await page.waitForTimeout(200);
  await page.mouse.move(5, 400);
  await page.keyboard.down("Alt");
  await page.keyboard.press("ArrowRight");
  await page.keyboard.up("Alt");
  await page.waitForTimeout(200);
  const selected = await page.evaluate(() => Object.keys(window.h.state.selectedElementIds));
  await page.keyboard.press("Delete");
  await page.waitForTimeout(200);
  const deleted = await page.evaluate(() => !!window.h.elements.find(e => e.id === "lockedB")?.isDeleted);
  console.log("selected after Alt+ArrowRight from A:", selected.join(","), "| locked B deleted after Delete:", deleted);
  if (selected.includes("lockedB") || deleted) {
    console.log("DEFECT: Alt+arrow navigation selects a locked flowchart node" + (deleted ? " and Delete removes it" : ""));
    process.exit(1);
  }
  process.exit(0);
} finally { await browser.close().catch(() => {}); }
JS
node ./.repro-locked-$$.mjs
rc=$?
rm -f ./.repro-locked-$$.mjs
exit $rc
