# Mischief Next Door — project rules for Claude Code

## What this is
A LANDSCAPE mobile (Android 7+ / iOS 15+) slapstick stealth-prank game: sneak around your grumpy
neighbour's side-view house, set up pranks along his daily routine, freeze in plain sight, and bring
the house down for a live theatre audience (a stage farce: Nights, Acts, Applause, Curtain Calls —
never TV/viewers/ratings framing). Solo, offline, episode based. Godot 4.7.2 GDScript, Compatibility renderer,
a **3D view (Node3D world, Camera3D) with a 2D HUD and overlays** (branch `r3d`; `main` keeps the 2D Gate-0 build).
Design: `docs/GDD.md` + `docs/REDESIGN_3D.md` (the 3D spec). Tech/contracts: `docs/TECH.md`.
Build plan + status: `docs/PLAN.md`, `docs/PROGRESS.md`.
Original IP: never use names, characters, art, levels or branding from Neighbours from Hell (THQ Nordic).

## Golden rules
1. FUN FIRST. Every change is judged by how it feels on a phone held sideways: readable, responsive,
   funny. Look at screenshots / frame sequences of what you build (SHOT_SIZE=1200x540).
2. Typed GDScript (`var x: int`, typed returns), tabs for indentation, `##` doc comments.
3. Content (episodes, pranks, items, animations, lines) lives in `game/data/**` as JSON, loaded and
   validated at startup; never hardcode level content in scripts.
4. No monetisation, ads, energy timers or network permissions in v1. Never add camera/mic/contacts.
5. 60 fps on a mid-range Android phone: pooled nodes, no per-frame allocations in hot paths,
   CPUParticles3D (and CPUParticles2D in the HUD) with capped counts.

## Commands (run from the repo root)
- Tests: `tools/scripts/test_game.sh <sandbox-name> [-- filter]` (headless, in a private sandbox copy)
- Screenshot: `tools/scripts/shot.sh res://scenes/x.tscn out.png [frames] [sandbox] [-- user args]`
  (landscape 1200x540 = 20:9 phone; `--shot-seq=/abs/dir --every=N --count=K` for frame sequences)
- Blender (headless, one thread): `tools/art3d/blender.sh [blender args]`
  (`bash tools/art3d/setup_blender.sh` reinstalls Blender 4.5 LTS when /opt was wiped)
- 3D clips: `tools/art3d/anim/bake.sh <rig> [<clip>|--changed]` (bpy clip specs → `game/art3d/anim/**` + sidecars)
- CPU slots: `tools/scripts/slot.sh <cmd…>` — 4 slots, one process and one render thread each. **Godot and Blender
  only through the slot-wrapped scripts** (sandbox.sh / test_game.sh / solve.sh / lint.sh / fuzz.sh, shot.sh,
  capture.sh, e2e.sh, blender.sh), **one process per task**.
- Android debug APK: `tools/scripts/export_android.sh` (the first complete SDK of ANDROID_HOME, /opt/android-sdk, …;
  `bash tools/ci/setup_godot.sh` reinstalls Godot 4.7.2, its export templates and the SDK)
- Import metadata check: `tools/ci/check_import_meta.sh` (commit every `.import` / `.uid` sidecar)
- Run Godot only through these scripts (sandbox copies), never directly on `game/` while others work.

## Branches and commits
Never switch branches; the orchestrator commits (and pushes). Tasks never run git write commands.

## Definition of done
Tests green, import metadata committed, screenshots looked at, `docs/PROGRESS.md` updated
(during R3D the task report replaces the PROGRESS.md line).
