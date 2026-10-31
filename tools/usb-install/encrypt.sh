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
        vnD.qml) echo edafa15cf5118423f1fe6e71a9bd54f525099dbbf3083a275e7d1fa1ba67806c ;;
        vnG.qml) echo 2db5953fe0ddda609fab05f25fdda2449a71b7f63fde2a03e63024155bb9cb84 ;;
        vnL.qml) echo b151901cadd37b7b1342a987ebf482db5692f40e05251311c8b38f299a258a80 ;;
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
# menu-v13 adds chime set A in /etc/sound and changes vnL (the round 43/44 alert panel, overspeed, and cruise). The Launcher stays.
etc_previous() {
    case "$1" in
        vnB.qml) echo cf4c014945f604b5a0da27d70ec0849a54fb57c972bd9ca55c3f0effd8504aee ;;
        vnD.qml) echo 7cb87b4ba052d3b52934c2e8c57e61398c6bb638d8e64acace967b2b5d619c56 ;;
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

log() {
    printf '%s %s\n' "$(date +%H:%M:%S 2>/dev/null)" "$*" >> "$out/install.log"
}
# STATUS.txt line 1 is the result. Line 2, when present, adds detail.
finish() {
    printf '%s\n' "$@" > "$out/STATUS.txt"
    log "STATUS $*"
    sync
}
abort() {
    finish "ABORTED $1"
    exit 0
}
hash_of() {
    h=$(sha256sum "$1" 2>/dev/null) || return 1
    printf '%s' "${h%% *}"
}
payload_check() {
    [ -f "$P/$1" ] && [ ! -L "$P/$1" ] && [ "$(hash_of "$P/$1")" = "$2" ] || abort "payload $1"
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
    : > "$LAUNCHER_LOG"
    fbinit 0 >/dev/null 2>&1
    (cd / && exec "$R/etc/qtenv.sh" >/dev/null 2>&1 </dev/null) &
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
# Restore /private/Launcher from a tar of the directory. The old directory stays until the new one is in place.
restore_settings() {
    if [ ! -f "$1" ]; then
        log "no settings backup at $1"
        return 0
    fi
    new=$R/private/.Launcher.restore
    old=$R/private/.Launcher.old
    rm -rf "$new" "$old"
    mkdir "$new" && tar -xf "$1" -C "$new" 2>>"$out/install.log" && [ -d "$new/Launcher" ] || { rm -rf "$new"; return 1; }
    if [ -e "$R/private/Launcher" ]; then
        mv "$R/private/Launcher" "$old" || { rm -rf "$new"; return 1; }
    fi
    if ! mv "$new/Launcher" "$R/private/Launcher"; then
        [ ! -e "$old" ] || mv "$old" "$R/private/Launcher"
        rm -rf "$new"
        return 1
    fi
    rm -rf "$new" "$old"
    log "settings restored from $1"
}
# Put back the original Launcher, remove the new /etc files, put back the stock sounds, restore the settings,
# and start the original Launcher. Sets started to the start check result.
restore_original() {
    launcher_stop
    remove_staged
    stage "$P/original/Launcher" "$LAUNCHER" "$ORIGINAL_SHA256" 777 && mv -f "$R/usr/bin/.Launcher.new" "$LAUNCHER" || return 1
    for f in $ETC_FILES $RETIRED_FILES; do
        rm -f "$R/etc/$f" || return 1
    done
    for f in $SOUND_FILES; do
        stage "$P/original/sound/$f" "$R/etc/sound/$f" "$(sound_stock "$f")" "$(sound_mode "$f")" && mv -f "$R/etc/sound/.$f.new" "$R/etc/sound/$f" || return 1
    done
    restore_settings "$1" || return 1
    sync
    [ "$(hash_of "$LAUNCHER")" = "$ORIGINAL_SHA256" ] || return 1
    for f in $SOUND_FILES; do
        [ "$(hash_of "$R/etc/sound/$f")" = "$(sound_stock "$f")" ] || return 1
    done
    launcher_start original
    if health; then started="original Launcher started"; else started="original Launcher start check failed: $reason"; fi
    cp "$LAUNCHER_LOG" "$out/Launcher-original.log" 2>/dev/null
    log "$started"
    return 0
}
# Failure before the new files are in place: nothing changed. Start the original Launcher again.
fail_restart() {
    log "failed: $1"
    remove_staged
    launcher_start original
    abort "$1"
}
# Failure after the new files are in place: restore the original and block a repeat install from this drive.
rollback_now() {
    log "rollback: $1"
    cp "$LAUNCHER_LOG" "$out/Launcher-failed.log" 2>/dev/null
    printf '%s\n' "$1" > "$usb_root/INSTALL-BLOCKED.txt"
    if restore_original "$out/private-Launcher.tar"; then
        finish "ROLLED_BACK $1" "$started"
    else
        finish "ROLLBACK_FAILED $1"
    fi
    exit 0
}

do_install() {
    [ ! -e "$usb_root/INSTALL-BLOCKED.txt" ] || { finish BLOCKED "Remove INSTALL-BLOCKED.txt only after the cause is fixed."; exit 0; }
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
        finish ALREADY_INSTALLED
        exit 0
    fi
    # Staged files go to /usr/bin, /etc, and /etc/sound. Each folder must have room for all staged files,
    # so the check also holds when the folders sit on separate filesystems.
    for d in "$R/usr/bin" "$R/etc" "$R/etc/sound"; do
        free=$(df -k "$d" 2>/dev/null | awk 'END {print $(NF - 2)}')
        case "$free" in ''|*[!0-9]*) abort "low space" ;; esac
        [ "$free" -ge "$MIN_FREE_KB" ] || abort "low space"
    done

    launcher_stop
    # The settings database is closed now. Keep the first copy from the original Launcher for a later rollback.
    # An upgrade from an earlier release keeps that copy and never replaces the copy with release settings.
    if ! tar -cf "$out/private-Launcher.tar" -C "$R/private" Launcher 2>>"$out/install.log" || ! tar -tf "$out/private-Launcher.tar" >/dev/null 2>&1; then
        fail_restart "settings backup"
    fi
    if [ "$launcher" = "$ORIGINAL_SHA256" ] && [ ! -e "$P/settings-before-install.tar" ]; then
        cp "$out/private-Launcher.tar" "$P/settings-before-install.tar" \
            && [ "$(hash_of "$P/settings-before-install.tar")" = "$(hash_of "$out/private-Launcher.tar")" ] || fail_restart "settings backup"
    fi
    for f in $ETC_FILES; do
        stage "$P/etc/$f" "$R/etc/$f" "$(etc_sha256 "$f")" 644 || fail_restart "copy /etc/$f"
    done
    for f in $SOUND_FILES; do
        stage "$P/sound/$f" "$R/etc/sound/$f" "$(sound_sha256 "$f")" "$(sound_mode "$f")" || fail_restart "copy /etc/sound/$f"
    done
    stage "$P/Launcher" "$LAUNCHER" "$CANDIDATE_SHA256" 777 || fail_restart "copy Launcher"
    # The root filesystem mounts with noauto_da_alloc, so a rename does not flush the data first. Write the staged data now.
    sync

    # The original Launcher ignores the /etc files and plays any sound file, so the /etc files and the sounds go first.
    # The Launcher goes last.
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
    finish INSTALLED "Keep the drive in for 3 more minutes for Launcher-later.log."
    sleep "$LOG_WAIT"
    cp "$LAUNCHER_LOG" "$out/Launcher-later.log" 2>/dev/null
    log "later log copied"
    sync
}

do_rollback() {
    payload_check original/Launcher "$ORIGINAL_SHA256"
    for f in $SOUND_FILES; do
        payload_check "original/sound/$f" "$(sound_stock "$f")"
    done
    check_launcher
    check_etc
    check_sound
    if [ "$launcher" = "$ORIGINAL_SHA256" ] && [ "$etc_present" -eq 0 ] && [ "$etc_old" -eq 0 ] && [ "$sound_new" -eq 0 ]; then
        finish ALREADY_ORIGINAL
        exit 0
    fi
    if restore_original "$P/settings-before-install.tar"; then
        finish "ROLLED_BACK by request" "$started"
    else
        finish ROLLBACK_FAILED
    fi
}

do_log() {
    cp "$LAUNCHER_LOG" "$out/Launcher.log" 2>/dev/null
    [ ! -f "$R/var/log/Launcher.log" ] || cp "$R/var/log/Launcher.log" "$out/var-Launcher.log" 2>/dev/null
    {
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
        df -k "$R/usr/bin"
        ps
    } > "$out/installed-sha256.txt" 2>&1
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
    (cd / && exec sh "$RECORDER" "$R" "$usb_root" "$out" </dev/null >/dev/null 2>&1) &
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
