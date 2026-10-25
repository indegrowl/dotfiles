#!/bin/bash
# Unit tests for dot_local/bin/executable_bastion-stream (Sunshine prep/undo and
# the disconnect watchdog). External commands are stubbed against a fake world
# in a temp dir. Usage: tests/test-bastion-stream.sh
set -u
cd "$(dirname "$0")/.."
script=dot_local/bin/executable_bastion-stream
failed=0

check() {
    if eval "$2"; then echo "PASS $1"; else echo "FAILED $1"; failed=1; fi
}

# Fresh state + world for each case. World files: steam (a Steam client runs),
# stream (the STREAM output exists), gamescope (the gamescope unit is active).
setup() {
    tmp=$(mktemp -d)
    mkdir -p "$tmp/state" "$tmp/world"
    : > "$tmp/calls"
    unset SUNSHINE_CLIENT_WIDTH SUNSHINE_CLIENT_HEIGHT SUNSHINE_CLIENT_FPS GS_FAIL STEAM_STUCK
    BASTION_STREAM_LIB=1 BASTION_STREAM_STATE=$tmp/state BASTION_STREAM_STEAM_TIMEOUT=2 source "$script"
    world=$tmp/world
    _hyprctl() {
        echo "hyprctl $*" >> "$tmp/calls"
        case "$1" in
            output) [ "$2" = create ] && touch "$world/stream"; [ "$2" = remove ] && rm -f "$world/stream"; echo ok ;;
            monitors) echo "Monitor DP-3 (ID 0):"; [ -e "$world/stream" ] && echo "Monitor STREAM (ID 1):"; true ;;
            clients) [ -e "$world/gamescope" ] && echo '"class": "gamescope",'; true ;;
            *) echo ok ;;
        esac
    }
    _steam() {
        echo "steam $*" >> "$tmp/calls"
        [ -n "${STEAM_STUCK:-}" ] || rm -f "$world/steam" "$world/gamescope"
    }
    _steam_running() { [ -e "$world/steam" ]; }
    _systemd_run() {
        echo "systemd-run $*" >> "$tmp/calls"
        case "$*" in
            *gamescope*) [ -z "${GS_FAIL:-}" ] || return 1; touch "$world/gamescope" ;;
            *bazzite-steam*) touch "$world/steam" "$world/desktop_unit" ;;
        esac
    }
    _systemctl() {
        echo "systemctl $*" >> "$tmp/calls"
        case "$*" in
            *is-active*gamescope*) [ -e "$world/gamescope" ] ;;
            *stop*gamescope*) rm -f "$world/gamescope" ;;
            *is-active*bastion-desktop-steam*) [ -e "$world/desktop_unit" ] ;;
            *stop*bastion-desktop-steam*) rm -f "$world/desktop_unit" "$world/steam" ;;
            *) true ;;
        esac
    }
    _sleep() { :; }
}
teardown() { rm -rf "$tmp"; }
calls() { cat "$tmp/calls"; }
line_of() { grep -n -m1 -- "$1" "$tmp/calls" | cut -d: -f1; }

setup
check "mode comes from the client" '[ "$(SUNSHINE_CLIENT_WIDTH=2176 SUNSHINE_CLIENT_HEIGHT=1224 SUNSHINE_CLIENT_FPS=90 stream_mode)" = "2176 1224 90" ]'
check "mode defaults to 1080p60" '[ "$(stream_mode)" = "1920 1080 60" ]'
teardown

setup
touch "$world/steam"
SUNSHINE_CLIENT_WIDTH=2176 SUNSHINE_CLIENT_HEIGHT=1224 SUNSHINE_CLIENT_FPS=90 prep >/dev/null; rc=$?
check "prep succeeds" '[ $rc = 0 ]'
check "prep creates STREAM at the client mode" 'calls | grep -q "output create headless STREAM" && calls | grep -q "mode = \"2176x1224@90\"" && calls | grep -q "scale = 1"'
check "monitor rule is set before the output exists" '[ "$(line_of "hyprctl eval")" -lt "$(line_of "output create")" ]'
check "STREAM sits at a negative position" 'calls | grep -q "position = \"-10000x0\""'
check "prep stops desktop steam before gamescope" '[ "$(line_of "steam -shutdown")" -lt "$(line_of "gamescope -e")" ]'
check "gamescope runs big picture at the client mode" 'calls | grep -q -- "--unit=bastion-stream-gamescope .*gamescope -e -W 2176 -H 1224 -w 2176 -h 1224 -r 90 -f -- steam -gamepadui"'
check "gamescope never gets -steamos3" '! calls | grep -q steamos3'
check "prep holds an idle and sleep inhibitor" 'calls | grep -q -- "--unit=bastion-stream-inhibit .*systemd-inhibit --what=idle:sleep"'
check "prep marks the session" '[ -e "$tmp/state/session" ]'
: > "$tmp/calls"
prep >/dev/null
check "prep twice keeps one output and one gamescope" '! calls | grep -q "output create" && ! calls | grep -q "gamescope -e"'
check "never touches DP-3" '! grep -q "DP-3" "$tmp/calls"'
teardown

setup
touch "$world/steam"
GS_FAIL=1 prep >/dev/null 2>&1; rc=$?
check "prep failure exits non-zero and cleans up" '[ $rc != 0 ] && calls | grep -q "output remove STREAM" && calls | grep -q bazzite-steam && [ ! -e "$tmp/state/session" ] && [ ! -e "$world/stream" ]'
teardown

setup
touch "$world/steam"
STEAM_STUCK=1 prep >/dev/null 2>&1; rc=$?
check "steam that won't shut down fails prep" '[ $rc != 0 ] && ! calls | grep -q "gamescope -e" && [ ! -e "$tmp/state/session" ]'
teardown

setup
touch "$tmp/state/session" "$world/stream"
undo >/dev/null; rc=$?
check "undo after partial prep restores everything" '[ $rc = 0 ] && calls | grep -q "output remove STREAM" && calls | grep -q "systemctl --user stop bastion-stream-inhibit" && [ -e "$world/steam" ] && [ ! -e "$tmp/state/session" ]'
check "desktop steam is restarted detached" 'calls | grep -q -- "systemd-run --user --unit=bastion-desktop-steam --collect --slice=app.slice -- bazzite-steam -silent"'
teardown

setup
touch "$tmp/state/session" "$world/stream" "$world/gamescope"
undo >/dev/null
check "undo ends gamescope through a clean steam shutdown" 'calls | grep -q "steam -shutdown" && ! calls | grep -q "stop bastion-stream-gamescope"'
check "undo leaves no gamescope" '[ ! -e "$world/gamescope" ]'
teardown

setup
touch "$tmp/state/session" "$world/stream" "$world/gamescope"
STEAM_STUCK=1 undo >/dev/null 2>&1
check "undo stops a stuck gamescope after asking steam first" '[ "$(line_of "steam -shutdown")" -lt "$(line_of "stop bastion-stream-gamescope")" ] && [ ! -e "$world/gamescope" ]'
teardown

setup
touch "$world/steam"
undo >/dev/null; rc=$?
check "undo with nothing running is a no-op that succeeds" '[ $rc = 0 ] && ! calls | grep -q "output remove" && ! calls | grep -q bazzite-steam'
teardown

setup
touch "$world/steam" "$world/desktop_unit"
_steam() { echo "steam $*" >> "$tmp/calls"; rm -f "$world/steam" "$world/desktop_unit"; }
prep >/dev/null
check "a running desktop steam is shut down cleanly, not killed" 'calls | grep -q "steam -shutdown" && ! calls | grep -q "stop bastion-desktop-steam"'
teardown

setup
touch "$world/desktop_unit"
prep >/dev/null
check "a starting desktop steam is stopped without a shutdown request" '! calls | grep -q "steam -shutdown"'
check "prep stops a desktop steam that is still starting" 'calls | grep -q "systemctl --user stop bastion-desktop-steam" && [ "$(line_of "stop bastion-desktop-steam")" -lt "$(line_of "gamescope -e")" ]'
teardown

setup
touch "$tmp/state/session"
prep >/dev/null
check "stale session without gamescope is rebuilt" 'calls | grep -q "gamescope -e" && [ -e "$world/stream" ]'
teardown

exit $failed
