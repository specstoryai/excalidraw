#!/bin/sh
# requires: env OSS_STATS_TOKEN
# Mermaid dialog: a definition opened by a multi-line %%{init}%% directive gets
# no auto-fix (and generic guidance), unlike the same definition with a
# one-line directive.
APP_URL="${APP_URL:-http://[::1]:13001/}"
CHROMIUM="${CHROMIUM:-$(command -v chromium || command -v chromium-browser || command -v google-chrome)}"
if ! curl -s -o /dev/null "$APP_URL"; then
  echo "open app: no answer from $APP_URL (start the excalidraw-app dev server)" >&2; exit 2
fi
CHROMIUM="$CHROMIUM" APP_URL="$APP_URL" node -e '
const { chromium } = require("./node_modules/playwright");
const run = async (b, text) => {
  const p = await b.newPage();
  await p.goto(process.env.APP_URL);
  await p.waitForSelector("canvas"); await p.waitForTimeout(1000);
  await p.getByRole("button", { name: "More tools" }).click();
  await p.getByRole("menuitem", { name: "Mermaid to Excalidraw" }).click();
  await p.waitForTimeout(1500);
  await p.locator(".ttd-dialog textarea, .ttd-dialog [contenteditable=true]").first().fill(text);
  await p.waitForTimeout(2500);
  const out = await p.evaluate(() => document.querySelector(".ttd-dialog").innerText);
  await p.close();
  return out;
};
(async () => {
  const b = await chromium.launch(process.env.CHROMIUM ? { executablePath: process.env.CHROMIUM } : {});
  try {
    const body = "flowchart TD\n  A --> B\n  C --> D]";
    const oneLine = await run(b, "%%{init: {\"theme\":\"dark\"}}%%\n" + body);
    const multiLine = await run(b, "%%{init: {\n  \"theme\":\"dark\"\n}}%%\n" + body);
    if (!/Auto-fix is available/.test(oneLine)) { console.error("control (one-line directive): no auto-fix offered either: " + JSON.stringify(oneLine.slice(-300))); process.exit(2); }
    console.log("one-line directive: auto-fix offered");
    if (/Auto-fix is available/.test(multiLine)) { console.log("multi-line directive: auto-fix offered"); process.exit(0); }
    console.log("DEFECT: multi-line directive: no auto-fix offered; dialog shows: " + JSON.stringify(multiLine.split("Mermaid Syntax").pop().replace(/\s+/g, " ").slice(0, 300)));
    process.exit(1);
  } finally { await b.close(); }
})().catch(e => { console.error("drive browser: " + e.message.split("\n")[0]); process.exit(2); });
'
