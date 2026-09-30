# r3d-anim-bellows-b — Bellows' bits, one-shots and micro-gags in 3D (20 clips)

Owner key `r3d-anim-bellows-b` (brief `r3d-anim-bellows.md`, index §5.3). Every clip: spec
`tools/art3d/anim/bellows/<clip>.py` → `game/art3d/anim/bellows/<clip>.res` + `game/data/anim/bellows3d/<clip>.json`,
lint `--strict` clean, no drafts. Judge everything at 1200×540 (the phone held sideways).

| artefact | what it shows | what to judge |
|---|---|---|
| `rubric.md` | TECH §11 rubric per clip with frame numbers; funny / readable / fresh scores; the known weak spots | is every non-draft ≥ 3? |
| `boards/bits.png` | the two squeak bits at the game camera in the real P00 set: `bit_warmup` at the gramophone, `bit_tea` on the stool (every 6 f) | the crack → yodel → throat clutch → "…the pipes"; the snort with the legs kicking and the saucer flung; is the ×1.8 cup readable in every tea cell? |
| `boards/ingame_bit_warmup_pip.png` | `bit_warmup` as the player actually sees it in P00: in the Bellows window while Hush is in the kitchen (ViewSandbox3D, the real sim, the ideal route, fixed 60 fps) | does the bit read at window size (≈ 200 px)? |
| `boards/oneshots.png` | the eight one-shots / state clips (head turn, specs on, double take, suspicious, look, look back, smirk, cravat pause) at the game camera | does each read in half a second? is the face on the house when it matters (D8)? |
| `boards/microgags.png` | the ten micro-gags each OVER ITS ACTIVITY (-a's `act_warmup`, `act_tea` at f420 / f120, `act_fixup_mirror`, `loco_strut`) | readable as a gag, not a twitch? does the overlay fight the base? |
| `sheets/<clip>_{contact,onion,curves,sil64,phone,lint}` | r3d-rig's 3D review sheets per clip (side profile, onion skin, curves, 64 px silhouettes, a phone strip, the lint) | spacing, arcs, holds; NOTE the sheet's phone strip always faces +1 and z −1.0, so the clips staged facing −1 (bits, warm-up and tea micro-gags) turn their baked camera-look AWAY in that strip — use the boards for staging |
