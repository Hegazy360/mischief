#!/usr/bin/env bash
# Headless Blender through a CPU slot (R3D index §3.1 step 3, ruling R11): background mode, factory
# settings, one thread. Usage: tools/art3d/blender.sh [blender args...]
#   e.g. tools/art3d/blender.sh --python tools/art3d/look-cartoon/src/build_char.py -- --out=…
# Env: BLENDER (default blender on PATH; tools/art3d/setup_blender.sh installs /opt/blender).
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
exec "$ROOT/tools/scripts/slot.sh" "${BLENDER:-blender}" -b --factory-startup --threads 1 "$@"
