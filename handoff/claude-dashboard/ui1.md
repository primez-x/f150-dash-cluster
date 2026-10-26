# UI1 design specification

Labelled reconstruction from compiled QML. No actual screen capture.

- Entry component: `Trucks/ui1/Dashboard.qml`
- Canvas: 1920 × 932. Physical display: 1920 × 720. Use the shared measurement contract.
- Alarm component: `qrc:/Trucks/ui1/AlarmPage.qml`. UI3–UI6 share the UI3 alarm component.
- Component definitions: 57. Public assist widget definitions: 21.
- Constant schematic bounds: 9. Unresolved bounds: 4.

Open [the schematic](ui1.svg) and [the full JSON specification](ui1.json).

## Component hierarchy

| Object | Type | ID | Parent | Source line |
|---|---|---|---|---|
| 0 | ItemInfo | mRootId |  | 14 |
| 1 | Image | image | 0 | 67 |
| 3 | Behavior |  | 1 | 75 |
| 4 | NumberAnimation |  | 3 | 76 |
| 5 | Image | mLogoId | 0 | 88 |
| 7 | OpacityAnimator |  | 5 | 101 |
| 8 | Loader | mClockId | 0 | 109 |
| 10 | Loader | mOutSideTempId | 0 | 120 |
| 12 | Loader | mAngleInfoId | 0 | 132 |
| 14 | OpacityAnimator |  | 12 | 145 |
| 15 | Loader | mPitchId | 0 | 154 |
| 17 | NumberAnimation |  | 16 | 174 |
| 19 | OpacityAnimator |  | 15 | 184 |
| 20 | Loader | mRollId | 0 | 193 |
| 22 | NumberAnimation |  | 21 | 211 |
| 24 | OpacityAnimator |  | 20 | 218 |
| 25 | Loader | mCompassInfoId | 0 | 227 |
| 27 | OpacityAnimator |  | 25 | 240 |
| 28 | Loader |  | 0 | 248 |
| 30 | Loader | mTachoInfoId | 0 | 329 |
| 32 | NumberAnimation |  | 31 | 344 |
| 34 | OpacityAnimator |  | 30 | 351 |
| 35 | Loader | mDockId | 0 | 371 |
| 37 | NumberAnimation |  | 36 | 378 |
| 39 | Loader | mSpeedInfoId | 0 | 387 |
| 41 | NumberAnimation |  | 40 | 401 |
| 43 | OpacityAnimator |  | 39 | 408 |
| 44 | Loader |  | 0 | 417 |

## Style selectors

- `mLogo`: `{"kind": "expression", "expression": "[\"../images/ui1/logo\", \"../images/ui1/logo_ford\"]", "function": 4}`
- `mWallpaper`: `{"kind": "expression", "expression": "[\"../images/ui1/bg\", \"../images/ui1/ford_bg\"]", "function": 3}`

## Cruise regions

- ACC/LIM location: X `255`; Y `610`.
- ACC/LIM component bounds: 90 × 50. Child text and images can extend beyond these bounds.
- Generic cruise alarm: index 31. The alarm grid and ACC/LIM have separate state predicates.
- Alarm grid: `{"x": 350, "y": 80, "columns": 4, "spacing": 15, "slot": 2}`.

## Constant component bounds

| Component | X | Y | Width | Height |
|---|---|---|---|---|
| mClockId [8] | -20.0 | 440.0 | 200.0 | 50.0 |
| mOutSideTempId [10] | 1760.0 | 440.0 | 160.0 | 50.0 |
| mAngleInfoId [12] | 590.0 | 170.0 | 740.0 | 740.0 |
| mPitchId [15] | 100.0 | 60.0 | 570.0 | 570.0 |
| mRollId [20] | 1250.0 | 60.0 | 570.0 | 570.0 |
| mCompassInfoId [25] | 607.0 | 510.0 | 706.0 | 91.0 |
| Loader [28] | 1510.0 | 687.0 | 100.0 | 70.0 |
| mSpeedInfoId [39] | 810.0 | 300.0 | 300.0 | 200.0 |
| Loader [44] | 0 | 0 | 1920.0 | 932.0 |

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
