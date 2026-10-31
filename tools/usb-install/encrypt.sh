#!/bin/sh
# F150 cluster UI update from a USB drive: install, rollback, log collection, or recording.
# The vendor USB updater (/etc/mdev/update.sh) unpacks encrypt.zip to /mnt/temp/encrypt and runs this file as root.
# One marker file next to encrypt.zip selects the action. The payload folder viknav-ui/ sits next to encrypt.zip.
# The hashes below pin every payload file. tools/build_usb_install.py builds the drive contents.
# tests/usb-install-replay.py replays this file against a fake cluster root.
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
log() {
    printf '%s %s\n' "$(date +%H:%M:%S 2>/dev/null)" "$*" >> "$out/install.log"
}
# STATUS.txt line 1 is the result. Line 2, when present, adds detail.
finish() {
    printf '%s\n' "$@" > "$out/STATUS.txt"
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
launcher_stop() {
    log "stop Launcher"
    killall Launcher >/dev/null 2>&1
    i=0
    while launcher_running && [ "$i" -lt 10 ]; do
        sleep 1
        i=$((i + 1))
    done
}
# Start as /etc/init.d/S22launcher and the vendor updater do. The new Launcher must not hold the USB drive:
# the working directory is / and all output goes to /dev/null (qtenv.sh writes /tmp/Launcher.log itself).
launcher_start() {
    log "start Launcher"
    [ ! -f "$LAUNCHER_LOG" ] || cp "$LAUNCHER_LOG" "$out/Launcher-before-$1.log" 2>/dev/null
    # qtenv.sh writes a new log. The old log goes, so old startup lines cannot pass the health check.
    rm -f "$LAUNCHER_LOG"
    fbinit 0 >/dev/null 2>&1
    (cd / && exec "$R/etc/qtenv.sh") >/dev/null 2>&1 </dev/null &
}
# The patched VehicleEvent (/etc/vnV.qml) logs its version from Global (/etc/vnG.qml), so the line proves both loaded.
health() {
    i=0
    until grep -q 'VehicleEvent Ver:VehicleEvent@' "$LAUNCHER_LOG" 2>/dev/null && grep -q 'main.qml starting' "$LAUNCHER_LOG" 2>/dev/null; do
        i=$((i + 1))
        [ "$i" -le "$HEALTH_WAIT" ] || { reason="startup markers missing"; return 1; }
        sleep 1
    done
    sleep "$SETTLE_WAIT"
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
# Restore /private/Launcher from a tar of the folder. The steps are safe to run again from any state that a power cut leaves.
# A cut between the two moves leaves no /private/Launcher: the old folder goes back first, so no step removes the only copy.
restore_settings() {
    if [ ! -e "$R/private/Launcher" ] && [ -d "$SETTINGS_OLD" ]; then
        mv "$SETTINGS_OLD" "$R/private/Launcher" || return 1
    fi
    rm -rf "$SETTINGS_NEW" "$SETTINGS_OLD" || return 1
    if ! mkdir "$SETTINGS_NEW" || ! tar -xf "$1" -C "$SETTINGS_NEW" 2>>"$out/install.log" || [ ! -d "$SETTINGS_NEW/Launcher" ]; then
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
    if [ ! -e "$R/private/Launcher" ] && [ -d "$SETTINGS_OLD" ]; then
        mv "$SETTINGS_OLD" "$R/private/Launcher" || return 1
    fi
    [ -d "$R/private/Launcher" ] || return 1
    rm -rf "$SETTINGS_NEW" "$SETTINGS_OLD"
}
# 0 when tar $1 is complete: every member reads to the end. A listing alone passes a tar that ends inside file data.
tar_ok() {
    tar -xOf "$1" >/dev/null 2>&1
}
BACKUP_HELP="Copy private-Launcher.tar from the first install folder to viknav-ui/settings-before-install.tar."
# Write the stock settings backup on the drive from the settings backup of this run: temp file, full read, hash check,
# sync, rename, sync. A power cut leaves no file, the old file, or the complete new file, never a torn file.
stock_backup_write() {
    backup_tmp=$P/.settings-before-install.tar.new
    rm -f "$backup_tmp" 2>>"$out/install.log"
    if cp "$out/private-Launcher.tar" "$backup_tmp" 2>>"$out/install.log" && tar_ok "$backup_tmp" &&
        [ "$(hash_of "$backup_tmp")" = "$(hash_of "$out/private-Launcher.tar")" ] && sync &&
        mv -f "$backup_tmp" "$P/settings-before-install.tar" && sync; then
        return 0
    fi
    rm -f "$backup_tmp" 2>>"$out/install.log"
    return 1
}

# The rollback journal and the settings copy live on the root filesystem, next to the files that a rollback changes.
# A rollback restores the settings from the copy, so a replaced or changed drive cannot change the restored settings.
SETTINGS_COPY_NAME=/etc/.viknav-settings.tar
SETTINGS_COPY=$R$SETTINGS_COPY_NAME
# Copy settings tar $1 to the settings copy: temp file, hash check, sync, rename, sync.
settings_copy() {
    rm -f "$SETTINGS_COPY.new" 2>>"$out/install.log"
    if cp "$1" "$SETTINGS_COPY.new" 2>>"$out/install.log" && [ "$(hash_of "$SETTINGS_COPY.new")" = "$(hash_of "$1")" ] &&
        sync && mv -f "$SETTINGS_COPY.new" "$SETTINGS_COPY" && sync; then
        return 0
    fi
    rm -f "$SETTINGS_COPY.new" 2>>"$out/install.log"
    log "settings copy failed"
    return 1
}
# The journal records a rollback target: the original Launcher, the stock sounds, no /etc vn files, and the settings.
# Line 1: the settings copy name, or none (keep the current settings). Line 2: the copy hash.
# Line 3: the phase. files: the files and the settings still need the restore. start: the files and the settings are stock,
# and only the start check is open.
# An install and a requested rollback put the journal in place before the first live change. The journal goes away only
# after the start check passes, so a power cut or a failed step makes the next drive insert finish the rollback.
JOURNAL=$R/etc/.viknav-rollback
# $1: the settings copy name or none. $2: the phase.
journal_write() {
    sum=
    if [ "$1" != none ]; then
        sum=$(hash_of "$R$1") || { log "rollback journal write failed: no settings copy"; return 1; }
    fi
    rm -f "$JOURNAL.new" 2>>"$out/install.log"
    printf '%s\n%s\n%s\n' "$1" "$sum" "$2" > "$JOURNAL.new" && sync && mv -f "$JOURNAL.new" "$JOURNAL" && sync && return 0
    rm -f "$JOURNAL.new" 2>>"$out/install.log"
    log "rollback journal write failed"
    return 1
}
# The journal removal is the commit point. A power cut after the removal leaves only the settings copy, a leftover.
journal_clear() {
    rm -f "$JOURNAL" || return 1
    sync
    rm -f "$JOURNAL.new" "$SETTINGS_COPY" "$SETTINGS_COPY.new" 2>>"$out/install.log"
    sync
}
# Sets journal_name (line 1), journal_phase (line 3), and journal_settings: the settings copy path, none, or bad
# (the copy is missing or does not have the journaled hash).
journal_read() {
    journal_name=$(awk 'NR == 1' "$JOURNAL" 2>/dev/null)
    sum=$(awk 'NR == 2' "$JOURNAL" 2>/dev/null)
    journal_phase=$(awk 'NR == 3' "$JOURNAL" 2>/dev/null)
    journal_settings=bad
    case "$journal_name" in
        none) journal_settings=none ;;
        "$SETTINGS_COPY_NAME") [ -n "$sum" ] && [ "$(hash_of "$SETTINGS_COPY")" = "$sum" ] && journal_settings=$SETTINGS_COPY ;;
    esac
}
# Remove what a stopped run left: stage files and an unpublished journal. Every journal goes in place before the first live
# change, so a journal that never got the final name means that nothing live changed. Without a journal, the settings copy
# and a temp stock backup on the drive are leftovers too.
clean_leftovers() {
    remove_staged
    rm -f "$JOURNAL.new" "$P/.settings-before-install.tar.new" 2>>"$out/install.log"
    [ -e "$JOURNAL" ] || rm -f "$SETTINGS_COPY" "$SETTINGS_COPY.new" 2>>"$out/install.log"
}
# When no Launcher runs, start the Launcher on disk and check the start. Adds the result to started.
launcher_keep() {
    launcher_running && return 0
    launcher_start current
    if health; then kept="current Launcher started"; else kept="current Launcher start check failed: $reason"; fi
    started=${started:+$started; }$kept
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
# Every stock file stages first, while the dashboard still runs, so a failed copy changes nothing. A failed copy clears the
# journal when $1 is clear (a requested rollback; the cluster is still a known release) and keeps the journal otherwise.
# After the stop, each step runs where safe and a Launcher always starts again. The journal goes only after the start
# check passes. A journal in the start phase over stock files needs only the start.
# Sets started to the result detail. Returns 1 when a step or the start check fails.
restore_original() {
    journal_read
    failed=
    note=
    settings_note=
    if [ "$journal_phase" = start ] && files_stock; then
        note="files already stock; "
        launcher_stop
    else
        remove_staged
        copied=1
        stage "$P/original/Launcher" "$LAUNCHER" "$ORIGINAL_SHA256" 777 || copied=0
        for f in $SOUND_FILES; do
            [ "$copied" -eq 1 ] || break
            stage "$P/original/sound/$f" "$R/etc/sound/$f" "$(sound_stock "$f")" "$(sound_mode "$f")" || copied=0
        done
        if [ "$copied" -eq 0 ]; then
            remove_staged
            started="stock file copy failed; nothing changed"
            if [ "$1" = clear ]; then
                journal_clear
            else
                started="$started; the next drive insert finishes the rollback"
            fi
            launcher_keep
            log "$started"
            return 1
        fi
        # The root filesystem mounts with noauto_da_alloc, so a rename does not flush the data first. Write the staged data now.
        sync
        launcher_stop
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
        [ -n "$failed" ] || journal_write "$journal_name" start || failed="rollback journal update"
    fi
    which=original
    [ "$(hash_of "$LAUNCHER")" = "$ORIGINAL_SHA256" ] || which=current
    launcher_start "$which"
    healthy=1
    if health; then started="$which Launcher started"; else started="$which Launcher start check failed: $reason"; healthy=0; fi
    cp "$LAUNCHER_LOG" "$out/Launcher-$which.log" 2>/dev/null
    started="$note$started$settings_note"
    [ -z "$failed" ] || started="$failed failed; $started"
    if [ -z "$failed" ] && [ "$healthy" -eq 1 ] && ! journal_clear; then
        failed="clear the rollback journal"
        started="$failed failed; $started"
    fi
    log "$started"
    [ -z "$failed" ] && [ "$healthy" -eq 1 ]
}
# A journal on the cluster: finish that rollback before anything else, whatever the live files hold, then stop.
resume_rollback() {
    [ -e "$JOURNAL" ] || return 0
    log "rollback journal found"
    for f in $SOUND_FILES; do
        payload_ok "original/sound/$f" "$(sound_stock "$f")" || abort "rollback journal: payload missing"
    done
    payload_ok original/Launcher "$ORIGINAL_SHA256" || abort "rollback journal: payload missing"
    if restore_original keep; then
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
    rm -f "$SETTINGS_COPY" "$SETTINGS_COPY.new" 2>>"$out/install.log"
    launcher_start original
    abort "$1"
}
# Failure after the journal: block a repeat install from this drive, then restore the original.
rollback_now() {
    log "rollback: $1"
    cp "$LAUNCHER_LOG" "$out/Launcher-failed.log" 2>/dev/null
    printf '%s\n' "$1" > "$usb_root/INSTALL-BLOCKED.txt"
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
do_install() {
    clean_leftovers
    resume_rollback
    if [ -e "$usb_root/INSTALL-BLOCKED.txt" ]; then
        launcher_keep
        finish BLOCKED ${started:+"$started"} "Remove INSTALL-BLOCKED.txt only after the cause is fixed."
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
    backup_new=0
    if [ ! -e "$P/settings-before-install.tar" ]; then
        [ "$launcher" != "$ORIGINAL_SHA256" ] || backup_new=1
    elif ! tar_ok "$P/settings-before-install.tar"; then
        [ "$launcher" = "$ORIGINAL_SHA256" ] || abort "settings-before-install.tar damaged" "$BACKUP_HELP"
        log "settings-before-install.tar damaged; replaced from this run"
        backup_new=1
    fi
    # Staged files go to /usr/bin, /etc, and /etc/sound. Each folder must have room for all staged files,
    # so the check also holds when the folders sit on separate filesystems.
    for d in "$R/usr/bin" "$R/etc" "$R/etc/sound"; do
        free=$(df -k "$d" 2>/dev/null | awk 'END {print $(NF - 2)}')
        case "$free" in ''|*[!0-9]*) abort "low space" ;; esac
        [ "$free" -ge "$MIN_FREE_KB" ] || abort "low space"
    done

    launcher_stop
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
    settings_copy "$out/private-Launcher.tar" || fail_restart "settings copy"

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

    launcher_start candidate
    health || rollback_now "$reason"
    cp "$LAUNCHER_LOG" "$out/Launcher-start.log" 2>/dev/null
    # The start check passed: the journal removal commits the install.
    journal_clear || rollback_now "clear the rollback journal"
    finish INSTALLED "Keep the drive in for 3 more minutes for Launcher-later.log."
    sleep "$LOG_WAIT"
    cp "$LAUNCHER_LOG" "$out/Launcher-later.log" 2>/dev/null
    log "later log copied"
    sync
}

# A requested rollback that stops before the journal: nothing changed. $1 names the failed step.
rollback_not_started() {
    rm -f "$SETTINGS_COPY" "$SETTINGS_COPY.new" 2>>"$out/install.log"
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
        finish ALREADY_ORIGINAL ${started:+"$started"}
        exit 0
    fi
    # Without the stock backup, the rollback keeps the current settings. A damaged stock backup stops the rollback.
    settings=none
    if [ -e "$P/settings-before-install.tar" ]; then
        tar_ok "$P/settings-before-install.tar" || abort "settings-before-install.tar damaged" "$BACKUP_HELP"
        settings_copy "$P/settings-before-install.tar" || rollback_not_started "settings copy"
        settings=$SETTINGS_COPY_NAME
    fi
    journal_write "$settings" files || rollback_not_started "rollback journal write"
    if restore_original clear; then
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
    (cd / && exec sh "$RECORDER" "$R" "$usb_root" "$out") </dev/null >/dev/null 2>&1 &
    echo "$!" > "$RECORDER_PID"
    finish RECORDING "Turn on Factory > Debug logging for values and UART frames. Each power-up with the drive in starts a new folder."
}

[ "$actions" -eq 1 ] || abort "more than one action marker"
log "action $action from $usb_root"
case "$action" in
    install) do_install ;;
    rollback) do_rollback ;;
    log) do_log ;;
    record) do_record ;;
esac
exit 0
