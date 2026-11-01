"""Build the USB drive contents for the cluster UI install, rollback, and log collection (tools/usb-install/encrypt.sh).

Run under WSL: python3 tools/build_usb_install.py [--output DIR]
Inputs: the UI candidate (analysis/capture-04/ui-candidate-menu-v14), the captured original Launcher, chime set A
(design/round-43/sounds/a, written by design/round-43/sounds/make_sounds.py), and the captured stock /etc/sound files.
The vendor USB updater unpacks encrypt.zip with a password. The builder reads that password from the captured updater
(installed/capture-04/rootfs/etc/mdev/update.sh) at build time; the password never enters Git or the output text.
Info-ZIP (tools/infozip/usr/bin/zip) writes the encrypted archive, as for the diagnostic packages.

Output (ignored by Git):
  drive/      copy everything here to the top level of the USB drive
  markers/    copy exactly one marker next to encrypt.zip to select install, rollback, log collection, or recording
  MANIFEST.json
"""
import argparse
import hashlib
import json
import re
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools/usb-install/encrypt.sh"
CANDIDATE = ROOT / "analysis/capture-04/ui-candidate-menu-v14"
ORIGINAL = ROOT / "installed/capture-04/rootfs/usr/bin/Launcher"
UPDATER = ROOT / "installed/capture-04/rootfs/etc/mdev/update.sh"
ZIP_TOOL = ROOT / "tools/infozip/usr/bin/zip"
OUTPUT_DEFAULT = ROOT / "analysis/capture-04/usb-install-menu-v14"
SOUND_SET = ROOT / "design/round-43/sounds/a"
STOCK_SOUND = ROOT / "installed/capture-04/rootfs/etc/sound"
ETC = ["vnD.qml", "vnG.qml", "vnL.qml", "vnM.qml", "vnN.qml", "vnS.qml", "vnV.qml"]
# Free space above the staged files that encrypt.sh MIN_FREE_KB must keep (filesystem metadata and other writers).
STAGE_MARGIN_KB = 4096

sha = lambda data: hashlib.sha256(data).hexdigest()


def require(condition, message):
    if not condition:
        raise SystemExit("FAIL: " + message)


def case_pins(text, function):
    """NAME -> hash from the case lines of one encrypt.sh function."""
    body = re.search(rf"^{function}\(\) {{\n(.*?)^}}$", text, re.M | re.S)
    require(body is not None, f"encrypt.sh has no {function}")
    return dict(re.findall(r"^\s+(\S+)\) echo ([0-9a-f]{64}) ;;$", body.group(1), re.M))


def script_pins(text):
    """Payload path -> pinned hash, the sound file names, the marker tokens, and MIN_FREE_KB."""
    launchers = {"original/Launcher": re.search(r"^ORIGINAL_SHA256=([0-9a-f]{64})$", text, re.M),
                 "Launcher": re.search(r"^CANDIDATE_SHA256=([0-9a-f]{64})$", text, re.M)}
    require(all(launchers.values()), "encrypt.sh Launcher pins are incomplete")
    pins = {key: match.group(1) for key, match in launchers.items()}
    etc = case_pins(text, "etc_sha256")
    require(sorted(etc) == ETC, "encrypt.sh /etc pins are incomplete")
    pins.update({f"etc/{name}": value for name, value in etc.items()})
    files = re.search(r'^SOUND_FILES="([^"]+)"$', text, re.M)
    require(files is not None, "encrypt.sh has no SOUND_FILES")
    sounds = files.group(1).split()
    stock = case_pins(text, "sound_stock")
    new = case_pins(text, "sound_sha256")
    require(len(sounds) == 15 and sorted(new) == sorted(stock) == sorted(sounds), "encrypt.sh sound pins are incomplete")
    pins.update({f"sound/{name}": value for name, value in new.items()})
    pins.update({f"original/sound/{name}": value for name, value in stock.items()})
    markers = dict(re.findall(r"^\s+(VIKNAV-UI-\w+\.txt)\) echo (\w+) ;;$", text, re.M))
    require(len(markers) == 4, "encrypt.sh marker tokens are incomplete")
    free = re.search(r"^MIN_FREE_KB=(\d+)$", text, re.M)
    require(free is not None, "encrypt.sh has no MIN_FREE_KB")
    return pins, sounds, markers, int(free.group(1))


def blocks_kb(data):
    """Disk use of one file in 4 KB blocks."""
    return -(-len(data) // 4096) * 4


def zip_password():
    """The -P argument of the vendor encrypt.zip unzip line, with a $NAME value resolved in the same file."""
    text = UPDATER.read_text(encoding="utf-8", errors="replace")
    line = next((l for l in text.splitlines() if "encrypt.zip -d" in l and "unzip" in l), None)
    require(line is not None, "captured updater has no encrypt.zip unzip line")
    match = re.search(r"-P\s*(\S+)", line)
    require(match is not None, "captured updater unzip line has no password argument")
    value = match.group(1).strip("\"'")
    if value.startswith("$"):
        assignment = re.search(rf"^{re.escape(value.strip('${}'))}=(\S+)$", text, re.M)
        require(assignment is not None, "captured updater password variable is not assigned")
        value = assignment.group(1)
    return value


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=OUTPUT_DEFAULT)
    args = parser.parse_args()
    out = args.output
    require(not out.exists(), f"{out} exists; choose a new output directory")

    script = SCRIPT.read_bytes()
    require(script.startswith(b"#!/bin/sh\n") and b"\r" not in script, "encrypt.sh must start with #!/bin/sh and use LF")
    expected, sounds, markers, min_free_kb = script_pins(script.decode())
    require(all((SOUND_SET / name).is_file() for name in sounds),
            "chime set A is missing; run python3 design/round-43/sounds/make_sounds.py")
    payload = {"Launcher": (CANDIDATE / "Launcher").read_bytes(), "original/Launcher": ORIGINAL.read_bytes()}
    payload.update({f"etc/{name}": (CANDIDATE / "etc" / name).read_bytes() for name in ETC})
    payload.update({f"sound/{name}": (SOUND_SET / name).read_bytes() for name in sounds})
    payload.update({f"original/sound/{name}": (STOCK_SOUND / name).read_bytes() for name in sounds})
    require(sorted(payload) == sorted(expected), "payload files differ from the encrypt.sh pins")
    for name, data in payload.items():
        require(sha(data) == expected[name], f"{name} does not match the encrypt.sh pin")
    # An install stages the Launcher, the /etc files, and the sounds before the first rename.
    staged_kb = sum(blocks_kb(data) for name, data in payload.items() if not name.startswith("original/"))
    require(min_free_kb >= staged_kb + STAGE_MARGIN_KB,
            f"encrypt.sh MIN_FREE_KB {min_free_kb} is below the staged files ({staged_kb} KB) plus {STAGE_MARGIN_KB} KB")
    manifest = json.loads((CANDIDATE / "manifest.json").read_text())
    require(manifest["source"]["sha256"] == expected["original/Launcher"], "candidate manifest source differs from the original pin")
    require(manifest["candidate"]["sha256"] == expected["Launcher"], "candidate manifest Launcher differs from the pin")

    password = zip_password()
    with tempfile.TemporaryDirectory(prefix="usb-install-build-") as temporary:
        staging = Path(temporary)
        member = staging / "encrypt/encrypt.sh"
        member.parent.mkdir()
        member.write_bytes(script)
        member.chmod(0o755)
        subprocess.run([str(ZIP_TOOL), "-q", "-9", "-P", password, "encrypt.zip", "encrypt/encrypt.sh"],
                       cwd=staging, check=True, timeout=60)
        archive_bytes = (staging / "encrypt.zip").read_bytes()
        with zipfile.ZipFile(staging / "encrypt.zip") as archive:
            archive.setpassword(password.encode())
            infos = archive.infolist()
            require([i.filename for i in infos] == ["encrypt/encrypt.sh"], "unexpected archive members")
            require(infos[0].flag_bits & 1 and infos[0].create_system == 3, "archive member must be encrypted with Unix attributes")
            require((infos[0].external_attr >> 16) & 0o777 == 0o755, "archive member must be mode 0755")
            require(archive.read(infos[0]) == script, "archive member differs from encrypt.sh")

        build = out.with_name(out.name + ".partial")
        require(not build.exists(), f"{build} exists from an earlier failed build; remove the directory")
        drive = build / "drive"
        (drive / "viknav-ui").mkdir(parents=True)
        (drive / "encrypt.zip").write_bytes(archive_bytes)
        for name, data in payload.items():
            target = drive / "viknav-ui" / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            require(sha(target.read_bytes()) == expected[name], f"{name} readback differs")
        (build / "markers").mkdir()
        for name, token in markers.items():
            (build / "markers" / name).write_bytes(token.encode() + b"\n")
        record = {
            "encrypt.zip": {"sha256": sha(archive_bytes), "member": "encrypt/encrypt.sh", "member_sha256": sha(script),
                            "encryption": "Traditional PKZIP (ZipCrypto), vendor updater password"},
            "payload": {name: {"sha256": sha(data), "size": len(data)} for name, data in payload.items()},
            "markers": {name: token for name, token in markers.items()},
            "candidate": str(CANDIDATE.relative_to(ROOT)),
            "sounds": {"set": "A", "source": SOUND_SET.relative_to(ROOT).as_posix(), "stock": STOCK_SOUND.relative_to(ROOT).as_posix(),
                       "files": sounds, "staged_kb": staged_kb, "min_free_kb": min_free_kb},
            "status": "built; not run on the cluster",
        }
        (build / "MANIFEST.json").write_text(json.dumps(record, indent=2) + "\n")
        build.rename(out)
    print(json.dumps({"output": str(out), "encrypt.zip": record["encrypt.zip"]["sha256"], "files": len(payload)}))


if __name__ == "__main__":
    main()
