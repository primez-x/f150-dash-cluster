# UI6 design specification

Labelled reconstruction from compiled QML. No actual screen capture.

- Entry component: `Trucks/ui6/Dashboard.qml`
- Canvas: 1920 × 932. Physical display: 1920 × 720. Use the shared measurement contract.
- Alarm component: `qrc:/Trucks/ui3/AlarmPage.qml`. UI3–UI6 share the UI3 alarm component.
- Component definitions: 54. Public assist widget definitions: 21.
- Constant schematic bounds: 5. Unresolved bounds: 4.

Open [the schematic](ui6.svg) and [the full JSON specification](ui6.json).

## Component hierarchy

| Object | Type | ID | Parent | Source line |
|---|---|---|---|---|
| 0 | ItemInfo | mRootId |  | 15 |
| 1 | Image | image | 0 | 64 |
| 3 | Behavior |  | 1 | 72 |
| 4 | NumberAnimation |  | 3 | 73 |
| 5 | Loader | mVehicleId | 0 | 84 |
| 6 | OpacityAnimator |  | 5 | 89 |
| 7 | GlowImage | mLogoId | 0 | 108 |
| 9 | NumberAnimation |  | 8 | 121 |
| 11 | OpacityAnimator |  | 7 | 128 |
| 12 | Loader | mAngleId | 0 | 138 |
| 14 | NumberAnimation |  | 13 | 151 |
| 16 | OpacityAnimator |  | 12 | 158 |
| 17 | Loader | mPitchId | 0 | 167 |
| 19 | NumberAnimation |  | 18 | 185 |
| 21 | OpacityAnimator |  | 17 | 192 |
| 22 | Loader | mRollId | 0 | 201 |
| 24 | NumberAnimation |  | 23 | 219 |
| 26 | OpacityAnimator |  | 22 | 226 |
| 27 | Loader | mCompassId | 0 | 235 |
| 29 | NumberAnimation |  | 28 | 248 |
| 31 | OpacityAnimator |  | 27 | 255 |
| 32 | Loader | mDockId | 0 | 264 |
| 34 | NumberAnimation |  | 33 | 275 |
| 36 | OpacityAnimator |  | 32 | 282 |
| 37 | Loader |  | 0 | 290 |

## Style selectors

- `mLogo`: `{"kind": "expression", "expression": "[\"../images/ui345/logo\", \"../images/ui1/logo_ford\"]", "function": 4}`
- `mSprite`: `{"kind": "expression", "expression": "[\"qrc:/Trucks/ui6/Awd.qml\", \"qrc:/Trucks/ui5/Ford.qml\"]", "function": 3}`

## Cruise regions

- ACC/LIM location: X `Number(mTrucksModel) ? 465 : 435`; Y `Number(mTrucksModel) ? 670 : 720`.
- ACC/LIM component bounds: 90 × 50. Child text and images can extend beyond these bounds.
- Generic cruise alarm: index 31. The alarm grid and ACC/LIM have separate state predicates.
- Alarm grid: `{"x": 315, "y": 80, "columns": 4, "spacing": 5, "slot": 4}`.

## Constant component bounds

| Component | X | Y | Width | Height |
|---|---|---|---|---|
| image [1] | 0.0 | 0.0 | 1920 | 932 |
| mVehicleId [5] | 0 | 0 | 1920.0 | 932.0 |
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
