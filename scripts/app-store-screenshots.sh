#!/bin/sh
# Takes the App Store screenshots: five screens of the sample club, in English,
# on the iPhone, iPad (landscape) and iPhone Duo simulators, with a clean
# status bar.
#
#   scripts/app-store-screenshots.sh [language]   # default: en
#   DEVICES="iPhone Duo" scripts/app-store-screenshots.sh   # one device only
#
# Needs Xcode 27.1 or later (the iPhone Duo only fills its screen with that
# SDK) and the simulators named below. Uses the Debug-only launch arguments
# from CONTRIBUTING.md, so nothing real is shown or touched. The screenshots go
# to Design/AppStore/Screenshots/<language>/<device>/.
set -eu

LANGUAGE="${1:-en}"
DEVICES="${DEVICES:-iPhone 18 Pro Max|iPad Pro 13-inch (M5)|iPhone Duo}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED="${TMPDIR:-/tmp}/winter-screenshots"
OUT="$ROOT/Design/AppStore/Screenshots/$LANGUAGE"
BUNDLE_ID="$(xcodebuild -project "$ROOT/Winter.xcodeproj" -scheme Winter -showBuildSettings 2>/dev/null | awk -F' = ' '/ PRODUCT_BUNDLE_IDENTIFIER /{print $2; exit}')"

cd "$ROOT"
xcodegen generate --quiet
xcodebuild build -project Winter.xcodeproj -scheme Winter -configuration Debug \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DERIVED" -quiet
APP="$DERIVED/Build/Products/Debug-iphonesimulator/Winter.app"

# name|arguments — one line per screenshot, in App Store order.
SCREENS='01-home|-sampleClub 3
02-started|-sampleClub 2 -sampleScreen start
03-stop|-sampleClub 3 -sampleScreen stop -sampleFilled
04-material|-sampleClub 3 -sampleScreen stop -sampleAlert picker
05-hours|-sampleClub 2 -sampleScreen sync'

echo "$DEVICES" | tr '|' '\n' | while read -r DEVICE; do
    UDID="$(xcrun simctl list devices available | grep -F "    $DEVICE (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')"
    [ -n "$UDID" ] || { echo "No simulator named $DEVICE" >&2; exit 1; }
    xcrun simctl boot "$UDID" 2>/dev/null || true
    xcrun simctl bootstatus "$UDID" -b >/dev/null
    # The iPad in landscape, the app's reference layout; the phones upright.
    # Only a UI test can turn a simulator (ScreenshotTests/RotateDevice.swift).
    case "$DEVICE" in
        iPad*) ORIENTATION=testLandscape ;;
        *) ORIENTATION=testPortrait ;;
    esac
    xcodebuild test -project Winter.xcodeproj -scheme WinterScreenshots -destination "id=$UDID" \
        -derivedDataPath "$DERIVED" -only-testing:"WinterScreenshots/RotateDevice/$ORIENTATION" -quiet >/dev/null
    xcrun simctl ui "$UDID" appearance light
    xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 \
        --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 --operatorName ""
    xcrun simctl uninstall "$UDID" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl install "$UDID" "$APP"

    mkdir -p "$OUT/$DEVICE"
    echo "$SCREENS" | while IFS='|' read -r NAME ARGS; do
        # shellcheck disable=SC2086 — the arguments are meant to split.
        xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE_ID" \
            $ARGS -AppleLanguages "($LANGUAGE)" -AppleLocale "${LANGUAGE}_BE" >/dev/null
        # Long enough for a sheet opened over a sheet to finish moving.
        sleep 14
        xcrun simctl io "$UDID" screenshot "$OUT/$DEVICE/$NAME.png" >/dev/null 2>&1
        echo "$DEVICE: $NAME"
    done
    xcrun simctl status_bar "$UDID" clear
done
echo "Saved to $OUT"
