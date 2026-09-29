# Bellows art sources

Every SVG in `game/art/chars/bellows/{parts,face,props,residue}/` and the rig data in
`game/data/rigs/bellows/{rig,poses,faces}.json` are GENERATED. Do not hand-edit them.

    python3 tools/art/bellows/build.py      # regenerate every SVG + rig/poses/faces.json (deterministic)
    python3 tools/art/bellows/validate.py   # SVG rules, schema, refs, mirror pairs, residues, FK checks
    python3 tools/art/bellows/preview.py --out <dir>   # review sheets (poses, expressions, residues, temper, ...)

Generators: `parts_body.py` (torso, belly, tails, cravat, hands, slippers), `parts_head.py` (head, nose,
bouffant x7, sideburns), `parts_face.py` (eyes, pupils, lids, brows, mouths, overlays), `parts_props.py`,
`parts_residue.py` (residues, costumes, combos), `rig_spec.py` (hierarchy, offsets, z, springs, sockets, tint),
`poses_spec.py`, `faces_spec.py`. This folder is Godot-ignored (`.gdignore`).
