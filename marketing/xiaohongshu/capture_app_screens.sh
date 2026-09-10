#!/bin/zsh
set -euo pipefail

device_id="57263FEE-587B-4551-A7F9-0F5152BC6365"
app_path=".codex-derived-data/Build/Products/Debug-iphonesimulator/PayJoy.app"
bundle_id="app.payjoy.kaixin"
output_dir="marketing/xiaohongshu/app-screens"

xcrun simctl boot "$device_id" 2>/dev/null || true
xcrun simctl bootstatus "$device_id" -b
xcrun simctl install "$device_id" "$app_path"

for screen in home widgets wish-tab daily-report; do
    xcrun simctl terminate "$device_id" "$bundle_id" 2>/dev/null || true
    SIMCTL_CHILD_PAYJOY_SCREENSHOT_MODE=1 \
    SIMCTL_CHILD_PAYJOY_SCREENSHOT_SCREEN="$screen" \
    SIMCTL_CHILD_PAYJOY_SCREENSHOT_LANGUAGE=zhHans \
    SIMCTL_CHILD_PAYJOY_SCREENSHOT_THEME=classic \
    xcrun simctl launch "$device_id" "$bundle_id" >/dev/null
    sleep 2
    xcrun simctl io "$device_id" screenshot "$output_dir/$screen.png" >/dev/null
done
