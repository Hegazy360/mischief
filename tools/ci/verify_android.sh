#!/usr/bin/env bash
# Verify an exported Mischief APK/AAB: package id, version, SDK levels, ABIs, signature and the
# permission allow-list (CLAUDE.md rule 5: never camera / microphone / contacts).
#
#   tools/ci/verify_android.sh build/android/mischief-debug.apk
#   tools/ci/verify_android.sh build/android/mischief-release.aab
#
# Exit 1 when the package id is wrong, the signature does not verify, or a forbidden or
# unexpected permission is requested. Env: ANDROID_HOME (build-tools with aapt2 + apksigner),
# EXPECT_PACKAGE (default gg.mischief.app), ALLOWED_PERMISSIONS (space separated).
set -euo pipefail
F="${1:?usage: verify_android.sh <apk|aab>}"
[[ -f "$F" ]] || { echo "no such file: $F" >&2; exit 1; }
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-/opt/android-sdk}}"
BT="$(ls -d "$SDK"/build-tools/* 2>/dev/null | sort -V | tail -1)"
AAPT2="$BT/aapt2"; APKSIGNER="$BT/apksigner"
[[ -x "$AAPT2" ]] || { echo "aapt2 not found under $SDK/build-tools" >&2; exit 1; }
EXPECT_PACKAGE="${EXPECT_PACKAGE:-gg.mischief.app}"
# INTERNET + VIBRATE are ours (export preset). The others are merged in by libraries and are
# install-time "normal"/signature permissions with no user prompt:
#   ACCESS_NETWORK_STATE, com.android.vending.BILLING  <- Play Billing (godot-iap / GodotGooglePlayBilling)
#   <package>.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION <- AndroidX core (Gradle builds)
ALLOWED="${ALLOWED_PERMISSIONS:-android.permission.INTERNET android.permission.VIBRATE android.permission.ACCESS_NETWORK_STATE com.android.vending.BILLING gg.mischief.app.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION}"
FORBIDDEN_RE='CAMERA|RECORD_AUDIO|READ_CONTACTS|WRITE_CONTACTS|GET_ACCOUNTS|READ_PHONE_STATE|ACCESS_(FINE|COARSE)_LOCATION|READ_EXTERNAL_STORAGE|READ_MEDIA_'

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
APK="$F"
case "$F" in
  *.aab)
    # Turn the base module into a proto APK and let aapt2 convert it, so `dump badging` works
    # without bundletool.
    mkdir -p "$TMP/base"
    unzip -q "$F" 'base/*' -d "$TMP/x"
    ( cd "$TMP/x/base" && mv manifest/AndroidManifest.xml . && rmdir manifest \
      && zip -q -r "$TMP/proto.apk" AndroidManifest.xml resources.pb res 2>/dev/null )
    "$AAPT2" convert --output-format binary -o "$TMP/base.apk" "$TMP/proto.apk"
    APK="$TMP/base.apk"
    ;;
esac

BADGING="$("$AAPT2" dump badging "$APK" 2>/dev/null)"
PERMS="$("$AAPT2" dump permissions "$APK" 2>/dev/null | sed -n "s/^uses-permission: name='\([^']*\)'.*/\1/p" | sort -u)"
field() { echo "$BADGING" | sed -n "s/.*$1='\([^']*\)'.*/\1/p" | head -1; }

echo "== $(basename "$F")  ($(numfmt --to=iec --suffix=B "$(stat -c %s "$F")"))"
echo "package        $(field "package: name")  versionCode=$(field versionCode) versionName=$(field versionName)"
echo "label          $(echo "$BADGING" | sed -n "s/^application-label:'\(.*\)'/\1/p")"
echo "sdk            min=$(echo "$BADGING" | sed -n "s/^minSdkVersion:'\(.*\)'/\1/p") target=$(echo "$BADGING" | sed -n "s/^targetSdkVersion:'\(.*\)'/\1/p")"
ORIENT="$("$AAPT2" dump xmltree --file AndroidManifest.xml "$APK" 2>/dev/null | sed -n 's/.*screenOrientation([^)]*)=\(0x[0-9a-f]*\|[0-9]*\).*/\1/p' | head -1)"
case "$((ORIENT))" in 1) ORIENT="portrait" ;; 7) ORIENT="sensorPortrait" ;; 0) ORIENT="landscape" ;; *) ORIENT="$ORIENT" ;; esac
echo "orientation    $ORIENT"
if [[ "$F" == *.apk ]]; then
  echo "abis           $(unzip -l "$F" 'lib/*' | awk '{print $4}' | grep '^lib/' | cut -d/ -f2 | sort -u | tr '\n' ' ')"
else
  echo "abis           $(unzip -l "$F" 'base/lib/*' | awk '{print $4}' | grep '^base/lib/' | cut -d/ -f3 | sort -u | tr '\n' ' ')"
fi
echo "permissions    $(echo "$PERMS" | tr '\n' ' ')"

rc=0
# Android screenOrientation: 0 landscape, 6 sensorLandscape, 8 reverseLandscape, 11 userLandscape (Godot "sensor_landscape").
[[ "$ORIENT" =~ ^(landscape|sensorLandscape|userLandscape|0|6|8|11)$ ]] || { echo "FAIL orientation is '$ORIENT', expected landscape"; rc=1; }
pkg="$(field "package: name")"
if [[ "$pkg" != "$EXPECT_PACKAGE" ]]; then echo "FAIL package is $pkg, expected $EXPECT_PACKAGE"; rc=1; fi
if echo "$PERMS" | grep -Eq "$FORBIDDEN_RE"; then
  echo "FAIL forbidden permission(s): $(echo "$PERMS" | grep -E "$FORBIDDEN_RE" | tr '\n' ' ') (CLAUDE.md rule 5)"; rc=1
fi
for p in $PERMS; do
  [[ " $ALLOWED " == *" $p "* ]] || { echo "FAIL unexpected permission $p (add it to ALLOWED_PERMISSIONS only after review)"; rc=1; }
done

if [[ "$F" == *.apk ]]; then
  if [[ -x "$APKSIGNER" ]] && "$APKSIGNER" verify --verbose --print-certs "$F" > "$TMP/sig.txt" 2>&1; then
    echo "signature      $(grep -E '^Verified using v[0-9].*true' "$TMP/sig.txt" | sed 's/Verified using //; s/ scheme.*//' | tr '\n' ' ')"
    echo "cert           $(grep -m1 'certificate DN' "$TMP/sig.txt" | sed 's/.*certificate DN: //')"
    echo "cert sha256    $(grep -m1 'certificate SHA-256' "$TMP/sig.txt" | sed 's/.*digest: //')"
  else
    echo "FAIL apksigner verify:"; cat "$TMP/sig.txt" 2>/dev/null; rc=1
  fi
else
  if jarsigner -verify "$F" > "$TMP/sig.txt" 2>&1 && grep -q "jar verified" "$TMP/sig.txt"; then
    echo "signature      jar verified (upload key)"
    keytool -printcert -jarfile "$F" 2>/dev/null | grep -m2 -E 'Owner:|SHA256:' | sed 's/^\s*/cert           /'
  else
    echo "FAIL jarsigner -verify:"; cat "$TMP/sig.txt"; rc=1
  fi
fi
[[ $rc == 0 ]] && echo "verify_android: OK" || echo "verify_android: FAILED"
exit $rc
