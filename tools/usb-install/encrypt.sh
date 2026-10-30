#!/bin/sh
# F150 cluster UI update from a USB drive: install, rollback, or log collection.
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
MIN_FREE_KB=40960
HEALTH_WAIT=90
SETTLE_WAIT=20
LOG_WAIT=180

# Captured original Launcher (capture-04) and the ui-candidate-gps-clock-v2 files.
ORIGINAL_SHA256=2451c3fb6f6c1344625aa2882760eaaccd3dc0979ad1296c9028838e77e2823b
CANDIDATE_SHA256=74f3d2ecfe80bbf2b8d58d7812ba277af5289f9dc48cae73d14f59944d6d6005
ETC_FILES="vnB.qml vnF.qml vnG.qml vnU.qml vnV.qml"
etc_sha256() {
    case "$1" in
        vnB.qml) echo 02e74078b79bb0e7b33fff1b0f0e7182d0e940b1fca951b405528d6b2e72758c ;;
        vnF.qml) echo b9db48d55d04d3dc941d32142a6c435cfa89d9f184029bab5ea9b63621879f84 ;;
        vnG.qml) echo a877fb6d4c4785146264a2c9b0c9b10ffe58a68f597a1e22f5073a0ce51db065 ;;
        vnU.qml) echo 10aec2382811d6120f70d88c1640ce8009c2a867c4ae473e878b217beddada80 ;;
        vnV.qml) echo bc2ba70e6a039ac583045d5cd3212584d914ec466aa6a9f41ab3618e14308dd1 ;;
    esac
}

MARKERS="VIKNAV-UI-INSTALL.txt VIKNAV-UI-ROLLBACK.txt VIKNAV-UI-LOG.txt"
marker_token() {
    case "$1" in
        VIKNAV-UI-INSTALL.txt) echo VIKNAV_UI_INSTALL_GPS_CLOCK_V2 ;;
        VIKNAV-UI-ROLLBACK.txt) echo VIKNAV_UI_ROLLBACK_CAPTURE04 ;;
        VIKNAV-UI-LOG.txt) echo VIKNAV_UI_LOG ;;
    esac
}
marker_ok() {
    [ -f "$1/$2" ] && [ ! -L "$1/$2" ] || return 1
    [ "$(head -c 256 "$1/$2" 2>/dev/null)" = "$(marker_token "$2")" ]
}

R=$SYSTEM_ROOT
LAUNCHER=$R/usr/bin/Launcher
LAUNCHER_LOG=$R/tmp/Launcher.log

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
    rm -f "$R/usr/bin/.Launcher.new"
}
# 0 when every /etc file is absent or the candidate file. Sets etc_present to the count of candidate files.
check_etc() {
    etc_present=0
    for f in $ETC_FILES; do
        target=$R/etc/$f
        [ -e "$target" ] || [ -L "$target" ] || continue
        [ -f "$target" ] && [ ! -L "$target" ] && [ "$(hash_of "$target")" = "$(etc_sha256 "$f")" ] || abort "unknown /etc/$f"
        etc_present=$((etc_present + 1))
    done
}
check_launcher() {
    launcher=$(hash_of "$LAUNCHER")
    case "$launcher" in
        "$ORIGINAL_SHA256"|"$CANDIDATE_SHA256") ;;
        *) abort "unknown Launcher" ;;
    esac
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
# Put back the original Launcher, remove the new /etc files, restore the settings, and start the original Launcher.
# Sets started to the start check result.
restore_original() {
    launcher_stop
    remove_staged
    stage "$P/original/Launcher" "$LAUNCHER" "$ORIGINAL_SHA256" 777 && mv -f "$R/usr/bin/.Launcher.new" "$LAUNCHER" || return 1
    for f in $ETC_FILES; do
        rm -f "$R/etc/$f" || return 1
    done
    restore_settings "$1" || return 1
    sync
    [ "$(hash_of "$LAUNCHER")" = "$ORIGINAL_SHA256" ] || return 1
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
    check_launcher
    check_etc
    if [ "$launcher" = "$CANDIDATE_SHA256" ] && [ "$etc_present" -eq 5 ]; then
        finish ALREADY_INSTALLED
        exit 0
    fi
    free=$(df -k "$R/usr/bin" 2>/dev/null | awk 'END {print $(NF - 2)}')
    case "$free" in ''|*[!0-9]*) abort "low space" ;; esac
    [ "$free" -ge "$MIN_FREE_KB" ] || abort "low space"

    launcher_stop
    # The settings database is closed now. Keep the first pre-install copy for a later rollback.
    if ! tar -cf "$out/private-Launcher.tar" -C "$R/private" Launcher 2>>"$out/install.log" || ! tar -tf "$out/private-Launcher.tar" >/dev/null 2>&1; then
        fail_restart "settings backup"
    fi
    if [ ! -e "$P/settings-before-install.tar" ]; then
        cp "$out/private-Launcher.tar" "$P/settings-before-install.tar" \
            && [ "$(hash_of "$P/settings-before-install.tar")" = "$(hash_of "$out/private-Launcher.tar")" ] || fail_restart "settings backup"
    fi
    for f in $ETC_FILES; do
        stage "$P/etc/$f" "$R/etc/$f" "$(etc_sha256 "$f")" 644 || fail_restart "copy /etc/$f"
    done
    stage "$P/Launcher" "$LAUNCHER" "$CANDIDATE_SHA256" 777 || fail_restart "copy Launcher"

    # The original Launcher ignores the /etc files, so they go first. The Launcher goes last.
    for f in $ETC_FILES; do
        mv -f "$R/etc/.$f.new" "$R/etc/$f" || rollback_now "move /etc/$f"
    done
    mv -f "$R/usr/bin/.Launcher.new" "$LAUNCHER" || rollback_now "move Launcher"
    sync
    [ "$(hash_of "$LAUNCHER")" = "$CANDIDATE_SHA256" ] || rollback_now "verify Launcher"
    for f in $ETC_FILES; do
        [ "$(hash_of "$R/etc/$f")" = "$(etc_sha256 "$f")" ] || rollback_now "verify /etc/$f"
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
    check_launcher
    check_etc
    if [ "$launcher" = "$ORIGINAL_SHA256" ] && [ "$etc_present" -eq 0 ]; then
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
        for f in $ETC_FILES; do
            [ ! -e "$R/etc/$f" ] || sha256sum "$R/etc/$f"
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

[ "$actions" -eq 1 ] || abort "more than one action marker"
log "action $action from $usb_root"
case "$action" in
    install) do_install ;;
    rollback) do_rollback ;;
    log) do_log ;;
esac
exit 0
