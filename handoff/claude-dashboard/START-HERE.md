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
The physical screen measures 1920 × 720. Main applies uniform scale, rotation, and margins for the selected vehicle model.
Model index 0 uses scale 0.7752 when the screen height equals 720.
Other model branches remain explicit in the main geometry bytecode.
Do not assume a simple vertical resize or claim pixel-perfect physical alignment.

## Visual limits

Schematics show constant component bounds and labels. Schematics are not actual screenshots.
Runtime branches, native custom controls, loaded image metrics, and live vehicle state remain unresolved where marked.
No gauge sweep or sample vehicle value was invented.
Asset candidates from a dynamic prefix do not imply simultaneous visibility.
Factory, credential, update, private configuration, serial, QR, database, raw capture, and executable files are excluded.
