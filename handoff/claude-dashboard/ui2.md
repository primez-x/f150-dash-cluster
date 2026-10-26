# UI2 design specification

Labelled reconstruction from compiled QML. No actual screen capture.

- Entry component: `Trucks/ui2/Dashboard.qml`
- Canvas: 1920 × 932. Physical display: 1920 × 720. Use the shared measurement contract.
- Alarm component: `qrc:/Trucks/ui2/AlarmPage.qml`. UI3–UI6 share the UI3 alarm component.
- Component definitions: 53. Public assist widget definitions: 21.
- Constant schematic bounds: 9. Unresolved bounds: 8.

Open [the schematic](ui2.svg) and [the full JSON specification](ui2.json).

## Component hierarchy

| Object | Type | ID | Parent | Source line |
|---|---|---|---|---|
| 0 | ItemInfo | mRootId |  | 14 |
| 1 | Rectangle |  | 0 | 19 |
| 3 | Image | mBgId | 0 | 79 |
| 5 | OpacityAnimator | mBgAnimationId | 3 | 92 |
| 6 | Timer |  | 3 | 100 |
| 7 | Image | image | 0 | 110 |
| 8 | Loader |  | 0 | 116 |
| 10 | Image | mLogoId | 0 | 130 |
| 12 | NumberAnimation |  | 11 | 144 |
| 14 | OpacityAnimator |  | 10 | 151 |
| 15 | Loader |  | 0 | 160 |
| 17 | Loader | mClockId | 0 | 168 |
| 19 | Loader |  | 0 | 180 |
| 21 | Loader |  | 0 | 190 |
| 23 | Loader |  | 0 | 200 |
| 25 | Loader | mDockId | 0 | 210 |
| 27 | NumberAnimation |  | 26 | 221 |
| 29 | OpacityAnimator |  | 25 | 228 |
| 30 | Loader |  | 0 | 237 |
| 32 | Behavior |  | 30 | 247 |
| 33 | NumberAnimation |  | 32 | 248 |
| 34 | Loader |  | 0 | 254 |
| 36 | Behavior |  | 34 | 264 |
| 37 | NumberAnimation |  | 36 | 265 |
| 38 | Loader |  | 0 | 270 |
| 40 | Loader | mVehicleId | 0 | 284 |
| 41 | Loader |  | 0 | 359 |
| 43 | Loader |  | 0 | 366 |

## Style selectors

- `mSprite`: `{"kind": "expression", "expression": "[\"qrc:/Trucks/ui2/Ram.qml\", \"qrc:/Trucks/ui2/Ford.qml\"]", "function": 5}`
- `mLogo`: `{"kind": "expression", "expression": "[\"../images/ui2/logo/ram\", \"../images/ui2/logo/ford/ford\"]", "function": 4}`
- `mWallpaper`: `{"kind": "expression", "expression": "[\"../images/ui2/bg\", \"../images/ui2/bg_ford\"]", "function": 3}`

## Cruise regions

- ACC/LIM location: X `80`; Y `260`.
- ACC/LIM component bounds: 90 × 50. Child text and images can extend beyond these bounds.
- Generic cruise alarm: index 31. The alarm grid and ACC/LIM have separate state predicates.
- Alarm grid: `{"anchor_top": "parent.top", "topMargin": 120, "anchor_right": "parent.right", "rightMargin": 225, "columns": 6, "spacing": "Qt default zero; no spacing binding", "slot": 6}`.

## Constant component bounds

| Component | X | Y | Width | Height |
|---|---|---|---|---|
| Rectangle [1] | 0 | 0 | 1920.0 | 932.0 |
| image [7] | 0 | 0 | 1920 | 932 |
| Loader [8] | 0 | 70.0 | 1920.0 | 261.0 |
| Loader [15] | 570.0 | 722.0 | 160.0 | 50.0 |
| Loader [21] | 580.0 | -298.0 | 1920.0 | 720.0 |
| Loader [23] | 580.0 | 82.0 | 1920.0 | 720.0 |
| mDockId [25] | 0 | 782.0 | 1920.0 | 150.0 |
| Loader [38] | 1220.0 | 697.0 | 100.0 | 70.0 |
| Loader [43] | 0 | 0 | 1920.0 | 932.0 |

## Exact evidence

Each JSON object preserves anchors, geometry, colors, fonts, property bindings, and source lines.
Each function preserves resolved bytecode. Branch-free expressions remain marked as inferences.
The asset manifest maps original literals to local files with dimensions and SHA-256 hashes.
Public assist widgets cover trip, fuel, TPMS, battery, oil life, runtime, off-road, pitch, roll, and G-force data.

## Reconstruction limits

- Schematics show constant bounds, not actual screenshots.
- No vehicle sample data or invented gauge geometry appears in the schematics.
- Runtime branches, native custom types, implicit text metrics, loaded data, and state-dependent transforms need reconstruction.
- Asset prefix matches are candidate sets, not proof that every candidate appears simultaneously.
