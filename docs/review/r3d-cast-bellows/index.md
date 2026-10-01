# r3d-cast-bellows: review index

Horace Bellows in 3D: look A (Toy Box) with the board's fixes. Unless a line says otherwise, every render goes through
the game's own `RigPlayer3D` + `char_toon` at the base framing (1200×540, FOV 30°, KEEP_HEIGHT), where he stands
about 233 px tall. Final mesh (fix pass, 2026-10-01): 8,755 tris (≤ 9,571 with the largest bouffant variant attached),
90 bones of which 50 carry skin weight (jiggle and prop / FX bones included, as RigPerf3D counts them), 1.781 m to the
top of the bouffant. The boards below are the P2 renders; `fixpass_before_after.png` shows the fix pass changes nothing
visible.

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
| `fixpass_before_after.png` | Fix pass (index row 17): the P2 build (5fd4911) next to the budget build, same clip frames and cameras: game cam idle, sneeze f94 and f110; face cam pompous and sneeze_choo; act_tea f420; bit_livid fists; act_hunt curls; the flipped / frazzled / wet variants from q34, the back and above; sneeze build f70 from the side | He looks the same. Only hidden geometry is gone: the shirt under the coat, the hip ends of the legs and the elbow ends of the cuffs (inside the barrel / sleeve), variant faces buried in the head below the open crown, and a 48-tri tea disc. Weights: the ring finger rides the middle finger's bones (on its own segments), the thumb is rigid on thumb_01, and the neck stub blends spine_03 → Head. Tried and reverted, because they showed: rigid fingers (stiff fists), the sleeve shoulder cap (a gap with the arms up in bit_livid), the spat sole (side view), the sibling-lobe cull on the variants (lost creases and a gap), and the cull above the crown opening (back view). |
