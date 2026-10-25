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

# --- watchdog ---------------------------------------------------------------
wd_setup() {
    setup
    touch "$tmp/state/session"
    close_app() { echo close >> "$tmp/calls"; }
    closes() { grep -c '^close$' "$tmp/calls"; }
}

wd_setup
on_line "[2026-10-25 18:30:10.000]: Info: CLIENT DISCONNECTED" 0
tick 899
check "no close before the grace ends" '[ "$(closes)" = 0 ]'
tick 900
check "disconnect then 900 s closes the app" '[ "$(closes)" = 1 ]'
tick 960
check "closes once" '[ "$(closes)" = 1 ]'
teardown

wd_setup
on_line "Info: CLIENT DISCONNECTED" 0
on_line "Info: CLIENT CONNECTED" 300
tick 2000
check "reconnect inside grace cancels teardown" '[ "$(closes)" = 0 ]'
teardown

wd_setup
rm "$tmp/state/session"
on_line "Info: CLIENT DISCONNECTED" 0
tick 5000
check "no session means no close" '[ "$(closes)" = 0 ]'
teardown

wd_setup
on_line "Info: New streaming session started [active sessions: 1]" 0
on_line "Info: Executing Undo Cmd: [x]" 0
on_line "Info: [wlgrab] Selected monitor [] for streaming" 0
tick 5000
check "unrelated lines are ignored" '[ "$(closes)" = 0 ]'
teardown

wd_setup
BASTION_STREAM_GRACE=60
on_line "Info: CLIENT DISCONNECTED" 100
tick 159
check "grace is configurable" '[ "$(closes)" = 0 ]'
tick 160
check "configured grace closes" '[ "$(closes)" = 1 ]'
unset BASTION_STREAM_GRACE
teardown

unit=dot_config/systemd/user/bastion-stream-watchdog.service
check "service follows the Sunshine journal" 'grep -q "journalctl --user -fu app-dev.lizardbyte.app.Sunshine -o cat -n 0" $unit && grep -q "bastion-stream watchdog" $unit'
check "service starts with the session" 'grep -qx "WantedBy=graphical-session.target" $unit'
check "service restarts if it dies" 'grep -qx "Restart=always" $unit'

# --- Sunshine config ----------------------------------------------------------
conf=dot_config/sunshine/sunshine.conf
check "conf captures STREAM with wlr" 'grep -qx "capture = wlr" $conf && grep -qx "output_name = STREAM" $conf'
check "conf encodes with vaapi on the 9070" 'grep -qx "encoder = vaapi" $conf && grep -qx "adapter_name = /dev/dri/renderD128" $conf'
check "web UI stays local" 'grep -qx "origin_web_ui_allowed = lan" $conf'
apps=$(chezmoi execute-template < dot_config/sunshine/apps.json.tmpl 2>/dev/null)
check "one app named Steam Big Picture" '[ "$(jq -r ".apps | length" <<<"$apps")" = 1 ] && [ "$(jq -r ".apps[0].name" <<<"$apps")" = "Steam Big Picture" ]'
check "app preps and undoes with bastion-stream by absolute path" '[ "$(jq -r ".apps[0][\"prep-cmd\"][0].do" <<<"$apps")" = "$HOME/.local/bin/bastion-stream prep" ] && [ "$(jq -r ".apps[0][\"prep-cmd\"][0].undo" <<<"$apps")" = "$HOME/.local/bin/bastion-stream undo" ]'
check "app has no command and nothing detached" '[ "$(jq -r ".apps[0].cmd // \"\"" <<<"$apps")" = "" ] && [ "$(jq -r ".apps[0].detached // [] | length" <<<"$apps")" = 0 ] && [ "$(jq -r ".apps[0][\"auto-detach\"]" <<<"$apps")" = false ]'
check "secrets are not managed" '! chezmoi managed 2>/dev/null | grep -E "sunshine_state|api-creds|credentials"'
check "sunshine and the watchdog start with the session" '[ "$(cat dot_config/systemd/user/graphical-session.target.wants/symlink_app-dev.lizardbyte.app.Sunshine.service)" = /usr/lib/systemd/user/app-dev.lizardbyte.app.Sunshine.service ] && [ "$(cat dot_config/systemd/user/graphical-session.target.wants/symlink_bastion-stream-watchdog.service)" = ../bastion-stream-watchdog.service ]'
hl=dot_config/hypr/hyprland.lua
check "touch goes to STREAM" 'grep -A2 "name *= *\"libvirtualhid-touchscreen\"" $hl | grep -q "output *= *\"STREAM\"" && grep -A2 "name *= *\"libvirtualhid-pen-tablet\"" $hl | grep -q "output *= *\"STREAM\""'
check "hyprland config parses" 'luac -p $hl'
check "a restarted sunshine first clears a stale session" 'grep -qx "ExecStartPre=%h/.local/bin/bastion-stream undo" dot_config/systemd/user/app-dev.lizardbyte.app.Sunshine.service.d/bastion-stream.conf'
check "host verify script exists" '[ -x tests/verify-stream-host.sh ]'

exit $failed
