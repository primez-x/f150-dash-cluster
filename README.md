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
- Both source replays pass: 632 gauge cases and 194 unit-state cases. Earlier independent review covered the original unit and persistence changes.
- The TOW telltale (alarm 90) selects the towing layout (`towDashboard`, now stock UI2). Tow/Haul off returns to the saved driver layout. The tow replay passes 11 cases, and host Qt compiles the source.
- The MCU source of alarm 90 on this truck is not yet verified. Confirm on the vehicle that the stock TOW telltale lights with Tow/Haul.
- The GPS clock sets the MCU clock from GPS UTC (NMEA RMC) with the time zone from the GPS position and US and Canada daylight saving time. The MCU clock loses the time when the relay cuts power.
- The clock replay passes 39 cases. The zone grid matches Python zoneinfo for 45 test cities. Host Qt compiles the source.
- Until the first clock write after power-up (GPS or the Date and time menu), the dashboard clock shows dashes, unless the MCU date is plausible. GPS auto time is on by default. System > Date and time > GPS sets the clock turns GPS auto time on and off. While GPS auto time is on, the manual set row shows the reason and does not open.
- Source formatters distinguish L/h fuel flow from distance consumption. Raw consumption values no longer animate through unavailable sentinels.
- The compiled FuelInfo and MpgInfo pages label the instant consumption with the distance unit (MPG, L/100km, km/l). In flow mode (L/h) those pages now show 0, not an L/h number under an MPG label.
- Travel and idle times show minutes with two digits (`1:05`, not `1:5`).
- The oil-life trip on the OilLifeinfo page now follows the distance unit. The adapter field is 16 bits; the page shows `---` until the first trailer frame and for 0xFFFF. The field was matched by storage order, and the km unit is an inference. The logger records `trucksOilLifeTripRaw` with `odo`, so one drive confirms the unit.
- The settings menu is the owned page `/etc/vnM.qml`. MenuPage loads vnM in place of the compiled menu list, so vnM owns Vehicle, System, Service, and Factory. G-force and the five Factory setup pages (Advanced, Fuel tank, Vehicle profile, Odometer, Service commands) are compiled vendor pages that open inside vnM. The menu audit is in `analysis/capture-04/menu-audit/` (private).
- Each menu key event writes one `viknav-key <ms> <code> <state> <page path> <cursor>` line to `/tmp/Launcher.log`. The install copies the log to the drive (`Launcher-later.log`) 3 minutes after the restart. The lines show repeated, held, or missing wheel events.
- Wheel key bounce filter (`VehicleEvent.qml`, all pages and the dashboard). The menu-v2 truck trace (2026-10-30) shows one Down press as two or three press-release pairs; each extra press starts 9–20 ms after a release. Real presses start 120 ms or more after a release. A release now reaches the pages 50 ms later. A press of the same key inside that time joins the key press; a press of another key is dropped with its hold and release. Each drop writes a `viknav-key-drop <ms> <code> <state> <reason>` line. The Up key showed no bounce. The replay passes 17 cases against the truck trace.
- The menu uses the locked round 21 design: layout A (each open page stays on screen as a column), values B (switches, segments, and a percent meter), and confirm A (press OK twice). The accent is blue, and teal while the towing layout is on. The menu uses the BMW Type Global font from `/usr/share/fonts`. At most three columns show; a fourth level (Factory > General settings) moves the oldest column off the left side, and the narrow first column shows titles only.
- System > Display > Dashboard layout selects one of the six layouts (Layout 1–6 are UI1–UI6), the same set as the OK hold on the dashboard. OK opens the editor, Up and Down change the layout, and OK saves the layout. While Tow/Haul shows the towing layout automatically, the row shows "· Towing"; a layout chosen then stays after Tow/Haul ends.
- Factory > Screen grid closes the menu and covers the whole screen with a pixel grid (`/etc/vnS.qml`): lines every 20 px, x,y labels, colored frames every 10 px from each edge, the screen size, and the dashboard transform. A photo of the grid maps the area that the bezel and the steering column leave visible. Any wheel key after the first second, or a power cycle, hides the grid. The truck photos (2026-10-30) show a 1920 × 932 screen drawn 1:1; `handoff/claude-dashboard/START-HERE.md` describes the visible area.
- Menu keys act on release. Up and Down wrap; Left goes back; Right and OK open or change; Modes steps down; a Modes hold acts as OK; a Back hold closes the menu. The release after a hold is ignored. Each page opens on the first row and drops any unfinished edit.
- Settings with more than two values open an editor: Up and Down change the value, OK sends the value once, and Back cancels. Oil life start value stays between 10% and 100%. The off-road camera never sends the camera fault value. Ford settings show "Waiting for truck" until the first settings frame, and 500 ms after a change the menu reads the settings back once.
- Reset rows and service resets need a second OK within 5 seconds. Reset keeps the rows, titles, and commands of the captured Reset page; the 2011-2014 F150 profile (truck model 1, vehicle model 1) keeps Oil Life, which the captured page removed for every Ford.
- Pages send their inquiry when the page opens, not when the cursor passes the row. Rows that do nothing on this truck show the reason. Service shows "No data from adapter" when the adapter sends no maintenance data.
- The menu labels are English. The Language setting still changes the rest of the UI.
- The door and radar popup no longer takes key presses while the menu is open. The compiled Dashboard gave the first key release after a door change, and every release while radar data arrived, to the hidden popup. Factory > Doors info now turns the door popup off.
- System > Version shows the compiled launcher version `FORD@20250714 r36582`. The owned Global came from the older source text and showed `RAM@20240401 r26971`.
- Oil Life reset on the 2011-2014 F150 sends `setFordSetup(14, 8, 100)`: the same Ford setup command that the vendor sends from Vehicle > Assist row 59 for this profile. Other profiles keep the vendor command. The effect on the truck is not yet verified; a record drive with Debug logging: UART transmit shows the frame.
- The native trip reset command sends only for some CAN box vendors. By the vendor enum order, the JLY box is vendor 1, which is one of them. Reset Trip A and Trip B therefore most likely send on this truck.
- The native decoder raises the fuel notification on every fuel frame (0x06), with no change check. The compiled fuel gauges draw `fuelPercentage`, `mainTankPercentage`, and `subTankPercentage` directly.
- A fuel reading outside 0..100 keeps the last valid gauge value. The raw byte stays in the `*Raw` properties for the data log.
- The low-fuel warning (`fuelLevel`) is the higher of the adapter state and the percent level: 12% or less is low, and 5% or less is critical. An invalid reading shows at least the low level. The native decoder turns adapter states 3 and up into 0.
- Fuel data age is logged, not shown. The cadence of fuel frames on the truck is not yet verified.
- The data logger writes one `viknav-data` line per second while Factory > Debug logging is on. The line includes coolant, oil, and transmission temperatures both oil pressure values (`oilPressurePercentage`, `engOilPercent`), the four cruise fields of the stock cruise widget (`cruiseState`, `cruiseSpeedSet`, `cruiseSetSpeedState`, `cruiseSpeed`), and the boost and trailer brake readings that the stock layouts never read (`diffOilTemp`, `turbo`, `boostPercentage` from JLY command 0x40; `trucksTrailerGain`, `trucksTrailerBrakeState`, `trucksTrailerOutputState`, `trucksTrailerOutput` from command 0x1A), the engine gauge frame (`vacuumBoost`, `vacuumBoostDir`, `cylinderHeadTemp`, `inletAirTemp`, `airFuelRatio` and their percentages and states, from command 0x3B or command 0x16 sub-command 0x45), `oilLifePercentage` (command 0x1B) and `compass` (command 0x3F), so one drive shows which readings the truck sends. Debug values 2 and 4 also make the native plugin print each received or sent UART frame. The frame print stops after 90 minutes in one power cycle, because `/tmp` is in RAM.
- Fuel range-validity flags preserve invalid raw samples for diagnostics. Compiled gauge visibility and unit-label changes remain integration work.
- Five temperature families preserve documented unavailable states. Native calibration and actual vehicle accuracy remain unverified.
- Boot candidates remove automatic formatting after mount failure and stop later init scripts after critical mount failures.
- Private-data migration restores the original directory after a failed mount. If rollback fails, the data remains in `/private-move`.
- A failed copy preserves the migration backup. Independent review approved the boot candidates for a local commit.
- The settings menu, including Factory and General settings, passes 245 host Qt checks.
- Eight additional Qt checks execute the patched MenuPage cache. The checks verify that MenuPage loads `/etc/vnM.qml` and passes the keys.
- Native Qt fixture previews cover eight settings menu states, including the layout editor, Factory, and General settings, and the screen grid. Real vehicle rendering remains unverified.
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
node tests/clock-sync-replay.cjs original
node tests/clock-sync-replay.cjs patched
node tests/swc-debounce-replay.cjs original
node tests/swc-debounce-replay.cjs patched
node tests/settings-menu-replay.cjs
```

Rebuild the GPS clock zone grid in `Global.qml` from timezone-boundary-builder. The tool needs Pillow and the `tzdata` package:

```powershell
gh release download 2026e -R evansiroky/timezone-boundary-builder -p timezones-now.geojson.zip -D $env:TEMP\tbb
python tools/build_timezone_grid.py $env:TEMP\tbb\timezones-now.geojson.zip
python tools/build_timezone_grid.py $env:TEMP\tbb\timezones-now.geojson.zip --check
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
The host accepts original and redirected caches for the main and MenuPage routes.
Global and VehicleEvent wrappers compile in isolated directories. The settings menu, Factory, and General pages run with safe context stubs.
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

Check the visible-area mask in the handoff against the edge points read from the truck grid photos. With the private photos present, the tool also writes mask overlays to `analysis/capture-04/vehicle-runs/screen-grid-2026-10-30/mask-check/`:

```powershell
python tools/check_visible_area.py
```

Open `handoff/claude-dashboard/index.html` for the gallery. Schematics describe declared bounds; the schematics are not device screenshots.

## USB install

The vendor USB updater (`/etc/mdev/update.sh`) runs `encrypt/encrypt.sh` from `encrypt.zip` as root on each USB drive insertion. The updater runs from the USB hotplug rule, not from the dashboard. A broken dashboard therefore does not block a USB rollback.

`tools/usb-install/encrypt.sh` installs, rolls back, or collects logs. One marker file next to `encrypt.zip` selects the action. The script pins the hash of every payload file in `viknav-ui/`.

- Install: the script aborts with no change for an unknown Launcher, an unknown `/etc/vn*.qml` file, a damaged payload, or low space. Files of an earlier release are known files, so a new drive upgrades the cluster in place. The install removes files that only an earlier release used (`RETIRED_FILES`). The script stops the Launcher, backs up `/private/Launcher` to the drive, and stages and checks each file. Only an install over the original Launcher writes `viknav-ui/settings-before-install.tar`; an upgrade keeps that stock backup. Then the script renames the `/etc` files and the Launcher into place and starts the Launcher.
- Health check: the new Launcher must log `VehicleEvent Ver:VehicleEvent@` and `main.qml starting`, stay up for 20 s, and log no `/etc/vn` error. Otherwise the script restores the original Launcher, the `/etc` files, and the settings. The script also writes `INSTALL-BLOCKED.txt`, so the next insertion does not try the install again.
- Rollback: the script restores the original Launcher from the drive, removes the current and retired `/etc/vn*.qml` files, and restores the settings from before the first install.
- Log: the script copies `/tmp/Launcher.log` and the installed hashes. The script changes nothing.
- Record: the script starts a background copy of `/tmp/Launcher.log` to the drive every 2 s. The copy stops when the drive is unmounted or the power goes. The script changes nothing on the cluster.
- A repeated install or rollback with nothing to change does not restart the dashboard.

The USB port becomes a host port at the end of `rcS`, after the hotplug handler starts. A drive left in at power-up therefore runs the updater; the first truck install (menu-v1, 2026-10-30) ran this way. A repeated install does nothing, and each record run writes a new folder.
Results go to a new `viknav-ui-<action>-<time>-<pid>` folder on the drive. Line 1 of `STATUS.txt` is the result. The boot scripts (`S01private`, `S90mount`, `rcS`) are not part of the install.

Replay the installer against a fake cluster root with the real payload bytes, then build the drive contents (Ubuntu under WSL):

```powershell
wsl.exe -d Ubuntu --exec sh -c "cd /mnt/c/f150-dash-cluster/tools/busybox && apt-get download busybox-static && dpkg-deb -x busybox-static_*.deb deb && cp deb/usr/bin/busybox busybox"
wsl.exe -d Ubuntu --exec python3 /mnt/c/f150-dash-cluster/tests/usb-install-replay.py
wsl.exe -d Ubuntu --exec sh -c "cd /mnt/c/f150-dash-cluster && python3 tools/build_usb_install.py"
```

The builder reads the updater archive password from the captured updater; the password does not enter Git. Copy `drive/` to the top level of the USB drive, and copy exactly one file from `markers/`. Keep `viknav-ui/settings-before-install.tar` on the drive after the first install; rollback restores the stock settings from that file.
To release a new candidate, move the current `etc_sha256` pins into `etc_previous` (and a changed Launcher pin into `PREVIOUS_LAUNCHERS`), list files the new release drops in `RETIRED_FILES`, then pin the new files.
Do not put `dashboard.zip`, `Ford.zip`, `factory.zip`, or a `dashboard_backup` folder on the drive. Those names start other vendor updater actions.

## Patch boundary

Source replay verifies selected math and state transitions. Source replay does not verify Qt rendering, CAN interpretation, sensor calibration, or live vehicle behavior.

The UI candidate redirects three compiled loaders and includes four source files.
The generator clears 13 code records in the old factory gate. The generator preserves native code, ELF geometry, and the other 195 cache units.
The menu-v1 and menu-v2 candidates are installed on the truck (2026-10-30). Both install logs show a clean start, and the menu-v2 key trace recorded the wheel bounce. Other vehicle checks remain open.

System > Units shows independent Manual/Follow state and exposes `followVehicleUnits()`. Host tests verify the controls with recorded native-call stubs.

Factory is a vnM page without a code prompt. The page exposes General settings and the compiled Advanced, Fuel tank, Vehicle profile, Odometer, and Service commands pages.
The page also exposes the existing ADB, Debug logging, USB image preview, Screen grid, and Car model options actions. Actions require explicit activation.
Factory runs the vendor service-list query on entry. General settings run the separate status query on entry; the original page waited 50 ms.
General settings show all 19 controls. Seven controls that no compiled page or native code reads (sub tank, eco, gear, oil temperature, range, oil pressure, chassis state) show "No effect in this firmware" and do not change.
Back returns to the Factory row where the page opened. A compiled page opened from Advanced settings returns to Advanced settings.
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

The GPS clock keeps the native GPS time sync off (`timezone: 255`). The native path writes a whole-hour offset with no daylight saving time.
Check these items on the truck before the GPS clock counts as verified:

- Which notification (`gpsDateTimeInfoNotify` or `gpsLatLongInfoNotify`) follows an RMC sentence. The source calls the sync from both.
- The `getGpsNmea(NMEA_TYPE_RMC)` text: a full `$..RMC` sentence, with or without the checksum.
- The MCU accepts `setRtc("yyyy-MM-dd hh:mm:ss")` with seconds, and the next 0x32 notification shows the new time.
- The MCU date after a power cut. A year before 2026 shows dashes until the first GPS time or a manual set.
- The time from power-up to the first GPS time, under open sky and in a garage.
- A GPS receiver with the week-rollover fault reports a year before 2026. The clock then never sets.

The zone grid uses 0.05° cells (about 5 km). Within one cell of a zone line, the zone can be wrong. A new zone must hold for 60 s before the clock changes.
Zones with rules other than the US and Canada rule (for example Cuba) have no grid cells. There the clock keeps the last zone.

Keep power relays and vehicle controls unchanged until separate hardware checks prove the shutdown path.

## Third-party source notices

`evidence/qt-5.14.2/qv4instr_moth_p.h` preserves the Qt 5.14.2 copyright and license header unchanged.
The adjacent `LICENSE.LGPL3`, `LICENSE.GPL2`, and `LICENSE.GPL3` files preserve the upstream license texts.
`PROVENANCE.json` records official source URLs and byte hashes. The decoder reads opcode declarations from the header.
Vendor QML fixtures and dashboard assets retain vendor ownership. This repository grants no new license for vendor content.
The GPS clock zone grid in `patches/capture-04/etc/common/Global.qml` comes from timezone-boundary-builder 2026e.
The grid contains OpenStreetMap data, © OpenStreetMap contributors, under the Open Database License 1.0. The generated header records the source hash.
