#!/usr/bin/env bash
# Exports the debug APK from the command line: bash game/tools/build_apk.sh
# Set GODOT=/path/to/godot if the binary is not called "godot" on your PATH.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-}"
if [ -z "$GODOT" ]; then
  for c in godot godot4 Godot; do command -v "$c" > /dev/null && GODOT="$c" && break; done
fi
if [ -z "$GODOT" ] && flatpak info org.godotengine.Godot > /dev/null 2>&1; then
  GODOT="flatpak run org.godotengine.Godot"
fi
[ -n "$GODOT" ] || { echo "Godot not found. Run: GODOT=/path/to/godot bash $0"; exit 1; }

mkdir -p "$ROOT/export"
$GODOT --headless --path "$ROOT/game" --import
$GODOT --headless --path "$ROOT/game" --export-debug "Android" "$ROOT/export/flipjar-debug.apk"
echo
echo "APK: $ROOT/export/flipjar-debug.apk"
echo "Install on a phone with USB debugging on:  adb install -r \"$ROOT/export/flipjar-debug.apk\""
echo "Or copy the file to the phone and open it (allow installs from unknown sources)."
