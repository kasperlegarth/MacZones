#!/bin/bash
# Builds MacZones and installs it in /Applications, replacing any running copy.
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build-app.sh

pkill -x MacZones 2>/dev/null || true
rm -rf /Applications/MacZones.app
ditto build/MacZones.app /Applications/MacZones.app
open /Applications/MacZones.app

echo "Installed /Applications/MacZones.app"
