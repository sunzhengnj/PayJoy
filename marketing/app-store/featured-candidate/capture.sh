#!/bin/zsh
set -euo pipefail

if (( $# < 4 )); then
    print -u2 'Usage: capture.sh DEVICE_ID APP_PATH OUTPUT_DIR SCREEN...'
    exit 2
fi

if [[ "${PAYJOY_CAPTURE_HOST_READY:-}" != '1' ]]; then
    print -u2 'Simulator capture is disabled on this host. Run only on a verified test host with PAYJOY_CAPTURE_HOST_READY=1.'
    exit 1
fi

if pgrep -x 'xcodebuild|swift-test' >/dev/null; then
    print -u2 'A build or test is running; wait for it to finish before simulator capture.'
    exit 1
fi

device_id="$1"
app_path="$2"
output_dir="$3"
shift 3
bundle_id='app.payjoy.kaixin'
booted_here=0
status_bar_overridden=0
display_args=()
if [[ -n "${PAYJOY_CAPTURE_DISPLAY:-}" ]]; then
    display_args=("--display=$PAYJOY_CAPTURE_DISPLAY")
fi

cleanup() {
    if (( status_bar_overridden )); then
        xcrun simctl status_bar "$device_id" clear >/dev/null 2>&1 || true
    fi
    if (( booted_here )); then
        xcrun simctl shutdown "$device_id" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT
trap 'exit 130' INT TERM

booted_devices="$(xcrun simctl list devices booted)"
if ! print -r -- "$booted_devices" | rg -q -F "$device_id"; then
    booted_count="$(print -r -- "$booted_devices" | rg -c '\(Booted\)' || true)"
    booted_count="${booted_count:-0}"
    if (( booted_count >= 2 )); then
        print -u2 'Two simulators are already booted; close one before capturing.'
        exit 1
    fi
    # Own only this startup attempt; an existing test device belongs to its caller.
    booted_here=1
    if ! boot_status="$(xcrun simctl bootstatus "$device_id" -b 2>&1)"; then
        print -u2 -- "$boot_status"
        exit 1
    fi
    print -r -- "$boot_status"
    if [[ "$boot_status" == *'Data Migration Failed'* || "$boot_status" == *'Status=3 isTerminal=YES'* ]]; then
        print -u2 'Simulator startup failed; capture stopped before app installation.'
        exit 1
    fi
fi
xcrun simctl install "$device_id" "$app_path"
mkdir -p "$output_dir"

for screen in "$@"; do
    case "$screen" in
        home-after-midnight) status_time='00:18' ;;
        weekly-echo) status_time='19:24' ;;
        *) status_time='15:24' ;;
    esac
    xcrun simctl status_bar "$device_id" override --time "$status_time" --dataNetwork wifi --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
    status_bar_overridden=1
    xcrun simctl terminate "$device_id" "$bundle_id" >/dev/null 2>&1 || true
    SIMCTL_CHILD_PAYJOY_SCREENSHOT_MODE=1 \
    SIMCTL_CHILD_PAYJOY_SCREENSHOT_SCREEN="$screen" \
    SIMCTL_CHILD_PAYJOY_SCREENSHOT_LANGUAGE=zhHans \
    SIMCTL_CHILD_PAYJOY_SCREENSHOT_THEME=classic \
        xcrun simctl launch "$device_id" "$bundle_id" >/dev/null
    sleep 5
    xcrun simctl io "$device_id" screenshot --mask=black "$display_args[@]" "$output_dir/$screen.png"
done
