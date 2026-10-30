# Dashboard design handoff

Open `index.html` directly. No server or dependency install required.

- Six layouts: `ui1` through `ui6`.
- Each layout has a concise Markdown guide, a self-contained JSON specification, an SVG schematic, and a PNG schematic.
- `contact-sheet.png` compares all six schematics.
- `shared-contracts.json` defines navigation, data semantics, measurement rules, and reconstruction limits.
- `factory-settings.json` lists all 19 recovered configuration rows without credential values.
- `asset-manifest.json` lists genuine local assets, dimensions, hashes, and unresolved source literals.
- `verification.json` records the generator checks.

## Use with Claude

Provide this whole folder. Start from a selected layout JSON and the shared contracts.
Design a new visual style while preserving the public data, alarm, cruise, limiter, unit, and navigation behavior.
Read every unresolved function before assigning a fixed shape, state, position, or value.
Use the local asset paths. Preserve original asset names and case.
Use one cruise region across all six styles. Preserve distinct available, engaged, set-speed, ACC, and LIM meanings.
Read the unit-preference contract before designing the Units menu. Show manual/follow state and expose the vehicle-follow action.
Expose supported advanced settings through ordinary menu navigation. Keep unsupported entries visible with a clear reason.
Compare all six layouts before consolidating shared visual components.

## Evidence model

Literal values and object hierarchy come from compiled QML.
Branch-free expression text comes from decoder inference.
Resolved bytecode preserves the branch evidence where source reconstruction remains incomplete.
Source line numbers refer to original QML source locations embedded in compiled units.
Component paths identify source evidence, not files that Claude must load from an external device.
Relative asset literals can contain parent segments as historical evidence. Exported asset paths remain inside this folder.

## Measurement

Use declared 1920 × 932 layout coordinates for redesign.
The truck screen measures 1920 × 932, and main.qml draws the dashboard at scale 1, rotation 0, and top 0 (truck model 1, measured 2026-10-30).
The bezel opening has an arched top edge: 3 px hidden at the center, 43 px at x 360 and x 1560, and 106 px at the side edges.
The steering column shroud hides the bottom center: from y 776 between x 572 and x 1348, widening to x 180–1710 at the bottom row.
From the driver eye, the steering wheel rim also hides the top corners: down to y 158 at x 0 and y 177 at x 1920.
Schematics shade the hidden areas red: the bezel arch, the steering column shroud, and the wheel rim corners. `shared-contracts.json` → `measurement.visible_area` holds the exact points.
Physical check engine and tire pressure lamps sit on the bezel outside the screen. Do not draw duplicates for them.

## Visual limits

Schematics show constant component bounds and labels. Schematics are not actual screenshots.
Runtime branches, native custom controls, loaded image metrics, and live vehicle state remain unresolved where marked.
No gauge sweep or sample vehicle value was invented.
Asset candidates from a dynamic prefix do not imply simultaneous visibility.
Factory, credential, update, private configuration, serial, QR, database, raw capture, and executable files are excluded.
