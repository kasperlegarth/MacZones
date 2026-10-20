#!/bin/bash
# Packages build/MacZones.app into build/MacZones.dmg with an Applications shortcut.
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build-app.sh

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT

ditto build/MacZones.app "$STAGING/MacZones.app"
ln -s /Applications "$STAGING/Applications"

DMG="build/MacZones-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -volname "MacZones" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
echo "Built $DMG"
