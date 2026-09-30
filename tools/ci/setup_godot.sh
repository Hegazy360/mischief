#!/usr/bin/env bash
# (Re)install the Godot toolchain when /opt was wiped by a container restart (R3D index §3.6, ruling R16):
#   (1) Godot 4.7.2 at /opt/godot + /usr/local/bin/godot
#   (2) its export templates (android / web / linux / version.txt) in ~/.local/share/godot/export_templates/4.7.2.stable/
#   (3) the Android SDK at ${ANDROID_HOME:-/opt/android-sdk}: cmdline-tools, licences and the SAME packages CI installs
#       (.github/workflows/android-preview.yml: platform-tools, platforms;android-36, build-tools;36.1.0 — the Godot 4.7.2
#       template needs build-tools 36.1.0), plus the debug keystore ~/.android/debug.keystore.
# Every part is idempotent (a no-op when already present) and the whole run holds /tmp/mnd_godot_setup.lock, so any
# task that finds Godot or the SDK missing may run it: bash tools/ci/setup_godot.sh
# Downloads are verified: the editor zip against the sha256 pinned below AND the release's SHA512-SUMS.txt, the
# templates against SHA512-SUMS.txt (abort on any mismatch). Prints the three versions at the end.
# Env: ANDROID_HOME (SDK root, default /opt/android-sdk), GODOT_DIR (default /opt/godot), SKIP_ANDROID=1.
set -euo pipefail
GODOT_VER=4.7.2
GODOT_TAG="${GODOT_VER}-stable"
BASE_URL="https://github.com/godotengine/godot/releases/download/$GODOT_TAG"
EDITOR_ZIP="Godot_v${GODOT_TAG}_linux.x86_64.zip"
# sha256 of the known-good /opt/godot/godot.zip (its sha512 matches the release's SHA512-SUMS.txt)
EDITOR_SHA256=cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4
TPZ="Godot_v${GODOT_TAG}_export_templates.tpz"
GODOT_DIR="${GODOT_DIR:-/opt/godot}"
TPL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${GODOT_VER}.stable"
SDK="${ANDROID_HOME:-/opt/android-sdk}"
CLT_ZIP=commandlinetools-linux-13114758_latest.zip
SDK_PACKAGES=("platform-tools" "platforms;android-36" "build-tools;36.1.0")
LOCK=/tmp/mnd_godot_setup.lock

log() { echo "[setup_godot] $*"; }
die() { echo "[setup_godot] ERROR: $*" >&2; exit 1; }

exec 9>"$LOCK"
flock 9
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mnd_godot_setup.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

sums() {  # the release's SHA512-SUMS.txt, fetched once
  [ -s "$TMP/SHA512-SUMS.txt" ] || curl -fsSL --retry 3 -o "$TMP/SHA512-SUMS.txt" "$BASE_URL/SHA512-SUMS.txt"
  echo "$TMP/SHA512-SUMS.txt"
}
check_sha512() {  # $1 file (in $TMP), $2 its release name
  local line
  line="$(grep " $2\$" "$(sums)")" || die "$2 is not listed in SHA512-SUMS.txt"
  (cd "$(dirname "$1")" && echo "${line%% *}  $(basename "$1")" | sha512sum -c -) || die "sha512 mismatch for $2"
}

# --- (1) Godot editor ---------------------------------------------------------------------------------------------
if godot --version 2>/dev/null | grep -q "^${GODOT_VER}\.stable"; then
  log "godot $(godot --version 2>/dev/null | head -1) already installed"
else
  log "installing Godot $GODOT_VER into $GODOT_DIR"
  curl -fL --retry 3 -o "$TMP/$EDITOR_ZIP" "$BASE_URL/$EDITOR_ZIP"
  echo "$EDITOR_SHA256  $TMP/$EDITOR_ZIP" | sha256sum -c - || die "sha256 mismatch for $EDITOR_ZIP"
  check_sha512 "$TMP/$EDITOR_ZIP" "$EDITOR_ZIP"
  mkdir -p "$GODOT_DIR"
  unzip -o -q "$TMP/$EDITOR_ZIP" -d "$GODOT_DIR"
  cp "$TMP/$EDITOR_ZIP" "$GODOT_DIR/godot.zip"   # the known-good copy the pin was computed from
  chmod +x "$GODOT_DIR/Godot_v${GODOT_TAG}_linux.x86_64"
  ln -sf "$GODOT_DIR/Godot_v${GODOT_TAG}_linux.x86_64" /usr/local/bin/godot
  godot --version 2>/dev/null | grep -q "^${GODOT_VER}\.stable" || die "godot does not start after the install"
fi

# --- (2) export templates -----------------------------------------------------------------------------------------
tpl_ok() {
  [ -f "$TPL_DIR/version.txt" ] && grep -q "^${GODOT_VER}\.stable" "$TPL_DIR/version.txt" \
    && [ -f "$TPL_DIR/android_debug.apk" ] && [ -f "$TPL_DIR/android_release.apk" ] && [ -f "$TPL_DIR/android_source.zip" ] \
    && [ -f "$TPL_DIR/linux_release.x86_64" ] && [ -f "$TPL_DIR/web_release.zip" ]
}
if tpl_ok; then
  log "export templates $(cat "$TPL_DIR/version.txt") already installed"
else
  log "installing export templates into $TPL_DIR"
  curl -fL --retry 3 -o "$TMP/$TPZ" "$BASE_URL/$TPZ"
  check_sha512 "$TMP/$TPZ" "$TPZ"
  mkdir -p "$TPL_DIR"
  # keep only android / web / linux / version.txt (the rest is ~1 GB we never use)
  unzip -o -q -j "$TMP/$TPZ" "templates/version.txt" "templates/android_*" "templates/web_*" "templates/linux_*" -d "$TPL_DIR"
  rm -f "$TMP/$TPZ"
  tpl_ok || die "export templates incomplete in $TPL_DIR"
fi

# --- (3) Android SDK + debug keystore -----------------------------------------------------------------------------
sdk_ok() {
  [ -x "$SDK/cmdline-tools/latest/bin/sdkmanager" ] && [ -x "$SDK/platform-tools/adb" ] \
    && [ -f "$SDK/platforms/android-36/android.jar" ] && [ -x "$SDK/build-tools/36.1.0/apksigner" ] \
    && [ -x "$SDK/build-tools/36.1.0/aapt2" ]
}
if [ -n "${SKIP_ANDROID:-}" ]; then
  log "SKIP_ANDROID set: Android SDK not checked"
elif sdk_ok; then
  log "Android SDK at $SDK already has ${SDK_PACKAGES[*]}"
else
  command -v java >/dev/null || die "java not found (the SDK manager needs a JDK 17+)"
  log "installing the Android SDK into $SDK"
  mkdir -p "$SDK/cmdline-tools"
  if [ ! -x "$SDK/cmdline-tools/latest/bin/sdkmanager" ]; then
    curl -fL --retry 3 -o "$TMP/$CLT_ZIP" "https://dl.google.com/android/repository/$CLT_ZIP"
    rm -rf "$SDK/cmdline-tools/latest" "$TMP/clt"
    unzip -q "$TMP/$CLT_ZIP" -d "$TMP/clt"
    mv "$TMP/clt/cmdline-tools" "$SDK/cmdline-tools/latest"
    chmod +x "$SDK/cmdline-tools/latest/bin/"*
  fi
  sm="$SDK/cmdline-tools/latest/bin/sdkmanager"
  yes | "$sm" --sdk_root="$SDK" --licenses >/dev/null 2>&1 || true
  "$sm" --sdk_root="$SDK" --install "${SDK_PACKAGES[@]}" 2>&1 | tr '\r' '\n' | grep -vE '^\s*\[|^\s*$' | tail -5 || true
  sdk_ok || die "Android SDK incomplete in $SDK after sdkmanager"
fi
if [ -z "${SKIP_ANDROID:-}" ] && [ ! -f "$HOME/.android/debug.keystore" ]; then
  log "creating the debug keystore ~/.android/debug.keystore"
  mkdir -p "$HOME/.android"
  keytool -genkeypair -v -keystore "$HOME/.android/debug.keystore" -storepass android -alias androiddebugkey \
    -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
fi

# --- versions -------------------------------------------------------------------------------------------------------
log "godot:     $(godot --version 2>/dev/null | head -1)"
log "templates: $(cat "$TPL_DIR/version.txt" 2>/dev/null) ($TPL_DIR)"
if [ -z "${SKIP_ANDROID:-}" ]; then
  log "android:   $SDK build-tools $(ls "$SDK/build-tools" 2>/dev/null | tr '\n' ' ')| platforms $(ls "$SDK/platforms" 2>/dev/null | tr '\n' ' ')| platform-tools $(sed -n 's/^Pkg.Revision=//p' "$SDK/platform-tools/source.properties" 2>/dev/null)"
fi
