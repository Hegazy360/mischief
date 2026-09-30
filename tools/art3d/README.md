# art3d — 3D pipeline sources (look-dev phase)

Sources from the 3D pivot spike and the "Toy Box" look-dev (see `docs/REDESIGN_3D.md`, `docs/review/lookdev/`).
Blender 4.5 LTS headless (`/opt/blender`, from download.blender.org) builds props and characters in Python on the CC0
Quaternius Universal Animation Library skeleton and exports .glb; Godot 4.7.2 (Compatibility renderer) renders them with the
toon + outline shaders.

- `spike/` — character builder (`build_char.py`), glTF skin/animation test, Godot test scenes and shaders.
- `diorama/` — the simplified two-room set (Blender prop builders, palette, Godot scene builder, shot tools).
- `look-toy/` — the Toy Box characters (Hush, Bellows): modelling, face decals, clips, board scripts.
- `SOURCES.txt` — every third-party CC0 asset (URL + licence). Assets are downloaded, not committed:
  `itch_free_dl.py` (free-tier itch.io), `gdrive_ls.py` (public Drive listing), `glb_info.py` (inspect a .glb).
