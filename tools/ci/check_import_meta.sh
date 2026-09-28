#!/usr/bin/env bash
# Import metadata check (CI): Godot's per-file metadata must be committed.
#   * every imported asset (svg/png/wav/ttf/...) has its `<file>.import` sidecar,
#   * every script/shader has its `<file>.uid` sidecar,
#   * no orphan sidecar is left behind for a deleted file,
#   * .gitignore does NOT ignore *.import / *.uid (they are how scenes keep stable UIDs;
#     without them every fresh checkout re-imports everything and logs "invalid UID").
# Fix a failure with ONE import on the real project (nobody else running Godot there):
#   godot --headless --path game --import
# Usage: tools/ci/check_import_meta.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
fail=0

# 1. .gitignore must not swallow the sidecars.
probe_import="$(find game -name '*.import' -not -path '*/.godot/*' -print -quit)"
probe_uid="$(find game -name '*.gd.uid' -not -path '*/.godot/*' -print -quit)"
for p in "${probe_import:-game/ui/icons/play.svg.import}" "${probe_uid:-game/autoload/router.gd.uid}" \
		game/new_asset.svg.import game/new_script.gd.uid; do
	if git check-ignore -q --no-index "$p" 2>/dev/null; then
		echo "FAIL: $p is gitignored ($(git check-ignore -v --no-index "$p"))"
		fail=1
	fi
done

# 2. Sidecars present for every asset / script (skipping dirs with a .gdignore and .godot/).
IGNORED_DIRS=()
while IFS= read -r g; do IGNORED_DIRS+=("$(dirname "$g")"); done < <(find game -name .gdignore)
skip() {
	local f="$1" d
	[[ "$f" == */.godot/* ]] && return 0
	for d in "${IGNORED_DIRS[@]:-}"; do
		[[ -n "$d" && "$f" == "$d"/* ]] && return 0
	done
	return 1
}
missing=0
while IFS= read -r f; do
	skip "$f" && continue
	if [[ ! -f "$f.import" ]]; then echo "MISSING: $f.import"; missing=$((missing + 1)); fi
done < <(find game -type f \( -iname '*.svg' -o -iname '*.png' -o -iname '*.jpg' -o -iname '*.webp' \
	-o -iname '*.wav' -o -iname '*.ogg' -o -iname '*.mp3' -o -iname '*.ttf' -o -iname '*.otf' \) | sort)
while IFS= read -r f; do
	skip "$f" && continue
	if [[ ! -f "$f.uid" ]]; then echo "MISSING: $f.uid"; missing=$((missing + 1)); fi
done < <(find game -type f \( -name '*.gd' -o -name '*.gdshader' \) | sort)

# 3. Orphans.
orphans=0
while IFS= read -r s; do
	skip "$s" && continue
	src="${s%.*}"
	if [[ ! -f "$src" ]]; then echo "ORPHAN: $s (no $src)"; orphans=$((orphans + 1)); fi
done < <(find game -type f \( -name '*.import' -o -name '*.uid' \) | sort)

if (( missing > 0 || orphans > 0 )); then
	echo "FAIL: $missing missing and $orphans orphan sidecar(s) — run: godot --headless --path game --import"
	fail=1
fi
if (( fail == 0 )); then
	echo "[import-meta] OK: $(find game -name '*.import' -not -path '*/.godot/*' | wc -l) .import," \
		"$(find game -name '*.uid' -not -path '*/.godot/*' | wc -l) .uid, none ignored"
fi
exit "$fail"
