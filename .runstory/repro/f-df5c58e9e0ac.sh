#!/bin/sh
# requires: env OSS_STATS_TOKEN
# Alt-dragging a frame whose arrow is bound to a rectangle in another frame:
# the duplicate arrow's end lands at a place that depends on how many pointer
# moves the drag had, not on where the drag ended.
T=packages/element/tests/zz_repro_altdrag.test.tsx
cat > "$T" <<'EOF'
import { Excalidraw } from "@excalidraw/excalidraw";
import { arrayToMap } from "@excalidraw/common";
import { API } from "@excalidraw/excalidraw/tests/helpers/api";
import { Keyboard, Pointer, UI } from "@excalidraw/excalidraw/tests/helpers/ui";
import { render } from "@excalidraw/excalidraw/tests/test-utils";
import { LinearElementEditor } from "../src/linearElementEditor";
const { h } = window;
const mouse = new Pointer("mouse");
for (const moves of [[550], [400, 550]]) {
  it("alt-drag " + moves.join(","), async () => {
    await render(<Excalidraw handleKeyboardGlobally={true} />);
    const frameA = API.createElement({ type: "frame", width: 300, height: 300 });
    const frameB = API.createElement({ type: "frame", x: 500, y: 0, width: 300, height: 300 });
    const rectA = API.createElement({ type: "rectangle", x: 50, y: 100, width: 100, height: 100, backgroundColor: "red", fillStyle: "solid", frameId: frameA.id });
    const rectB = API.createElement({ type: "rectangle", x: 600, y: 100, width: 100, height: 100, backgroundColor: "red", fillStyle: "solid", frameId: frameB.id });
    API.setElements([rectA, frameA, rectB, frameB]);
    UI.clickTool("arrow");
    mouse.downAt(100, 150); mouse.moveTo(400, 150); mouse.moveTo(650, 150); mouse.up();
    UI.clickTool("selection");
    const orig = h.elements.find((e: any) => e.type === "arrow") as any;
    API.setSelectedElements([frameA]);
    Keyboard.withModifierKeys({ alt: true }, () => {
      mouse.downAt(250, 250);
      moves.forEach((y) => mouse.moveTo(250, y));
      mouse.up();
    });
    const dup = h.elements.find((e: any) => e.type === "arrow" && !e.isDeleted && e.id !== orig.id) as any;
    if (!dup) { console.log("RESULT none"); return; }
    const p = LinearElementEditor.getPointAtIndexGlobalCoordinates(dup, -1, arrayToMap(h.elements));
    console.log("RESULT " + moves.length + " " + Math.round(p[0]) + "," + Math.round(p[1]));
  });
}
EOF
OUT=$(npx vitest run "$T" 2>&1)
rm -f "$T"
R1=$(printf '%s\n' "$OUT" | sed -n 's/.*RESULT 1 \([-0-9,]*\).*/\1/p' | head -1)
R2=$(printf '%s\n' "$OUT" | sed -n 's/.*RESULT 2 \([-0-9,]*\).*/\1/p' | head -1)
if [ -z "$R1" ] || [ -z "$R2" ]; then
  echo "setup: vitest run did not report the duplicate arrow's end: $(printf '%s\n' "$OUT" | tail -3 | tr '\n' ' ')" >&2
  exit 2
fi
echo "duplicate arrow end after one-move drag: $R1; after two-move drag to the same point: $R2"
if [ "$R1" != "$R2" ]; then
  echo "DEFECT: duplicate arrow end depends on drag path ($R1 vs $R2)"
  exit 1
fi
exit 0
