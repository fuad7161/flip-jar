#!/usr/bin/env bash
# Minimal Android toolchain for Godot 4.4 exports WITHOUT Android Studio.
# Installs: Android command-line tools + platform-tools + build-tools (about 350 MB),
# the Godot export templates (about 1 GB, all platforms in one file), a debug keystore,
# and writes the paths into Godot's editor settings.
# Needs: java/keytool, curl, unzip. Re-running is safe; finished steps are skipped.
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.4.1}"
GODOT_RELEASE="${GODOT_RELEASE:-stable}"
SDK="${ANDROID_SDK_ROOT:-$HOME/Android/sdk}"
CMDLINE_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
TPL_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-${GODOT_RELEASE}/Godot_v${GODOT_VERSION}-${GODOT_RELEASE}_export_templates.tpz"
TPL_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.${GODOT_RELEASE}"
KEYSTORE="$HOME/.android/debug.keystore"

for tool in java keytool curl unzip; do
  command -v "$tool" > /dev/null || { echo "Missing $tool. On Fedora: sudo dnf install java-17-openjdk curl unzip"; exit 1; }
done
JAVA_DIR="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
TMP="$(mktemp -d)"

echo "== 1/4 Android command-line tools -> $SDK"
if [ ! -x "$SDK/cmdline-tools/latest/bin/sdkmanager" ]; then
  mkdir -p "$SDK/cmdline-tools"
  curl -L -o "$TMP/cmdline.zip" "$CMDLINE_URL"
  unzip -q "$TMP/cmdline.zip" -d "$TMP/cmdline"
  rm -rf "$SDK/cmdline-tools/latest"
  mv "$TMP/cmdline/cmdline-tools" "$SDK/cmdline-tools/latest"
fi
SDKM="$SDK/cmdline-tools/latest/bin/sdkmanager"
yes | "$SDKM" --sdk_root="$SDK" --licenses > /dev/null 2>&1 || true
"$SDKM" --sdk_root="$SDK" "platform-tools" "build-tools;34.0.0" > /dev/null

echo "== 2/4 Godot export templates -> $TPL_DIR"
if [ ! -f "$TPL_DIR/android_debug.apk" ]; then
  curl -L -o "$TMP/templates.tpz" "$TPL_URL"
  unzip -q "$TMP/templates.tpz" -d "$TMP/tpl"
  mkdir -p "$(dirname "$TPL_DIR")"
  rm -rf "$TPL_DIR"
  mv "$TMP/tpl/templates" "$TPL_DIR"
fi

echo "== 3/4 Debug keystore -> $KEYSTORE"
if [ ! -f "$KEYSTORE" ]; then
  mkdir -p "$(dirname "$KEYSTORE")"
  keytool -genkeypair -keystore "$KEYSTORE" -alias androiddebugkey -keyalg RSA -keysize 2048 \
    -validity 10000 -storepass android -keypass android -dname "CN=Android Debug,O=Android,C=US"
fi

echo "== 4/4 Godot editor settings"
CFG_DIR="$HOME/.config/godot"
mkdir -p "$CFG_DIR"
set_key() {  # file key value
  local file="$1" key="$2" value="$3"
  if [ ! -f "$file" ]; then
    printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' > "$file"
  fi
  if grep -q "^${key} = " "$file"; then
    sed -i "s|^${key} = .*|${key} = \"${value}\"|" "$file"
  else
    printf '%s = "%s"\n' "$key" "$value" >> "$file"
  fi
}
for f in "$CFG_DIR/editor_settings-4.4.tres" "$CFG_DIR/editor_settings-4.tres"; do
  set_key "$f" "export/android/android_sdk_path" "$SDK"
  set_key "$f" "export/android/java_sdk_path" "$JAVA_DIR"
  set_key "$f" "export/android/debug_keystore" "$KEYSTORE"
  set_key "$f" "export/android/debug_keystore_user" "androiddebugkey"
  set_key "$f" "export/android/debug_keystore_pass" "android"
done
rm -rf "$TMP"
echo
echo "Done. Build the APK with:  bash game/tools/build_apk.sh"
echo "(If Godot was open while this ran, restart it so it reads the new settings.)"
