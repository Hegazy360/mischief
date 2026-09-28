#!/usr/bin/env bash
# Run the GDScript test suite headless in a sandbox copy of the project.
# Usage: tools/scripts/test_game.sh [sandbox-name] [-- filter]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
NAME="${1:-tests}"; shift || true
exec "$ROOT/tools/scripts/sandbox.sh" "$NAME" -s res://tests/run_tests.gd -- "$@"
