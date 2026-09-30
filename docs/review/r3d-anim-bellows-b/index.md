# r3d-anim-bellows-b — Bellows' bits, one-shots and micro-gags in 3D (20 clips)

Owner key `r3d-anim-bellows-b` (brief `r3d-anim-bellows.md`, index §5.3). Every clip: spec
`tools/art3d/anim/bellows/<clip>.py` → `game/art3d/anim/bellows/<clip>.res` + `game/data/anim/bellows3d/<clip>.json`,
lint `--strict` clean, no drafts. All boards are 1:1 crops of 1200×540 frames rendered at a fixed 60 fps
(`capture.sh`, Movie Maker) — judge them at phone scale.

| artefact | what it shows | what to judge |
|---|---|---|
| `rubric.md` | TECH §11 rubric per clip with frame numbers; funny / readable / fresh scores; the known weak spots | is every non-draft ≥ 3? |
| `boards/bits.png` | the two squeak bits at the game camera in the real P00 set, every 6 f: `bit_warmup` at the gramophone, `bit_tea` on the stool (accent cells outlined red) | crack → yodel → wind-up → collar clutch → "…the pipes"; the sip → the SNORT (legs kick, saucer flung) → splutter → glare; is the ×1.8 cup readable in every tea cell? |
| `boards/ingame_bit_warmup_pip.png` | `bit_warmup` as the player sees it in P00 (ViewSandbox3D, the real sim, the ideal route): in the Bellows window while Hush is in the kitchen, every 6 f | does the bit read at window size (≈ 200 px)? |
| `boards/ingame_p00_warmup_mute.gif` | the same in-game stretch (P00 sim ticks 120–450, mute): the horn micro-gag, the squeak bit in the window, the walk to the tea | the whole beat in motion |
| `boards/oneshots.png` | the eight one-shot / state clips at the game camera in the parlour lane (facing −1): head turn (with a look-at to the camera = the intended runtime gaze), specs on, double take (look-at), suspicious, look, look back, smirk, the doorway cravat pause | does each read in half a second? is the face on the house when it matters (D8)? |
| `boards/microgags.png` | the ten micro-gags each OVER ITS ACTIVITY: -a's `act_warmup` (hum, trill, conduct, horn), `act_tea` at f420 (pinkie) and f120 (kettle, head mask), `act_fixup_mirror` in the hall (comb), `loco_strut` (cravat tug, walk hum, walk scale) | a readable gag, not a twitch? does the overlay fight its base? |
| `sheets/<clip>_{contact,onion,curves,sil64,phone}` + `_lint.txt` | r3d-rig's 3D review sheets for the 7 BASE clips (bits, double take, suspicious, look, look back, cravat pause) and the lint of all 20 | spacing, arcs, holds. The sheet tool fails on overlay clips (request to r3d-rig), so the 13 overlays are reviewed in the boards; its phone strip always faces +1 at z −1.0, so the clips staged facing −1 turn their baked camera look away there — use the boards for staging |
