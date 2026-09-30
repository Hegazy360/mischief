# art3d — 3D pipeline sources

Sources from the 3D pivot spike and the "Toy Box" look-dev (see `docs/REDESIGN_3D.md`, `docs/review/lookdev/`).
Blender 4.5 LTS headless (`/opt/blender`, from download.blender.org) builds props and characters in Python on the CC0
Quaternius Universal Animation Library skeleton and exports .glb; Godot 4.7.2 (Compatibility renderer) renders them with the
toon + outline shaders.

- `setup_blender.sh` — (re)installs Blender 4.5.14 LTS into `/opt/blender` (sha256-checked, idempotent, locked); run it
  once when Blender is missing after a container restart.
- `blender.sh` — headless Blender through a CPU slot: `tools/art3d/blender.sh --python <script.py> -- <args>`
  (`-b --factory-startup --threads 1`, via `tools/scripts/slot.sh`). Every R3D Blender run goes through it.
- `vendor/ual/` — the vendored CC0 build inputs `UAL1_Standard.glb`, `UAL2_Standard.glb` + their licences and
  `SHA256SUMS` (credits: `game/art3d/CREDITS.md`). Build inputs only; never copied under `game/`.
- `cache/` (gitignored) — regenerated look-dev `.glb`s and other build intermediates.
- `spike/` — character builder (`build_char.py`), glTF skin/animation test, Godot test scenes and shaders.
- `diorama/` — the simplified two-room set (Blender prop builders, palette, Godot scene builder, shot tools).
- `look-toy/` — look A, the Toy Box characters (Hush, Bellows): modelling, face decals, clips, board scripts;
  `look-toy/proj/` is its Godot project (`toy/toy.gdshader` = the template for `char_toon`, `toy/toy_char.gd` = the face
  driver).
- `look-cartoon/` — look B, "Saturday Cartoon": `src/*.py` (builders), `chars/{hush,bellows}_{meta,faces}.json`,
  `numbers.txt`, `NOTES.md` — the owner's binding reference for Hush's dimensions (R3D: "Prankster dimensions from B").
- The four look-dev folders are **frozen references** (R3D index §4); their scripts may still point at the scratch
  copies they were written against.
- `SOURCES.txt` — every third-party CC0 asset (URL + licence). The look-dev assets are downloaded, not committed:
  `itch_free_dl.py` (free-tier itch.io), `gdrive_ls.py` (public Drive listing), `glb_info.py` (inspect a .glb).
