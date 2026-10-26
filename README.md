# F150 digital dashboard cluster

Shared Codex and Claude project for the VikNav 13.1-inch Ford F150 cluster.

Private repository: [primez-x/f150-dash-cluster](https://github.com/primez-x/f150-dash-cluster).

Continue in the T3 project **F150 Dash Cluster**, which uses `C:\f150-dash-cluster` as the workspace.
Start each agent with `AGENTS.md` and this README. Claude also has `CLAUDE.md` as the entry point.

The repository contains source candidates, verification tools, and the complete design handoff.
Raw backups, extracted firmware, private settings, and credentials remain local in this workspace.
A fresh clone needs the local firmware evidence before the replay tools can run.

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
- Both source replays pass: 206 gauge cases and 194 unit-state cases. Independent review confirmed the candidate logic and persistence SQL.
- Five temperature families preserve documented unavailable states. Native calibration and actual vehicle accuracy remain unverified.
- Boot candidates remove automatic formatting after mount failure and stop later init scripts after critical mount failures.
- Private-data migration restores the original directory after a failed mount. If rollback fails, the data remains in `/private-move`.
- A failed copy preserves the migration backup. Independent review approved the boot candidates for a local commit.
- All six layouts have detailed specifications, coordinate schematics, and genuine assets under `handoff/claude-dashboard/`.

## Focused checks

Run the source replay from the project root:

```powershell
node tests/gauge-replay.cjs original
node tests/gauge-replay.cjs patched
node tests/unit-state-replay.cjs original
node tests/unit-state-replay.cjs patched
```

The original phase must reproduce the known failures. The patched phase must pass. Results are stored under `analysis/capture-04/`.

Check the boot candidates with Ubuntu under WSL:

```powershell
wsl.exe -d Ubuntu --exec python3 /mnt/c/f150-dash-cluster/tests/mount-safeguard.py
```

The boot replay uses mocked mount, filesystem-check, and format commands. Migration cases use guarded file operations inside temporary directories.
The replay also executes the candidate init loop against fake services. No device partition is mounted or changed.

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

The source candidates require integration into the active compiled UI or a verified external-source loader. No custom dashboard update has been installed.

The Units menu must show manual/follow state and expose `followVehicleUnits()` before vehicle delivery. The handoff includes that interface contract.

The new settings menu and consolidated cruise region remain UI integration work. The review records both current cruise display paths across all six layouts.

Boot candidates require target-shell and hardware checks before deployment. Launcher starts before the separate media mount in the captured boot order.
The existing stop functions do not unmount partitions. A restart can return a filesystem-check error when a partition remains mounted.
Critical failures stop later init scripts. The hardware postlude still runs. Repeated migration failures preserve the backup and hold normal boot.
Legacy migration copies the complete saved directory. Legacy files replace same-named partition files; the replay verifies that precedence.
Confirm migration precedence, display availability, and recovery access before any vehicle deployment.

Fuel and coolant calibration, invalid native values, signal freshness, polling limits, and shutdown behavior require vehicle reference data and hardware checks.

Keep power relays and vehicle controls unchanged until separate hardware checks prove the shutdown path.
