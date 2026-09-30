#!/usr/bin/env bash
# Export Mischief for Android from a sandbox copy of game/ and verify the result.
#
#   tools/scripts/export_android.sh                 # debug APK  -> build/android/mischief-debug.apk
#   tools/scripts/export_android.sh release         # release APK -> build/android/mischief-release.apk
#   tools/scripts/export_android.sh release --aab   # Play bundle -> build/android/mischief-release.aab
#                                                   #   (Gradle build, preset "Android AAB")
# Options: --out PATH   --sandbox NAME (default android)   --no-verify
#
# Env:
#   ANDROID_HOME | ANDROID_SDK_ROOT   Android SDK (the first complete one of these, /opt/android-sdk, ~/Android/Sdk;
#                                     tools/ci/setup_godot.sh installs /opt/android-sdk)
#   JAVA_HOME                         JDK 17+ (default: derived from `java` on PATH)
#   Debug signing:   GODOT_ANDROID_KEYSTORE_DEBUG_PATH/_USER/_PASSWORD
#                    (default ~/.android/debug.keystore / androiddebugkey / android; created if missing)
#   Release signing: ANDROID_KEYSTORE_B64 (base64 .jks/.keystore) or ANDROID_KEYSTORE_PATH,
#                    ANDROID_KEYSTORE_ALIAS, ANDROID_KEYSTORE_PASS
#                    (or Godot's own GODOT_ANDROID_KEYSTORE_RELEASE_PATH/_USER/_PASSWORD)
#   MND_VERSION_CODE / MND_VERSION_NAME   override version/code and version/name
set -euo pipefail
export MND_TAG=android
# shellcheck source=../ci/export_lib.sh
source "$(cd "$(dirname "$0")/../ci" && pwd)/export_lib.sh"

MODE=debug; AAB=0; OUT=""; SB_NAME=android; VERIFY=1;
while [[ $# -gt 0 ]]; do
  case "$1" in
    debug|release) MODE="$1" ;;
    --aab) AAB=1 ;;
    --out) OUT="$2"; shift ;;
    --sandbox) SB_NAME="$2"; shift ;;
    --no-verify) VERIFY=0 ;;
    -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
  shift
done
if [[ $AAB == 1 ]]; then
  PRESET="Android AAB"; EXT=aab
else
  PRESET="Android"; EXT=apk
fi
OUT="${OUT:-$MND_ROOT/build/android/mischief-$MODE.$EXT}"
[[ "$OUT" = /* ]] || OUT="$PWD/$OUT"

check_godot

# --- toolchain ------------------------------------------------------------------------------
# The first COMPLETE SDK wins: $ANDROID_HOME, $ANDROID_SDK_ROOT, then the usual locations (tools/ci/setup_godot.sh
# installs /opt/android-sdk with CI's packages). Complete = platform-tools/adb (Godot's export check wants it),
# a build-tools/<v>/apksigner and a platforms/android-<n>; an incomplete $ANDROID_HOME is skipped with a warning.
sdk_complete() {
  local d="$1" bt
  [[ -n "$d" && -x "$d/platform-tools/adb" ]] || return 1
  bt="$(ls -d "$d"/build-tools/* 2>/dev/null | sort -V | tail -1)"
  [[ -n "$bt" && -x "$bt/apksigner" ]] || return 1
  compgen -G "$d/platforms/android-*" >/dev/null
}
SDK=""
for cand in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" /opt/android-sdk "$HOME/Android/Sdk" /usr/local/lib/android/sdk; do
  [[ -n "$cand" ]] || continue
  if sdk_complete "$cand"; then SDK="$cand"; break; fi
  if [[ -d "$cand" ]]; then
    log "warning: Android SDK $cand is incomplete (needs platform-tools/adb, build-tools/*/apksigner, platforms/android-*), skipping"
  fi
done
[[ -n "$SDK" ]] || die "Android SDK not found (set ANDROID_HOME, or run tools/ci/setup_godot.sh)"
BT="$(ls -d "$SDK"/build-tools/* 2>/dev/null | sort -V | tail -1)"
log "Android SDK $SDK (build-tools $(basename "$BT"), $(cd "$SDK/platforms" && ls -d android-* | sort -V | tail -1))"
if [[ -z "${JAVA_HOME:-}" ]]; then
  command -v java >/dev/null || die "java not found (install JDK 17+ or set JAVA_HOME)"
  JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
fi
export ANDROID_HOME="$SDK" JAVA_HOME

# Debug keystore (also needed for release: Godot validates both).
DBG_KS="${GODOT_ANDROID_KEYSTORE_DEBUG_PATH:-$HOME/.android/debug.keystore}"
DBG_USER="${GODOT_ANDROID_KEYSTORE_DEBUG_USER:-androiddebugkey}"
DBG_PASS="${GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD:-android}"
if [[ ! -f "$DBG_KS" ]]; then
  log "creating debug keystore $DBG_KS"
  mkdir -p "$(dirname "$DBG_KS")"
  "$JAVA_HOME/bin/keytool" -genkeypair -v -keystore "$DBG_KS" -storepass "$DBG_PASS" -alias "$DBG_USER" \
    -keypass "$DBG_PASS" -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
fi
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$DBG_KS" GODOT_ANDROID_KEYSTORE_DEBUG_USER="$DBG_USER" \
  GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="$DBG_PASS"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
if [[ "$MODE" == release ]]; then
  if [[ -n "${ANDROID_KEYSTORE_B64:-}" ]]; then
    echo "$ANDROID_KEYSTORE_B64" | base64 -d > "$WORK/release.keystore"
    export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$WORK/release.keystore"
  elif [[ -n "${ANDROID_KEYSTORE_PATH:-}" ]]; then
    export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$ANDROID_KEYSTORE_PATH"
  fi
  [[ -n "${ANDROID_KEYSTORE_ALIAS:-}" ]] && export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$ANDROID_KEYSTORE_ALIAS"
  [[ -n "${ANDROID_KEYSTORE_PASS:-}" ]] && export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$ANDROID_KEYSTORE_PASS"
  if [[ -z "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}" ]]; then
    die "release export needs ANDROID_KEYSTORE_B64 (or ANDROID_KEYSTORE_PATH) + ANDROID_KEYSTORE_ALIAS + ANDROID_KEYSTORE_PASS"
  fi
fi

private_editor_settings "$WORK/xdg" \
  "export/android/android_sdk_path=$SDK" \
  "export/android/java_sdk_path=$JAVA_HOME" \
  "export/android/debug_keystore=$DBG_KS" \
  "export/android/debug_keystore_user=$DBG_USER" \
  "export/android/debug_keystore_pass=$DBG_PASS" \
  "export/android/shutdown_adb_on_exit=false"

# --- sandbox --------------------------------------------------------------------------------
SB="$(make_sandbox "$SB_NAME")"
if [[ -n "${MND_VERSION_CODE:-}" || -n "${MND_VERSION_NAME:-}" ]]; then
  python3 - "$SB/export_presets.cfg" "${MND_VERSION_CODE:-}" "${MND_VERSION_NAME:-}" <<'PY'
import re, sys
path, code, name = sys.argv[1:4]
t = open(path).read()
if code: t = re.sub(r'^version/code=\d+$', f'version/code={int(code)}', t, flags=re.M)
if name: t = re.sub(r'^version/name=".*"$', f'version/name="{name}"', t, flags=re.M)
open(path, "w").write(t)
PY
  log "version code=${MND_VERSION_CODE:-(preset)} name=${MND_VERSION_NAME:-(preset)}"
fi


EXTRA=()
if [[ $AAB == 1 ]]; then
  # Fresh Gradle template each run (sandbox.sh rsync --delete removes res://android/).
  EXTRA+=(--install-android-build-template)
fi
run_export "$SB" "--export-$MODE" "$PRESET" "$OUT" "${EXTRA[@]}"
log "built $OUT ($(human_size "$OUT"))"

[[ $VERIFY == 1 ]] || exit 0
exec "$MND_ROOT/tools/ci/verify_android.sh" "$OUT"
