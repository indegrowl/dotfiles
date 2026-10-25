#!/bin/bash
# Live checks of the game streaming host on this PC (Sunshine + bastion-stream).
# Run on bastion with no stream active. Usage: tests/verify-stream-host.sh
set -u
failed=0
sunshine=app-dev.lizardbyte.app.Sunshine

check() {
    if eval "$2" >/dev/null 2>&1; then echo "PASS $1"; else echo "FAILED $1"; failed=1; fi
}

inv=$(systemctl --user show -p InvocationID --value $sunshine)
check "sunshine is running" 'systemctl --user is-active -q $sunshine'
check "sunshine starts with the session" 'systemctl --user is-enabled -q $sunshine'
check "watchdog is running" 'systemctl --user is-active -q bastion-stream-watchdog'
check "watchdog starts with the session" 'systemctl --user is-enabled -q bastion-stream-watchdog'
check "hevc encoder on the 9070" 'journalctl --user _SYSTEMD_INVOCATION_ID=$inv -o cat | grep -q "Found HEVC encoder: hevc_vaapi" && journalctl --user _SYSTEMD_INVOCATION_ID=$inv -o cat | grep -q "RX 9070"'
check "sunshine serves one app" '[ "$(curl -sk -u "$(cat ~/.config/bastion-stream/api-creds)" https://localhost:47990/api/apps | jq -r "[.apps[].name] | join(\",\")")" = "Steam Big Picture" ]'
check "no STREAM output while idle" '! hyprctl monitors | grep -q "^Monitor STREAM "'
check "no gamescope unit while idle" '! systemctl --user is-active -q bastion-stream-gamescope'
check "no streaming inhibitor while idle" '! systemd-inhibit --list --no-pager | grep -q bastion-stream'
check "desktop steam runs silently" 'pgrep -f -- "ubuntu12_32/steam .*-silent"'
check "DP-3 at the origin" 'hyprctl monitors | grep -A1 "^Monitor DP-3 " | grep -q " at 0x0"'

exit $failed
