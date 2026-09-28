# Mischief Next Door — project rules for Claude Code

## What this is
A LANDSCAPE mobile (Android 7+ / iOS 15+) slapstick stealth-prank game: sneak around your grumpy
neighbour's side-view house, set up pranks along his daily routine, don't get caught, and make the
TV audience howl. Solo, offline, episode based. Godot 4.7.2 GDScript, Compatibility renderer, 2D.
Design: `docs/GDD.md`. Tech/contracts: `docs/TECH.md`. Build plan + status: `docs/PLAN.md`, `docs/PROGRESS.md`.
Original IP: never use names, characters, art, levels or branding from Neighbours from Hell (THQ Nordic).

## Golden rules
1. FUN FIRST. Every change is judged by how it feels on a phone held sideways: readable, responsive,
   funny. Look at screenshots / frame sequences of what you build (SHOT_SIZE=1200x540).
2. Typed GDScript (`var x: int`, typed returns), tabs for indentation, `##` doc comments.
3. Content (episodes, pranks, items, animations, lines) lives in `game/data/**` as JSON, loaded and
   validated at startup; never hardcode level content in scripts.
4. No monetisation, ads, energy timers or network permissions in v1. Never add camera/mic/contacts.
5. 60 fps on a mid-range Android phone: pooled nodes, no per-frame allocations in hot paths,
   CPUParticles2D with capped counts.

## Commands (run from the repo root)
- Tests: `tools/scripts/test_game.sh <sandbox-name> [-- filter]` (headless, in a private sandbox copy)
- Screenshot: `tools/scripts/shot.sh res://scenes/x.tscn out.png [frames] [sandbox] [-- user args]`
  (landscape 1200x540 = 20:9 phone; `--shot-seq=/abs/dir --every=N --count=K` for frame sequences)
- Android debug APK: `tools/scripts/export_android.sh` (ANDROID_HOME must point at an SDK)
- Import metadata check: `tools/ci/check_import_meta.sh` (commit every `.import` / `.uid` sidecar)
- Run Godot only through these scripts (sandbox copies), never directly on `game/` while others work.

## Definition of done
Tests green, import metadata committed, screenshots looked at, `docs/PROGRESS.md` updated.
