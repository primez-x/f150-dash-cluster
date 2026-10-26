# UI4 design specification

Labelled reconstruction from compiled QML. No actual screen capture.

- Entry component: `Trucks/ui4/Dashboard.qml`
- Canvas: 1920 × 932. Physical display: 1920 × 720. Use the shared measurement contract.
- Alarm component: `qrc:/Trucks/ui3/AlarmPage.qml`. UI3–UI6 share the UI3 alarm component.
- Component definitions: 55. Public assist widget definitions: 21.
- Constant schematic bounds: 3. Unresolved bounds: 6.

Open [the schematic](ui4.svg) and [the full JSON specification](ui4.json).

## Component hierarchy

| Object | Type | ID | Parent | Source line |
|---|---|---|---|---|
| 0 | ItemInfo | mRootId |  | 15 |
| 1 | Image | image | 0 | 70 |
| 3 | Behavior |  | 1 | 78 |
| 4 | NumberAnimation |  | 3 | 79 |
| 5 | Loader | mVehicleId | 0 | 92 |
| 6 | OpacityAnimator |  | 5 | 98 |
| 7 | GlowImage | mLogoId | 0 | 119 |
| 9 | NumberAnimation |  | 8 | 132 |
| 11 | OpacityAnimator |  | 7 | 139 |
| 12 | Loader | mAngleId | 0 | 149 |
| 14 | NumberAnimation |  | 13 | 162 |
| 16 | OpacityAnimator |  | 12 | 169 |
| 17 | Loader | mPitchId | 0 | 178 |
| 19 | NumberAnimation |  | 18 | 196 |
| 21 | OpacityAnimator |  | 17 | 203 |
| 22 | Loader | mRollId | 0 | 212 |
| 24 | NumberAnimation |  | 23 | 230 |
| 26 | OpacityAnimator |  | 22 | 237 |
| 27 | Loader | mCompassId | 0 | 246 |
| 29 | NumberAnimation |  | 28 | 259 |
| 31 | OpacityAnimator |  | 27 | 266 |
| 32 | Loader | mDockId | 0 | 275 |
| 34 | NumberAnimation |  | 33 | 286 |
| 36 | OpacityAnimator |  | 32 | 293 |
| 37 | Loader |  | 0 | 302 |

## Style selectors

- `mLogo`: `{"kind": "expression", "expression": "[\"../images/ui345/logo\", \"../images/ui345/logo_ford\"]", "function": 5}`
- `mSprite`: `{"kind": "expression", "expression": "[\"qrc:/Trucks/ui4/Ram.qml\", \"qrc:/Trucks/ui4/Ford.qml\"]", "function": 4}`
- `mWallpaper`: `{"kind": "expression", "expression": "[\"../images/ui345/snow/bg\", \"../images/ui345/snow/ford/bg\"]", "function": 3}`

## Cruise regions

- ACC/LIM location: X `Number(mTrucksModel) ? 465 : 435`; Y `Number(mTrucksModel) ? 670 : 720`.
- ACC/LIM component bounds: 90 × 50. Child text and images can extend beyond these bounds.
- Generic cruise alarm: index 31. The alarm grid and ACC/LIM have separate state predicates.
- Alarm grid: `{"x": 315, "y": 80, "columns": 4, "spacing": 5, "slot": 4}`.

## Constant component bounds

| Component | X | Y | Width | Height |
|---|---|---|---|---|
| mAngleId [12] | 590.0 | 270.0 | 740.0 | 740.0 |
| mDockId [32] | 0 | 702.0 | 1920.0 | 230.0 |
| Loader [37] | 0 | 0 | 1920.0 | 932.0 |

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
