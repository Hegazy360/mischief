#!/usr/bin/env bash
# (Re)install Blender 4.5 LTS when /opt was wiped by a container restart (R3D index §3.4, ruling R16).
# Idempotent: exits 0 at once when "$DEST/blender --version" prints "Blender 4.5". Takes a lock
# (/tmp/mnd_blender_setup.lock), so tasks that find Blender missing may all run it: one installs,
# the others wait and then see it installed.
#   bash tools/art3d/setup_blender.sh
# Env: BLENDER_DIR (default /opt/blender).
set -euo pipefail
VER=4.5.14
URL=https://download.blender.org/release/Blender4.5/blender-4.5.14-linux-x64.tar.xz
SHA256=9ba871ff2ecd36526b77432745980b7e6664ecd0c7ca11c48849073dcfe06da3
DEST="${BLENDER_DIR:-/opt/blender}"
LOCK=/tmp/mnd_blender_setup.lock

have_blender() { "$DEST/blender" --version 2>/dev/null | grep -q "^Blender 4\.5"; }

if have_blender; then
  "$DEST/blender" --version 2>/dev/null | head -1
  exit 0
fi

exec 9>"$LOCK"
flock 9
if have_blender; then   # another task installed it while we waited for the lock
  "$DEST/blender" --version 2>/dev/null | head -1
  exit 0
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/mnd_blender.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
tarball="$TMP/blender-$VER-linux-x64.tar.xz"
echo "[setup_blender] downloading Blender $VER"
curl -fL --retry 3 -o "$tarball" "$URL"
echo "$SHA256  $tarball" | sha256sum -c - || { echo "[setup_blender] sha256 mismatch, aborting" >&2; exit 1; }
mkdir -p "$DEST"
tar -xJf "$tarball" -C "$DEST" --strip-components=1
ln -sf "$DEST/blender" /usr/local/bin/blender

if ! "$DEST/blender" --version >"$TMP/version.txt" 2>&1; then
  if grep -q "error while loading shared libraries" "$TMP/version.txt"; then
    echo "[setup_blender] missing runtime libraries: $(grep -o 'lib[^:]*\.so[^:]*' "$TMP/version.txt" | head -3 | tr '\n' ' ')"
    apt-get install -y libxi6 libxkbcommon0 libsm6 libgl1 libxrender1 libxfixes3 \
      || { apt-get update && apt-get install -y libxi6 libxkbcommon0 libsm6 libgl1 libxrender1 libxfixes3; }
  fi
fi
have_blender || { echo "[setup_blender] Blender still does not start:" >&2; "$DEST/blender" --version >&2 || true; exit 1; }
"$DEST/blender" --version 2>/dev/null | head -1
