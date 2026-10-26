# F150 digital dashboard cluster

Shared Codex and Claude project for the VikNav 13.1-inch Ford F150 cluster.

Repository: [primez-x/f150-dash-cluster](https://github.com/primez-x/f150-dash-cluster).

Continue in the T3 project **F150 Dash Cluster**, which uses `C:\f150-dash-cluster` as the workspace.
Start each agent with `AGENTS.md` and this README. Claude also has `CLAUDE.md` as the entry point.

The repository contains source candidates, verification tools, and the complete design handoff.
Raw backups, extracted firmware, private settings, and credentials remain local in this workspace.
A fresh clone can run gauge, unit, and boot replays with the included static fixtures.
Cache analysis and UI candidate preparation still require the local Launcher. Required parser metadata is included.
Vendor source and assets retain the original notices. No blanket redistribution license is assigned.

Goals:

- Correct fuel, coolant, temperature-unit, gauge, and cruise defects.
- Preserve independent speed and temperature preferences.
- Review reliability, data freshness, shutdown, persistence, and polling behavior.
- Make supported settings accessible through ordinary menu navigation.
- Provide all six existing layouts and assets for new dashboard designs.

## Project contents

| Path | Contents |
| --- | --- |
| `originals/` | Three original firmware ZIPs with verified hashes |
| `captures/capture-01/` | First diagnostic capture |
| `captures/capture-02/` | Missing-command trace |
| `captures/capture-03/` | Verified filesystem backup and interrupted raw capture |
| `captures/capture-04/` | Complete verified filesystem and raw backups |
| `installed/capture-04/mmcblk0.img` | Reassembled 7,759,462,400-byte MMC main-area image |
| `installed/capture-04/rootfs/` | 5,457 verified files from the installed filesystem |
| `installed/capture-04/rootfs-manifest.json` | File hashes and 694 Linux link records |
| `extracted/`, `decrypted/` | Earlier firmware analysis views |
| `recovered-resources/` | Recovered dashboard image assets |
| `analysis/capture-04/` | Meter, settings, cruise, reliability, and compiled-QML evidence |
| `patches/capture-04/` | PC-only source candidates |
| `tests/` | Focused source and state replay checks |
| `evidence/fixtures/capture-04/` | Static source and menu test inputs, parser metadata, and provenance |
| `evidence/qt-5.14.2/` | Verified opcode header, upstream provenance, and Qt license texts |
| `handoff/claude-dashboard/` | Six-layout design handoff and assets |
| `diagnostic/` | USB capture tooling and historical packages |
| `analysis/relocation.json` | Earlier project location and preservation checks |

Private evidence and firmware remain local and ignored by Git. Historical evidence retains original paths; resolve those paths through the relocation record.

## Verified state

- Both backups completed. All 15 raw parts and both filesystem parts passed SHA-256 checks.
- The filesystem archive contains 6,808 entries. The extraction preserves all regular files and records Linux links separately.
- The raw image has six GPT partitions. Separate MMC boot and RPMB areas remain excluded.
- The installed Launcher and native plugins match the latest recovered firmware package.
- The main UI uses 198 compiled QML units. Plain source copies under `/etc/common` do not replace the direct compiled loaders.
- The cache decoder maps all 198 units and validates objects, bindings, functions, and bytecode spans.
- The source candidate corrects pressure conversion, low-RPM updates, DPC assignments, and idle fuel units.
- The candidate keeps temperature and speed preferences independent. Separate saved overrides prevent native unit snapshots from changing manual choices.
- Both source replays pass: 527 gauge cases and 194 unit-state cases. Earlier independent review covered the original unit and persistence changes.
- The TOW telltale (alarm 90) selects the towing layout (`towDashboard`, now stock UI2). Tow/Haul off returns to the saved driver layout. The tow replay passes 11 cases, and host Qt compiles the source.
- The MCU source of alarm 90 on this truck is not yet verified. Confirm on the vehicle that the stock TOW telltale lights with Tow/Haul.
- Source formatters distinguish L/h fuel flow from distance consumption. Raw consumption values no longer animate through unavailable sentinels.
- Fuel range-validity flags preserve invalid raw samples for diagnostics. Compiled gauge visibility and unit-label changes remain integration work.
- Five temperature families preserve documented unavailable states. Native calibration and actual vehicle accuracy remain unverified.
- Boot candidates remove automatic formatting after mount failure and stop later init scripts after critical mount failures.
- Private-data migration restores the original directory after a failed mount. If rollback fails, the data remains in `/private-move`.
- A failed copy preserves the migration backup. Independent review approved the boot candidates for a local commit.
- General settings and Units pass 1,062 source assertions. The catalog, General settings, and Units pass 120 host Qt checks.
- Thirteen additional Qt checks execute the patched System Settings cache and verify route creation, removal, and recreation.
- Native Qt fixture previews cover all three pages at 1920×932 and 1920×720. Real vehicle rendering remains unverified.
- The candidate clears all 13 vendor factory-menu code records and exposes labeled settings and diagnostic entries.
- All six layouts have detailed specifications, coordinate schematics, and genuine assets under `handoff/claude-dashboard/`.

## Focused checks

Run the source replay from the project root:

```powershell
node tests/gauge-replay.cjs original
node tests/gauge-replay.cjs patched
node tests/unit-state-replay.cjs original
node tests/unit-state-replay.cjs patched
node tests/tow-layout-replay.cjs original
node tests/tow-layout-replay.cjs patched
node tests/settings-menu-replay.cjs
```

The original phase must reproduce the known failures. The patched phase must pass. Results are stored under `analysis/capture-04/`.

Check the boot candidates with Ubuntu under WSL:

```powershell
wsl.exe -d Ubuntu --exec python3 /mnt/c/f150-dash-cluster/tests/mount-safeguard.py
```

The boot replay uses mocked mount, filesystem-check, and format commands. Migration cases use guarded file operations inside temporary directories.
The replay also executes the candidate init loop against fake services. No device partition is mounted or changed.

The fixture manifest preserves source and export hashes. One vendor menu-code comment is removed from the VehicleEvent fixture.
The original captured source remains unchanged outside Git. Git keeps the selected fixture bytes unchanged.
Earlier public commits retain the removed vendor menu-code comment. This source change does not purge Git history or change device access.

Prepare a new UI candidate directory:

```powershell
python tools/prepare_ui_candidate.py --output analysis/capture-04/ui-candidate-next
python tests/ui-loader-replay.py
```

The generator rejects an existing output directory. Choose a new directory for each candidate.
Candidate firmware remains under ignored `analysis/` paths. No USB update package is installed or deployed by these commands.

Check cache routing with the exact host Qt version:

```powershell
wsl.exe -d Ubuntu --exec python3 -m venv /mnt/c/f150-dash-cluster/tools/qt-host/venv
wsl.exe -d Ubuntu --exec /mnt/c/f150-dash-cluster/tools/qt-host/venv/bin/python -m pip install -r /mnt/c/f150-dash-cluster/tests/qt-host-requirements.txt
wsl.exe -d Ubuntu --exec /mnt/c/f150-dash-cluster/tools/qt-host/venv/bin/python /mnt/c/f150-dash-cluster/tests/qt-ui-loader.py
```

The Qt probe requires the local Launcher, recovered resources, and decoded metadata under `analysis/capture-04/qml-cache/`.
The Qt probe uses fixture components and a mocked native type. The probe never loads the captured ARM program or native plugins.
The host accepts original and redirected caches for the main and System Settings routes.
Global and VehicleEvent wrappers compile in isolated directories. Factory and Units pages run with safe context stubs.
Wrapper startup and vehicle behavior remain unverified.

Decode the installed Launcher metadata:

```powershell
python tools/decode_qml_units.py
```

The decoder requires Python 3 and Capstone. The layout exporter also requires Pillow.

Export the Claude design handoff:

```powershell
python tools/export_layouts.py
```

Open `handoff/claude-dashboard/index.html` for the gallery. Schematics describe declared bounds; the schematics are not device screenshots.

## Patch boundary

Source replay verifies selected math and state transitions. Source replay does not verify Qt rendering, CAN interpretation, sensor calibration, or live vehicle behavior.

The UI candidate redirects four compiled loaders and includes five source files.
The generator clears 13 code records in the old factory gate. The generator preserves native code, ELF geometry, and the other 195 cache units.
No custom dashboard update has been installed. Device-fork cache acceptance and wrapper startup remain unverified.

The new Units page shows independent Manual/Follow state and exposes `followVehicleUnits()`. Host tests verify the controls with recorded native-call stubs.

Factory opens a labeled menu without a code prompt. The menu exposes General, Advanced, tank, vehicle-profile, odometer, and service-command pages.
The menu also exposes the existing USB debug, log mode, image preview, and model-option actions. Actions require explicit activation.
The catalog preserves the vendor service-list query after 300 ms. General settings preserve the separate status query after 50 ms.
General settings retain all 19 controls. Back returns to the catalog.
Back returns to the menu where the page opened. Pages opened from Advanced return to Advanced.
The old factory gate has no route from System Settings. All 13 former code literals are empty in the copied Launcher.
Linux login credentials, keys, service defaults, and captured backups remain unchanged.
Selecting a USB debug action can change USB debug state. Merely opening the menu leaves that state unchanged.
Host Qt verifies the actual catalog and General page. The other vendor pages use safe route markers with recorded Back behavior.
Native service semantics, vendor recovery, and update access still require vehicle checks before deployment.
Cruise consolidation and compiled fuel-quality gates remain integration work. The review records current bindings across all six layouts.

Boot candidates require target-shell and hardware checks before deployment. Launcher starts before the separate media mount in the captured boot order.
The existing stop functions do not unmount partitions. A restart can return a filesystem-check error when a partition remains mounted.
Critical failures stop later init scripts. The hardware postlude still runs. Repeated migration failures preserve the backup and hold normal boot.
Legacy migration copies the complete saved directory. Legacy files replace same-named partition files; the replay verifies that precedence.
Confirm migration precedence, display availability, and recovery access before any vehicle deployment.

Fuel and coolant calibration, invalid native values, signal freshness, polling limits, and shutdown behavior require vehicle reference data and hardware checks.

Keep power relays and vehicle controls unchanged until separate hardware checks prove the shutdown path.

## Third-party source notices

`evidence/qt-5.14.2/qv4instr_moth_p.h` preserves the Qt 5.14.2 copyright and license header unchanged.
The adjacent `LICENSE.LGPL3`, `LICENSE.GPL2`, and `LICENSE.GPL3` files preserve the upstream license texts.
`PROVENANCE.json` records official source URLs and byte hashes. The decoder reads opcode declarations from the header.
Vendor QML fixtures and dashboard assets retain vendor ownership. This repository grants no new license for vendor content.
