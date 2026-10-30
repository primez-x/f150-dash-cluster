# UI3 design specification

Labelled reconstruction from compiled QML. No actual screen capture.

- Entry component: `Trucks/ui3/Dashboard.qml`
- Canvas: 1920 × 932, drawn 1:1 on the truck screen. Red areas in the schematic are hidden by the bezel or the steering column (`visible_area` in the shared measurement contract).
- Alarm component: `qrc:/Trucks/ui3/AlarmPage.qml`. UI3–UI6 share the UI3 alarm component.
- Component definitions: 55. Public assist widget definitions: 21.
- Constant schematic bounds: 3. Unresolved bounds: 6.

Open [the schematic](ui3.svg) and [the full JSON specification](ui3.json).

## Component hierarchy

| Object | Type | ID | Parent | Source line |
|---|---|---|---|---|
| 0 | ItemInfo | mRootId |  | 15 |
| 1 | Image | image | 0 | 71 |
| 3 | Behavior |  | 1 | 79 |
| 4 | NumberAnimation |  | 3 | 80 |
| 5 | GlowImage | mLogoId | 0 | 92 |
| 7 | NumberAnimation |  | 6 | 105 |
| 9 | OpacityAnimator |  | 5 | 112 |
| 10 | Loader | mAngleId | 0 | 121 |
| 12 | NumberAnimation |  | 11 | 134 |
| 14 | OpacityAnimator |  | 10 | 141 |
| 15 | Loader | mVehicleId | 0 | 158 |
| 16 | OpacityAnimator |  | 15 | 164 |
| 17 | Loader | mDockId | 0 | 176 |
| 19 | NumberAnimation |  | 18 | 187 |
| 21 | OpacityAnimator |  | 17 | 194 |
| 22 | Loader | mPitchId | 0 | 203 |
| 24 | NumberAnimation |  | 23 | 222 |
| 26 | OpacityAnimator |  | 22 | 229 |
| 27 | Loader | mRollId | 0 | 238 |
| 29 | NumberAnimation |  | 28 | 256 |
| 31 | OpacityAnimator |  | 27 | 263 |
| 32 | Loader | mCompassId | 0 | 271 |
| 34 | NumberAnimation |  | 33 | 284 |
| 36 | OpacityAnimator |  | 32 | 291 |
| 37 | Loader |  | 0 | 300 |

## Style selectors

- `mSprite`: `{"kind": "expression", "expression": "[\"qrc:/Trucks/ui3/Ram.qml\", \"qrc:/Trucks/ui3/Ford.qml\"]", "function": 5}`
- `mLogo`: `{"kind": "expression", "expression": "[\"../images/ui345/logo\", \"../images/ui345/logo_ford\"]", "function": 4}`
- `mWallpaper`: `{"kind": "expression", "expression": "[\"../images/ui345/desert/bg\", \"../images/ui345/desert/ford/bg\"]", "function": 3}`

## Cruise regions

- ACC/LIM location: X `Number(mTrucksModel) ? 465 : 435`; Y `Number(mTrucksModel) ? 670 : 720`.
- ACC/LIM component bounds: 90 × 50. Child text and images can extend beyond these bounds.
- Generic cruise alarm: index 31. The alarm grid and ACC/LIM have separate state predicates.
- Alarm grid: `{"x": 315, "y": 80, "columns": 4, "spacing": 5, "slot": 4}`.

## Constant component bounds

| Component | X | Y | Width | Height |
|---|---|---|---|---|
| mAngleId [10] | 590.0 | 270.0 | 740.0 | 740.0 |
| mDockId [17] | 0 | 702.0 | 1920.0 | 230.0 |
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
