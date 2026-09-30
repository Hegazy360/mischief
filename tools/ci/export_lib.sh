#!/usr/bin/env bash
# Shared helpers for tools/scripts/export_{android,web,ios}.sh. Source it, don't run it.
#
# Exports never run inside mischief/game/ (other agents / the editor may be importing there):
# the project is rsynced into a private sandbox (tools/scripts/sandbox.sh) and exported
# from there. Godot's editor settings (Android SDK / JDK / debug keystore paths) are written to
# a private XDG_CONFIG_HOME so exports never touch ~/.config/godot.
#
# Env (all optional):
#   GODOT                 godot binary (default: godot on PATH)
#   GODOT_VERSION         expected version prefix (default 4.7.2.stable)
#   MND_SANDBOX_ROOT    sandbox root (default /tmp/mnd_sandbox)

set -euo pipefail

MND_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT="${GODOT:-godot}"
GODOT_VERSION="${GODOT_VERSION:-4.7.2.stable}"
MND_SANDBOX_ROOT="${MND_SANDBOX_ROOT:-/tmp/mnd_sandbox}"
export MND_SANDBOX_ROOT

log() { printf '\033[1;36m[%s]\033[0m %s\n' "${MND_TAG:-export}" "$*" >&2; }
die() { printf '\033[1;31m[%s] error:\033[0m %s\n' "${MND_TAG:-export}" "$*" >&2; exit 1; }

check_godot() {
  command -v "$GODOT" >/dev/null || die "godot not found (set GODOT=/path/to/godot)"
  local v; v="$("$GODOT" --version 2>/dev/null | tail -1)"
  [[ "$v" == "$GODOT_VERSION"* ]] || log "warning: godot is $v, presets were written for $GODOT_VERSION"
  # Godot keeps templates under "<version>.stable" (e.g. 4.7.2.stable); CI sets GODOT_VERSION=4.7.2.
  local tver="${GODOT_VERSION%.stable}.stable"
  local tpl="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${tver}"
  [[ "$(uname -s)" == Darwin ]] && tpl="$HOME/Library/Application Support/Godot/export_templates/${tver}"
  [[ -d "$tpl" ]] || die "export templates missing: $tpl (download Godot_v${GODOT_VERSION%.stable}-stable_export_templates.tpz)"
}

# private_editor_settings <dir> [key=value ...] -> exports XDG_CONFIG_HOME=<dir>
# (Linux/BSD only; macOS Godot ignores XDG and keeps its settings in ~/Library.)
private_editor_settings() {
  local dir="$1"; shift
  local major_minor; major_minor="$(echo "$GODOT_VERSION" | cut -d. -f1-2)"
  mkdir -p "$dir/godot"
  {
    echo '[gd_resource type="EditorSettings" format=3]'
    echo
    echo '[resource]'
    local kv
    for kv in "$@"; do
      printf '%s = "%s"\n' "${kv%%=*}" "${kv#*=}"
    done
  } > "$dir/godot/editor_settings-${major_minor}.tres"
  export XDG_CONFIG_HOME="$dir"
}

# make_sandbox <name> -> prints the sandbox game dir after a clean import.
# The repo does not commit *.import files, and sandbox.sh's `rsync --delete` removes the ones
# the previous import generated, so a reused .godot/ cache ends up with stale UIDs ("invalid
# UID ... using text path instead" at runtime). Exports therefore always re-import from scratch
# (~20-60 s); MND_KEEP_IMPORT=1 skips the wipe for quick local iterations.
make_sandbox() {
  local name="$1"
  if [[ -z "${MND_KEEP_IMPORT:-}" ]]; then
    rm -rf "${MND_SANDBOX_ROOT:?}/$name/game/.godot"
  fi
  "$MND_ROOT/tools/scripts/sandbox.sh" "$name" >&2 || die "sandbox import failed"
  echo "$MND_SANDBOX_ROOT/$name/game"
}


# run_export <sandbox> <--export-debug|--export-release|--export-pack> <preset> <abs out> [extra godot args]
run_export() {
  local sb="$1" mode="$2" preset="$3" out="$4"; shift 4
  mkdir -p "$(dirname "$out")"
  local logf
  logf="$MND_SANDBOX_ROOT/export-$(echo "$preset" | tr ' A-Z' '_a-z').log"
  log "godot $mode \"$preset\" -> $out"
  set +e
  "$MND_ROOT/tools/scripts/slot.sh" timeout "${EXPORT_TIMEOUT:-1800}" "$GODOT" --headless --path "$sb" "$@" "$mode" "$preset" "$out" >"$logf" 2>&1
  local rc=$?
  set -e
  # Godot can exit 0 after a failed export, so the artifact is the real check.
  if [[ $rc -ne 0 || ! -s "$out" && ! -d "$out" ]]; then
    tail -60 "$logf" >&2
    die "export failed (rc=$rc), full log: $logf"
  fi
  grep -E "ERROR|WARNING" "$logf" | grep -v "^WARNING: Unable to read HTTP proxy" | sort | uniq -c | sort -rn | head -20 >&2 || true
  log "export log: $logf"
}

human_size() { numfmt --to=iec --suffix=B "$(stat -c %s "$1")" 2>/dev/null || stat -c %s "$1"; }
