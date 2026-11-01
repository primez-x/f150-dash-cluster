"""Replay the USB installer (tools/usb-install/encrypt.sh) against a fake cluster root with the real payload bytes.

Run under WSL: python3 tests/usb-install-replay.py
The installer runs in the BusyBox ash shell, the shell of the cluster. BusyBox ash runs the BusyBox applets before PATH, so the
case copy of the installer defines shell functions for the stubs. Stubs replace killall, ps, sleep, fbinit, df, mv, and /etc/qtenv.sh. The qtenv stub writes a Launcher log for the installed Launcher: the candidate log follows the case, and
the original log is always healthy. The df stub reports a set free space for a folder only when the case asks for one, less the staged files present.
The fake root starts with the stock /etc/sound files; the payload carries chime set A and the stock sounds.
No device, partition, or captured ARM program is used.
"""
import hashlib
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools/usb-install/encrypt.sh"
BUSYBOX = ROOT / "tools/busybox/busybox"
CANDIDATE = ROOT / "analysis/capture-04/ui-candidate-menu-v15"
ORIGINAL = ROOT / "installed/capture-04/rootfs/usr/bin/Launcher"
RESULT = ROOT / "analysis/capture-04/usb-install-replay-results.json"
ETC = ["vnD.qml", "vnG.qml", "vnL.qml", "vnM.qml", "vnN.qml", "vnS.qml", "vnV.qml"]
# The first cluster install (menu-v1). The upgrade cases start from these files and the Launcher next to them.
V1_ETC = ROOT / "analysis/capture-04/usb-install-menu-v1/drive/viknav-ui/etc"
# The second release (menu-v2: native Factory pages and the key trace).
V2_ETC = ROOT / "analysis/capture-04/usb-install-menu-v2/drive/viknav-ui/etc"
# The third release (menu-v3: the wheel key bounce filter).
V3_ETC = ROOT / "analysis/capture-04/usb-install-menu-v3/drive/viknav-ui/etc"
# The fourth release (menu-v4: oil pressure in the data log).
V4_ETC = ROOT / "analysis/capture-04/usb-install-menu-v4/drive/viknav-ui/etc"
# The fifth release (menu-v5: the cruise fields in the data log).
V5_ETC = ROOT / "analysis/capture-04/usb-install-menu-v5/drive/viknav-ui/etc"
# The sixth release (menu-v6: boost and trailer brake readings in the data log).
V6_ETC = ROOT / "analysis/capture-04/usb-install-menu-v6/drive/viknav-ui/etc"
# The seventh release (menu-v7: engine gauge frame, compass, and oil life in the data log).
V7_ETC = ROOT / "analysis/capture-04/usb-install-menu-v7/drive/viknav-ui/etc"
# The eighth release (menu-v8: menu motion). menu-v8 has no vnD.qml and no vnN.qml.
V8_ETC = ROOT / "analysis/capture-04/usb-install-menu-v8/drive/viknav-ui/etc"
# The eleventh release (menu-v11: the owned dashboard shell and the fixed notification text). menu-v11 has no vnL.qml,
# and the menu-v11 Launcher is the candidate Launcher.
V11_ETC = ROOT / "analysis/capture-04/usb-install-menu-v11/drive/viknav-ui/etc"
# The twelfth release (menu-v12: the Daily A and Towing A layouts). menu-v12 left the stock sounds in /etc/sound.
V12_ETC = ROOT / "analysis/capture-04/usb-install-menu-v12/drive/viknav-ui/etc"
# Chime set A (design/round-43/sounds/make_sounds.py writes the files) and the stock sounds of the cluster.
SOUND_SET = ROOT / "design/round-43/sounds/a"
STOCK_SOUND = ROOT / "installed/capture-04/rootfs/etc/sound"

RETIRED = ["vnB.qml", "vnF.qml"]
APPLETS = ["awk", "cat", "chmod", "cp", "date", "grep", "head", "mkdir", "rm", "sha256sum", "sync", "tar", "wc"]
MARKERS = {"install": ("VIKNAV-UI-INSTALL.txt", "VIKNAV_UI_INSTALL"),
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
    "An upgrade from an earlier release is refused, keeps a retired file, or replaces the stock settings backup",
    "The installer replaces an /etc/sound file that is missing, a link, or not a stock or set A file",
    "The free space check misses the sounds or a filesystem that receives staged files",
    "A failed install or a failed sound copy leaves set A or a partial sound set on the cluster",
    "A rollback leaves set A sounds, or reports success after a failed sound restore",
    "A repeated install or rollback skips a needed sound change",
    "Log collection omits the /etc/sound hashes",
    "A rollback renames a stock file before every stock file is on disk, or changes the cluster when a copy fails",
    "A power cut or a failed step during a rollback leaves a mixed cluster, no settings, or the wrong settings, and the next insert skips the rollback",
    "A failed rollback step leaves the dashboard stopped",
    "A rollback reports success when the restarted Launcher fails the start check",
    "Two runs at once share the rollback journal, or a lock left by a stopped run blocks every later run",
    "The installer changes the cluster while a Launcher that does not stop still runs",
    "A damaged or changed stock settings backup reaches the cluster",
    "A block from a failed install stops a different release, or stays after a rollback",
]
# A real truck settings archive: the run backup of the menu-v2 install (Launcher/Databases sqlite and ini files).
TRUCK_SETTINGS = ROOT / "analysis/capture-04/vehicle-runs/menu-v2-install-1/private-Launcher.tar"
BACKUP_HELP = "Copy private-Launcher.tar from the first install folder to viknav-ui/settings-before-install.tar."
HASH_NOTE = "settings backup hash recorded now"
BUSY = "BUSY another viknav-ui run is active"
# STATUS.txt line 2 of BLOCKED: the drive marker alone, or the block on the cluster (with or without the drive marker).
DRIVE_BLOCK_HELP = "Remove INSTALL-BLOCKED.txt only after the cause is fixed."
CLUSTER_BLOCK_HELP = ("After the cause is fixed, insert a rollback drive: the rollback clears the block on the cluster and "
                      "INSTALL-BLOCKED.txt on that drive. Removing INSTALL-BLOCKED.txt alone leaves the block on the cluster.")

sha = lambda data: hashlib.sha256(data).hexdigest()
ORIGINAL_BYTES = ORIGINAL.read_bytes()
CANDIDATE_BYTES = (CANDIDATE / "Launcher").read_bytes()
ETC_BYTES = {name: (CANDIDATE / "etc" / name).read_bytes() for name in ETC}
SOUNDS = sorted(path.name for path in STOCK_SOUND.glob("*.wav"))
if len(SOUNDS) != 15 or not all((SOUND_SET / name).is_file() for name in SOUNDS):
    raise SystemExit("Chime set A is missing: run python3 design/round-43/sounds/make_sounds.py")
SOUND_BYTES = {name: (SOUND_SET / name).read_bytes() for name in SOUNDS}
# The release identity in the cluster block: the hash of the pinned Launcher, /etc, and sound hashes, one per line.
PAYLOAD_ID = sha("".join(h + "\n" for h in [sha(CANDIDATE_BYTES)] + [sha(ETC_BYTES[n]) for n in ETC]
                         + [sha(SOUND_BYTES[n]) for n in SOUNDS]).encode())
STOCK_SOUND_BYTES = {name: (STOCK_SOUND / name).read_bytes() for name in SOUNDS}
SETTINGS = b"settings before install\n"
# The settings that the candidate stub writes, and the settings in the backup of a failed install (rollback_now).
CANDIDATE_SETTINGS = b"changed by candidate\n"
AUTO_SETTINGS = b"settings at the failed install\n"
# The stock notification text table on the cluster (/etc/common/NotifyTranslation.qml).
STOCK_NOTIFY = (ROOT / "installed/capture-04/rootfs/etc/common/NotifyTranslation.qml").read_bytes()

STUB_QTENV = r"""#!/bin/sh
# Test stub for /etc/qtenv.sh: records the caller context, then writes the Launcher log.
T=__T__
R=$T/root
printf 'start cwd=%s fd1=%s\n' "$(pwd)" "$(readlink /proc/$$/fd/1)" >> "$T/calls"
h=$(sha256sum "$R/usr/bin/Launcher"); h=${h%% *}
mode=healthy
[ "$h" = "__CANDIDATE__" ] && mode=$(cat "$T/candidate-mode")
# original-mode sets the start of any other Launcher; without the file, that Launcher is healthy.
[ "$h" != "__CANDIDATE__" ] && [ -f "$T/original-mode" ] && mode=$(cat "$T/original-mode")
# The process runs before the process writes a log line. A process that dies leaves the flag off.
[ "$mode" = dies ] || : > "$T/running"
# long-launcher: a process that outlives this script stands in for the Launcher. The process keeps every inherited fd.
if [ -f "$T/long-launcher" ] && [ "$mode" != dies ]; then
    __BB__ sleep 60 </dev/null >/dev/null 2>&1 &
    echo "$!" >> "$T/launcher-pids"
fi
# locksound: the candidate does not start, and /etc/sound turns read-only, so the sound restore fails.
[ "$mode" = locksound ] && chmod 555 "$R/etc/sound"
# breakstock: the candidate does not start, and one stock sound on the drive turns bad, so the stock copy fails.
[ "$mode" = breakstock ] && printf x >> "$T/usb/sda1/viknav-ui/original/sound/door.wav"
# sticky: the candidate does not start, and the Launcher process then ignores every stop signal.
[ "$mode" = sticky ] && echo ignore-all > "$T/killall-mode"
log=$R/tmp/Launcher.log
printf 'qml: [Translation Starting...]\n' > "$log"
case "$mode" in nomarker|locksound|breakstock|sticky) ;; *)
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
# __T__/killall-mode: ignore-term (only KILL stops the Launcher) or ignore-all (the Launcher does not stop).
echo "killall $*" >> __T__/calls
case "$(cat __T__/killall-mode 2>/dev/null)" in
    ignore-term) [ "$1" = -9 ] || exit 0 ;;
    ignore-all) exit 0 ;;
esac
rm -f __T__/running
exit 0
"""
# __T__/real-sleep holds one duration in seconds: a sleep of that duration runs in full. Every other sleep is short.
STUB_SLEEP = """#!/bin/sh
[ "$1" = "$(cat __T__/real-sleep 2>/dev/null)" ] && exec __BB__ sleep "$1"
exec __BB__ sleep 0.02
"""
STUB_FBINIT = "#!/bin/sh\nexit 0\n"
STUB_MV = r"""#!/bin/sh
# Test stub for mv: a move to a target that ends with the text in __T__/mv-fail fails. Other moves run.
for a; do d=$a; done
if [ -f __T__/mv-fail ]; then
    s=$(cat __T__/mv-fail)
    [ "${d%"$s"}" = "$d" ] || exit 1
fi
exec __BB__ mv "$@"
"""
STUB_DF = r"""#!/bin/sh
# Test stub for df: the file __T__/df-<folder> sets the free space of that folder without staged files. The staged files
# present (.*.new) take their size off, as on the one root filesystem of the cluster. Other folders report real values.
for a; do d=$a; done
case "$d" in */etc/sound) k=sound ;; */etc) k=etc ;; */usr/bin) k=bin ;; *) k=none ;; esac
if [ -f __T__/df-$k ]; then
    staged=$(__BB__ find __T__/root -name '.*.new' -type f -exec __BB__ du -k {} \; | __BB__ awk '{s += $1} END {print s + 0}')
    echo 'Filesystem           1K-blocks      Used Available Use% Mounted on'
    echo "/dev/mmcblk0p4          761776    584948 $(($(cat __T__/df-$k) - staged))  78% /"
    exit 0
fi
exec __BB__ df "$@"
"""


def stock_mode(name):
    """Stock mode of a sound file (capture-04 ROOTFS-INVENTORY): the radar files are 644, the others 777."""
    return 0o644 if name.startswith("radar_") else 0o777



class Case:
    def __init__(self, base):
        self.t = Path(tempfile.mkdtemp(dir=base))
        self.root = self.t / "root"
        self.usb = self.t / "usb" / "sda1"
        for d in ("usr/bin", "etc/sound", "private/Launcher", "tmp", "proc", "mnt/temp/encrypt"):
            (self.root / d).mkdir(parents=True)
        (self.root / "usr/bin/Launcher").write_bytes(ORIGINAL_BYTES)
        for name, data in STOCK_SOUND_BYTES.items():
            (self.root / "etc/sound" / name).write_bytes(data)
            (self.root / "etc/sound" / name).chmod(stock_mode(name))
        (self.root / "private/Launcher/settings.db").write_bytes(SETTINGS)
        self.usb.mkdir(parents=True)
        (self.usb / "encrypt.zip").write_bytes(b"zip")
        payload = self.usb / "viknav-ui"
        (payload / "etc").mkdir(parents=True)
        (payload / "sound").mkdir()
        (payload / "original/sound").mkdir(parents=True)
        (payload / "Launcher").write_bytes(CANDIDATE_BYTES)
        (payload / "original/Launcher").write_bytes(ORIGINAL_BYTES)
        for name, data in ETC_BYTES.items():
            (payload / "etc" / name).write_bytes(data)
        for name in SOUNDS:
            (payload / "sound" / name).write_bytes(SOUND_BYTES[name])
            (payload / "original/sound" / name).write_bytes(STOCK_SOUND_BYTES[name])
        (self.root / "proc/mounts").write_text(f"/dev/root / ext2 rw 0 0\n/dev/sda1 {self.usb} vfat rw,relatime 0 0\n")
        (self.t / "candidate-mode").write_text("healthy")
        # The log of the running original Launcher already has both startup lines: a stale log must not pass the health check.
        (self.root / "tmp/Launcher.log").write_text("qml: [VehicleEvent Ver:VehicleEvent@20250714 r36577]\nqml: [main.qml starting...]\n")
        (self.t / "running").write_text("")
        fakebin = self.t / "bin"
        fakebin.mkdir()
        for applet in APPLETS + ["readlink", "pwd", "tail", "cut", "kill"]:
            (fakebin / applet).symlink_to(BUSYBOX)
        (fakebin / "flock").symlink_to(flock_tool())
        (fakebin / "sh").symlink_to("/bin/dash")
        stubs = {"ps": STUB_PS, "killall": STUB_KILLALL, "sleep": STUB_SLEEP, "fbinit": STUB_FBINIT, "df": STUB_DF, "mv": STUB_MV}
        for name, text in stubs.items():
            self.stub(fakebin / name, text)
        self.stub(self.root / "etc/qtenv.sh", STUB_QTENV)
        source = SCRIPT.read_text()
        for anchor, value in (("USB_BASE=/mnt/usb\n", f"USB_BASE={self.usb.parent}\n"),
                              ("SYSTEM_ROOT=\n", f"SYSTEM_ROOT={self.root}\n"),
                              ("PATH=/bin:/usr/bin:/sbin:/usr/sbin\n",
                               f"PATH={fakebin}\n" + "".join(f'{n}() {{ "{fakebin / n}" "$@"; }}\n' for n in stubs)),
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
        result = subprocess.run([str(BUSYBOX), "ash", str(self.script)], capture_output=True, text=True, timeout=120,
                                env={"PATH": "/usr/bin:/bin"})
        new = sorted(set(self.outputs()) - set(before))
        self.out = self.usb / new[-1] if new else None
        self.stderr = result.stderr
        return self

    def outputs(self):
        return sorted(p.name for p in self.usb.glob("viknav-ui-*"))

    def status(self):
        return (self.out / "STATUS.txt").read_text().split("\n")[0] if self.out and (self.out / "STATUS.txt").exists() else None

    def detail(self):
        lines = (self.out / "STATUS.txt").read_text().split("\n") if self.out and (self.out / "STATUS.txt").exists() else []
        return lines[1] if len(lines) > 2 else None

    def running(self):
        return (self.t / "running").exists()

    def private(self):
        """Every entry under /private, so a test sees leftover restore folders."""
        return sorted(str(p.relative_to(self.root / "private")) for p in (self.root / "private").rglob("*"))

    def journal_path(self):
        return self.root / "etc/.viknav-rollback"

    def block_path(self):
        """The cluster block of a release that failed the install. Line 1 is the release identity."""
        return self.root / "etc/.viknav-blocked"

    def block(self):
        """Line 1 of the cluster block, or None."""
        path = self.block_path()
        return path.read_text().split("\n")[0] if path.is_file() else None

    def drive_blocked(self):
        return (self.usb / "INSTALL-BLOCKED.txt").exists()

    def lock_path(self):
        """The run lock file on tmpfs. A run holds a kernel lock (flock) on the file."""
        return self.root / "tmp/viknav-ui.lock"

    def hold_lock(self):
        """Hold the run lock from another process, as a live run does. Stop the returned process after the case."""
        holder = subprocess.Popen(flock_command() + [str(self.lock_path()), str(BUSYBOX), "sleep", "60"])
        if not wait_for(lambda: not self.lock_free(), 10):
            raise RuntimeError("lock holder did not take the lock")
        return holder

    def lock_free(self):
        return subprocess.run(flock_command() + ["-n", str(self.lock_path()), "true"]).returncode == 0

    def lock_holders(self, pids=None):
        """The pids (of pids, or of the long-lived Launcher stand-ins) that have the lock file open."""
        if pids is None:
            path = self.t / "launcher-pids"
            pids = [int(p) for p in path.read_text().split()] if path.exists() else []
        held = []
        for pid in pids:
            for fd in Path(f"/proc/{pid}/fd").glob("*"):
                try:
                    if os.readlink(fd) == str(self.lock_path()):
                        held.append(pid)
                except OSError:
                    pass
        return sorted(set(held))

    def sums(self):
        """First field of the drive and the internal stock settings hash files (None when absent)."""
        paths = (self.usb / "viknav-ui/settings-before-install.sha256", self.root / "etc/.viknav-stock-settings.sha256")
        return [p.read_text().split()[0] if p.is_file() and p.read_text().split() else None for p in paths]

    def lines(self):
        return (self.out / "STATUS.txt").read_text().splitlines() if self.out and (self.out / "STATUS.txt").exists() else []

    def copy_path(self):
        """The internal copy of the settings tar that the journal names."""
        return self.root / "etc/.viknav-settings.tar"

    def journal_text(self, phase, block=False):
        """The journal that the installer writes. block: line 4 names the release to block (a failed install)."""
        return f"/etc/.viknav-settings.tar\n{sha(self.copy_path().read_bytes())}\n{phase}\n{PAYLOAD_ID if block else 'none'}\n"

    def settings_tar(self, path, data):
        """Write a tar of /private/Launcher with one settings file, as the installer makes the settings backup."""
        source = self.t / "tar-source"
        shutil.rmtree(source, ignore_errors=True)
        (source / "Launcher").mkdir(parents=True)
        (source / "Launcher/settings.db").write_bytes(data)
        path.parent.mkdir(parents=True, exist_ok=True)
        with tarfile.open(path, "w", format=tarfile.USTAR_FORMAT) as tar:
            tar.add(source / "Launcher", arcname="Launcher")
        return path

    def put(self, name, data, folder="etc/sound", staged=False):
        """Write one live or staged file with the stock mode of that file, as the installer writes the file."""
        path = self.root / folder / (f".{name}.new" if staged else name)
        path.write_bytes(data)
        path.chmod(stock_mode(name) if folder == "etc/sound" else 0o644 if folder == "etc" else 0o777)

    def cut(self, step, automatic):
        """Leave the cluster as a power cut at one step leaves the cluster. Steps: CUT_INSTALL (an install over the original),
        then CUT_RESTORE (the rollback of that failed install, automatic=True) or CUT_REQUESTED (a requested rollback of a
        healthy install, automatic=False). Returns the settings that a finished rollback restores."""
        root, private = self.root, self.root / "private"
        stock = self.settings_tar(self.usb / "viknav-ui/settings-before-install.tar", SETTINGS)
        # The first install over the original wrote the stock backup from the run backup of that install.
        self.first_install().mkdir()
        (self.first_install() / "private-Launcher.tar").write_bytes(stock.read_bytes())
        # The settings backup of the install run. A rollback of a failed install restores these settings.
        run_tar = self.settings_tar(self.usb / "viknav-ui-install-20261031-120000-99/private-Launcher.tar", AUTO_SETTINGS)
        expected = AUTO_SETTINGS if automatic else SETTINGS
        if step in CUT_INSTALL:
            k = CUT_INSTALL.index(step)
            (private / "Launcher/settings.db").write_bytes(AUTO_SETTINGS)
            (self.t / "running").unlink(missing_ok=True)
            if k <= 3:
                for name, data in ETC_BYTES.items():
                    self.put(name, data, "etc", staged=True)
                for name, data in SOUND_BYTES.items():
                    self.put(name, data, staged=True)
                self.put("Launcher", CANDIDATE_BYTES, "usr/bin", staged=True)
            if k >= 1:
                self.copy_path().write_bytes(run_tar.read_bytes())
                (root / "etc/.viknav-rollback.new").write_text(self.journal_text("files"))
            if k >= 2:
                (root / "etc/.viknav-rollback.new").replace(self.journal_path())
            if k == 3:
                for name in ETC:
                    (root / "etc" / f".{name}.new").replace(root / "etc" / name)
                for name in SOUNDS[:7]:
                    (root / "etc/sound" / f".{name}.new").replace(root / "etc/sound" / name)
            if k >= 4:
                (root / "usr/bin/.Launcher.new").unlink(missing_ok=True)
                for name, data in ETC_BYTES.items():
                    self.put(name, data, "etc")
                for name, data in SOUND_BYTES.items():
                    self.put(name, data)
                self.put("Launcher", CANDIDATE_BYTES, "usr/bin")
            if k >= 5:
                (self.t / "running").write_text("")
                (private / "Launcher/settings.db").write_bytes(CANDIDATE_SETTINGS)
            if k >= 6:
                self.journal_path().write_text(self.journal_text("files", True))
            if k >= 7:
                (self.usb / "INSTALL-BLOCKED.txt").write_text("startup markers missing\n")
            return expected
        # A healthy install of the release is in place and running.
        for name, data in ETC_BYTES.items():
            self.put(name, data, "etc")
        for name, data in SOUND_BYTES.items():
            self.put(name, data)
        self.put("Launcher", CANDIDATE_BYTES, "usr/bin")
        (private / "Launcher/settings.db").write_bytes(CANDIDATE_SETTINGS)
        source = run_tar if automatic else self.usb / "viknav-ui/settings-before-install.tar"
        self.copy_path().write_bytes(source.read_bytes())
        if automatic:
            (self.usb / "INSTALL-BLOCKED.txt").write_text("startup markers missing\n")
        if step == "journal-new":
            (root / "etc/.viknav-rollback.new").write_text(self.journal_text("files"))
            return expected
        if step == "cleared":
            # The rollback finished and removed the journal. The cut came before the removal of the settings copy.
            for name in ETC:
                (root / "etc" / name).unlink()
            for name, data in STOCK_SOUND_BYTES.items():
                self.put(name, data)
            self.put("Launcher", ORIGINAL_BYTES, "usr/bin")
            (private / "Launcher/settings.db").write_bytes(SETTINGS)
            return expected
        self.journal_path().write_text(self.journal_text("files", automatic))
        k = CUT_RESTORE.index(step) if step in CUT_RESTORE else -1
        if k >= 0:
            self.put("Launcher", ORIGINAL_BYTES, "usr/bin", staged=True)
            for name in SOUNDS[:5] if k == 0 else SOUNDS:
                self.put(name, STOCK_SOUND_BYTES[name], staged=True)
        if k >= 1:
            (self.t / "running").unlink(missing_ok=True)
        if k >= 2:
            (root / "usr/bin/.Launcher.new").replace(root / "usr/bin/Launcher")
        if k >= 3:
            for name in SOUNDS[:7] if k == 3 else SOUNDS:
                (root / "etc/sound" / f".{name}.new").replace(root / "etc/sound" / name)
        if k >= 4:
            for name in ETC[:3] if k == 4 else ETC:
                (root / "etc" / name).unlink()
        if k >= 5:
            (private / ".Launcher.restore/Launcher").mkdir(parents=True)
            (private / ".Launcher.restore/Launcher/settings.db").write_bytes(expected)
        if k >= 6:
            (private / "Launcher").replace(private / ".Launcher.old")
        if k >= 7:
            (private / ".Launcher.restore/Launcher").replace(private / "Launcher")
            shutil.rmtree(private / ".Launcher.restore")
            shutil.rmtree(private / ".Launcher.old")
        if k >= 8:
            self.journal_path().write_text(self.journal_text("start", automatic))
        if k >= 9:
            # The stock Launcher started and passed the start check. The cut came before the journal removal.
            (self.t / "running").write_text("")
            if automatic:
                (root / "etc/.viknav-blocked.new").write_text(PAYLOAD_ID + "\n")
        if k >= 10 and automatic:
            (root / "etc/.viknav-blocked.new").replace(self.block_path())
        return expected

    def calls(self):
        path = self.t / "calls"
        return path.read_text().splitlines() if path.exists() else []

    def starts(self):
        return sum(1 for line in self.calls() if line.startswith("start"))

    def device(self):
        launcher = sha((self.root / "usr/bin/Launcher").read_bytes())
        state = "original" if launcher == sha(ORIGINAL_BYTES) else "candidate" if launcher == sha(CANDIDATE_BYTES) else "other"
        etc = {name: (self.root / "etc" / name).exists() and sha((self.root / "etc" / name).read_bytes()) == sha(ETC_BYTES[name]) for name in ETC}
        present = [name for name in ETC + RETIRED if (self.root / "etc" / name).exists()]
        sound = self.sound()
        if state == "candidate" and all(etc.values()) and sound == "A":
            return "candidate"
        if state == "original" and not present and sound == "stock":
            return "original"
        return f"mixed launcher={state} etc={present} sound={sound}"

    def sound(self):
        """stock or A when every /etc/sound file is a regular file of that set, mixed otherwise."""
        paths = [self.root / "etc/sound" / name for name in SOUNDS]
        found = [None if p.is_symlink() or not p.is_file() else sha(p.read_bytes()) for p in paths]
        if found == [sha(STOCK_SOUND_BYTES[name]) for name in SOUNDS]:
            return "stock"
        if found == [sha(SOUND_BYTES[name]) for name in SOUNDS]:
            return "A"
        return "mixed"

    def sound_modes(self):
        """True when every /etc/sound file has the stock mode of that file."""
        return all((self.root / "etc/sound" / name).stat().st_mode & 0o777 == stock_mode(name) for name in SOUNDS)

    def state(self):
        """Hash and link flag of every file that an install or a rollback can change."""
        paths = [self.root / "usr/bin/Launcher", self.root / "private/Launcher/settings.db", self.root / "etc/.viknav-rollback",
                 self.root / "etc/.viknav-settings.tar", self.block_path()]
        paths += [self.root / "etc" / name for name in ETC + RETIRED] + [self.root / "etc/sound" / name for name in SOUNDS]
        return {str(p.relative_to(self.root)): [sha(p.read_bytes()) if p.is_file() else None, p.is_symlink()] for p in paths}

    def free(self, folder, kb):
        """Make the df stub report kb free for folder (bin, etc, or sound)."""
        (self.t / f"df-{folder}").write_text(str(kb))

    def settings(self):
        return (self.root / "private/Launcher/settings.db").read_bytes()

    def install_v1(self, etc=V1_ETC):
        """Put the cluster in an earlier release state (menu-v1 by default), with the stock settings backup on the drive.
        The Launcher comes from the same release drive, so an upgrade replaces an earlier-release Launcher."""
        (self.root / "usr/bin/Launcher").write_bytes((etc.parent / "Launcher").read_bytes())
        for path in etc.iterdir():
            (self.root / "etc" / path.name).write_bytes(path.read_bytes())
        (self.root / "private/Launcher/settings.db").write_bytes(b"settings of v1\n")
        # As on the truck drive: the first install folder holds the run backup that became the stock backup, byte for byte.
        # Earlier releases wrote no hash files.
        stock = tarfile_bytes(SETTINGS)
        (self.usb / "viknav-ui/settings-before-install.tar").write_bytes(stock)
        self.first_install().mkdir()
        (self.first_install() / "private-Launcher.tar").write_bytes(stock)
        return self

    def first_install(self):
        """The result folder of the first install on the drive (the name of the truck drive folder)."""
        return self.usb / "viknav-ui-install-19700101-000007-1577"

    def backup(self):
        return sha((self.usb / "viknav-ui/settings-before-install.tar").read_bytes())

    def leftovers(self):
        return sorted(str(p.relative_to(self.root)) for p in self.root.rglob(".*.new"))


def flock_tool():
    """The flock applet of BUSYBOX. The Ubuntu busybox-static build has no flock applet: util-linux flock stands in."""
    if BUSYBOX not in FLOCK_TOOLS:
        probe = subprocess.run([str(BUSYBOX), "flock", "-n", "/dev/null", "true"], capture_output=True)
        FLOCK_TOOLS[BUSYBOX] = BUSYBOX if probe.returncode == 0 else Path("/usr/bin/flock")
    return FLOCK_TOOLS[BUSYBOX]


def flock_command():
    """The argument list that runs flock_tool()."""
    return [str(BUSYBOX), "flock"] if flock_tool() == BUSYBOX else [str(flock_tool())]


FLOCK_TOOLS = {}


def stop_long_launchers(base):
    """Stop every long-lived Launcher stand-in under base."""
    for path in Path(base).rglob("launcher-pids"):
        for pid in path.read_text().split():
            try:
                os.kill(int(pid), signal.SIGKILL)
            except (OSError, ValueError):
                pass


def script_min_free_kb():
    line = next(l for l in SCRIPT.read_text().splitlines() if l.startswith("MIN_FREE_KB="))
    return int(line.split("=", 1)[1])


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


# POSIX shells exit on a failed redirection of a special builtin or of a compound command. Background jobs are exempt:
# the failure stays in the child. fd duplications (2>&1) cannot fail.
SPECIAL_BUILTINS = {":", ".", "break", "continue", "eval", "exec", "exit", "export", "readonly", "return", "set", "shift", "times",
                    "trap", "unset"}
REDIRECTION = re.compile(r"\d*(>>|>|<)(?![&>(])")


def unsafe_redirection_lines(text):
    """Line numbers with a special builtin or a compound command that has a redirection. One form is allowed: exec N>>"$VAR"
    right after a code line that checks [ -w "$VAR" ] and ends with || return N, so the open cannot fail."""
    found = []
    heredoc = None
    previous = ""
    for number, line in enumerate(text.splitlines(), 1):
        if heredoc:
            if line.strip() == heredoc:
                heredoc = None
            continue
        start = re.search(r"<<-?\s*'?(\w+)'?", line)
        if start:
            heredoc = start.group(1)
        code = re.sub(r"'[^']*'|\"(?:\\.|[^\"\\])*\"", '""', line)
        code = re.sub(r"(^|\s)#.*", "", code).replace("<<", "")
        # The closing brace of a parameter expansion is not a compound command.
        code = re.sub(r"\$\{[^}]*\}", "x", code)
        for segment in re.split(r"&&|\|\||[;|&(){}]|\$\(", code):
            words = [word for word in segment.split() if word != "!"]
            if words and words[0] in SPECIAL_BUILTINS and REDIRECTION.search(segment):
                guarded = re.fullmatch(r'exec \d>>?"\$(\w+)"', line.strip())
                if not (guarded and f'[ -w "${guarded.group(1)}" ]' in previous and re.search(r"\|\| return \d+$", previous)):
                    found.append(number)
        compound = re.search(r"(\}|\)|\bdone|\bfi|\besac)\s*(\d*(>>|>|<)(?![&>(]))", code)
        if compound and not code.rstrip().endswith("&"):
            found.append(number)
        if line.strip() and not line.strip().startswith("#"):
            previous = line.strip()
    return sorted(set(found))


# Power cut points. CUT_INSTALL: an install over the original, from the staged files to the journal with the release to block and
# INSTALL-BLOCKED.txt of the rollback.
# CUT_RESTORE: the rollback of that failed install. CUT_REQUESTED: a requested rollback of a healthy install.
CUT_INSTALL = ["install-staged", "install-journal-new", "install-journal", "install-moving", "install-moved", "install-started",
               "journal-block", "blocked"]
# block-new and block: the cluster block write of a failed install (temp file, then the rename). A requested rollback has no block.
CUT_RESTORE = ["staged", "stopped", "launcher", "sounds", "etc", "extracted", "between", "settled", "phase-start", "block-new",
               "block", "journal-removal"]
CUT_REQUESTED = ["journal-new", "journal"] + [s for s in CUT_RESTORE if not s.startswith("block")] + ["cleared"]
cut_table = []


def cut_blocks(step, automatic, action):
    """(cluster block, drive marker) after the next drive insert at cut point step. A rollback insert clears both. The journal of a
    failed install names the release to block, and the resumed rollback puts the block in place before the journal removal."""
    if action == "rollback" or not automatic:
        return False, False
    if step in CUT_RESTORE:
        return True, True
    k = CUT_INSTALL.index(step)
    return k >= 6, k >= 7


def cut_expected(step, automatic, action):
    """(status, device, settings, detail or None) after the next drive insert at cut point step."""
    install_next = action == "install"
    if step in ("install-staged", "install-journal-new"):
        # Nothing live changed: the next install runs in full, and a rollback finds the original.
        return ("INSTALLED", "candidate", CANDIDATE_SETTINGS, None) if install_next else ("ALREADY_ORIGINAL", "original", AUTO_SETTINGS, None)
    if step == "journal-new":
        return ("ALREADY_INSTALLED", "candidate", CANDIDATE_SETTINGS, None) if install_next else \
            ("ROLLED_BACK by request", "original", SETTINGS, None)
    if step == "cleared":
        return ("INSTALLED", "candidate", CANDIDATE_SETTINGS, None) if install_next else ("ALREADY_ORIGINAL", "original", SETTINGS, None)
    detail = ("files already stock; original Launcher started" if step in ("phase-start", "block-new", "block", "journal-removal")
              else "original Launcher started")
    return "ROLLED_BACK resumed", "original", AUTO_SETTINGS if automatic else SETTINGS, detail


def tarfile_bytes(data):
    """A settings tar of one settings file, as bytes."""
    import io
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w", format=tarfile.USTAR_FORMAT) as tar:
        folder = tarfile.TarInfo("Launcher")
        folder.type = tarfile.DIRTYPE
        folder.mode = 0o755
        tar.addfile(folder)
        member = tarfile.TarInfo("Launcher/settings.db")
        member.size = len(data)
        tar.addfile(member, io.BytesIO(data))
    return buffer.getvalue()


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
                    (c.out / "Launcher-start.log").exists(), (c.out / "Launcher-later.log").exists(), c.leftovers(),
                    c.sound(), c.sound_modes()]
        check("install-healthy", 4, ["INSTALLED", "candidate", 1, True, True, True, True, True, [], "A", True], healthy)

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
            (c.root / "etc/vnM.qml").write_text("other\n")
            install(c)
            return [c.status(), c.device(), c.starts()]
        check("unknown-etc-file-refused", 1, ["ABORTED unknown /etc/vnM.qml", "mixed launcher=original etc=['vnM.qml'] sound=stock", 0],
              unknown_etc)

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
            c.free("bin", script_min_free_kb() - 1)
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
                        (c.out / "Launcher-failed.log").exists(), c.leftovers(), c.sound(), c.sound_modes()]
            check(f"unhealthy-{mode}-rolls-back", 4, [reason, "original", 2, True, True, True, [], "stock", True], unhealthy)

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
            return [c.status(), c.device(), c.starts(), c.settings() == SETTINGS, c.leftovers(), c.sound_modes()]
        check("rollback-restores-original", 7, ["ROLLED_BACK by request", "original", 2, True, [], True], rollback)

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

        def upgrade():
            c = new().install_v1()
            before = c.backup()
            install(c)
            return [c.status(), c.device(), c.starts(), [n for n in RETIRED if (c.root / "etc" / n).exists()],
                    c.backup() == before, c.leftovers()]
        check("upgrade-from-v1", 11, ["INSTALLED", "candidate", 1, [], True, []], upgrade)

        def upgrade_v2():
            c = new().install_v1(V2_ETC)
            before = c.backup()
            install(c)
            return [c.status(), c.device(), c.starts(), c.backup() == before, c.leftovers()]
        check("upgrade-from-v2", 11, ["INSTALLED", "candidate", 1, True, []], upgrade_v2)

        def upgrade_v3():
            c = new().install_v1(V3_ETC)
            before = c.backup()
            install(c)
            return [c.status(), c.device(), c.starts(), c.backup() == before, c.leftovers()]
        check("upgrade-from-v3", 11, ["INSTALLED", "candidate", 1, True, []], upgrade_v3)

        def upgrade_v4():
            c = new().install_v1(V4_ETC)
            before = c.backup()
            install(c)
            return [c.status(), c.device(), c.starts(), c.backup() == before, c.leftovers()]
        check("upgrade-from-v4", 11, ["INSTALLED", "candidate", 1, True, []], upgrade_v4)

        def upgrade_v5():
            c = new().install_v1(V5_ETC)
            before = c.backup()
            install(c)
            return [c.status(), c.device(), c.starts(), c.backup() == before, c.leftovers()]
        check("upgrade-from-v5", 11, ["INSTALLED", "candidate", 1, True, []], upgrade_v5)

        def upgrade_v6():
            c = new().install_v1(V6_ETC)
            before = c.backup()
            install(c)
            return [c.status(), c.device(), c.starts(), c.backup() == before, c.leftovers()]
        check("upgrade-from-v6", 11, ["INSTALLED", "candidate", 1, True, []], upgrade_v6)

        def upgrade_v7():
            c = new().install_v1(V7_ETC)
            before = c.backup()
            install(c)
            return [c.status(), c.device(), c.starts(), c.backup() == before, c.leftovers()]
        check("upgrade-from-v7", 11, ["INSTALLED", "candidate", 1, True, []], upgrade_v7)

        def upgrade_v8():
            c = new().install_v1(V8_ETC)
            # The stock notification table stays in place; the candidate Launcher reads vnN.qml instead.
            stock = c.root / "etc/common/NotifyTranslation.qml"
            stock.parent.mkdir(parents=True, exist_ok=True)
            stock.write_bytes(STOCK_NOTIFY)
            before = c.backup()
            install(c)
            added = [(c.root / "etc" / name).exists() for name in ("vnD.qml", "vnL.qml", "vnN.qml")]
            installed = [c.status(), c.device(), c.starts(), added, c.backup() == before, c.leftovers(),
                         stock.read_bytes() == STOCK_NOTIFY]
            c.unmark()
            c.marker("rollback")
            c.run()
            removed = [(c.root / "etc" / name).exists() for name in ("vnD.qml", "vnL.qml", "vnN.qml")]
            return installed + [c.status(), c.device(), removed, c.settings() == SETTINGS, stock.read_bytes() == STOCK_NOTIFY]
        check("upgrade-from-v8-then-rollback", 11, ["INSTALLED", "candidate", 1, [True, True, True], True, [], True,
                                                    "ROLLED_BACK by request", "original", [False, False, False], True, True],
              upgrade_v8)

        def upgrade_v11():
            c = new().install_v1(V11_ETC)
            before = c.backup()
            install(c)
            installed = [c.status(), c.device(), c.starts(), (c.root / "etc/vnL.qml").exists(), c.backup() == before,
                         c.leftovers()]
            c.unmark()
            c.marker("rollback")
            c.run()
            removed = [(c.root / "etc" / name).exists() for name in ETC]
            return installed + [c.status(), c.device(), removed, c.settings() == SETTINGS]
        check("upgrade-from-v11-then-rollback", 11, ["INSTALLED", "candidate", 1, True, True, [],
                                                     "ROLLED_BACK by request", "original", [False] * len(ETC), True],
              upgrade_v11)

        def upgrade_again():
            c = install(new().install_v1())
            c.run()
            return [c.status(), c.device(), c.starts()]
        check("upgrade-again-no-restart", 6, ["ALREADY_INSTALLED", "candidate", 1], upgrade_again)

        def retired_left():
            c = install(new())
            (c.root / "etc/vnF.qml").write_bytes((V1_ETC / "vnF.qml").read_bytes())
            c.run()
            return [c.status(), c.device(), c.starts()]
        check("retired-file-removed", 11, ["INSTALLED", "candidate", 2], retired_left)

        def unknown_retired():
            c = new().install_v1()
            (c.root / "etc/vnB.qml").write_text("other\n")
            install(c)
            return [c.status(), c.starts()]
        check("unknown-retired-file-refused", 1, ["ABORTED unknown /etc/vnB.qml", 0], unknown_retired)

        def upgrade_unhealthy():
            c = install(new().install_v1(), "vnerror")
            return [c.status(), c.device(), c.settings() == b"settings of v1\n", (c.usb / "INSTALL-BLOCKED.txt").exists()]
        check("upgrade-unhealthy-rolls-back", 4, ["ROLLED_BACK new QML error", "original", True, True], upgrade_unhealthy)

        def rollback_v1():
            c = new().install_v1()
            c.marker("rollback")
            c.run()
            return [c.status(), c.device(), c.settings() == SETTINGS, c.leftovers()]
        check("rollback-from-v1", 7, ["ROLLED_BACK by request", "original", True, []], rollback_v1)

        def upgrade_v12():
            c = new().install_v1(V12_ETC)
            before = c.backup()
            stock = c.sound()
            install(c)
            installed = [stock, c.status(), c.device(), c.starts(), c.backup() == before, c.leftovers()]
            c.run()
            return installed + [c.status(), c.device(), c.starts()]
        check("upgrade-from-v12-then-again", 11, ["stock", "INSTALLED", "candidate", 1, True, [], "ALREADY_INSTALLED", "candidate", 1],
              upgrade_v12)

        def unknown_sound():
            c = new()
            (c.root / "etc/sound/ding.wav").write_bytes(b"other\n")
            before = c.state()
            install(c)
            return [c.status(), c.state() == before, c.starts(), [x for x in c.calls() if x.startswith("killall")]]
        check("unknown-sound-refused", 12, ["ABORTED unknown /etc/sound/ding.wav", True, 0, []], unknown_sound)

        def linked_sound():
            c = new()
            real = c.root / "etc/door-real.wav"
            real.write_bytes(STOCK_SOUND_BYTES["door.wav"])
            (c.root / "etc/sound/door.wav").unlink()
            (c.root / "etc/sound/door.wav").symlink_to(real)
            before = c.state()
            install(c)
            return [c.status(), c.state() == before, c.starts()]
        check("linked-sound-refused", 12, ["ABORTED unknown /etc/sound/door.wav", True, 0], linked_sound)

        def missing_sound():
            c = new()
            (c.root / "etc/sound/buzzer.wav").unlink()
            before = c.state()
            install(c)
            return [c.status(), c.state() == before, c.starts()]
        check("missing-sound-refused", 12, ["ABORTED unknown /etc/sound/buzzer.wav", True, 0], missing_sound)

        for payload_name in ("sound/radar_b3.wav", "original/sound/door.wav"):
            def bad_sound_payload(payload_name=payload_name):
                c = new()
                path = c.usb / "viknav-ui" / payload_name
                path.write_bytes(path.read_bytes()[:-10])
                before = c.state()
                install(c)
                return [c.status(), c.state() == before, c.starts(), c.calls()]
            check(f"damaged-payload-{payload_name.replace('/', '-')}-refused", 2, [f"ABORTED payload {payload_name}", True, 0, []],
                  bad_sound_payload)

        def sound_copy_fails():
            c = new()
            # A folder in the place of one staged file makes the copy of that one sound fail after the earlier files staged.
            blocker = c.root / "etc/sound/.ding.wav.new"
            blocker.mkdir()
            before = c.state()
            install(c)
            blocker.chmod(0o755)
            return [c.status(), c.state() == before, c.starts(), c.leftovers()]
        check("failed-sound-copy-changes-nothing", 14, ["ABORTED copy /etc/sound/ding.wav", True, 1, ["etc/sound/.ding.wav.new"]],
              sound_copy_fails)

        def free_limit():
            blocks = lambda data: -(-len(data) // 4096) * 4
            staged = blocks(CANDIDATE_BYTES) + sum(map(blocks, ETC_BYTES.values())) + sum(map(blocks, SOUND_BYTES.values()))
            return script_min_free_kb() >= staged + 4096
        check("free-space-limit-covers-staged-files", 13, True, free_limit)

        for folder in ("bin", "etc", "sound"):
            def short(folder=folder):
                c = new()
                for other in ("bin", "etc", "sound"):
                    c.free(other, script_min_free_kb() - (1 if other == folder else 0))
                before = c.state()
                install(c)
                return [c.status(), c.state() == before, c.starts()]
            check(f"low-space-in-{folder}-refused", 13, ["ABORTED low space", True, 0], short)

        def exact_space():
            c = new()
            for folder in ("bin", "etc", "sound"):
                c.free(folder, script_min_free_kb())
            install(c)
            return [c.status(), c.device()]
        check("enough-space-in-every-folder-installs", 13, ["INSTALLED", "candidate"], exact_space)

        def install_needs_sounds():
            c = install(new())
            (c.root / "etc/sound/ding.wav").write_bytes(STOCK_SOUND_BYTES["ding.wav"])
            c.run()
            return [c.status(), c.device(), c.starts()]
        check("install-again-replaces-stock-sound", 16, ["INSTALLED", "candidate", 2], install_needs_sounds)

        def rollback_needs_sounds():
            c = install(new())
            c.unmark()
            c.marker("rollback")
            c.run()
            (c.root / "etc/sound/ding.wav").write_bytes(SOUND_BYTES["ding.wav"])
            c.run()
            return [c.status(), c.device(), c.starts()]
        check("rollback-again-restores-stock-sound", 16, ["ROLLED_BACK by request", "original", 3], rollback_needs_sounds)

        def rollback_sound_fails():
            c = install(new())
            c.unmark()
            c.marker("rollback")
            (c.root / "etc/sound").chmod(0o555)
            c.run()
            (c.root / "etc/sound").chmod(0o755)
            return [c.status(), c.sound(), c.leftovers()]
        check("rollback-sound-restore-failure-reported", 15, ["ROLLBACK_FAILED", "A", []], rollback_sound_fails)

        def unhealthy_sound_fails():
            c = install(new(), "locksound")
            (c.root / "etc/sound").chmod(0o755)
            return [c.status(), c.sound(), (c.usb / "INSTALL-BLOCKED.txt").exists()]
        check("unhealthy-sound-restore-failure-reported", 15, ["ROLLBACK_FAILED startup markers missing", "A", True],
              unhealthy_sound_fails)

        def rollback_bad_sound_payload():
            c = install(new())
            c.unmark()
            path = c.usb / "viknav-ui/original/sound/ding.wav"
            path.write_bytes(path.read_bytes()[:-10])
            c.marker("rollback")
            before = c.state()
            c.run()
            return [c.status(), c.state() == before, c.starts()]
        check("rollback-damaged-sound-payload-refused", 15, ["ABORTED payload original/sound/ding.wav", True, 1],
              rollback_bad_sound_payload)

        def rollback_copy_fails():
            c = install(new())
            c.unmark()
            c.marker("rollback")
            # A folder in the place of one staged sound makes the copy of that one sound fail.
            blocker = c.root / "etc/sound/.ding.wav.new"
            blocker.mkdir()
            before, calls = c.state(), len(c.calls())
            c.run()
            blocker.chmod(0o755)
            return [c.status(), c.state() == before, c.running(), c.calls()[calls:], c.leftovers(), c.journal_path().exists()]
        check("rollback-copy-failure-changes-nothing", 18, ["ROLLBACK_FAILED", True, True, [], ["etc/sound/.ding.wav.new"], False],
              rollback_copy_fails)

        def automatic_copy_fails():
            c = install(new(), "breakstock")
            return [c.status(), c.running(), c.device(), c.journal_path().exists(), (c.usb / "INSTALL-BLOCKED.txt").exists(),
                    c.leftovers()]
        check("automatic-rollback-copy-failure-keeps-journal", 18,
              ["ROLLBACK_FAILED startup markers missing", True, "candidate", True, True, []], automatic_copy_fails)

        def automatic_copy_fails_then_resume():
            c = install(new(), "breakstock")
            (c.usb / "viknav-ui/original/sound/door.wav").write_bytes(STOCK_SOUND_BYTES["door.wav"])
            c.run()
            return [c.status(), c.device(), c.settings() == SETTINGS, c.running(), c.journal_path().exists(), c.block() == PAYLOAD_ID]
        check("automatic-rollback-copy-failure-resumes-next-insert", 18, ["ROLLED_BACK resumed", "original", True, True, False, True],
              automatic_copy_fails_then_resume)

        # A power cut at each step of an install, an automatic rollback, and a requested rollback. The next drive insert of
        # either kind ends healthy and installed, stock with the matching settings, or as an honest failure.
        for automatic, steps in ((True, CUT_INSTALL + CUT_RESTORE), (False, CUT_REQUESTED)):
            for step in steps:
                for action in ("install", "rollback"):
                    status, device, settings, detail = cut_expected(step, automatic, action)
                    cluster_block, drive_block = cut_blocks(step, automatic, action)
                    path = "automatic" if automatic else "requested"
                    cut_table.append({"cut": step, "path": path, "next": action, "status": status, "device": device,
                                      "detail": detail, "clusterBlock": cluster_block, "driveBlock": drive_block})

                    def resume(step=step, automatic=automatic, action=action, settings=settings, detail=detail):
                        c = new()
                        c.cut(step, automatic)
                        c.marker(action)
                        c.run()
                        shown = c.detail() if detail is not None else None
                        return [c.status(), shown, c.device(), c.settings() == settings, c.running(), c.journal_path().exists(),
                                c.copy_path().exists(), c.leftovers(), c.private(), c.sound_modes(), c.block() == PAYLOAD_ID,
                                c.drive_blocked()]
                    check(f"cut-{path}-{step}-then-{action}", 19,
                          [status, detail, device, True, True, False, False, [], ["Launcher", "Launcher/settings.db"], True,
                           cluster_block, drive_block], resume)

        for name, spoil in (("missing", lambda p: p.unlink()), ("changed", lambda p: p.write_bytes(b"changed\n"))):
            def copy_bad(spoil=spoil):
                c = new()
                c.cut("etc", True)
                spoil(c.copy_path())
                c.marker("install")
                c.run()
                return [c.status(), c.detail(), c.device(), c.settings() == CANDIDATE_SETTINGS, c.journal_path().exists(), c.running()]
            check(f"cut-settings-copy-{name}-fails-and-keeps-journal", 19,
                  ["ROLLBACK_FAILED resumed", "settings copy check failed; original Launcher started", "original", True, True, True],
                  copy_bad)

        for action in ("install", "rollback"):
            def run_tar_missing(action=action):
                c = new()
                expected = c.cut("between", True)
                (c.usb / "viknav-ui-install-20261031-120000-99/private-Launcher.tar").unlink()
                c.marker(action)
                c.run()
                return [c.status(), c.settings() == expected, c.journal_path().exists()]
            check(f"cut-run-backup-missing-on-drive-then-{action}", 19, ["ROLLED_BACK resumed", True, False], run_tar_missing)

        for action, status in (("install", "INSTALLED"), ("rollback", "ALREADY_ORIGINAL")):
            def stages_at_min_free(action=action):
                c = new()
                c.cut("install-staged", True)
                # The df stub takes the abandoned stages off this free space, as the real filesystem does.
                for folder in ("bin", "etc", "sound"):
                    c.free(folder, script_min_free_kb())
                c.marker(action)
                c.run()
                return [c.status(), c.leftovers(), c.running(), c.copy_path().exists()]
            check(f"abandoned-stages-at-min-free-then-{action}", 13, [status, [], True, False], stages_at_min_free)

        # Two updater runs can start at once (the boot scan in /etc/init.d/rcS and the hotplug event). One kernel lock
        # (flock on /tmp/viknav-ui.lock) serializes the runs; the kernel drops the lock when the run ends or dies.
        for action in ("install", "rollback", "log"):
            def busy(action=action):
                c = install(new()) if action == "rollback" else new()
                c.unmark()
                holder = c.hold_lock()
                try:
                    before, calls = c.state(), len(c.calls())
                    c.marker(action)
                    c.run()
                    return [c.status(), c.state() == before, c.calls()[calls:], c.lock_free(), c.running()]
                finally:
                    holder.kill()
                    holder.wait()
            check(f"busy-{action}-changes-nothing", 22, [BUSY, True, [], False, True], busy)

        def lock_gate(c, name):
            """A copy of the case installer that holds right after the lock until the release file exists."""
            source = c.script.read_text()
            anchor = 'case "$action" in\n    install) do_install ;;\n'
            gate = f'printf won > "{c.t}/{name}-won-$$"\nwhile [ ! -f "{c.t}/{name}-release" ]; do "{BUSYBOX}" sleep 0.02; done\n'
            if source.count(anchor) != 1:
                raise ValueError("installer dispatch anchor missing")
            path = c.t / f"{name}.sh"
            path.write_text(source.replace(anchor, gate + anchor))
            return path

        def race():
            c = new()
            c.marker("log")
            results = []
            for round_number in range(20):
                path = lock_gate(c, f"r{round_number}")
                runs = [subprocess.Popen([str(BUSYBOX), "ash", str(path)], env={"PATH": "/usr/bin:/bin"},
                                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) for _ in range(2)]
                try:
                    # The loser ends with BUSY while the winner holds at the gate.
                    ended = wait_for(lambda: any(p.poll() is not None for p in runs), 30)
                    won = len(list(c.t.glob(f"r{round_number}-won-*")))
                finally:
                    (c.t / f"r{round_number}-release").write_text("go")
                    for p in runs:
                        p.wait(timeout=60)
                results.append([ended, won])
            statuses = sorted((p / "STATUS.txt").read_text().split("\n")[0] for p in c.usb.glob("viknav-ui-log-*"))
            return [all(r == [True, 1] for r in results), statuses.count("LOGGED"), statuses.count(BUSY), c.lock_free()]
        check("lock-race-one-winner-20-rounds", 22, [True, 20, 20, True], race)

        def killed_run():
            c = new()
            c.marker("install")
            path = lock_gate(c, "killed")
            run = subprocess.Popen([str(BUSYBOX), "ash", str(path)], env={"PATH": "/usr/bin:/bin"}, start_new_session=True,
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            held = wait_for(lambda: any(c.t.glob("killed-won-*")), 30) and not c.lock_free()
            os.killpg(run.pid, signal.SIGKILL)
            run.wait()

            def group_gone():
                # The gate sleep child of the killed run also holds fd 9 until the child exits.
                try:
                    os.killpg(run.pid, 0)
                    return False
                except ProcessLookupError:
                    return True
            wait_for(group_gone, 5)
            free = c.lock_free()
            c.run()
            return [held, free, c.status(), c.device()]
        check("killed-run-releases-lock", 22, [True, True, "INSTALLED", "candidate"], killed_run)

        def killed_in_log_wait():
            # The run stops during the wait for Launcher-later.log. Only the run process dies, as on a real kill: the sleep
            # child stays. The sleep must not keep the lock.
            c = new()
            c.marker("install")
            (c.t / "real-sleep").write_text("60")
            source = c.script.read_text()
            if source.count("LOG_WAIT=1\n") != 1:
                raise ValueError("LOG_WAIT anchor missing")
            path = c.t / "log-wait.sh"
            path.write_text(source.replace("LOG_WAIT=1\n", "LOG_WAIT=60\n"))
            run = subprocess.Popen([str(BUSYBOX), "ash", str(path)], env={"PATH": "/usr/bin:/bin"}, start_new_session=True,
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            try:
                installed = wait_for(lambda: any(p.read_text().startswith("INSTALLED") for p in c.usb.glob("viknav-ui-install-*/STATUS.txt")), 60)
                os.kill(run.pid, signal.SIGKILL)
                run.wait()
                (c.t / "real-sleep").unlink()
                # A short child of the run (sync, cp) can still hold the lock for a moment after the kill. The long sleep
                # must not: the lock comes free once the short children end.
                free = wait_for(c.lock_free, 5)
                c.run()
                return [installed, free, c.status()]
            finally:
                try:
                    os.killpg(run.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
        check("run-killed-in-log-wait-releases-lock", 22, [True, True, "ALREADY_INSTALLED"], killed_in_log_wait)

        def old_pid_in_lock():
            # The lock file of the earlier design held a pid. A live, unrelated process with that pid blocks nothing.
            c = new()
            c.lock_path().write_text(f"{os.getpid()}\n")
            c.marker("log")
            c.run()
            return [c.status(), c.lock_free()]
        check("unrelated-pid-does-not-block", 22, ["LOGGED", True], old_pid_in_lock)

        def lock_open_fails():
            c = new()
            c.lock_path().mkdir()
            before, calls = c.state(), len(c.calls())
            install(c)
            return [c.status(), c.state() == before, c.calls()[calls:], c.running()]
        check("lock-open-failure-reported", 22, ["ABORTED lock", True, [], True], lock_open_fails)

        def children_drop_lock():
            # The Launcher stub leaves a long-lived process, as the real Launcher does. No child may keep the lock.
            found = []
            try:
                c = new()
                (c.t / "long-launcher").write_text("")
                install(c)
                found.append([c.status(), c.lock_free(), c.lock_holders()])
                found.append(c.run().status())
                c = new()
                (c.t / "long-launcher").write_text("")
                install(c, "dies")
                found.append([c.status(), c.lock_free(), c.lock_holders()])
                found.append(c.run().status())
                c = new()
                c.marker("record")
                c.run()
                pid = int((c.root / "tmp/viknav-recorder.pid").read_text())
                found.append([c.status(), c.lock_free(), c.lock_holders([pid])])
                c.unmark()
                c.marker("log")
                found.append(c.run().status())
                (c.root / "proc/mounts").write_text("/dev/root / ext2 rw 0 0\n")
                wait_for(lambda: not Path(f"/proc/{pid}").exists())
            finally:
                stop_long_launchers(base)
            return found
        check("children-do-not-hold-lock", 22,
              [["INSTALLED", True, []], "ALREADY_INSTALLED", ["ROLLED_BACK Launcher stopped", True, []], "BLOCKED",
               ["RECORDING", True, []], "LOGGED"], children_drop_lock)

        def lock_released():
            found = []
            c = install(new())
            found.append([c.status(), c.lock_free()])
            c.run()
            found.append([c.status(), c.lock_free()])
            c.unmark()
            c.marker("log")
            c.run()
            found.append([c.status(), c.lock_free()])
            c = install(new(), "dies")
            found.append([c.status(), c.lock_free()])
            c = new()
            (c.root / "usr/bin/Launcher").write_bytes(b"unknown\n")
            install(c)
            found.append([c.status(), c.lock_free()])
            return found
        check("lock-released-on-every-exit", 22, [["INSTALLED", True], ["ALREADY_INSTALLED", True], ["LOGGED", True],
                                                 ["ROLLED_BACK Launcher stopped", True], ["ABORTED unknown Launcher", True]],
              lock_released)

        def no_settings_no_start():
            # A cut between the two settings renames, then the move back of the old settings folder fails.
            c = new()
            c.cut("between", True)
            (c.t / "mv-fail").write_text("private/Launcher")
            starts = c.starts()
            c.marker("install")
            c.run()
            return [c.status(), c.detail(), c.starts() - starts, c.journal_path().exists(), (c.root / "private/Launcher").exists(),
                    (c.root / "private/.Launcher.old").is_dir()]
        check("no-settings-folder-no-start", 19,
              ["ROLLBACK_FAILED resumed", "restore settings failed; original Launcher not started: no settings folder", 0, True, False,
               True], no_settings_no_start)

        def concurrent_runs():
            # The first run holds at the journal removal of a healthy install. A rollback run starts from the same drive.
            c = new()
            c.marker("install")
            source = c.script.read_text()
            anchor = '    journal_clear || rollback_now "clear the rollback journal"\n'
            gate = f'    printf ready > "{c.t}/first-ready"\n    while [ ! -f "{c.t}/first-release" ]; do "{BUSYBOX}" sleep 0.02; done\n'
            first_script = c.t / "first.sh"
            first_script.write_text(source.replace(anchor, gate + anchor))
            first = subprocess.Popen([str(BUSYBOX), "ash", str(first_script)], env={"PATH": "/usr/bin:/bin"},
                                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            try:
                ready = wait_for(lambda: (c.t / "first-ready").exists(), 60)
                held = [c.device(), c.journal_path().exists()]
                c.unmark()
                c.marker("rollback")
                c.run()
                second = [c.status(), c.device(), c.journal_path().exists()]
            finally:
                (c.t / "first-release").write_text("go")
                first.wait(timeout=120)
            first_out = sorted(c.usb.glob("viknav-ui-install-*"))[0]
            first_status = (first_out / "STATUS.txt").read_text().split("\n")[0]
            return [ready, held, second, first_status, c.device(), c.journal_path().exists(), c.lock_free(), c.running()]
        check("concurrent-runs-serialized", 22,
              [True, ["candidate", True], [BUSY, "candidate", True], "INSTALLED", "candidate", False, True, True], concurrent_runs)

        # A Launcher that ignores TERM gets KILL. A Launcher that ignores both stops the run before any live change.
        def term_ignored():
            c = new()
            (c.t / "killall-mode").write_text("ignore-term")
            install(c)
            return [c.status(), c.device(), "killall -9 Launcher" in c.calls()]
        check("launcher-ignores-term-gets-kill", 23, ["INSTALLED", "candidate", True], term_ignored)

        def stop_refused_install():
            c = new()
            (c.t / "killall-mode").write_text("ignore-all")
            before = c.state()
            install(c)
            return [c.status(), c.state() == before, c.running(), c.starts(), (c.out / "private-Launcher.tar").exists(), c.leftovers(),
                    c.journal_path().exists(), c.copy_path().exists()]
        check("launcher-refuses-stop-install-changes-nothing", 23,
              ["ABORTED Launcher did not stop", True, True, 0, False, [], False, False], stop_refused_install)

        def stop_refused_rollback():
            c = install(new())
            c.unmark()
            (c.t / "killall-mode").write_text("ignore-all")
            before = c.state()
            c.marker("rollback")
            c.run()
            return [c.status(), c.detail(), c.state() == before, c.running(), c.leftovers(), c.device()]
        check("launcher-refuses-stop-rollback-changes-nothing", 23,
              ["ROLLBACK_FAILED", "Launcher did not stop; nothing changed", True, True, [], "candidate"], stop_refused_rollback)

        def stop_refused_automatic():
            c = install(new(), "sticky")
            failed = [c.status(), c.detail(), c.journal_path().exists(), c.running(), c.device(), c.leftovers()]
            (c.t / "killall-mode").unlink()
            c.run()
            return failed + [c.status(), c.device(), c.settings() == SETTINGS, c.journal_path().exists(), c.running()]
        check("launcher-refuses-stop-automatic-keeps-journal", 23,
              ["ROLLBACK_FAILED startup markers missing", "Launcher did not stop; nothing changed; the next drive insert finishes the rollback",
               True, True, "candidate", [], "ROLLED_BACK resumed", "original", True, False, True], stop_refused_automatic)

        def stop_refused_start_phase():
            c = new()
            c.cut("journal-removal", True)
            (c.t / "killall-mode").write_text("ignore-all")
            c.marker("install")
            c.run()
            failed = [c.status(), c.detail(), c.journal_path().exists(), c.running()]
            (c.t / "killall-mode").unlink()
            c.run()
            return failed + [c.status(), c.detail(), c.journal_path().exists(), c.running()]
        check("launcher-refuses-stop-start-phase-keeps-journal", 23,
              ["ROLLBACK_FAILED resumed", "Launcher did not stop; nothing changed; the next drive insert finishes the rollback", True, True,
               "ROLLED_BACK resumed", "files already stock; original Launcher started", False, True], stop_refused_start_phase)

        # The stock settings backup has a recorded hash: on the drive, and inside the cluster for a replacement drive.
        def hash_recorded():
            c = install(new())
            return [c.sums() == [c.backup()] * 2, HASH_NOTE in c.lines()]
        check("install-records-stock-backup-hash", 24, [True, False], hash_recorded)

        def flip(path):
            raw = bytearray(path.read_bytes())
            raw[raw.index(SETTINGS)] ^= 1
            path.write_bytes(raw)

        for suffix, drop in (("", False), ("-replacement-drive", True)):
            def flipped(drop=drop):
                c = install(new())
                c.unmark()
                backup = c.usb / "viknav-ui/settings-before-install.tar"
                good = backup.read_bytes()
                flip(backup)
                if drop:
                    (c.usb / "viknav-ui/settings-before-install.sha256").unlink()
                before = c.state()
                c.marker("rollback")
                c.run()
                refused = [c.status(), c.detail(), c.state() == before, c.running(), c.journal_path().exists()]
                # A repair of the drive archive clears the refusal.
                backup.write_bytes(good)
                c.run()
                return refused + [c.status(), c.device(), c.settings() == SETTINGS, c.journal_path().exists()]
            check(f"stock-backup-bit-flip-refused{suffix}", 24,
                  ["ABORTED settings-before-install.tar damaged", BACKUP_HELP, True, True, False,
                   "ROLLED_BACK by request", "original", True, False], flipped)

        def legacy_empty_then_repaired():
            c = new().install_v1(V12_ETC)
            backup = c.usb / "viknav-ui/settings-before-install.tar"
            empty = __import__("io").BytesIO()
            with tarfile.open(fileobj=empty, mode="w", format=tarfile.USTAR_FORMAT):
                pass
            backup.write_bytes(empty.getvalue())
            before = c.state()
            c.marker("rollback")
            c.run()
            refused = [c.status(), c.detail(), c.state() == before, c.running(), c.sums()]
            backup.write_bytes(tarfile_bytes(SETTINGS))
            c.run()
            return refused + [c.status(), c.device(), c.settings() == SETTINGS, c.journal_path().exists(), HASH_NOTE in c.lines(),
                              c.sums() == [c.backup()] * 2]
        check("legacy-empty-backup-refused-then-repaired", 24,
              ["ABORTED settings-before-install.tar damaged", BACKUP_HELP, True, True, [None, None],
               "ROLLED_BACK by request", "original", True, False, True, True], legacy_empty_then_repaired)

        def legacy_members(members):
            import io
            buffer = io.BytesIO()
            with tarfile.open(fileobj=buffer, mode="w", format=tarfile.USTAR_FORMAT) as tar:
                for name, data in members:
                    info = tarfile.TarInfo(name)
                    if data is None:
                        info.type = tarfile.DIRTYPE
                        info.mode = 0o755
                        tar.addfile(info)
                    else:
                        info.size = len(data)
                        tar.addfile(info, io.BytesIO(data))
            return buffer.getvalue()

        for name, members in (("outside-launcher", [("Launcher", None), ("Launcher/settings.db", SETTINGS), ("etc/passwd", b"x\n")]),
                              ("parent-path", [("Launcher", None), ("Launcher/../etc/settings.db", SETTINGS)]),
                              ("no-regular-file", [("Launcher", None), ("Launcher/Databases", None)]),
                              ("empty-file", [("Launcher", None), ("Launcher/settings.db", b"")])):
            def legacy_bad(members=members):
                # No install folder on the drive: the member check decides.
                c = new().install_v1(V12_ETC)
                shutil.rmtree(c.first_install())
                (c.usb / "viknav-ui/settings-before-install.tar").write_bytes(legacy_members(members))
                before = c.state()
                install(c)
                return [c.status(), c.detail(), c.state() == before, c.running(), c.sums()]
            check(f"legacy-backup-{name}-refused", 24,
                  ["ABORTED settings-before-install.tar damaged", BACKUP_HELP, True, True, [None, None]], legacy_bad)

        # A backup from before the hash files must match the run backup of an install folder on the drive.
        for action in ("install", "rollback"):
            def legacy_flip(action=action):
                c = new().install_v1(V12_ETC)
                flip(c.usb / "viknav-ui/settings-before-install.tar")
                before = c.state()
                c.marker(action)
                c.run()
                return [c.status(), c.detail(), c.state() == before, c.running(), c.sums()]
            check(f"legacy-backup-bit-flip-refused-on-{action}", 24,
                  ["ABORTED settings-before-install.tar damaged", BACKUP_HELP, True, True, [None, None]], legacy_flip)

        def legacy_no_folder():
            # Without any install folder, the member check and a first record of the hash decide.
            c = new().install_v1(V12_ETC)
            shutil.rmtree(c.first_install())
            c.marker("rollback")
            c.run()
            return [c.status(), c.settings() == SETTINGS, HASH_NOTE in c.lines(), c.sums() == [c.backup()] * 2]
        check("legacy-backup-without-install-folder-recorded", 24, ["ROLLED_BACK by request", True, True, True], legacy_no_folder)

        for name, keep_folder in (("matched-by-install-folder", True), ("member-check", False)):
            def truck_archive(keep_folder=keep_folder):
                # The real truck settings archive (menu-v2 install run backup): Launcher/Databases with sqlite and ini files.
                real = TRUCK_SETTINGS.read_bytes()
                c = new().install_v1(V12_ETC)
                (c.usb / "viknav-ui/settings-before-install.tar").write_bytes(real)
                if keep_folder:
                    (c.first_install() / "private-Launcher.tar").write_bytes(real)
                else:
                    shutil.rmtree(c.first_install())
                install(c)
                return [c.status(), HASH_NOTE in c.lines(), c.sums() == [sha(real)] * 2]
            check(f"truck-settings-archive-accepted-{name}", 24, ["INSTALLED", True, True], truck_archive)

        # A partial encrypt.sh (a second updater rewrote encrypt.zip during the unzip) must run no command at all.
        def truncated(fraction):
            def run_cut():
                c = new()
                c.marker("install")
                text = c.script.read_text()
                last = text.rstrip("\n").rsplit("\n", 1)[1]
                stop = 'launcher_stop || abort "Launcher did not stop"\n'
                offsets = {"early": text.index("\nlog() {"),
                           "after-stop": text.index(stop) + len(stop),
                           "mid-restore": text.index("restore_original() {") + 400,
                           "before-last-line": len(text.rstrip("\n")) - len(last)}
                c.script.write_text(text[:offsets[fraction]])
                before, calls, outputs = c.state(), c.calls(), c.outputs()
                c.run()
                return [c.state() == before, c.calls() == calls, c.outputs() == outputs, c.running(), c.leftovers(),
                        c.lock_path().exists()]
            return run_cut
        for fraction in ("early", "after-stop", "mid-restore", "before-last-line"):
            check(f"truncated-installer-runs-nothing-{fraction}", 0, [True, True, True, True, [], False], truncated(fraction))

        def legacy_upgrade_records():
            c = new().install_v1(V12_ETC)
            install(c)
            return [c.status(), HASH_NOTE in c.lines(), c.sums() == [c.backup()] * 2]
        check("legacy-backup-hash-recorded-on-upgrade", 24, ["INSTALLED", True, True], legacy_upgrade_records)

        def internal_hash_beats_drive():
            # The drive holds another valid settings archive with a matching drive hash file; the internal hash decides.
            c = install(new())
            c.unmark()
            backup = c.usb / "viknav-ui/settings-before-install.tar"
            backup.write_bytes(tarfile_bytes(b"other settings\n"))
            (c.usb / "viknav-ui/settings-before-install.sha256").write_text(f"{c.backup()}  settings-before-install.tar\n")
            before = c.state()
            c.marker("rollback")
            c.run()
            return [c.status(), c.state() == before]
        check("internal-stock-hash-preferred", 24, ["ABORTED settings-before-install.tar damaged", True], internal_hash_beats_drive)

        def copy_missing_between():
            # A bad settings copy at a cut between the two settings renames: the old settings folder goes back in place.
            c = new()
            c.cut("between", True)
            c.copy_path().unlink()
            c.marker("install")
            c.run()
            first = [c.status(), c.detail(), c.journal_path().exists(), c.running(), c.settings() == CANDIDATE_SETTINGS]
            c.run()
            return first + [c.status(), c.journal_path().exists(), c.running(), c.settings() == CANDIDATE_SETTINGS]
        def drive_removed():
            # The drive goes away after the first live rename. Cleanup on the cluster must not depend on the drive log.
            c = new()
            c.marker("install")
            source = c.script.read_text()
            anchor = '        mv -f "$R/etc/.$f.new" "$R/etc/$f" || rollback_now "move /etc/$f"\n'
            hidden = c.t / "removed-usb"
            c.script.write_text(source.replace(anchor, anchor + f'        [ "$f" != vnD.qml ] || mv "$usb_root" "{hidden}"\n'))
            c.run()
            removed = [c.device(), c.running(), c.journal_path().exists(), c.copy_path().exists(), c.leftovers()]
            hidden.replace(c.usb)
            c.script.write_text(source)
            c.run()
            return removed + [c.status(), c.device()]
        check("drive-removed-during-install", 19, ["candidate", True, False, False, [], "ALREADY_INSTALLED", "candidate"], drive_removed)

        check("settings-folder-kept-when-copy-bad", 19,
              ["ROLLBACK_FAILED resumed", "settings copy check failed; original Launcher started", True, True, True,
               "ROLLBACK_FAILED resumed", True, True, True], copy_missing_between)

        def temp_files_cut():
            # A power cut inside settings_copy and inside stock_backup_write: each temp file exists, the rename did not run.
            c = new()
            (c.root / "etc/.viknav-settings.tar.new").write_bytes(b"torn")
            (c.usb / "viknav-ui/.settings-before-install.tar.new").write_bytes(tarfile_bytes(SETTINGS)[:700])
            install(c)
            with tarfile.open(c.usb / "viknav-ui/settings-before-install.tar") as tar:
                saved = tar.extractfile("Launcher/settings.db").read()
            return [c.status(), c.leftovers(), c.copy_path().exists(), [p.name for p in (c.usb / "viknav-ui").glob(".*")],
                    saved == SETTINGS, c.journal_path().exists()]
        check("cut-temp-files-then-install", 13, ["INSTALLED", [], False, [], True, False], temp_files_cut)

        def phase_write_cut():
            # A power cut inside the start-phase journal write of a rollback: the start journal is written, not renamed.
            c = new()
            c.cut("settled", True)
            (c.root / "etc/.viknav-rollback.new").write_text(c.journal_text("start"))
            c.marker("install")
            c.run()
            return [c.status(), c.detail(), c.device(), c.settings() == AUTO_SETTINGS, c.leftovers(), c.journal_path().exists(),
                    c.copy_path().exists(), c.running()]
        check("cut-phase-journal-write-then-install", 19,
              ["ROLLED_BACK resumed", "original Launcher started", "original", True, [], False, False, True], phase_write_cut)

        def torn(data, size=700):
            return tarfile_bytes(data)[:size]

        def torn_backup_original():
            c = new()
            (c.usb / "viknav-ui/settings-before-install.tar").write_bytes(torn(SETTINGS))
            install(c)
            with tarfile.open(c.usb / "viknav-ui/settings-before-install.tar") as tar:
                saved = tar.extractfile("Launcher/settings.db").read()
            return [c.status(), saved == SETTINGS, [p.name for p in (c.usb / "viknav-ui").glob(".*")]]
        check("torn-stock-backup-replaced-on-original", 19, ["INSTALLED", True, []], torn_backup_original)

        def torn_backup_mid_data():
            c = new()
            (c.usb / "viknav-ui/settings-before-install.tar").write_bytes(torn(b"x" * 60000, 30000))
            install(c)
            with tarfile.open(c.usb / "viknav-ui/settings-before-install.tar") as tar:
                saved = tar.extractfile("Launcher/settings.db").read()
            return [c.status(), saved == SETTINGS]
        check("torn-stock-backup-mid-data-replaced-on-original", 19, ["INSTALLED", True], torn_backup_mid_data)

        def torn_backup_release():
            c = new().install_v1(V12_ETC)
            (c.usb / "viknav-ui/settings-before-install.tar").write_bytes(torn(SETTINGS))
            before = c.state()
            install(c)
            return [c.status(), c.detail(), c.state() == before, c.starts(), c.running()]
        check("torn-stock-backup-refused-on-release", 19,
              ["ABORTED settings-before-install.tar damaged",
               "Copy private-Launcher.tar from the first install folder to viknav-ui/settings-before-install.tar.", True, 0, True],
              torn_backup_release)

        def torn_backup_rollback():
            c = install(new())
            c.unmark()
            (c.usb / "viknav-ui/settings-before-install.tar").write_bytes(torn(SETTINGS))
            before = c.state()
            c.marker("rollback")
            c.run()
            return [c.status(), c.detail(), c.state() == before, c.running(), c.journal_path().exists()]
        check("torn-stock-backup-refused-on-rollback", 19,
              ["ABORTED settings-before-install.tar damaged",
               "Copy private-Launcher.tar from the first install folder to viknav-ui/settings-before-install.tar.", True, True, False],
              torn_backup_rollback)

        for action in ("install", "rollback"):
            def stock_start_fails(action=action):
                c = install(new())
                c.unmark()
                c.marker("rollback")
                (c.t / "original-mode").write_text("dies")
                c.run()
                first = [c.status(), c.detail(), c.journal_path().exists()]
                (c.t / "original-mode").unlink()
                starts = c.starts()
                c.unmark()
                c.marker(action)
                c.run()
                return first + [c.status(), c.detail(), c.running(), c.starts() - starts, c.journal_path().exists(), c.device(),
                                c.settings() == SETTINGS]
            check(f"stock-start-failure-keeps-journal-then-{action}", 21,
                  ["ROLLBACK_FAILED", "original Launcher start check failed: Launcher stopped", True,
                   "ROLLED_BACK resumed", "files already stock; original Launcher started", True, 1, False, "original", True],
                  stock_start_fails)

        def already_original_starts():
            c = new()
            (c.t / "running").unlink()
            c.marker("rollback")
            c.run()
            return [c.status(), c.detail(), c.running(), c.starts()]
        check("already-original-starts-a-stopped-launcher", 20, ["ALREADY_ORIGINAL", "current Launcher started", True, 1],
              already_original_starts)

        def already_installed_starts():
            c = install(new())
            (c.t / "running").unlink()
            c.run()
            return [c.status(), c.detail(), c.running(), c.starts()]
        check("already-installed-starts-a-stopped-launcher", 20, ["ALREADY_INSTALLED", "current Launcher started", True, 2],
              already_installed_starts)

        def blocked_starts():
            c = install(new(), "dies")
            (c.t / "running").unlink(missing_ok=True)
            c.run()
            return [c.status(), c.detail(), c.running()]
        check("blocked-starts-a-stopped-launcher", 20, ["BLOCKED", "current Launcher started", True], blocked_starts)

        def blocked_marker_write_fails():
            # Review 6 probe: the candidate start removes write access to the drive root, so INSTALL-BLOCKED.txt cannot be
            # written. The block on the cluster must stop the second insert.
            c = new().install_v1(V2_ETC)
            qtenv = c.root / "etc/qtenv.sh"
            anchor = "log=$R/tmp/Launcher.log\n"
            qtenv.write_text(qtenv.read_text().replace(anchor, f'[ "$h" != "{sha(CANDIDATE_BYTES)}" ] || chmod 555 "$T/usb/sda1"\n' + anchor))
            found = []
            try:
                for _ in range(2):
                    c.usb.chmod(0o755)
                    starts = c.starts()
                    install(c, "nomarker")
                    found.append([c.status(), c.lines()[1:], c.drive_blocked(), c.journal_path().exists(), c.device(), c.running(),
                                  c.starts() - starts, c.block() == PAYLOAD_ID])
            finally:
                c.usb.chmod(0o755)
            return found
        check("failed-install-blocks-without-drive-marker", 5,
              [["ROLLED_BACK startup markers missing", ["original Launcher started", HASH_NOTE], False, False, "original", True, 2, True],
               ["BLOCKED", [CLUSTER_BLOCK_HELP], False, False, "original", True, 0, True]], blocked_marker_write_fails)

        def cluster_block_same_release():
            c = new()
            c.block_path().write_text(PAYLOAD_ID + "\n")
            before, calls = c.state(), len(c.calls())
            install(c)
            return [c.lines(), c.state() == before, c.calls()[calls:], c.running(), c.leftovers()]
        check("cluster-block-stops-the-same-release", 5, [["BLOCKED", CLUSTER_BLOCK_HELP], True, [], True, []], cluster_block_same_release)

        def cluster_block_other_release():
            c = new()
            c.block_path().write_text("0" * 64 + "\n")
            install(c)
            return [c.status(), c.device(), c.block()]
        check("cluster-block-of-another-release-installs", 25, ["INSTALLED", "candidate", "0" * 64], cluster_block_other_release)

        def drive_marker_only():
            c = new()
            (c.usb / "INSTALL-BLOCKED.txt").write_text("startup markers missing\n")
            install(c)
            return [c.lines(), c.device()]
        check("drive-marker-alone-blocks", 5, [["BLOCKED", DRIVE_BLOCK_HELP], "original"], drive_marker_only)

        def drive_marker_names_release():
            # A failed install writes the reason on line 1 and the release identity on line 2.
            c = install(new(), "dies")
            return [c.status(), (c.usb / "INSTALL-BLOCKED.txt").read_text().splitlines()]
        check("drive-marker-names-the-release", 5,
              ["ROLLED_BACK Launcher stopped", ["Launcher stopped", f"release {PAYLOAD_ID}"]], drive_marker_names_release)

        def drive_marker_same_release():
            c = new()
            (c.usb / "INSTALL-BLOCKED.txt").write_text(f"startup markers missing\nrelease {PAYLOAD_ID}\n")
            install(c)
            return [c.lines(), c.device()]
        check("drive-marker-of-this-release-blocks", 5, [["BLOCKED", DRIVE_BLOCK_HELP], "original"], drive_marker_same_release)

        def drive_marker_other_release():
            # Review 7: a marker left by a failed earlier release must not stop a different release on the same drive.
            c = new()
            (c.usb / "INSTALL-BLOCKED.txt").write_text("startup markers missing\nrelease " + "0" * 64 + "\n")
            install(c)
            return [c.status(), c.device(), c.drive_blocked()]
        check("drive-marker-of-another-release-installs", 25, ["INSTALLED", "candidate", True], drive_marker_other_release)

        def rollback_clears_block():
            found = []
            c = install(new(), "dies")
            found.append([c.status(), c.block() == PAYLOAD_ID, c.drive_blocked()])
            c.unmark()
            c.marker("log")
            c.run()
            found.append([c.status(), f"install block: {PAYLOAD_ID}" in (c.out / "installed-sha256.txt").read_text()])
            # Removing the drive marker alone leaves the block on the cluster.
            (c.usb / "INSTALL-BLOCKED.txt").unlink()
            c.unmark()
            install(c, "dies")
            found.append([c.lines(), c.starts()])
            c.unmark()
            c.marker("rollback")
            c.run()
            found.append([c.status(), c.block(), c.drive_blocked(), c.leftovers()])
            c.unmark()
            install(c)
            found.append([c.status(), c.device()])
            return found
        check("rollback-insert-clears-the-block", 25,
              [["ROLLED_BACK Launcher stopped", True, True], ["LOGGED", True], [["BLOCKED", CLUSTER_BLOCK_HELP], 2],
               ["ALREADY_ORIGINAL", None, False, []], ["INSTALLED", "candidate"]], rollback_clears_block)

        def requested_rollback_clears_block():
            c = install(new())
            c.block_path().write_text(PAYLOAD_ID + "\n")
            (c.usb / "INSTALL-BLOCKED.txt").write_text("startup markers missing\n")
            c.unmark()
            c.marker("rollback")
            c.run()
            return [c.status(), c.device(), c.block(), c.drive_blocked()]
        check("requested-rollback-clears-the-block", 25, ["ROLLED_BACK by request", "original", None, False],
              requested_rollback_clears_block)

        def block_removal_fails():
            # A folder in the place of the cluster block cannot be removed. The result says so.
            c = new()
            c.block_path().mkdir()
            c.marker("rollback")
            c.run()
            return [c.lines(), c.block_path().exists(), c.running()]
        check("rollback-reports-a-block-not-removed", 25, [["ALREADY_ORIGINAL", "install block not removed"], True, True],
              block_removal_fails)

        def block_write_fails():
            c = new()
            blocker = c.root / "etc/.viknav-blocked.new"
            blocker.mkdir()
            install(c, "dies")
            failed = [c.status(), c.detail(), c.device(), c.running(), c.journal_path().exists(), c.block()]
            # The kept journal names the release to block. The next insert finishes the rollback and writes the block.
            blocker.rmdir()
            c.run()
            resumed = [c.status(), c.detail(), c.journal_path().exists(), c.block() == PAYLOAD_ID, c.leftovers()]
            c.run()
            return [failed, resumed, c.status()]
        check("cluster-block-write-failure-keeps-journal", 5,
              [["ROLLBACK_FAILED Launcher stopped", "install block write failed; original Launcher started", "original", True, True, None],
               ["ROLLED_BACK resumed", "files already stock; original Launcher started", False, True, []], "BLOCKED"], block_write_fails)

        def journal_blocked():
            c = install(new())
            c.unmark()
            c.marker("rollback")
            (c.root / "etc/.viknav-rollback.new").mkdir()
            before = c.state()
            c.run()
            return [c.status(), c.detail(), c.state() == before, c.running()]
        check("rollback-journal-write-failure-reported", 18,
              ["ROLLBACK_FAILED", "rollback journal write failed; rollback not started", True, True], journal_blocked)

        for blocker, reason in ((".viknav-rollback.new", "rollback journal"), (".viknav-settings.tar.new", "settings copy")):
            def install_write_fails(blocker=blocker):
                c = new()
                (c.root / "etc" / blocker).mkdir()
                before = c.state()
                install(c)
                return [c.status(), c.state() == before, wait_for(c.running, 5), c.leftovers(), c.copy_path().exists()]
            check(f"install-{reason.replace(' ', '-')}-write-failure-changes-nothing", 18,
                  [f"ABORTED {reason}", True, True, [f"etc/{blocker}"] if blocker.endswith(".new") else [], False], install_write_fails)

        def unsafe_redirections():
            return unsafe_redirection_lines(SCRIPT.read_text())

        def checker_self_test():
            sample = ('exec 9>>"$LOCK"\n'
                      '[ -f "$LOCK" ] && [ -w "$LOCK" ] || return 2\nexec 9>>"$LOCK"\n'
                      '[ -w "$OTHER" ] || return 2\nexec 9>>"$LOCK"\n'
                      ': > x\n{ a; } > x\nprintf a ${n:+"$n"} > "$o"\n(a) 9>&- &\n')
            return unsafe_redirection_lines(sample)
        check("static-check-flags-unguarded-exec", 18, [1, 5, 6, 7], checker_self_test)
        check("no-special-builtin-or-compound-redirection", 18, [], unsafe_redirections)

        def log_journal():
            c = new()
            c.cut("journal", False)
            c.marker("log")
            c.run()
            return [c.status(), "rollback journal: present" in (c.out / "installed-sha256.txt").read_text()]
        check("log-reports-rollback-journal", 17, ["LOGGED", True], log_journal)

        def journal_payload_missing():
            c = new()
            c.cut("sounds", True)
            (c.usb / "viknav-ui/original/sound/door.wav").unlink()
            before, calls = c.state(), len(c.calls())
            c.marker("install")
            c.run()
            return [c.status(), c.state() == before, c.calls()[calls:], c.journal_path().exists()]
        check("cut-journal-payload-missing-changes-nothing", 19, ["ABORTED rollback journal: payload missing", True, [], True],
              journal_payload_missing)

        def resume_start_fails():
            c = new()
            c.cut("etc", True)
            (c.t / "original-mode").write_text("nomarker")
            c.marker("install")
            c.run()
            return [c.status(), c.detail(), c.device(), c.journal_path().exists()]
        check("cut-resume-start-check-failure-reported", 21,
              ["ROLLBACK_FAILED resumed", "original Launcher start check failed: startup markers missing", "original", True],
              resume_start_fails)

        for target, detail, device in (
                ("etc/sound/door.wav", "move /etc/sound/door.wav failed; original Launcher started", "mixed launcher=original etc=[] sound=mixed"),
                ("usr/bin/Launcher", "move Launcher failed; current Launcher started", f"mixed launcher=candidate etc={ETC} sound=stock")):
            def move_fails(target=target):
                c = install(new())
                c.unmark()
                c.marker("rollback")
                (c.t / "mv-fail").write_text(target)
                c.run()
                failed = [c.status(), c.detail(), c.running(), c.device(), c.leftovers(), c.journal_path().exists()]
                # The kept journal makes the next insert finish the rollback.
                (c.t / "mv-fail").unlink()
                c.run()
                return failed + [c.status(), c.device(), c.settings() == SETTINGS, c.journal_path().exists()]
            check(f"rollback-move-failure-restarts-{target.rsplit('/', 1)[1]}", 20,
                  ["ROLLBACK_FAILED", detail, True, device, [], True, "ROLLED_BACK resumed", "original", True, False], move_fails)

        def rollback_start_fails():
            c = install(new())
            c.unmark()
            c.marker("rollback")
            (c.t / "original-mode").write_text("nomarker")
            c.run()
            return [c.status(), c.detail(), c.device(), c.journal_path().exists()]
        check("rollback-start-check-failure-reported", 21,
              ["ROLLBACK_FAILED", "original Launcher start check failed: startup markers missing", "original", True], rollback_start_fails)

        def unhealthy_start_fails():
            c = new()
            (c.t / "original-mode").write_text("nomarker")
            install(c, "nomarker")
            return [c.status(), c.detail(), c.device(), c.journal_path().exists()]
        check("unhealthy-start-check-failure-reported", 21,
              ["ROLLBACK_FAILED startup markers missing", "original Launcher start check failed: startup markers missing", "original",
               True], unhealthy_start_fails)

        def log_sounds():
            c = install(new())
            c.unmark()
            c.marker("log")
            c.run()
            text = (c.out / "installed-sha256.txt").read_text()
            return [c.status(), [n for n in SOUNDS if f"{sha(SOUND_BYTES[n])}  {c.root}/etc/sound/{n}" not in text]]
        check("log-lists-sound-hashes", 17, ["LOGGED", []], log_sounds)

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
        stop_long_launchers(base)
        for path in Path(base).rglob("*"):
            if path.is_dir():
                path.chmod(0o755)
        shutil.rmtree(base)

    payload = {"script": str(SCRIPT.relative_to(ROOT)), "script_sha256": sha(SCRIPT.read_bytes()),
               "shell": subprocess.run([str(BUSYBOX)], capture_output=True, text=True).stdout.split("\n")[0],
               "busybox": str(BUSYBOX), "flock": str(flock_tool()),
               "failureModes": FAILURE_MODES, "count": len(rows), "passed": sum(r["pass"] for r in rows),
               "failed": sum(not r["pass"] for r in rows), "rows": rows, "cutTable": cut_table,
               "scope": "BusyBox ash syntax check; BusyBox ash with stub functions for the cases; real Launcher, QML, and sound payload bytes, stubbed Launcher start, process list, and free space. "
                        "No cluster, vendor updater, Qt runtime, or vehicle proof."}
    RESULT.write_text(json.dumps(payload, indent=2) + "\n")
    print(json.dumps({k: payload[k] for k in ("count", "passed", "failed")} | {"result": str(RESULT)}))
    for row in rows:
        if not row["pass"]:
            print("FAIL", row["name"], "expected", row["expected"], "actual", row["actual"])
    return 1 if payload["failed"] else 0


if __name__ == "__main__":
    sys.exit(main())
