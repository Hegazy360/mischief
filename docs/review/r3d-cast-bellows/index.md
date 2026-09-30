# r3d-cast-bellows: review index

Horace Bellows in 3D: look A (Toy Box) with the board's fixes. Unless a line says otherwise, every render goes through
the game's own `RigPlayer3D` + `char_toon` at the base framing (1200×540, FOV 30°, KEEP_HEIGHT), where he stands
about 233 px tall. Final mesh: 9,155 tris (≤ 9,971 with the largest bouffant variant attached), 90 bones (49 deform +
9 jiggle), 1.781 m to the top of the bouffant.

| Artefact | What it shows | What to judge |
|---|---|---|
| `turnaround.png` | Front, 3/4, side and back, UAL Idle arms + the `arm_out` layer | The three-lobe dandelion reads as styled hair, not a cloud. The face sits clear of the hair. The arms clear the barrel. |
| `before_after.png` | Look A look-dev next to this build, front and in the kitchen at the same pixel height | Owner complaint 2: does he look better at game size (bigger face, smaller nose, cup that reads)? |
| `ingame_kitchen.png` | r3d-sets' kitchen (p00): tea on the stool with Hush beside him | Complaints 1-4 at 1200×540: is the room still readable with him in it, and does the tea beat read? |
| `ingame_kitchen_hold.png` | The same room, standing with the teacup + saucer held | The ×1.8 china reads against the plum coat and the white gloves. |
| `reach_proof.png` | P1 proof at SKELETON FROZEN (scratch studio shader, P1 blockout mesh): sip, 0.25 m in front of the belly, comb over the bouffant top, seated kettle/jar | Every reach is solved with `arm_out` on and grip error 0. The skeleton is unchanged since then, so the numbers still hold. |
| `faces_45.png` | All 45 presets (2D names) on the face card, 3× game scale | Each preset reads alone. The blink/lids layer is tint-safe (no pale band at tiers 3-4). |
| `faces_game.png` | The six read-test faces at 1× game scale (cheat 35), then the same pixels ×3 | The honest game-scale view. At the bare cheat the far eye hides. See `face_turn.png`. |
| `face_turn.png` | The six faces at 1× in the kitchen, cheat 35 alone vs cheat 35 + `look_at_point(camera)` | The main finding: face beats need the head turned to the camera (request to r3d-view3d / r3d-anim-bellows). |
| `tint_tiers.png` | Temper tiers 0-3 + livid on one face, then the tier faces at 1.5× | The body is the meter: the tiers step clearly, livid (#B8324B) is distinct, the specs go on at livid. |
| `props.png` | Teacup + saucer, sip, tea on the stool, honey spoon, comb, baton, specs, at 1× and 2× | Every held prop reads at 1× (C* ≥ 45 gold band on the cup, red comb, white baton). |
| `looks.png` | Bouffant slot: neat, flipped, FRAZZLED, BLINDED, SOAKED, FLOURY at 1.6× | Each residue look is readable at a glance. The flipped mop covers the eyes (the BLINDED gag). |
| `choo.png` | The vinyl CHOO puff (fx_choo) on the stool at the base framing and the 1.4× punch-in | The puff is the beat: big, white, it hides his face and it reads as a sneeze. |
| `stars_notes.png` | Dazed stars and orbiting notes at base and punch-in | Both FX rings read above the bouffant. They are clip-driven (the ring bone spins). |
| `portraits.png` | The 15 HUD portraits (256 px RGBA) + the same at 64 px | Each HUD mood is distinct at 64 px (tint + eyes carry it). |
| `silhouettes_64.png` | 64 px silhouettes of the proof poses: idle, strut, tea_seat, choo, dazed_sink | IoU: idle×strut 0.81, strut×tea_seat 0.83 (≥ 0.80 flagged). These are proof poses; the clips belong to r3d-anim-bellows. |
| `value_check.png` | `lab.py value` on a flat-lit render (game framing + front) | L* ≥ 85: 33.4 % / 37.2 %; L* ≤ 40: 44.8 % / 40.6 %. PASS (≥ 20 % each). |
| `packets/faces_c35/`, `packets/faces_face/` + `reviewer_prompt.md` | Opaque read-test packets (R17 fallback) | **Pending review.** The orchestrator runs one fresh reviewer per packet. |
