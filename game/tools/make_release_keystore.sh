#!/usr/bin/env bash
# Creates the Play Store upload keystore ONCE and prints the three values to paste into
# GitHub repository secrets. Keep the .jks file and the password safe: losing them means
# you cannot update the app (Play App Signing lets Google reset an upload key, but it is slow).
set -euo pipefail
OUT="${1:-$HOME/flipjar-upload.jks}"
ALIAS="flipjar"
if [ -f "$OUT" ]; then
  echo "Keystore already exists: $OUT"
else
  read -r -s -p "Choose a keystore password (remember it): " PASS; echo
  keytool -genkeypair -v -keystore "$OUT" -alias "$ALIAS" -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass "$PASS" -keypass "$PASS" -dname "CN=Flip Jar, O=Flip Jar, C=BD"
  echo "Created $OUT"
fi
echo
echo "Add these three secrets at github.com/fuad7161/flip-jar/settings/secrets/actions :"
echo "  ANDROID_KEYSTORE_ALIAS     = $ALIAS"
echo "  ANDROID_KEYSTORE_PASSWORD  = (the password you typed)"
echo "  ANDROID_KEYSTORE_BASE64    = (the single long line below)"
echo
base64 -w0 "$OUT"; echo
