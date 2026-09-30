# 3D art — third-party sources and licences

Everything under `game/art3d/` is original work made for Mischief Next Door, built by the committed Blender /
Godot scripts under `tools/art3d/`, **except** what is derived from the files below. Every third-party file is
CC0 1.0 (public domain); attribution is given as a courtesy. The source files are build inputs only: they live in
`tools/art3d/vendor/` (checksums in each folder's `SHA256SUMS`) and are never shipped under `game/` themselves.

| File (vendored copy) | Used for | Source | Licence |
|---|---|---|---|
| Quaternius **Universal Animation Library** [Standard], `UAL1_Standard.glb` (`tools/art3d/vendor/ual/UAL1_Standard.glb`, sha256 `69591853…c4ed67997`) | the 65-bone UE5-mannequin skeleton every 3D rig is built on (bone names, directions and rolls kept, lengths re-proportioned) and the locomotion / utility clips retargeted and baked into `game/art3d/anim/**` | https://quaternius.com/packs/universalanimationlibrary.html → https://quaternius.itch.io/universal-animation-library (`tools/art3d/vendor/ual/License_UAL1.txt`) | CC0 1.0 |
| Quaternius **Universal Animation Library 2** [Standard], `UAL2_Standard.glb` (`tools/art3d/vendor/ual/UAL2_Standard.glb`, sha256 `8cee20ab…7d54d7ab88a8`) | further source clips (same skeleton) retargeted and baked into `game/art3d/anim/**` | https://quaternius.itch.io/universal-animation-library-2 (`tools/art3d/vendor/ual/License_UAL2.txt`) | CC0 1.0 |

Models by @Quaternius — https://www.patreon.com/quaternius

A task that adds another third-party input asks the orchestrator (who owns this file) to add its row: file, use,
source URL, licence.
