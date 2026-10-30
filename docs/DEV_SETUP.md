# Developer setup

Everything in `tools/scripts/**` runs the same on a Linux CI runner and on a developer's macOS
machine. This page is what you install once; after that `tools/scripts/test_game.sh`,
`shot.sh`, `anim_sheet.sh`, `capture.sh` and `e2e.sh` all work.

## 1. Godot 4.7.2

The version is pinned: `game/project.godot` declares `config/features = ("4.7", "GL Compatibility")`
and CI uses `GODOT_VERSION: "4.7.2"`. A different 4.x will re-import every asset and churn the
committed `.import` / `.uid` sidecars.

**macOS**

```bash
curl -L -o /tmp/godot.zip \
  https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_macos.universal.zip
mkdir -p ~/godot-4.7.2 && (cd ~/godot-4.7.2 && unzip -q /tmp/godot.zip)
xattr -dr com.apple.quarantine ~/godot-4.7.2/Godot.app     # Gatekeeper, unsigned download
mkdir -p ~/.local/bin
printf '#!/usr/bin/env bash\nexec "$HOME/godot-4.7.2/Godot.app/Contents/MacOS/Godot" "$@"\n' \
  > ~/.local/bin/godot && chmod +x ~/.local/bin/godot
godot --version        # -> 4.7.2.stable.official.ed1daf0bf
```

`~/.local/bin` must be on `PATH`. The scripts call the bare name `godot`.

**Linux** — unpack `Godot_v4.7.2-stable_linux.x86_64.zip` and symlink the binary to `godot` on
`PATH`. CI does this with `.github/actions/setup-godot`.

## 2. Blender 4.5 LTS (only to rebuild 3D art)

Needed by `tools/art3d/**` to rebuild the cast and the set. You do **not** need it to run the game
or the tests — the built `.glb` files are committed.

```bash
# macOS (Apple silicon; use blender-4.5.x-macos-x64.dmg on Intel)
curl -L -o /tmp/blender.dmg https://download.blender.org/release/Blender4.5/blender-4.5.9-macos-arm64.dmg
hdiutil attach -nobrowse -quiet /tmp/blender.dmg -mountpoint /Volumes/B
mkdir -p ~/blender-4.5.9 && cp -R /Volumes/B/Blender.app ~/blender-4.5.9/ && hdiutil detach -quiet /Volumes/B
xattr -dr com.apple.quarantine ~/blender-4.5.9/Blender.app
printf '#!/usr/bin/env bash\nexec "$HOME/blender-4.5.9/Blender.app/Contents/MacOS/Blender" "$@"\n' \
  > ~/.local/bin/blender && chmod +x ~/.local/bin/blender
blender --version      # -> Blender 4.5.9 LTS
```

## 3. Python and the raster tools

The art validators, the audio renderer and the face-atlas builder run on the **system** Python, not
Blender's (Blender ships no Pillow — that is why `tools/art3d/cast/build.sh` splits its stages).

```bash
python3 -m pip install --user numpy Pillow
brew install librsvg          # rsvg-convert; Linux: apt install librsvg2-bin
```

## 4. Check it works

```bash
tools/scripts/test_game.sh mysandbox                     # ~5 min, expect "OK: … 0 failed"
tools/scripts/shot.sh res://scenes/boot/Boot.tscn /tmp/boot.png 120 mysandbox
tools/ci/check_import_meta.sh                            # expect "[import-meta] OK"
```

---

## Platform differences the scripts handle for you

macOS ships none of the GNU/Linux utilities the tooling was first written against. Rather than keep
two sets of scripts, `tools/scripts/lib.sh` picks the native tool where it exists and a portable
equivalent otherwise. Source it after `ROOT=` in any new script.

| Need | Linux | macOS | Helper |
|---|---|---|---|
| Kill a hung run | `timeout` | — | `mnd_timeout SECS cmd…` |
| A GL context with no display | `xvfb-run` | the window server | `"${MND_GUI[@]}" godot …` |
| Absolute path of a file that does not exist yet | `realpath -m` | — | `mnd_abspath PATH` |
| Serialise runs sharing a sandbox | `flock` | — | `mnd_lock NAME` |

`MND_GUI` is a command **prefix array**, not a shell function, for two reasons that are easy to trip
over: coreutils `timeout` execs its argument so it cannot call a function, and bash 3.2 — still
`/bin/bash` on macOS — errors on an empty array under `set -u`. The no-display branch therefore
expands to `env`, a real no-op binary.

### Screenshots on a desktop

`shot.sh` renders in a real window on macOS. A scripted run has nobody at the keyboard and the
window routinely loses focus, so `NightScene` — which correctly pauses when backgrounded — would
end every capture showing the pause menu. `DevShot.is_shooting()` suppresses that for capture runs
only; the shipped behaviour is unchanged.

Outline widths are specified at a 1080 px tall viewport (`width_1080`). The review framing is
1200×540, so a 3.5 px outline is ~1.7 px in a review shot — pass `--outline=7` to the cast
workbench to judge it at the size a phone actually shows.
