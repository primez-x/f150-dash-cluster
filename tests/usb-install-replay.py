"""Replay the USB installer (tools/usb-install/encrypt.sh) against a fake cluster root with the real payload bytes.

Run under WSL: python3 tests/usb-install-replay.py
The installer runs in dash (an ash-family shell) with BusyBox applets only on PATH. The BusyBox shell itself runs its own
applets before PATH, so the BusyBox shell only checks the syntax here. Stubs replace killall, ps, sleep, fbinit, and /etc/qtenv.sh. The qtenv stub writes a Launcher log for the installed Launcher: the candidate log follows the case, and
the original log is always healthy. No device, partition, or captured ARM program is used.
"""
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools/usb-install/encrypt.sh"
BUSYBOX = ROOT / "tools/busybox/busybox"
CANDIDATE = ROOT / "analysis/capture-04/ui-candidate-fuel-log-v1"
ORIGINAL = ROOT / "installed/capture-04/rootfs/usr/bin/Launcher"
RESULT = ROOT / "analysis/capture-04/usb-install-replay-results.json"
ETC = ["vnB.qml", "vnF.qml", "vnG.qml", "vnU.qml", "vnV.qml"]
APPLETS = ["awk", "cat", "chmod", "cp", "date", "df", "grep", "head", "mkdir", "mv", "rm", "sha256sum", "sync", "tar", "wc"]
MARKERS = {"install": ("VIKNAV-UI-INSTALL.txt", "VIKNAV_UI_INSTALL_FUEL_LOG_V1"),
           "rollback": ("VIKNAV-UI-ROLLBACK.txt", "VIKNAV_UI_ROLLBACK_CAPTURE04"),
           "log": ("VIKNAV-UI-LOG.txt", "VIKNAV_UI_LOG"),
           "record": ("VIKNAV-UI-RECORD.txt", "VIKNAV_UI_RECORD")}

FAILURE_MODES = [
    "The installer changes the cluster when the USB drive or the action is ambiguous",
    "The installer replaces a Launcher or /etc file that is not the known original or candidate",
    "A damaged or incomplete payload on the USB drive reaches the cluster",
    "Low space or a failed copy leaves a partial install or a stopped dashboard",
    "A candidate that does not start, does not load the new QML, or logs a new-QML error stays installed",
    "A failed install repeats each time the drive is inserted or the cluster starts",
    "A repeated install or rollback restarts the dashboard when nothing changes",
    "Rollback does not restore the original Launcher, /etc files, and settings",
    "The restarted Launcher holds the USB drive (working directory or output stream)",
    "Log collection changes the cluster",
    "The recorder misses new Launcher log lines, runs twice, or keeps running after the drive is gone",
]

sha = lambda data: hashlib.sha256(data).hexdigest()
ORIGINAL_BYTES = ORIGINAL.read_bytes()
CANDIDATE_BYTES = (CANDIDATE / "Launcher").read_bytes()
ETC_BYTES = {name: (CANDIDATE / "etc" / name).read_bytes() for name in ETC}
SETTINGS = b"settings before install\n"

STUB_QTENV = r"""#!/bin/sh
# Test stub for /etc/qtenv.sh: records the caller context, then writes the Launcher log.
T=__T__
R=$T/root
printf 'start cwd=%s fd1=%s\n' "$(pwd)" "$(readlink /proc/$$/fd/1)" >> "$T/calls"
h=$(sha256sum "$R/usr/bin/Launcher"); h=${h%% *}
mode=healthy
[ "$h" = "__CANDIDATE__" ] && mode=$(cat "$T/candidate-mode")
# The process runs before the process writes a log line. A process that dies leaves the flag off.
[ "$mode" = dies ] || : > "$T/running"
log=$R/tmp/Launcher.log
printf 'qml: [Translation Starting...]\n' > "$log"
case "$mode" in nomarker) ;; *)
    printf 'qml: [Starting VehicleEvent .....]\nqml: [VehicleEvent Ver:VehicleEvent@20250714 r36577]\nqml: [main.qml starting...]\n' >> "$log" ;; esac
[ "$mode" = vnerror ] && printf 'file:///etc/vnG.qml:120: ReferenceError: x is not defined\n' >> "$log"
[ "$h" = "__CANDIDATE__" ] && printf 'changed by candidate\n' > "$R/private/Launcher/settings.db"
exit 0
"""
STUB_PS = """#!/bin/sh
echo '  PID USER       COMMAND'
[ -f __T__/running ] && echo ' 1145 root       Launcher FORD-test 0 1 2 0'
exit 0
"""
STUB_KILLALL = """#!/bin/sh
echo "killall $*" >> __T__/calls
rm -f __T__/running
exit 0
"""
STUB_SLEEP = "#!/bin/sh\nexec __BB__ sleep 0.02\n"
STUB_FBINIT = "#!/bin/sh\nexit 0\n"


class Case:
    def __init__(self, base):
        self.t = Path(tempfile.mkdtemp(dir=base))
        self.root = self.t / "root"
        self.usb = self.t / "usb" / "sda1"
        for d in ("usr/bin", "etc", "private/Launcher", "tmp", "proc", "mnt/temp/encrypt"):
            (self.root / d).mkdir(parents=True)
        (self.root / "usr/bin/Launcher").write_bytes(ORIGINAL_BYTES)
        (self.root / "private/Launcher/settings.db").write_bytes(SETTINGS)
        self.usb.mkdir(parents=True)
        (self.usb / "encrypt.zip").write_bytes(b"zip")
        payload = self.usb / "viknav-ui"
        (payload / "etc").mkdir(parents=True)
        (payload / "original").mkdir()
        (payload / "Launcher").write_bytes(CANDIDATE_BYTES)
        (payload / "original/Launcher").write_bytes(ORIGINAL_BYTES)
        for name, data in ETC_BYTES.items():
            (payload / "etc" / name).write_bytes(data)
        (self.root / "proc/mounts").write_text(f"/dev/root / ext2 rw 0 0\n/dev/sda1 {self.usb} vfat rw,relatime 0 0\n")
        (self.t / "candidate-mode").write_text("healthy")
        # The log of the running original Launcher already has both startup lines: a stale log must not pass the health check.
        (self.root / "tmp/Launcher.log").write_text("qml: [VehicleEvent Ver:VehicleEvent@20250714 r36577]\nqml: [main.qml starting...]\n")
        (self.t / "running").write_text("")
        fakebin = self.t / "bin"
        fakebin.mkdir()
        for applet in APPLETS + ["readlink", "pwd", "tail", "cut", "kill"]:
            (fakebin / applet).symlink_to(BUSYBOX)
        # The recorder runs in a second shell. dash keeps the sleep stub in use (the BusyBox shell would run its own sleep).
        (fakebin / "sh").symlink_to("/bin/dash")
        stubs = {"ps": STUB_PS, "killall": STUB_KILLALL, "sleep": STUB_SLEEP, "fbinit": STUB_FBINIT}
        for name, text in stubs.items():
            self.stub(fakebin / name, text)
        self.stub(self.root / "etc/qtenv.sh", STUB_QTENV)
        source = SCRIPT.read_text()
        for anchor, value in (("USB_BASE=/mnt/usb\n", f"USB_BASE={self.usb.parent}\n"),
                              ("SYSTEM_ROOT=\n", f"SYSTEM_ROOT={self.root}\n"),
                              ("PATH=/bin:/usr/bin:/sbin:/usr/sbin\n", f"PATH={fakebin}\n"),
                              ("LOG_WAIT=180\n", "LOG_WAIT=1\n")):
            if source.count(anchor) != 1:
                raise SystemExit(f"Installer anchor missing: {anchor!r}")
            source = source.replace(anchor, value)
        self.script = self.root / "mnt/temp/encrypt/encrypt.sh"
        self.script.write_text(source)

    def stub(self, path, text):
        path.write_text(text.replace("__T__", str(self.t)).replace("__BB__", str(BUSYBOX))
                        .replace("__CANDIDATE__", sha(CANDIDATE_BYTES)))
        path.chmod(0o755)

    def marker(self, action, drive=None):
        name, token = MARKERS[action]
        ((drive or self.usb) / name).write_text(token + "\n")

    def unmark(self):
        for name, _ in MARKERS.values():
            (self.usb / name).unlink(missing_ok=True)

    def run(self):
        before = self.outputs()
        result = subprocess.run(["/bin/dash", str(self.script)], capture_output=True, text=True, timeout=120,
                                env={"PATH": "/usr/bin:/bin"})
        new = sorted(set(self.outputs()) - set(before))
        self.out = self.usb / new[-1] if new else None
        self.stderr = result.stderr
        return self

    def outputs(self):
        return sorted(p.name for p in self.usb.glob("viknav-ui-*"))

    def status(self):
        return (self.out / "STATUS.txt").read_text().split("\n")[0] if self.out and (self.out / "STATUS.txt").exists() else None

    def calls(self):
        path = self.t / "calls"
        return path.read_text().splitlines() if path.exists() else []

    def starts(self):
        return sum(1 for line in self.calls() if line.startswith("start"))

    def device(self):
        launcher = sha((self.root / "usr/bin/Launcher").read_bytes())
        state = "original" if launcher == sha(ORIGINAL_BYTES) else "candidate" if launcher == sha(CANDIDATE_BYTES) else "other"
        etc = {name: (self.root / "etc" / name).exists() and sha((self.root / "etc" / name).read_bytes()) == sha(ETC_BYTES[name]) for name in ETC}
        present = [name for name in ETC if (self.root / "etc" / name).exists()]
        if state == "candidate" and all(etc.values()):
            return "candidate"
        if state == "original" and not present:
            return "original"
        return f"mixed launcher={state} etc={present}"

    def settings(self):
        return (self.root / "private/Launcher/settings.db").read_bytes()

    def leftovers(self):
        return sorted(str(p.relative_to(self.root)) for p in self.root.rglob(".*.new"))


rows = []


def wait_for(condition, seconds=20):
    import time
    end = time.time() + seconds
    while time.time() < end:
        if condition():
            return True
        time.sleep(0.05)
    return False


def check(name, mode, expected, run):
    try:
        actual = run()
    except Exception as error:  # a crash is a failed case, not a stop
        actual = f"error: {type(error).__name__}: {error}"
    rows.append({"name": name, "failureMode": FAILURE_MODES[mode], "expected": expected, "actual": actual,
                 "pass": json.dumps(actual, sort_keys=True) == json.dumps(expected, sort_keys=True)})


def install(case, mode="healthy"):
    (case.t / "candidate-mode").write_text(mode)
    case.marker("install")
    return case.run()


def main():
    if not BUSYBOX.is_file():
        raise SystemExit("tools/busybox/busybox is missing (see README)")
    syntax = subprocess.run([str(BUSYBOX), "sh", "-n", str(SCRIPT)], capture_output=True, text=True)
    rows.append({"name": "busybox-ash-syntax", "failureMode": "The cluster shell rejects the installer", "expected": 0,
                 "actual": syntax.returncode, "pass": syntax.returncode == 0})
    base = tempfile.mkdtemp(prefix="usb-install-replay-")
    try:
        new = lambda: Case(base)

        def healthy():
            c = install(new())
            return [c.status(), c.device(), c.starts(), c.settings() == b"changed by candidate\n",
                    (c.out / "private-Launcher.tar").exists(), (c.usb / "viknav-ui/settings-before-install.tar").exists(),
                    (c.out / "Launcher-start.log").exists(), (c.out / "Launcher-later.log").exists(), c.leftovers()]
        check("install-healthy", 4, ["INSTALLED", "candidate", 1, True, True, True, True, True, []], healthy)

        def restart_context():
            c = install(new())
            return [line for line in c.calls() if line.startswith("start")]
        check("restart-detached-from-usb", 8, ["start cwd=/ fd1=/dev/null"], restart_context)

        def retrigger():
            c = install(new())
            c.run()
            return [c.status(), c.device(), c.starts()]
        check("install-again-no-restart", 6, ["ALREADY_INSTALLED", "candidate", 1], retrigger)

        def partial():
            c = new()
            (c.root / "etc/vnG.qml").write_bytes(ETC_BYTES["vnG.qml"])
            install(c)
            return [c.status(), c.device()]
        check("partial-earlier-install-completes", 6, ["INSTALLED", "candidate"], partial)

        def unknown_launcher():
            c = new()
            (c.root / "usr/bin/Launcher").write_bytes(ORIGINAL_BYTES + b"x")
            install(c)
            return [c.status(), c.starts(), [x for x in c.calls() if x.startswith("killall")]]
        check("unknown-launcher-refused", 1, ["ABORTED unknown Launcher", 0, []], unknown_launcher)

        def unknown_etc():
            c = new()
            (c.root / "etc/vnU.qml").write_text("other\n")
            install(c)
            return [c.status(), c.device(), c.starts()]
        check("unknown-etc-file-refused", 1, ["ABORTED unknown /etc/vnU.qml", "mixed launcher=original etc=['vnU.qml']", 0], unknown_etc)

        def bad_payload():
            c = new()
            (c.usb / "viknav-ui/etc/vnV.qml").write_bytes(ETC_BYTES["vnV.qml"][:-10])
            install(c)
            return [c.status(), c.device(), c.starts(), c.calls()]
        check("damaged-payload-refused", 2, ["ABORTED payload etc/vnV.qml", "original", 0, []], bad_payload)

        def missing_original():
            c = new()
            (c.usb / "viknav-ui/original/Launcher").unlink()
            install(c)
            return [c.status(), c.device(), c.starts()]
        check("install-needs-rollback-payload", 2, ["ABORTED payload original/Launcher", "original", 0], missing_original)

        def low_space():
            c = new()
            c.script.write_text(c.script.read_text().replace("MIN_FREE_KB=40960\n", "MIN_FREE_KB=999999999999\n"))
            install(c)
            return [c.status(), c.device(), c.starts()]
        check("low-space-refused", 3, ["ABORTED low space", "original", 0], low_space)

        def copy_fails():
            c = new()
            (c.root / "usr/bin").chmod(0o555)
            install(c)
            (c.root / "usr/bin").chmod(0o755)
            return [c.status(), c.device(), c.starts(), c.settings() == SETTINGS, c.leftovers()]
        check("failed-copy-restarts-original", 3, ["ABORTED copy Launcher", "original", 1, True, []], copy_fails)

        for mode, reason in (("nomarker", "ROLLED_BACK startup markers missing"), ("vnerror", "ROLLED_BACK new QML error"),
                             ("dies", "ROLLED_BACK Launcher stopped")):
            def unhealthy(mode=mode):
                c = install(new(), mode)
                return [c.status(), c.device(), c.starts(), c.settings() == SETTINGS, (c.usb / "INSTALL-BLOCKED.txt").exists(),
                        (c.out / "Launcher-failed.log").exists(), c.leftovers()]
            check(f"unhealthy-{mode}-rolls-back", 4, [reason, "original", 2, True, True, True, []], unhealthy)

        def blocked():
            c = install(new(), "dies")
            c.run()
            return [c.status(), c.device(), c.starts()]
        check("blocked-after-failed-install", 5, ["BLOCKED", "original", 2], blocked)

        def two_drives():
            c = new()
            other = c.usb.parent / "sdb1"
            shutil.copytree(c.usb, other)
            with open(c.root / "proc/mounts", "a") as mounts:
                mounts.write(f"/dev/sdb1 {other} vfat rw 0 0\n")
            c.marker("install")
            c.marker("install", other)
            c.run()
            return [c.out, list(other.glob("viknav-ui-*")), c.device(), c.starts()]
        check("two-marked-drives-refused", 0, [None, [], "original", 0], two_drives)

        def two_actions():
            c = new()
            c.marker("install")
            c.marker("rollback")
            c.run()
            return [c.status(), c.device(), c.starts()]
        check("two-actions-refused", 0, ["ABORTED more than one action marker", "original", 0], two_actions)

        def not_mounted():
            c = new()
            (c.root / "proc/mounts").write_text("/dev/root / ext2 rw 0 0\n")
            install(c)
            return [c.out, c.device(), c.starts()]
        check("unmounted-drive-refused", 0, [None, "original", 0], not_mounted)

        def rollback():
            c = install(new())
            c.unmark()
            c.marker("rollback")
            c.run()
            return [c.status(), c.device(), c.starts(), c.settings() == SETTINGS, c.leftovers()]
        check("rollback-restores-original", 7, ["ROLLED_BACK by request", "original", 2, True, []], rollback)

        def rollback_again():
            c = install(new())
            c.unmark()
            c.marker("rollback")
            c.run()
            c.run()
            return [c.status(), c.device(), c.starts()]
        check("rollback-again-no-restart", 6, ["ALREADY_ORIGINAL", "original", 2], rollback_again)

        def rollback_bad_payload():
            c = install(new())
            c.unmark()
            (c.usb / "viknav-ui/original/Launcher").write_bytes(b"bad")
            c.marker("rollback")
            c.run()
            return [c.status(), c.device(), c.starts()]
        check("rollback-damaged-payload-refused", 7, ["ABORTED payload original/Launcher", "candidate", 1], rollback_bad_payload)

        def log_only():
            c = install(new())
            c.unmark()
            c.marker("log")
            c.run()
            return [c.status(), c.device(), c.starts(), (c.out / "Launcher.log").exists(),
                    "Launcher check: running" in (c.out / "installed-sha256.txt").read_text()]
        check("log-changes-nothing", 9, ["LOGGED", "candidate", 1, True, True], log_only)

        def record():
            c = new()
            (c.root / "proc/uptime").write_text("12.34 5.00\n")
            c.marker("record")
            c.run()
            first = c.status()
            pidfile = c.root / "tmp/viknav-recorder.pid"
            pid = int(pidfile.read_text()) if pidfile.exists() else 0
            target = c.out / "launcher.log" if c.out else Path("/nonexistent")
            with open(c.root / "tmp/Launcher.log", "a") as log:
                log.write("qml: viknav-data {\"tick\": 1}\n")
            copied = wait_for(lambda: target.exists() and "viknav-data" in target.read_text())
            again = c.run().status()
            (c.root / "proc/mounts").write_text("/dev/root / ext2 rw 0 0\n")
            stopped = wait_for(lambda: not Path(f"/proc/{pid}").exists())
            return [first, again, copied, stopped, c.device(), c.starts()]
        check("record-copies-log-until-drive-gone", 10, ["RECORDING", "ALREADY_RECORDING", True, True, "original", 0], record)
    finally:
        for path in Path(base).rglob("*"):
            if path.is_dir():
                path.chmod(0o755)
        shutil.rmtree(base)

    payload = {"script": str(SCRIPT.relative_to(ROOT)), "script_sha256": sha(SCRIPT.read_bytes()),
               "shell": subprocess.run([str(BUSYBOX)], capture_output=True, text=True).stdout.split("\n")[0],
               "failureModes": FAILURE_MODES, "count": len(rows), "passed": sum(r["pass"] for r in rows),
               "failed": sum(not r["pass"] for r in rows), "rows": rows,
               "scope": "BusyBox ash syntax check; dash with BusyBox applets for the cases; real Launcher and QML payload bytes, stubbed Launcher start and process list. "
                        "No cluster, vendor updater, Qt runtime, or vehicle proof."}
    RESULT.write_text(json.dumps(payload, indent=2) + "\n")
    print(json.dumps({k: payload[k] for k in ("count", "passed", "failed")} | {"result": str(RESULT)}))
    for row in rows:
        if not row["pass"]:
            print("FAIL", row["name"], "expected", row["expected"], "actual", row["actual"])
    return 1 if payload["failed"] else 0


if __name__ == "__main__":
    sys.exit(main())
