#!/usr/bin/env bash
# Bundles the app and packages it into a drag-to-Applications disk image.
set -euo pipefail
cd "$(dirname "$0")/.."

scripts/bundle.sh
stage="build/dmg"
dmg="build/Metronome.dmg"
rm -rf "$stage" "$dmg"
mkdir -p "$stage"
cp -R build/Metronome.app "$stage/"
ln -s /Applications "$stage/Applications"
hdiutil create -volname Metronome -srcfolder "$stage" -ov -format UDZO "$dmg"
rm -rf "$stage"
echo "Built $dmg"
