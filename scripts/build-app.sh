#!/bin/bash
# Builds MacZones.app into ./build.
# Signs with SIGN_IDENTITY, else the "MacZones Dev" certificate (see create-signing-cert.sh), else ad-hoc.
# A stable identity keeps the Accessibility permission across rebuilds; ad-hoc signing resets it.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP=build/MacZones.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/MacZones "$APP/Contents/MacOS/MacZones"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
IDENTITY="${SIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ] && security find-certificate -c "MacZones Dev" >/dev/null 2>&1; then
    IDENTITY="MacZones Dev"
fi
if [ -z "$IDENTITY" ]; then
    echo "warning: signing ad-hoc; run scripts/create-signing-cert.sh to keep permissions across builds" >&2
    IDENTITY="-"
fi
codesign --force --deep --options runtime --sign "$IDENTITY" "$APP"

echo "Built $APP"
