#!/bin/sh
# F150 cluster UI update from a USB drive: install, rollback, log collection, or recording.
# The vendor USB updater (/etc/mdev/update.sh) unpacks encrypt.zip to /mnt/temp/encrypt and runs this file as root.
# One marker file next to encrypt.zip selects the action. The payload folder viknav-ui/ sits next to encrypt.zip.
# The hashes below pin every payload file. tools/build_usb_install.py builds the drive contents.
# tests/usb-install-replay.py replays this file against a fake cluster root.
# The whole script is one { } group, so the shell parses the full file before the first command runs. A truncated file
# (a second updater can rewrite encrypt.zip during the unzip) is a syntax error and runs nothing. A later rewrite of the
# file cannot change a run in progress.
{
set -u
PATH=/bin:/usr/bin:/sbin:/usr/sbin
export PATH
LC_ALL=C
export LC_ALL
umask 022
USB_BASE=/mnt/usb
SYSTEM_ROOT=
# Free space for the staged Launcher, /etc files, and sounds (about 56,600 KB in 4 KB blocks for menu-v13), plus a margin.
# The captured mounts show /usr/bin, /etc, and /etc/sound on one filesystem (/dev/mmcblk0p4 at /). The install checks each folder.
# tools/build_usb_install.py stops the build when this value is below the real staged size plus 4,096 KB.
MIN_FREE_KB=65536
HEALTH_WAIT=90
SETTLE_WAIT=20
LOG_WAIT=180

# Captured original Launcher (capture-04) and the ui-candidate-menu-v13 files.
ORIGINAL_SHA256=2451c3fb6f6c1344625aa2882760eaaccd3dc0979ad1296c9028838e77e2823b
CANDIDATE_SHA256=e5f223441e454e1c6707bec6f775eccdab4ab7760a874f0b16abe7bfc5db238c
# Launcher files of earlier releases (space separated). An install replaces them. menu-v1 to menu-v8 share one Launcher.
PREVIOUS_LAUNCHERS="3aee8242a8cb167069750bb721f34b5ab66e48cf634fe7c3fcb81b75abd49d8a"
ETC_FILES="vnD.qml vnG.qml vnL.qml vnM.qml vnN.qml vnS.qml vnV.qml"
# /etc files that only an earlier release installed. An install and a rollback remove them.
RETIRED_FILES="vnB.qml vnF.qml"
etc_sha256() {
    case "$1" in
        vnD.qml) echo 78758c2c2ba1e07f366b08751fad5cd0795634a4f04e14c753ea446b603097be ;;
        vnG.qml) echo 2db5953fe0ddda609fab05f25fdda2449a71b7f63fde2a03e63024155bb9cb84 ;;
        vnL.qml) echo 591be06b20724b84b1a15de69dd744e159875a28b0b9fa1b69b50e03a7847659 ;;
        vnM.qml) echo b7d449482ee2d7d952060ededcfbcc544e23f155855eb1bf556625eb43840af4 ;;
        vnN.qml) echo 976b5fb15f96b1a2c894ac8d23a993fd03890c8d58bdec952560990e48274595 ;;
        vnS.qml) echo 4d285e170e0de495842a247faf83c2d62834ceea8c1e25be7c56de45ee8bfa45 ;;
        vnV.qml) echo 0cf0ff8d8122a7e2f296098bfc012a85d3d168edb895079adde0747d0ec4c01a ;;
    esac
}
# /etc files of earlier releases (space separated per file). menu-v1: the first cluster install, 2026-10-30.
# menu-v2: native Factory pages and the key trace. menu-v3: the wheel key bounce filter.
# menu-v4: oil pressure in the data log. menu-v5: the cruise fields in the data log.
# menu-v6: boost and trailer brake readings in the data log. menu-v7: engine gauge frame, compass, and oil life.
# menu-v8: menu motion. The menu-v8 files are the current files. menu-v9 and menu-v10 did not ship.
# menu-v11 adds vnD (the owned dashboard shell with the wheel key map), vnN (the fixed notification text), and a new Launcher.
# menu-v12 adds vnL (the Daily A and Towing A layouts) and changes vnD, vnG, and vnM for the two layouts. The Launcher stays.
# menu-v13 adds chime set A in /etc/sound and changes vnL (the round 43/44 alert panel, overspeed, and cruise) and vnD (the Trip A hold
# follows the shown card). The Launcher stays.
etc_previous() {
    case "$1" in
        vnB.qml) echo cf4c014945f604b5a0da27d70ec0849a54fb57c972bd9ca55c3f0effd8504aee ;;
        vnD.qml) echo 7cb87b4ba052d3b52934c2e8c57e61398c6bb638d8e64acace967b2b5d619c56 edafa15cf5118423f1fe6e71a9bd54f525099dbbf3083a275e7d1fa1ba67806c ;;
        vnF.qml) echo e3b79fe488506ec3d1c096f3b545df1c166a3e9928f773b1b6507a63e1eb1e12 ;;
        vnG.qml) echo ce54efec52bfda1778234c1939f29dae6c703d1aa3315856260e37543edaf33e 1f018311b704ef57c0ac2ba2c6dca7bf62ebd00e14a4a5394d0a71f075892e9b c300a6bf3999a7dd406c1b956ff64693b4b5a5f0e9ba45205e7a76c22b19f2b4 ;;
        vnL.qml) echo 826b4c2dc9c2e65471220741edf43e2d339b1e986d8cb2433dcfe2c30d031d7e ;;
        vnM.qml) echo bcfbcb20cf4e2ae1853fc442983170a4303c1f4765979378e65dfbb306e8746b 27fac58c773beab055b7f5baa3203be379f0aba3287a20ecd2d10d6ae9f0a76b 0fa4d685121b9c8df22fef7f15a034c3e6452f21868abe7b171e0e20f375935b baf94b049c76bf491355ff1c56f66297500aa4ca34383cdff5857895f17f9911 ;;
        vnS.qml) echo 4d285e170e0de495842a247faf83c2d62834ceea8c1e25be7c56de45ee8bfa45 ;;
        vnV.qml) echo ef6d29dae3b736fa8239930c62cb582abc5c302441d47e35ac0f8c18634829c1 4d1c0e629904c709c651368c4b6465d8db3828b5737e11616060af3d7b040c3b 4a0c9f844b9dc1286c7a6db990659b2b8442b5e7a60b7b990d527204752ff367 787340b7ba86e2c5b116e923aad29ef62ea6bc109aeb659e2f403e4f6c02a512 f2f8ce13f2653d7560e162c28923c39ca08582c467219cb97c7119f8d93e09a9 ;;
    esac
}
# Chime sounds in /etc/sound. The native libVehicleEvent.so plays /etc/sound/NAME.wav; no QML reads the files.
# An install puts chime set A ("soft", design/round-43/sounds/make_sounds.py, picked 2026-10-31) in place of each file.
SOUND_FILES="breaker.wav buzzer.wav ding.wav direct_quick.wav direct_slow.wav door.wav radar_b0.wav radar_b1.wav radar_b2.wav radar_b3.wav radar_b4.wav radar_b5.wav radar_b6.wav seatbelt_quick.wav seatbelt_slow.wav"
sound_sha256() {
    case "$1" in
        breaker.wav) echo a583734e27abc76492ec9771448f2e772107d2d95ff2e2b90cf712106216b71b ;;
        buzzer.wav) echo cdd68b29d2e5814162298ab7cdd1e5657f6025387f85b098a5d6404c34e100f9 ;;
        ding.wav) echo 649561cab079747ae7666701eafb2b48bcfd87662e3413202c1e92db70c974ca ;;
        direct_quick.wav) echo 1df43f79dab41e1fabcccb8854d1d9b6d16dadb92cc3616a9e241a6652684e46 ;;
        direct_slow.wav) echo 183ee0f8d8cf9aab67141e086f5baaff60df520a086df1ce7d0d1b9be43c1f94 ;;
        door.wav) echo 0047155ebf8adca600d610ff8bcf1a21e68ff3ab2f2c3a9b7e2ed2f4ba01d804 ;;
        radar_b0.wav) echo cd3116b1da4f5fe9684efb00a500139e9f88ee59153b647296ce0d538624937f ;;
        radar_b1.wav) echo 9243447e85833dcd4fb248914c5ebed17f0412561a0725c4e71ecc8c4c34a5d2 ;;
        radar_b2.wav) echo 68cd0dfa12539f618b598314cb88d973bee781f51959c22c456a68f6a748262a ;;
        radar_b3.wav) echo b6e63010fafcdd0234ca5428cba7ea34e81d01c747ad9ff0e43f8f1885306ff3 ;;
        radar_b4.wav) echo 19429343024f33945456e199eb09d0f55294fe04f9c609684e7250bd1b4babf0 ;;
        radar_b5.wav) echo 3cbb3ab4a889c12aa8b2008cf3a92c1ae0fef2153c66c2b6260fdf4e2b998862 ;;
        radar_b6.wav) echo 0c2f12400e617540842d62badcbba74e7eec70dc74ac51d86659ac77d33645b8 ;;
        seatbelt_quick.wav) echo e5e24636b8ff5127391a6cffe3c138dd17492a4196f699b003ad3ecc7f2b8a6e ;;
        seatbelt_slow.wav) echo 4a3e83a1ce6bc8d7adf5a153cd11b06e135debbbea0c3e245f3f0edd5f096cea ;;
    esac
}
# Stock /etc/sound files (capture-04). menu-v1 to menu-v12 left these files in place. A rollback restores them.
sound_stock() {
    case "$1" in
        breaker.wav) echo c58a07b08e9b2543bfb246d5d02f3eb12c09402f96a91e54b04960513fedacfd ;;
        buzzer.wav) echo 586d779aa7252b1c229710adc110374a5866171cc0fda1fca5dc3965ef16891f ;;
        ding.wav) echo 6f0e96df3a13220d7e444bf09b3dd70f5bd65303310e56877a9e447e85eb2a17 ;;
        direct_quick.wav) echo 720bfda1061cb8f94c30c6a845d9d15e341b7ec6543dbb5c34a8b99521faa0ba ;;
        direct_slow.wav) echo ed044e96936dc9863834017cf21700adb37d7a5482ca7cbb04ff8bf25165b931 ;;
        door.wav) echo 92ae9bef554c151b91ed481fda07940c4f2ce3b8d179c13d6db848221c917417 ;;
        radar_b0.wav) echo fae6502101b588b66d9df32bdb5b81fb36f08c78d3b99880e693cc8503a2a7f2 ;;
        radar_b1.wav) echo 4e463ad791f461cada9a381ff841f43f6b2f3958fbf99f754f828308496c902f ;;
        radar_b2.wav) echo 549feb7bd746b48d07dedd10d1bf1e8114d014f2e08e03bef6fec44c982a7c71 ;;
        radar_b3.wav) echo 189de9a229edd493bf5a8e17d3901afa79839b3f9a0025a3dbbfcc5c3f5dbd57 ;;
        radar_b4.wav) echo e348d9245319d3b130c38bcd26e92ee9cfa638a9241acde03acb8aaca84c8a96 ;;
        radar_b5.wav) echo 84972b29599f73f3a8fa69c8add24d1d903a365a306ca8a14cda69873e259f32 ;;
        radar_b6.wav) echo 6d780369f5636ba52883c8cfc0c1571adbade7e2976cdc5a990cc0d7b314223a ;;
        seatbelt_quick.wav) echo b8e32d08852f0d1276fb8776fadf41d90bfc5dc6e5e2437f6a264f9eafda37ec ;;
        seatbelt_slow.wav) echo 48eb953740c12cc36ddf47e8ac4d2a5f83382877a0b72bdc7e552cc82bde8d9c ;;
    esac
}
# Stock file mode of each sound (capture-04 ROOTFS-INVENTORY): the radar files are 644, the others 777.
# An install and a rollback keep that mode, so a rollback leaves /etc/sound as stock.
sound_mode() {
    case "$1" in
        radar_*) echo 644 ;;
        *) echo 777 ;;
    esac
}
# 0 when word $1 is in list $2.
listed() {
    case " $2 " in *" $1 "*) return 0 ;; esac
    return 1
}

MARKERS="VIKNAV-UI-INSTALL.txt VIKNAV-UI-ROLLBACK.txt VIKNAV-UI-LOG.txt VIKNAV-UI-RECORD.txt"
marker_token() {
    case "$1" in
        VIKNAV-UI-INSTALL.txt) echo VIKNAV_UI_INSTALL ;;
        VIKNAV-UI-ROLLBACK.txt) echo VIKNAV_UI_ROLLBACK_CAPTURE04 ;;
        VIKNAV-UI-LOG.txt) echo VIKNAV_UI_LOG ;;
        VIKNAV-UI-RECORD.txt) echo VIKNAV_UI_RECORD ;;
    esac
}
marker_ok() {
    [ -f "$1/$2" ] && [ ! -L "$1/$2" ] || return 1
    [ "$(head -c 256 "$1/$2" 2>/dev/null)" = "$(marker_token "$2")" ]
}

R=$SYSTEM_ROOT
LAUNCHER=$R/usr/bin/Launcher
LAUNCHER_LOG=$R/tmp/Launcher.log
RECORDER=$R/tmp/viknav-recorder.sh
RECORDER_PID=$R/tmp/viknav-recorder.pid

# Exactly one drive with encrypt.zip and a valid marker, mounted read-write from a USB disk node.
usb_root=
drives=0
for candidate in "$USB_BASE"/*; do
    [ -d "$candidate" ] && [ ! -L "$candidate" ] && [ -f "$candidate/encrypt.zip" ] || continue
    marked=0
    for marker in $MARKERS; do
        marker_ok "$candidate" "$marker" && marked=1
    done
    [ "$marked" -eq 1 ] || continue
    usb_root=$candidate
    drives=$((drives + 1))
done
[ "$drives" -eq 1 ] || exit 1
awk -v target="$usb_root" '$2 == target {n++; if ($1 ~ /^\/dev\/sd[a-z]+[0-9]*$/ && index("," $4 ",", ",rw,")) good++}
    END {exit !(n == 1 && good == 1)}' "$R/proc/mounts" || exit 1
P=$usb_root/viknav-ui

action=
actions=0
for marker in $MARKERS; do
    marker_ok "$usb_root" "$marker" || continue
    actions=$((actions + 1))
    case "$marker" in
        VIKNAV-UI-INSTALL.txt) action=install ;;
        VIKNAV-UI-ROLLBACK.txt) action=rollback ;;
        VIKNAV-UI-LOG.txt) action=log ;;
        VIKNAV-UI-RECORD.txt) action=record ;;
    esac
done

stamp=$(date +%Y%m%d-%H%M%S 2>/dev/null) || stamp=unknown-time
case "$stamp" in ''|*[!0-9-]*) stamp=unknown-time ;; esac
out_base="$usb_root/viknav-ui-$action-$stamp-$$"
out=$out_base
attempt=0
while ! mkdir "$out" 2>/dev/null; do
    # An unset clock and a reused PID must never overwrite an earlier result.
    attempt=$((attempt + 1))
    [ "$attempt" -le 9 ] || exit 1
    out="$out_base-$attempt"
done

# The result detail of a Launcher start or a rollback, for STATUS.txt line 2.
started=
# Set when this run records the hash of an earlier stock settings backup. finish adds the note as the last STATUS.txt line.
hash_note=
log() {
    printf '%s %s\n' "$(date +%H:%M:%S 2>/dev/null)" "$*" >> "$out/install.log"
}
# STATUS.txt line 1 is the result. Line 2, when present, adds detail.
finish() {
    printf '%s\n' "$@" ${hash_note:+"$hash_note"} > "$out/STATUS.txt"
    log "STATUS $*"
    sync
}
# Line 2 and later, when given, add detail.
abort() {
    m=$1
    shift
    finish "ABORTED $m" "$@"
    exit 0
}
hash_of() {
    h=$(sha256sum "$1" 2>/dev/null) || return 1
    printf '%s' "${h%% *}"
}
payload_ok() {
    [ -f "$P/$1" ] && [ ! -L "$P/$1" ] && [ "$(hash_of "$P/$1")" = "$2" ]
}
payload_check() {
    payload_ok "$1" "$2" || abort "payload $1"
}
launcher_running() {
    ps 2>/dev/null | awk '{for (i = 1; i <= NF; i++) if ($i == "Launcher" || $i ~ /\/Launcher$/) found = 1} END {exit !found}'
}
# 0 when no Launcher runs within $1 seconds.
launcher_gone() {
    i=0
    while launcher_running; do
        [ "$i" -lt "$1" ] || return 1
        sleep 1 9>&-
        i=$((i + 1))
    done
}
# Stop every Launcher: TERM and a wait, then KILL and a wait. Returns 1 when a Launcher still runs.
launcher_stop() {
    log "stop Launcher"
    killall Launcher >/dev/null 2>&1
    launcher_gone 10 && return 0
    log "Launcher ignored TERM; send KILL"
    killall -9 Launcher >/dev/null 2>&1
    launcher_gone 5 && return 0
    log "Launcher did not stop"
    return 1
}
# Start as /etc/init.d/S22launcher and the vendor updater do. The new Launcher must not hold the USB drive:
# the working directory is / and all output goes to /dev/null (qtenv.sh writes /tmp/Launcher.log itself).
# The Launcher must not hold the run lock either: fd 9 closes for the child.
# A Launcher never starts without a settings folder: the folder that a stopped restore moved aside goes back first.
# Returns 1 and starts nothing when no settings folder is in place.
launcher_start() {
    log "start Launcher"
    if ! settings_back || [ ! -d "$R/private/Launcher" ]; then
        log "no settings folder; Launcher not started"
        return 1
    fi
    [ ! -f "$LAUNCHER_LOG" ] || cp "$LAUNCHER_LOG" "$out/Launcher-before-$1.log" 2>/dev/null
    # qtenv.sh writes a new log. The old log goes, so old startup lines cannot pass the health check.
    rm -f "$LAUNCHER_LOG"
    fbinit 0 >/dev/null 2>&1
    (cd / && exec "$R/etc/qtenv.sh") >/dev/null 2>&1 </dev/null 9>&- &
}
# The patched VehicleEvent (/etc/vnV.qml) logs its version from Global (/etc/vnG.qml), so the line proves both loaded.
health() {
    i=0
    until grep -q 'VehicleEvent Ver:VehicleEvent@' "$LAUNCHER_LOG" 2>/dev/null && grep -q 'main.qml starting' "$LAUNCHER_LOG" 2>/dev/null; do
        i=$((i + 1))
        [ "$i" -le "$HEALTH_WAIT" ] || { reason="startup markers missing"; return 1; }
        sleep 1 9>&-
    done
    sleep "$SETTLE_WAIT" 9>&-
    launcher_running || { reason="Launcher stopped"; return 1; }
    if grep -q '/etc/vn' "$LAUNCHER_LOG" 2>/dev/null; then
        reason="new QML error"
        return 1
    fi
    return 0
}
# Copy $1 to a hidden file next to $2 and check the hash. Rename later puts the file in place in one step.
stage() {
    tmp=${2%/*}/.${2##*/}.new
    rm -f "$tmp"
    if cp "$1" "$tmp" 2>>"$out/install.log" && chmod "$4" "$tmp" && [ "$(hash_of "$tmp")" = "$3" ]; then
        return 0
    fi
    rm -f "$tmp"
    return 1
}
remove_staged() {
    for f in $ETC_FILES; do
        rm -f "$R/etc/.$f.new"
    done
    for f in $SOUND_FILES; do
        rm -f "$R/etc/sound/.$f.new"
    done
    rm -f "$R/usr/bin/.Launcher.new"
}
# Stops the script when an owned /etc file is not a known release file. Sets etc_present to the count of
# current files, etc_total to the count of current owned files, and etc_old to the count of earlier-release files.
check_etc() {
    etc_present=0
    etc_total=0
    etc_old=0
    for f in $ETC_FILES $RETIRED_FILES; do
        listed "$f" "$ETC_FILES" && etc_total=$((etc_total + 1))
        target=$R/etc/$f
        [ -e "$target" ] || [ -L "$target" ] || continue
        [ -f "$target" ] && [ ! -L "$target" ] || abort "unknown /etc/$f"
        h=$(hash_of "$target")
        if listed "$f" "$ETC_FILES" && [ "$h" = "$(etc_sha256 "$f")" ]; then
            etc_present=$((etc_present + 1))
        elif listed "$h" "$(etc_previous "$f")"; then
            etc_old=$((etc_old + 1))
        else
            abort "unknown /etc/$f"
        fi
    done
}
# Stops the script when an /etc/sound file is missing, a link, or not a stock or set A file.
# Sets sound_new to the count of set A files and sound_total to the count of sound files.
check_sound() {
    sound_new=0
    sound_total=0
    for f in $SOUND_FILES; do
        sound_total=$((sound_total + 1))
        target=$R/etc/sound/$f
        [ -f "$target" ] && [ ! -L "$target" ] || abort "unknown /etc/sound/$f"
        h=$(hash_of "$target")
        if [ "$h" = "$(sound_sha256 "$f")" ]; then
            sound_new=$((sound_new + 1))
        elif [ "$h" != "$(sound_stock "$f")" ]; then
            abort "unknown /etc/sound/$f"
        fi
    done
}
check_launcher() {
    launcher=$(hash_of "$LAUNCHER")
    [ "$launcher" = "$ORIGINAL_SHA256" ] || [ "$launcher" = "$CANDIDATE_SHA256" ] || listed "$launcher" "$PREVIOUS_LAUNCHERS" ||
        abort "unknown Launcher"
}
SETTINGS_NEW=$R/private/.Launcher.restore
SETTINGS_OLD=$R/private/.Launcher.old
# A cut or a failed step between the two settings renames leaves no /private/Launcher. Put the old folder back in place.
settings_back() {
    [ -e "$R/private/Launcher" ] || [ ! -d "$SETTINGS_OLD" ] || mv "$SETTINGS_OLD" "$R/private/Launcher"
}
# Restore /private/Launcher from a tar of the folder. The steps are safe to run again from any state that a power cut leaves.
# A cut between the two moves leaves no /private/Launcher: the old folder goes back first, so no step removes the only copy.
restore_settings() {
    settings_back || return 1
    rm -rf "$SETTINGS_NEW" "$SETTINGS_OLD" || return 1
    if ! mkdir "$SETTINGS_NEW" || ! tar -xf "$1" -C "$SETTINGS_NEW" 2>/dev/null || [ ! -d "$SETTINGS_NEW/Launcher" ]; then
        rm -rf "$SETTINGS_NEW"
        return 1
    fi
    # The extracted data must be on disk before any rename.
    sync
    if [ -e "$R/private/Launcher" ]; then
        mv "$R/private/Launcher" "$SETTINGS_OLD" || { rm -rf "$SETTINGS_NEW"; return 1; }
    fi
    if ! mv "$SETTINGS_NEW/Launcher" "$R/private/Launcher"; then
        [ ! -e "$SETTINGS_OLD" ] || mv "$SETTINGS_OLD" "$R/private/Launcher"
        rm -rf "$SETTINGS_NEW"
        return 1
    fi
    rm -rf "$SETTINGS_NEW" "$SETTINGS_OLD"
    log "settings restored from $1"
}
# No settings backup: keep the current settings. A cut restore can leave the current folder moved aside.
keep_settings() {
    settings_back || return 1
    [ -d "$R/private/Launcher" ] || return 1
    rm -rf "$SETTINGS_NEW" "$SETTINGS_OLD"
}
# 0 when tar $1 is complete: every member reads to the end. A listing alone passes a tar that ends inside file data.
tar_ok() {
    tar -xOf "$1" >/dev/null 2>&1
}
BACKUP_HELP="Copy private-Launcher.tar from the first install folder to viknav-ui/settings-before-install.tar."
# Tar has no data checksum, so the stock settings backup has a recorded hash: on the drive, and inside the cluster for a
# replacement drive.
DRIVE_SUM=$P/settings-before-install.sha256
STOCK_SUM=$R/etc/.viknav-stock-settings.sha256
# Write hash $1 of the stock settings backup to both hash files: temp file, sync, rename, sync.
stock_sum_write() {
    for f in "$DRIVE_SUM" "$STOCK_SUM"; do
        rm -f "$f.new" 2>/dev/null
        if ! printf '%s  settings-before-install.tar\n' "$1" > "$f.new" || ! sync || ! mv -f "$f.new" "$f"; then
            rm -f "$f.new" 2>/dev/null
            log "settings backup hash write failed: $f"
            return 1
        fi
    done
    sync
}
# 0 when settings tar $1 has the members of a /private/Launcher backup: entries only under Launcher/, no parent folder step,
# and at least one regular file with content. Every member must read to the end.
stock_members_ok() {
    tar_ok "$1" || return 1
    tar -tf "$1" 2>/dev/null | awk '$0 !~ /^Launcher(\/|$)/ || $0 ~ /(^|\/)\.\.(\/|$)/ {bad = 1} END {exit bad || NR == 0}' || return 1
    # The cluster BusyBox tar has -t, -x, and -O. File content in the archive proves at least one regular file.
    size=$(tar -xOf "$1" 2>/dev/null | wc -c)
    case "$size" in *[1-9]*) return 0 ;; esac
    return 1
}
# Sets backup_state for the stock settings backup on the drive: none, ok, or bad. ok needs the recorded hash: the cluster
# hash first, then the drive hash. A backup from before the hash files must match the run backup of an install folder on
# the drive: the first install over the original wrote the stock backup from that run backup. Only a drive without any
# install folder backup falls back to the members of a settings backup. The run then records the hash of that backup.
# Sets backup_sum to the backup hash. Returns 1 when the record fails.
stock_backup_check() {
    backup_state=none
    backup_sum=
    [ -e "$P/settings-before-install.tar" ] || [ -L "$P/settings-before-install.tar" ] || return 0
    backup_state=bad
    [ -f "$P/settings-before-install.tar" ] && [ ! -L "$P/settings-before-install.tar" ] || return 0
    backup_sum=$(hash_of "$P/settings-before-install.tar")
    want=$(awk 'NR == 1 {print $1}' "$STOCK_SUM" 2>/dev/null)
    [ -n "$want" ] || want=$(awk 'NR == 1 {print $1}' "$DRIVE_SUM" 2>/dev/null)
    if [ -n "$want" ]; then
        [ "$backup_sum" != "$want" ] || backup_state=ok
        return 0
    fi
    runs=0
    matched=0
    for f in "$usb_root"/viknav-ui-install-*/private-Launcher.tar; do
        [ -f "$f" ] && [ ! -L "$f" ] || continue
        runs=1
        [ "$(hash_of "$f")" != "$backup_sum" ] || matched=1
    done
    if [ "$runs" -eq 1 ] && [ "$matched" -eq 0 ]; then
        log "settings-before-install.tar matches no install folder backup"
        return 0
    fi
    stock_members_ok "$P/settings-before-install.tar" || return 0
    stock_sum_write "$backup_sum" || return 1
    hash_note="settings backup hash recorded now"
    log "$hash_note"
    backup_state=ok
}
# Write the stock settings backup on the drive from the settings backup of this run: temp file, full read, hash check,
# sync, rename, sync, then the hash files. A power cut leaves no file, the old file, or the complete new file, never a torn
# file. A cut before the new hash files leaves a hash mismatch, and the next install over the original writes the file again.
stock_backup_write() {
    backup_tmp=$P/.settings-before-install.tar.new
    rm -f "$backup_tmp" 2>/dev/null
    if cp "$out/private-Launcher.tar" "$backup_tmp" 2>>"$out/install.log" && tar_ok "$backup_tmp" &&
        [ "$(hash_of "$backup_tmp")" = "$(hash_of "$out/private-Launcher.tar")" ] && sync &&
        mv -f "$backup_tmp" "$P/settings-before-install.tar" && sync && stock_sum_write "$(hash_of "$out/private-Launcher.tar")"; then
        return 0
    fi
    rm -f "$backup_tmp" 2>/dev/null
    return 1
}

# The rollback journal and the settings copy live on the root filesystem, next to the files that a rollback changes.
# A rollback restores the settings from the copy, so a replaced or changed drive cannot change the restored settings.
SETTINGS_COPY_NAME=/etc/.viknav-settings.tar
SETTINGS_COPY=$R$SETTINGS_COPY_NAME
# Copy settings tar $1 with the checked hash $2 to the settings copy: temp file, hash check, sync, rename, sync.
settings_copy() {
    rm -f "$SETTINGS_COPY.new" 2>/dev/null
    if [ -n "$2" ] && cp "$1" "$SETTINGS_COPY.new" 2>>"$out/install.log" && [ "$(hash_of "$SETTINGS_COPY.new")" = "$2" ] &&
        sync && mv -f "$SETTINGS_COPY.new" "$SETTINGS_COPY" && sync; then
        return 0
    fi
    rm -f "$SETTINGS_COPY.new" 2>/dev/null
    log "settings copy failed"
    return 1
}
# The journal records a rollback target: the original Launcher, the stock sounds, no /etc vn files, and the settings.
# Line 1: the settings copy name, or none (keep the current settings). Line 2: the copy hash.
# Line 3: the phase. files: the files and the settings still need the restore. start: the files and the settings are stock,
# and only the start check is open. Line 4: the release to block (a failed install), or none.
# An install and a requested rollback put the journal in place before the first live change. The journal goes away only
# after the start check passes, so a power cut or a failed step makes the next drive insert finish the rollback.
JOURNAL=$R/etc/.viknav-rollback
# $1: the settings copy name or none. $2: the phase. $3: the release to block, or empty.
journal_write() {
    sum=
    if [ "$1" != none ]; then
        sum=$(hash_of "$R$1") || { log "rollback journal write failed: no settings copy"; return 1; }
    fi
    rm -f "$JOURNAL.new" 2>/dev/null
    printf '%s\n%s\n%s\n%s\n' "$1" "$sum" "$2" "${3:-none}" > "$JOURNAL.new" && sync && mv -f "$JOURNAL.new" "$JOURNAL" && sync &&
        return 0
    rm -f "$JOURNAL.new" 2>/dev/null
    log "rollback journal write failed"
    return 1
}
# The journal removal is the commit point. A power cut after the removal leaves only the settings copy, a leftover.
journal_clear() {
    rm -f "$JOURNAL" || return 1
    sync
    rm -f "$JOURNAL.new" "$SETTINGS_COPY" "$SETTINGS_COPY.new" 2>/dev/null
    sync
}
# Sets journal_name (line 1), journal_phase (line 3), journal_block (line 4, empty for none), and journal_settings: the
# settings copy path, none, or bad (the copy is missing or does not have the journaled hash).
journal_read() {
    journal_name=$(awk 'NR == 1' "$JOURNAL" 2>/dev/null)
    sum=$(awk 'NR == 2' "$JOURNAL" 2>/dev/null)
    journal_phase=$(awk 'NR == 3' "$JOURNAL" 2>/dev/null)
    journal_block=$(awk 'NR == 4 && $0 != "none"' "$JOURNAL" 2>/dev/null)
    journal_settings=bad
    case "$journal_name" in
        none) journal_settings=none ;;
        "$SETTINGS_COPY_NAME") [ -n "$sum" ] && [ "$(hash_of "$SETTINGS_COPY")" = "$sum" ] && journal_settings=$SETTINGS_COPY ;;
    esac
}
# The cluster block stops a new install of a release that failed the install on this cluster. INSTALL-BLOCKED.txt on the drive
# can be missing, removed, or not written (a read-only drive), so the block also lives on the cluster. Line 1 names the release.
# A different release installs. A rollback insert that ends with the stock files removes the block and INSTALL-BLOCKED.txt.
BLOCK=$R/etc/.viknav-blocked
BLOCK_HELP="After the cause is fixed, insert a rollback drive: the rollback clears the block on the cluster and INSTALL-BLOCKED.txt on that drive. Removing INSTALL-BLOCKED.txt alone leaves the block on the cluster."
# The release identity: the hash of the pinned Launcher, /etc, and sound hashes, one per line.
payload_id() {
    h=$({
        echo "$CANDIDATE_SHA256"
        for f in $ETC_FILES; do etc_sha256 "$f"; done
        for f in $SOUND_FILES; do sound_sha256 "$f"; done
    } | sha256sum)
    printf '%s' "${h%% *}"
}
# 0 when the cluster block names release $1.
block_names() {
    [ -n "$1" ] && [ "$(awk 'NR == 1' "$BLOCK" 2>/dev/null)" = "$1" ]
}
# Put the block of release $1 in place: temp file, sync, rename, sync.
block_write() {
    block_names "$1" && return 0
    rm -f "$BLOCK.new" 2>/dev/null
    printf '%s\n' "$1" > "$BLOCK.new" && sync && mv -f "$BLOCK.new" "$BLOCK" && sync && return 0
    rm -f "$BLOCK.new" 2>/dev/null
    log "install block write failed"
    return 1
}
# A rollback insert ended with the stock files: remove the cluster block and INSTALL-BLOCKED.txt on this drive. Adds a failed
# removal to started.
block_clear() {
    rm -f "$BLOCK" "$BLOCK.new" "$usb_root/INSTALL-BLOCKED.txt" 2>/dev/null
    sync
    [ -e "$BLOCK" ] || [ -e "$usb_root/INSTALL-BLOCKED.txt" ] || return 0
    log "install block not removed"
    started="${started:+$started; }install block not removed"
}
# Remove what a stopped run left: stage files, temp hash and block files, and an unpublished journal. Every journal goes in place before the first live
# change, so a journal that never got the final name means that nothing live changed. Without a journal, the settings copy
# and a temp stock backup on the drive are leftovers too.
clean_leftovers() {
    remove_staged
    rm -f "$JOURNAL.new" "$BLOCK.new" "$P/.settings-before-install.tar.new" "$DRIVE_SUM.new" "$STOCK_SUM.new" 2>/dev/null
    [ -e "$JOURNAL" ] || rm -f "$SETTINGS_COPY" "$SETTINGS_COPY.new" 2>/dev/null
}
# When no Launcher runs, start the Launcher on disk and check the start. Adds the result to started.
launcher_keep() {
    launcher_running && return 0
    if ! launcher_start current; then
        kept="current Launcher not started: no settings folder"
    elif health; then
        kept="current Launcher started"
    else
        kept="current Launcher start check failed: $reason"
    fi
    started=${started:+$started; }$kept
}
# Nothing live changed: $1 names the failed step. Clear the journal when $2 is clear, keep the journal otherwise,
# and keep a Launcher running. Sets started.
rollback_unchanged() {
    remove_staged
    started="$1; nothing changed"
    if [ "$2" = clear ]; then
        journal_clear
    else
        started="$started; the next drive insert finishes the rollback"
    fi
    launcher_keep
    log "$started"
}
# 0 when the live files are the stock files: the original Launcher, the stock sounds, and no /etc vn files.
files_stock() {
    [ "$(hash_of "$LAUNCHER")" = "$ORIGINAL_SHA256" ] || return 1
    for f in $SOUND_FILES; do
        [ "$(hash_of "$R/etc/sound/$f")" = "$(sound_stock "$f")" ] || return 1
    done
    for f in $ETC_FILES $RETIRED_FILES; do
        [ ! -e "$R/etc/$f" ] || return 1
    done
}

# Put back the original Launcher and the stock sounds, remove the /etc vn files, restore the settings that the journal names,
# then start the Launcher and check the start. The journal must be in place.
# Every stock file stages first, while the dashboard still runs, so a failed copy or a Launcher that does not stop changes
# nothing. Then the journal goes when $1 is clear (a requested rollback; the cluster is still a known release) and stays otherwise.
# After the stop, each step runs where safe and a Launcher always starts again. The journal goes only after the start
# check passes and the block that the journal names is in place. A journal in the start phase over stock files needs only the start.
# Sets started to the result detail. Returns 1 when a step or the start check fails.
restore_original() {
    journal_read
    failed=
    note=
    settings_note=
    if [ "$journal_phase" = start ] && files_stock; then
        note="files already stock; "
        launcher_stop || { rollback_unchanged "Launcher did not stop" "$1"; return 1; }
    else
        remove_staged
        copied=1
        stage "$P/original/Launcher" "$LAUNCHER" "$ORIGINAL_SHA256" 777 || copied=0
        for f in $SOUND_FILES; do
            [ "$copied" -eq 1 ] || break
            stage "$P/original/sound/$f" "$R/etc/sound/$f" "$(sound_stock "$f")" "$(sound_mode "$f")" || copied=0
        done
        [ "$copied" -eq 1 ] || { rollback_unchanged "stock file copy failed" "$1"; return 1; }
        # The root filesystem mounts with noauto_da_alloc, so a rename does not flush the data first. Write the staged data now.
        sync
        launcher_stop || { rollback_unchanged "Launcher did not stop" "$1"; return 1; }
        moved=1
        mv -f "$R/usr/bin/.Launcher.new" "$LAUNCHER" || { failed="move Launcher"; moved=0; }
        for f in $SOUND_FILES; do
            mv -f "$R/etc/sound/.$f.new" "$R/etc/sound/$f" || failed=${failed:-move /etc/sound/$f}
        done
        # The original Launcher ignores the /etc files. Without the original Launcher, the /etc files and settings stay.
        if [ "$moved" -eq 1 ]; then
            for f in $ETC_FILES $RETIRED_FILES; do
                rm -f "$R/etc/$f" || failed=${failed:-remove /etc/$f}
            done
            case "$journal_settings" in
                bad) failed=${failed:-settings copy check} ;;
                none)
                    log "no settings backup; current settings kept"
                    settings_note="; no settings backup, current settings kept"
                    keep_settings || failed=${failed:-keep settings} ;;
                *) restore_settings "$journal_settings" || failed=${failed:-restore settings} ;;
            esac
        fi
        remove_staged
        sync
        files_stock || failed=${failed:-verify stock files}
        # The files and the settings are stock now. Only the start check stays open for a later drive insert.
        [ -n "$failed" ] || journal_write "$journal_name" start "$journal_block" || failed="rollback journal update"
    fi
    which=original
    [ "$(hash_of "$LAUNCHER")" = "$ORIGINAL_SHA256" ] || which=current
    healthy=0
    if ! launcher_start "$which"; then
        started="$which Launcher not started: no settings folder"
    elif health; then
        started="$which Launcher started"
        healthy=1
    else
        started="$which Launcher start check failed: $reason"
    fi
    cp "$LAUNCHER_LOG" "$out/Launcher-$which.log" 2>/dev/null
    started="$note$started$settings_note"
    [ -z "$failed" ] || started="$failed failed; $started"
    if [ -z "$failed" ] && [ "$healthy" -eq 1 ]; then
        # The block of a failed install goes in place before the journal removal. A failed block write keeps the journal,
        # so the next drive insert finishes the rollback and writes the block.
        if [ -n "$journal_block" ] && ! block_write "$journal_block"; then
            failed="install block write"
        elif ! journal_clear; then
            failed="clear the rollback journal"
        fi
        [ -z "$failed" ] || started="$failed failed; $started"
    fi
    log "$started"
    [ -z "$failed" ] && [ "$healthy" -eq 1 ]
}
# A journal on the cluster: finish that rollback before anything else, whatever the live files hold, then stop.
# A rollback insert then removes the block. An install insert keeps the block of the failed install.
resume_rollback() {
    [ -e "$JOURNAL" ] || return 0
    log "rollback journal found"
    for f in $SOUND_FILES; do
        payload_ok "original/sound/$f" "$(sound_stock "$f")" || abort "rollback journal: payload missing"
    done
    payload_ok original/Launcher "$ORIGINAL_SHA256" || abort "rollback journal: payload missing"
    if restore_original keep; then
        [ "$action" != rollback ] || block_clear
        finish "ROLLED_BACK resumed" "$started"
    else
        finish "ROLLBACK_FAILED resumed" "$started"
    fi
    exit 0
}
# Failure before the journal: nothing live changed. Start the Launcher on disk again.
fail_restart() {
    log "failed: $1"
    remove_staged
    rm -f "$SETTINGS_COPY" "$SETTINGS_COPY.new" 2>/dev/null
    launcher_start original || abort "$1" "Launcher not started: no settings folder"
    abort "$1"
}
# Failure after the journal: block a repeat install of this release, then restore the original. The journal names the release,
# so the cluster block goes in place before the journal removal, also when a later drive insert finishes the rollback.
# Without that journal line, the block goes in place now. INSTALL-BLOCKED.txt also blocks a repeat install from this drive.
rollback_now() {
    log "rollback: $1"
    cp "$LAUNCHER_LOG" "$out/Launcher-failed.log" 2>/dev/null
    release=$(payload_id)
    journal_write "$SETTINGS_COPY_NAME" files "$release" || block_write "$release"
    printf '%s\n' "$1" > "$usb_root/INSTALL-BLOCKED.txt" || log "INSTALL-BLOCKED.txt write failed"
    if restore_original keep; then
        finish "ROLLED_BACK $1" "$started"
    else
        finish "ROLLBACK_FAILED $1" "$started"
    fi
    exit 0
}

# The install is one transaction. Every check, the settings backups, the stage files, and the journal come before the
# first live change. From the first rename to a passed start check, the journal makes the next drive insert of any kind
# finish a rollback to the original.
# One run at a time reads or changes the cluster state. Two updater runs can start at once: the boot scan (mdev -s in
# /etc/init.d/rcS) and the hotplug event, and /etc/mdev/udisk_insert starts each updater in the background.
# The lock is a kernel lock (flock) on fd 9 of /tmp/viknav-ui.lock. A child that has fd 9 open holds the lock too, so the
# kernel drops the lock when the run and the short children of the run end or die. No stale lock exists. The waits (sleep)
# and the long-lived children (the Launcher, the recorder) start with fd 9 closed.
LOCK=$R/tmp/viknav-ui.lock
# Returns 0 with the lock held, 1 when another run holds the lock, and 2 when the lock file does not open.
lock_take() {
    # A failed exec redirection stops the shell. Create and check the lock file first, so the open of fd 9 cannot fail.
    [ -f "$LOCK" ] || printf '' >> "$LOCK" 2>/dev/null || return 2
    [ -f "$LOCK" ] && [ ! -L "$LOCK" ] && [ -w "$LOCK" ] || return 2
    exec 9>>"$LOCK"
    flock -n 9
    case "$?" in
        0) return 0 ;;
        1) return 1 ;;
    esac
    return 2
}

do_install() {
    clean_leftovers
    resume_rollback
    blocked=
    if block_names "$(payload_id)"; then
        blocked=$BLOCK_HELP
    elif [ -e "$usb_root/INSTALL-BLOCKED.txt" ]; then
        blocked="Remove INSTALL-BLOCKED.txt only after the cause is fixed."
    fi
    if [ -n "$blocked" ]; then
        launcher_keep
        finish BLOCKED ${started:+"$started"} "$blocked"
        exit 0
    fi
    payload_check original/Launcher "$ORIGINAL_SHA256"
    payload_check Launcher "$CANDIDATE_SHA256"
    for f in $ETC_FILES; do
        payload_check "etc/$f" "$(etc_sha256 "$f")"
    done
    for f in $SOUND_FILES; do
        payload_check "sound/$f" "$(sound_sha256 "$f")"
        payload_check "original/sound/$f" "$(sound_stock "$f")"
    done
    check_launcher
    check_etc
    check_sound
    if [ "$launcher" = "$CANDIDATE_SHA256" ] && [ "$etc_present" -eq "$etc_total" ] && [ "$etc_old" -eq 0 ] &&
        [ "$sound_new" -eq "$sound_total" ]; then
        launcher_keep
        finish ALREADY_INSTALLED ${started:+"$started"}
        exit 0
    fi
    # Only an install over the original Launcher writes the stock settings backup; an upgrade keeps the first one.
    # A damaged stock backup is replaced over the original Launcher and stops an upgrade: the stock settings are gone.
    stock_backup_check || abort "settings backup hash"
    backup_new=0
    case "$backup_state" in
        none) [ "$launcher" != "$ORIGINAL_SHA256" ] || backup_new=1 ;;
        bad)
            [ "$launcher" = "$ORIGINAL_SHA256" ] || abort "settings-before-install.tar damaged" "$BACKUP_HELP"
            log "settings-before-install.tar damaged; replaced from this run"
            backup_new=1 ;;
    esac
    # Staged files go to /usr/bin, /etc, and /etc/sound. Each folder must have room for all staged files,
    # so the check also holds when the folders sit on separate filesystems.
    for d in "$R/usr/bin" "$R/etc" "$R/etc/sound"; do
        free=$(df -k "$d" 2>/dev/null | awk 'END {print $(NF - 2)}')
        case "$free" in ''|*[!0-9]*) abort "low space" ;; esac
        [ "$free" -ge "$MIN_FREE_KB" ] || abort "low space"
    done

    launcher_stop || abort "Launcher did not stop"
    # The settings database is closed now. The backup of this run is the rollback target of this install.
    if ! tar -cf "$out/private-Launcher.tar" -C "$R/private" Launcher 2>>"$out/install.log" || ! tar_ok "$out/private-Launcher.tar"; then
        fail_restart "settings backup"
    fi
    [ "$backup_new" -eq 0 ] || stock_backup_write || fail_restart "settings backup"
    for f in $ETC_FILES; do
        stage "$P/etc/$f" "$R/etc/$f" "$(etc_sha256 "$f")" 644 || fail_restart "copy /etc/$f"
    done
    for f in $SOUND_FILES; do
        stage "$P/sound/$f" "$R/etc/sound/$f" "$(sound_sha256 "$f")" "$(sound_mode "$f")" || fail_restart "copy /etc/sound/$f"
    done
    stage "$P/Launcher" "$LAUNCHER" "$CANDIDATE_SHA256" 777 || fail_restart "copy Launcher"
    # The root filesystem mounts with noauto_da_alloc, so a rename does not flush the data first. Write the staged data now.
    sync
    settings_copy "$out/private-Launcher.tar" "$(hash_of "$out/private-Launcher.tar")" || fail_restart "settings copy"

    # The original Launcher ignores the /etc files and plays any sound file, so the /etc files and the sounds go first.
    # The Launcher goes last. The journal goes in place before the first rename.
    journal_write "$SETTINGS_COPY_NAME" files || fail_restart "rollback journal"
    for f in $ETC_FILES; do
        mv -f "$R/etc/.$f.new" "$R/etc/$f" || rollback_now "move /etc/$f"
    done
    for f in $SOUND_FILES; do
        mv -f "$R/etc/sound/.$f.new" "$R/etc/sound/$f" || rollback_now "move /etc/sound/$f"
    done
    for f in $RETIRED_FILES; do
        rm -f "$R/etc/$f" || rollback_now "remove /etc/$f"
    done
    mv -f "$R/usr/bin/.Launcher.new" "$LAUNCHER" || rollback_now "move Launcher"
    sync
    [ "$(hash_of "$LAUNCHER")" = "$CANDIDATE_SHA256" ] || rollback_now "verify Launcher"
    for f in $ETC_FILES; do
        [ "$(hash_of "$R/etc/$f")" = "$(etc_sha256 "$f")" ] || rollback_now "verify /etc/$f"
    done
    for f in $SOUND_FILES; do
        [ "$(hash_of "$R/etc/sound/$f")" = "$(sound_sha256 "$f")" ] || rollback_now "verify /etc/sound/$f"
    done
    for f in $RETIRED_FILES; do
        [ ! -e "$R/etc/$f" ] || rollback_now "verify /etc/$f removed"
    done
    log "files installed"

    launcher_start candidate || rollback_now "no settings folder"
    health || rollback_now "$reason"
    cp "$LAUNCHER_LOG" "$out/Launcher-start.log" 2>/dev/null
    # The start check passed: the journal removal commits the install.
    journal_clear || rollback_now "clear the rollback journal"
    finish INSTALLED "Keep the drive in for 3 more minutes for Launcher-later.log."
    sleep "$LOG_WAIT" 9>&-
    cp "$LAUNCHER_LOG" "$out/Launcher-later.log" 2>/dev/null
    log "later log copied"
    sync
}

# A requested rollback that stops before the journal: nothing changed. $1 names the failed step.
rollback_not_started() {
    rm -f "$SETTINGS_COPY" "$SETTINGS_COPY.new" 2>/dev/null
    started="$1 failed; rollback not started"
    launcher_keep
    finish ROLLBACK_FAILED "$started"
    exit 0
}

do_rollback() {
    clean_leftovers
    resume_rollback
    payload_check original/Launcher "$ORIGINAL_SHA256"
    for f in $SOUND_FILES; do
        payload_check "original/sound/$f" "$(sound_stock "$f")"
    done
    check_launcher
    check_etc
    check_sound
    if [ "$launcher" = "$ORIGINAL_SHA256" ] && [ "$etc_present" -eq 0 ] && [ "$etc_old" -eq 0 ] && [ "$sound_new" -eq 0 ]; then
        launcher_keep
        block_clear
        finish ALREADY_ORIGINAL ${started:+"$started"}
        exit 0
    fi
    # Without the stock backup, the rollback keeps the current settings. A damaged stock backup stops the rollback.
    stock_backup_check || abort "settings backup hash"
    settings=none
    case "$backup_state" in
        bad) abort "settings-before-install.tar damaged" "$BACKUP_HELP" ;;
        ok)
            settings_copy "$P/settings-before-install.tar" "$backup_sum" || rollback_not_started "settings copy"
            settings=$SETTINGS_COPY_NAME ;;
    esac
    journal_write "$settings" files || rollback_not_started "rollback journal write"
    if restore_original clear; then
        block_clear
        finish "ROLLED_BACK by request" "$started"
    else
        finish ROLLBACK_FAILED "$started"
    fi
}

do_log() {
    cp "$LAUNCHER_LOG" "$out/Launcher.log" 2>/dev/null
    [ ! -f "$R/var/log/Launcher.log" ] || cp "$R/var/log/Launcher.log" "$out/var-Launcher.log" 2>/dev/null
    # A command substitution keeps a failed write from stopping the script; the printf below reports the failure.
    report=$({
        sha256sum "$LAUNCHER"
        for f in $ETC_FILES $RETIRED_FILES; do
            [ ! -e "$R/etc/$f" ] || sha256sum "$R/etc/$f"
        done
        for f in $SOUND_FILES; do
            sha256sum "$R/etc/sound/$f"
        done
        date
        cat "$R/proc/uptime"
        # The install health check decides on these two results.
        if launcher_running; then echo "Launcher check: running"; else echo "Launcher check: not running"; fi
        if [ -e "$JOURNAL" ]; then
            echo "rollback journal: present"
            cat "$JOURNAL"
        else
            echo "rollback journal: none"
        fi
        if [ -e "$BLOCK" ]; then
            echo "install block: $(awk 'NR == 1' "$BLOCK")"
        else
            echo "install block: none"
        fi
        df -k "$R/usr/bin"
        ps
    } 2>&1)
    printf '%s
' "$report" > "$out/installed-sha256.txt" || abort "log write"
    finish LOGGED
}

# Start a background copy of the Launcher log to the drive. The copy ends when the drive is unmounted or the power goes.
# The vendor updater removes /mnt/temp/encrypt after this script, so the recorder runs from /tmp.
# The recorder opens the drive only for each append, so the drive stays free to unmount.
do_record() {
    if [ -f "$RECORDER_PID" ] && kill -0 "$(cat "$RECORDER_PID" 2>/dev/null)" 2>/dev/null; then
        finish ALREADY_RECORDING
        exit 0
    fi
    cat > "$RECORDER" <<'RECORDER_END' || abort "recorder copy"
#!/bin/sh
# Copy new Launcher log bytes to $3/launcher.log every 2 s while drive $2 stays mounted. $1 is the system root.
# chunks.txt records the uptime and the log byte offset of each copy, to line up the frame print in time.
R=$1
usb=$2
out=$3
log=$R/tmp/Launcher.log
off=0
n=0
while [ -d "$out" ] && awk -v t="$usb" '$2 == t {f = 1} END {exit !f}' "$R/proc/mounts"; do
    size=$(wc -c < "$log" 2>/dev/null)
    case "$size" in ''|*[!0-9\ ]*) size=0 ;; esac
    size=$((size))
    # A Launcher restart starts a new log.
    [ "$size" -ge "$off" ] || off=0
    if [ "$size" -gt "$off" ]; then
        tail -c +$((off + 1)) "$log" | head -c $((size - off)) >> "$out/launcher.log" || break
        printf '%s %s %s\n' "$(cut -d' ' -f1 "$R/proc/uptime" 2>/dev/null)" "$off" "$size" >> "$out/chunks.txt" || break
        off=$size
    fi
    n=$((n + 1))
    [ $((n % 5)) -ne 0 ] || sync
    sleep 2
done
rm -f "$R/tmp/viknav-recorder.pid"
RECORDER_END
    (cd / && exec sh "$RECORDER" "$R" "$usb_root" "$out") </dev/null >/dev/null 2>&1 9>&- &
    echo "$!" > "$RECORDER_PID"
    finish RECORDING "Turn on Factory > Debug logging for values and UART frames. Each power-up with the drive in starts a new folder."
}

[ "$actions" -eq 1 ] || abort "more than one action marker"
log "action $action from $usb_root"
# The record action reads no cluster state and needs no lock.
case "$action" in
    install|rollback|log)
        lock_take
        case "$?" in
            1) finish "BUSY another viknav-ui run is active"; exit 0 ;;
            2) abort lock "Restart the cluster to clear /tmp, then insert the drive again." ;;
        esac ;;
esac
case "$action" in
    install) do_install ;;
    rollback) do_rollback ;;
    log) do_log ;;
    record) do_record ;;
esac
exit 0
}
