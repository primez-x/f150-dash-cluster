from __future__ import annotations

import argparse
from contextlib import nullcontext
import hashlib
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
INSTALLED = ROOT / "installed" / "capture-04" / "rootfs" / "etc" / "init.d"
CANDIDATE = ROOT / "patches" / "capture-04" / "etc" / "init.d"
RESULT = ROOT / "analysis" / "capture-04" / "mount-safeguard-results.json"
COMMANDS = ("mount", "e2fsck", "mkfs.ext4", "mkdir", "rmdir", "rm", "mv", "cp", "ln", "sync")
SCRIPTS = ("S01private", "S90mount")


class CheckFailure(Exception):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise CheckFailure(message)


def prepare_fixture(work: Path, source: Path, statuses: dict[str, int | list[int]], stale: bool = False) -> tuple[Path, Path, Path]:
    fixture = work / "fixture"
    fake_bin = work / "bin"
    fake_bin.mkdir(parents=True, exist_ok=True)
    if not fixture.exists():
        (fixture / "private" / "zj_save").mkdir(parents=True)
        (fixture / "private" / "settings.ini").write_text("fixture\n", encoding="utf-8")
        (fixture / "private" / "other-data").write_text("preserve\n", encoding="utf-8")
        if stale:
            (fixture / "private-move").mkdir()
            (fixture / "private-move" / "earlier-data").write_text("earlier\n", encoding="utf-8")
        (fixture / "root").mkdir()
        (fixture / "mnt" / "usb").mkdir(parents=True)
        (fixture / "mnt" / "sdcard").mkdir()

    replacements = {
        "/dev/mmcblk0p5": str(fixture / "device-private"),
        "/dev/mmcblk0p6": str(fixture / "device-mnt"),
        "/private-move": str(fixture / "private-move"),
        "/private": str(fixture / "private"),
        "/root": str(fixture / "root"),
        "/mnt": str(fixture / "mnt"),
    }
    adapted = source.read_text(encoding="utf-8")
    placeholders = {token: f"__SAFE_PATH_{index}__" for index, token in enumerate(replacements)}
    for original in sorted(replacements, key=len, reverse=True):
        adapted = adapted.replace(original + "/", placeholders[original] + "__SAFE_PATH_SEP__")
        adapted = adapted.replace(original, placeholders[original])
    adapted = adapted.replace("__SAFE_PATH_SEP__", "/")
    for original, placeholder in placeholders.items():
        adapted = adapted.replace(placeholder, replacements[original])
    script_path = work / source.name
    script_path.write_text(adapted, encoding="utf-8")

    for command in COMMANDS:
        status = statuses.get(command, 0)
        if isinstance(status, list):
            cases = "\n".join(f"  {index}) status={value} ;;" for index, value in enumerate(status, 1))
            status_script = (
                'counter="$FAKE_LOG.$name.count"\n'
                'count=0; [ ! -f "$counter" ] || read -r count < "$counter"\n'
                'count=$((count + 1)); printf "%s\\n" "$count" > "$counter"\n'
                f'case "$count" in\n{cases}\n  *) status={status[-1]} ;;\nesac\n'
            )
        else:
            status_script = f"status={status}\n"
        wrapper = fake_bin / command
        wrapper.write_text(
            "#!/bin/sh\n"
            "name=${0##*/}\n"
            "{\n"
            "  printf '%s' \"$name\"\n"
            "  for arg do printf '\\t<%s>' \"$arg\"; done\n"
            "  printf '\\n'\n"
            "} >> \"$FAKE_LOG\"\n"
            "for arg do\n"
            "  case \"$arg\" in /*) resolved=$(/usr/bin/realpath -m -- \"$arg\") || exit 98; case \"$resolved\" in \"$FAKE_ROOT\"/*) ;; *) exit 98 ;; esac ;; esac\n"
            "done\n"
            + status_script +
            "[ \"$status\" -eq 0 ] || exit \"$status\"\n"
            "if [ \"$name\" = mount ] && [ \"$FAKE_SEED_PARTITION\" = 1 ]; then\n"
            "  for target do :; done\n"
            "  printf 'partition\\n' > \"$target/settings.ini\"\n"
            "  printf 'partition\\n' > \"$target/other-data\"\n"
            "fi\n"
            "if [ \"$FAKE_MUTATE\" = 1 ]; then\n"
            "  case \"$name\" in mkdir|rmdir|rm|mv|cp|ln) exec /usr/bin/\"$name\" \"$@\" ;; esac\n"
            "fi\n"
            "exit \"$status\"\n",
            encoding="utf-8",
        )
        wrapper.chmod(0o755)
    return fixture, fake_bin, script_path


def run_case(
    label: str,
    source: Path,
    action: str,
    fsck_status: int,
    mount_status: int,
    *,
    mutate: bool = True,
    stale: bool = False,
    cp_status: int = 0,
    extra_statuses: dict[str, int | list[int]] | None = None,
    work_dir: Path | None = None,
    seed_partition: bool = False,
) -> dict[str, object]:
    context = tempfile.TemporaryDirectory(prefix="mount-safeguard-") if work_dir is None else nullcontext(str(work_dir))
    with context as temp_root:
        work = Path(temp_root)
        fixture, fake_bin, script_path = prepare_fixture(
            work,
            source,
            {"e2fsck": fsck_status, "mount": mount_status, "cp": cp_status, **(extra_statuses or {})},
            stale,
        )
        log_path = work / "commands.log"
        log_path.write_text("", encoding="utf-8")
        for counter in work.glob("commands.log.*.count"):
            counter.unlink()
        env = os.environ.copy()
        env["PATH"] = f"{fake_bin}:/usr/bin:/bin"
        env["FAKE_LOG"] = str(log_path)
        env["FAKE_ROOT"] = str(fixture)
        env["FAKE_MUTATE"] = "1" if mutate else "0"
        env["FAKE_SEED_PARTITION"] = "1" if seed_partition else "0"
        result = subprocess.run(
            ["/bin/sh", str(script_path), action],
            cwd=fixture,
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )
        raw_lines = log_path.read_text(encoding="utf-8").splitlines() if log_path.exists() else []
        fixture_prefix = fixture.as_posix() + "/"
        for line in raw_lines:
            for field in line.split("\t")[1:]:
                argument = field.strip("<>")
                if argument.startswith("/"):
                    require(argument.startswith(fixture_prefix), f"Command path escaped fixture: {argument}")
        commands = [line.split("\t", 1)[0] for line in raw_lines]
        return {
            "label": label,
            "action": action,
            "fsck_status": fsck_status,
            "mount_status": mount_status,
            "exit_code": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr,
            "commands": commands,
            "command_log": raw_lines,
            "private_data_preserved": all((fixture / "private" / name).is_file() and (fixture / "private" / name).read_text() == value for name, value in (("settings.ini", "fixture\n"), ("other-data", "preserve\n"))),
            "backup_data_preserved": all((fixture / "private-move" / name).is_file() and (fixture / "private-move" / name).read_text() == value for name, value in (("settings.ini", "fixture\n"), ("other-data", "preserve\n"))),
            "backup_exists": (fixture / "private-move").exists(),
            "nested_backup_exists": (fixture / "private-move" / "private").exists(),
        }


def counts(case: dict[str, object], command: str) -> int:
    return list(case["commands"]).count(command)


def run_baseline() -> dict[str, dict[str, dict[str, object]]]:
    baseline: dict[str, dict[str, dict[str, object]]] = {}
    for name in SCRIPTS:
        source = INSTALLED / name
        require(source.is_file(), f"Missing installed source: {source}")
        mount_failure = run_case(f"baseline_{name}_mount_failure", source, "start", 0, 1, mutate=False)
        require(mount_failure["exit_code"] == 0, f"Expected baseline zero exit for {name} mount failure")
        require(counts(mount_failure, "mkfs.ext4") == 1, f"Expected baseline format after {name} mount failure")
        require(counts(mount_failure, "mount") == 2, f"Expected baseline retry mount for {name}")

        fsck_failure = run_case(f"baseline_{name}_fsck_4", source, "start", 4, 0, mutate=False)
        require(fsck_failure["exit_code"] == 0, f"Expected baseline zero exit for {name} fsck failure")
        require(counts(fsck_failure, "mount") == 1, f"Expected baseline mount after {name} fsck failure")
        baseline[name] = {"mount_failure": mount_failure, "fsck_4": fsck_failure}
    return baseline


def verify_red(baseline: dict[str, dict[str, dict[str, object]]]) -> None:
    for name in SCRIPTS:
        mount_failure = baseline[name]["mount_failure"]
        fsck_failure = baseline[name]["fsck_4"]
        require(mount_failure["exit_code"] == 0, f"Baseline {name} did not mask mount failure")
        require(counts(mount_failure, "mkfs.ext4") == 1, f"Baseline {name} did not reproduce format risk")
        require(counts(mount_failure, "rm") > 0, f"Baseline {name} did not continue cleanup")
        require(counts(fsck_failure, "mount") > 0, f"Baseline {name} did not mount after fsck status 4")
        require(counts(fsck_failure, "rm") > 0, f"Baseline {name} did not continue cleanup after fsck status 4")


def verify_candidate(name: str, source: Path) -> dict[str, dict[str, object]]:
    require(source.is_file(), f"Missing candidate source: {source}")
    cases: dict[str, dict[str, object]] = {}

    for action in ("start", "restart"):
        case = run_case(f"{name}_{action}_mount_failure", source, action, 0, 1)
        require(case["exit_code"] != 0, f"{name} {action} returned success after mount failure")
        require(counts(case, "mount") == 1, f"{name} {action} retried failed mount")
        require(counts(case, "mkfs.ext4") == 0, f"{name} {action} formatted after mount failure")
        require(counts(case, "cp") == 0, f"{name} {action} copied data after mount failure")
        require(counts(case, "rm") == 0, f"{name} {action} removed data after mount failure")
        require(counts(case, "ln") == 0, f"{name} {action} created root symlink after mount failure")
        require(counts(case, "sync") == 0, f"{name} {action} ran cleanup sync after mount failure")
        allowed_after_mount = ["rmdir", "mv"] if name == "S01private" else []
        mount_index = list(case["commands"]).index("mount")
        require(list(case["commands"])[mount_index + 1:] == allowed_after_mount, f"{name} {action} ran unexpected commands after mount failure")
        require("Failed to mount" in str(case["stderr"]), f"{name} {action} did not report mount failure")
        cases[f"mount_failure_{action}"] = case

    healthy = run_case(f"{name}_healthy", source, "start", 0, 0)
    require(healthy["exit_code"] == 0, f"{name} failed on healthy mount")
    require(counts(healthy, "mount") == 1, f"{name} healthy path did not mount once")
    require(counts(healthy, "mkfs.ext4") == 0, f"{name} healthy path formatted a partition")
    if name == "S01private":
        require(counts(healthy, "cp") == 1, "S01private must copy the complete legacy directory")
        require(counts(healthy, "rm") == 2, "S01private healthy path lost migration or root cleanup")
        require(counts(healthy, "ln") == 1, "S01private healthy path lost root symlink setup")
    else:
        require(counts(healthy, "rm") == 2, "S90mount healthy path lost mount cleanup")
        require(counts(healthy, "sync") == 1, "S90mount healthy path lost sync")
    cases["healthy"] = healthy

    corrected = run_case(f"{name}_fsck_1_corrected", source, "start", 1, 0)
    require(corrected["exit_code"] == 0, f"{name} rejected corrected e2fsck status 1")
    require(counts(corrected, "mount") == 1, f"{name} did not mount after corrected e2fsck status 1")
    require(counts(corrected, "mkfs.ext4") == 0, f"{name} formatted after corrected e2fsck status 1")
    cases["fsck_1_corrected"] = corrected

    uncorrectable = run_case(f"{name}_fsck_4_uncorrectable", source, "start", 4, 0)
    require(uncorrectable["exit_code"] != 0, f"{name} accepted e2fsck status 4")
    require(counts(uncorrectable, "mount") == 0, f"{name} mounted after e2fsck status 4")
    require(counts(uncorrectable, "mkfs.ext4") == 0, f"{name} formatted after e2fsck status 4")
    require(counts(uncorrectable, "cp") == 0, f"{name} copied data after e2fsck status 4")
    require(counts(uncorrectable, "rm") == 0, f"{name} removed data after e2fsck status 4")
    require(counts(uncorrectable, "ln") == 0, f"{name} created root symlink after e2fsck status 4")
    fsck_index = list(uncorrectable["commands"]).index("e2fsck")
    require(len(list(uncorrectable["commands"])) == fsck_index + 1, f"{name} ran commands after e2fsck status 4")
    require("e2fsck" in str(uncorrectable["stderr"]), f"{name} did not report e2fsck status 4")
    cases["fsck_4_uncorrectable"] = uncorrectable
    for status in (2, 3, 8, 12, 32):
        stopped = run_case(f"{name}_fsck_{status}", source, "start", status, 0)
        require(stopped["exit_code"] == status, f"{name} masked fsck status {status}")
        require(stopped["commands"] == ["e2fsck"], f"{name} changed data after fsck status {status}")
        cases[f"fsck_{status}"] = stopped
    for case in cases.values():
        for line in case["command_log"]:
            if line.startswith("mount\t"):
                require(f"device-{'private' if name == 'S01private' else 'mnt'}>" in line, f"{name} mounted the wrong device")
                require(line.endswith(f"/{'private' if name == 'S01private' else 'mnt'}>"), f"{name} mounted the wrong target")
                require(("\t<-o>\t<sync>" in line) == (name == "S01private"), f"{name} changed mount options")
    if name == "S01private":
        failed = run_case("migration_mount_failure", source, "start", 0, 1, mutate=True)
        require(failed["exit_code"] != 0 and failed["private_data_preserved"], "Mount failure lost original private data")
        require(not failed["backup_exists"], "Mount failure left migration state across boots")
        cases["migration_mount_failure"] = failed
        stale_case = run_case("migration_conflict", source, "start", 0, 0, mutate=True, stale=True)
        require(stale_case["exit_code"] != 0, "Conflicting migration directories were accepted")
        require(stale_case["private_data_preserved"] and stale_case["backup_exists"], "Migration conflict lost data")
        require(not stale_case["nested_backup_exists"], "Migration conflict nested the current private directory")
        require(counts(stale_case, "mv") == 0 and counts(stale_case, "rm") == 0, "Migration conflict changed data")
        cases["migration_conflict"] = stale_case
        copied = run_case("migration_success", source, "start", 0, 0, mutate=True)
        require(copied["exit_code"] == 0 and copied["private_data_preserved"], "Migration dropped legacy files")
        require(not copied["backup_exists"], "Successful migration retained pending state")
        cases["migration_success"] = copied
        overlap = run_case("migration_legacy_precedence", source, "start", 0, 0, seed_partition=True)
        require(overlap["exit_code"] == 0 and overlap["private_data_preserved"], "Migration changed the declared legacy-file precedence")
        cases["migration_legacy_precedence"] = overlap
        copy_failed = run_case("migration_copy_failure", source, "start", 0, 0, mutate=True, cp_status=1)
        require(copy_failed["exit_code"] != 0 and copy_failed["backup_data_preserved"], "Copy failure discarded the legacy backup")
        require(counts(copy_failed, "rm") == 0 and counts(copy_failed, "ln") == 0, "Copy failure continued cleanup")
        cases["migration_copy_failure"] = copy_failed
        mkdir_failed = run_case("migration_mkdir_failure", source, "start", 0, 0, extra_statuses={"mkdir": 1})
        require(mkdir_failed["exit_code"] == 1 and mkdir_failed["private_data_preserved"], "Directory creation failure lost legacy data")
        require(not mkdir_failed["backup_exists"], "Directory creation failure left pending migration state")
        cases["migration_mkdir_failure"] = mkdir_failed
        for command, status in (("rmdir", 1), ("mv", [0, 1])):
            rollback_failed = run_case(f"migration_rollback_{command}_failure", source, "start", 0, 1, extra_statuses={command: status})
            require(rollback_failed["exit_code"] != 0 and rollback_failed["backup_data_preserved"], f"Failed {command} rollback lost the backup")
            require(not rollback_failed["nested_backup_exists"], f"Failed {command} rollback nested legacy data")
            cases[f"migration_rollback_{command}_failure"] = rollback_failed
        remove_failed = run_case("migration_remove_failure", source, "start", 0, 0, extra_statuses={"rm": 1})
        require(remove_failed["exit_code"] != 0 and remove_failed["private_data_preserved"] and remove_failed["backup_data_preserved"], "Backup removal failure lost data")
        require(counts(remove_failed, "ln") == 0, "Backup removal failure continued root setup")
        cases["migration_remove_failure"] = remove_failed
        with tempfile.TemporaryDirectory(prefix="migration-boots-") as directory:
            for boot, copy_status in enumerate((1, 1, 0), 1):
                result = run_case(f"migration_boot_{boot}", source, "start", 0, 0, cp_status=copy_status, work_dir=Path(directory))
                require(result["exit_code"] == copy_status, f"Boot {boot} masked the copy result")
                require(not result["nested_backup_exists"], f"Boot {boot} nested the migration backup")
                require(result["backup_data_preserved"] if copy_status else result["private_data_preserved"], f"Boot {boot} lost legacy data")
                cases[f"migration_boot_{boot}"] = result
    return cases


def verify_boot_loop() -> dict[str, object]:
    source = CANDIDATE / "rcS"
    text = source.read_text(encoding="utf-8")
    begin = text.index("for i in /etc/init.d/S??*")
    end = text.index("\ndone", begin) + len("\ndone")
    require(text.rfind('exit "$boot_status"') > text.index("echo usb_host"), "Boot status exit skips the hardware postlude")
    loop = 'boot_status=0\n' + text[begin:end]
    results = {}
    for failed_script in ("none", "S01private", "S90mount"):
        with tempfile.TemporaryDirectory(prefix="mount-boot-loop-") as directory:
            work = Path(directory)
            log = work / "boot.log"
            for name in ("S00heartbeat", "S01private", "S22launcher", "S90mount", "S90zlink"):
                script = work / name
                script.write_text(f"#!/bin/sh\necho {name} >> '{log}'\nexit {7 if name == failed_script else 0}\n", encoding="utf-8")
                script.chmod(0o755)
            adapted = loop.replace("/etc/init.d/", str(work) + "/") + f'\nprintf "postlude\\n" >> "{log}"\nexit "$boot_status"\n'
            check = subprocess.run(["/bin/sh", "-c", adapted], capture_output=True, text=True)
            names = log.read_text().splitlines()
            expected = ["S00heartbeat", "S01private", "S22launcher", "S90mount", "S90zlink"]
            if failed_script != "none":
                expected = expected[:expected.index(failed_script) + 1]
            expected.append("postlude")
            require(names == expected, f"Boot sequence differs after {failed_script}: {names}")
            require(check.returncode == (0 if failed_script == "none" else 7), "Boot loop masked a critical mount failure")
            results[failed_script] = {"exit_code": check.returncode, "scripts": names}
    return results


def save_result(payload: dict[str, object]) -> None:
    RESULT.parent.mkdir(parents=True, exist_ok=True)
    RESULT.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--red", action="store_true")
    args = parser.parse_args()
    payload: dict[str, object] = {
        "project_root": str(ROOT),
        "fixture_policy": "Mount, fsck, and format commands are mocks. Selected migration checks use real file operations inside temporary fixtures with guarded absolute paths.",
    }
    try:
        baseline = run_baseline()
        verify_red(baseline)
        payload["pre_patch"] = {"status": "RED_REPRODUCED", "cases": baseline}
        if args.red:
            payload["result"] = "PRE_PATCH_RED_REPRODUCED"
            save_result(payload)
            print("RED: both installed scripts formatted after mount failure and returned zero.")
            print(f"Result: {RESULT}")
            return 0

        candidate: dict[str, dict[str, dict[str, object]]] = {}
        for name in SCRIPTS:
            for source in (INSTALLED / name, CANDIDATE / name):
                require(b"\r" not in source.read_bytes(), f"Non-LF shell source: {source}")
            candidate[name] = verify_candidate(name, CANDIDATE / name)
        payload["candidate"] = candidate
        payload["boot_loop"] = verify_boot_loop()
        payload["candidate_source_sha256"] = {}
        for name in (*SCRIPTS, "rcS"):
            source = CANDIDATE / name
            data = source.read_bytes()
            require(b"\r" not in data, f"Non-LF shell source: {source}")
            payload["candidate_source_sha256"][name] = hashlib.sha256(data).hexdigest()
        payload["result"] = "PASS"
        save_result(payload)
        print("GREEN: both candidates passed mount, fsck, healthy, corrected-status, and restart checks.")
        print(f"Result: {RESULT}")
        return 0
    except (CheckFailure, OSError, subprocess.SubprocessError) as error:
        payload["result"] = "FAIL"
        payload["failure"] = str(error)
        save_result(payload)
        print(f"FAIL: {error}", file=sys.stderr)
        print(f"Result: {RESULT}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
