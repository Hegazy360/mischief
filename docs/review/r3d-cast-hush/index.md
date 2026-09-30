# r3d-cast-hush — review index

Hush in 3D: look B's body (1.60 m, B's joints, B's head) built in look A's Toy Box vinyl style. All renders 1200×540
unless noted; "game runtime" = the game's own `AnimViewer3D` (RigPlayer3D + char_toon + outline 4.8 px @1080, D7) in
r3d-sets' n01 set; "scratch studio" = the private look-A project in `<SP>/work/r3d-cast-hush/proj` (char_toon copy).

| Artefact | What it shows | What to judge |
|---|---|---|
| `reach_proof.png` | P1: IK at B's arm lengths, front + side, the four reach bands at their placed targets (stool 0.387 m, lever 0.243, mime step 0.415, kneel 0.330; bar ≤ 0.50) | Do B's arms reach every band? (yes, 4/4) |
| `hybrid_vs_ab.png` | P1: look A's Hush, the hybrid, look B's Hush at the same framing (studio + kitchen) | Is the hybrid B's body in A's style? (P1 render: stripes were widened at P2 for the value rule) |
| `turnaround.png` | Front, 3/4, side, back on the game runtime | Silhouette, proportions, the beret / bob / gloves / braces read from every side |
| `ingame_kitchen.png` | Hush and Bellows v-current in the kitchen at base framing, 1× and 2× | Distinct at a glance (lanky dark stick + white gloves vs silver puff on a plum barrel)? Warm, cheeky? |
| `head_check.png` + `head_check.json` | R6: B's head vs ×1.1–1.3 measured at 1200×540 (head, face card, eye white, pupil, mouth, brow), the six test faces at 1× and 3× in four conditions | Step 1 fails (head 54.5 px < 60); ×1.2 is the smallest scale passing every bar with the face given to the camera |
| `faces_26.png` | Every preset on B's head, 3× crops of base-framing renders (face given to the camera) | Does every preset read, and differ from its neighbours (sneak vs smug, fear vs shock)? |
| `faces_game.png` | The six test faces at 1× on the game runtime: B's head and ×1.2, bare cheat 35 and head to camera | The phone-scale read the owner will see |
| `poses.png` | Tiptoe crouch, run lean, reach high (stool + pepper pot at the jar), reach mid (gramophone lever), reach low (kneel), marble statue, peeking eyes in a dark gap, squeak, snicker glance, bow — 2× crops of base-framing game-runtime renders | Do the verbs read? Note the reach-high staging finding (the pot is hidden behind her head as placed) |
| `silhouettes_64.png` | The same poses as black masks at 64 px + pairwise IoU (scratch studio masks) | Distinct families? (no pair ≥ 0.80; closest idle / reach-mid 0.68, idle / snicker 0.66) |
| `value_check.png` | REDESIGN §3.7 value rule with `lab.py value` + falsecolor: flat-lit (the rule), flat + outline, game runtime | Flat-lit 25.8 % ≥ 85 / 55.1 % ≤ 40 PASS; with the outline 20.6 / 63.1 PASS; toon-shaded in the kitchen 19.5 / 67.5 (at the bar) |
| `stone.png` | Colour vs marble statue (stone 1, keep mask = eyes, beret, braces) and the plinth | Does the marble read as a statue with her eyes still alive? |
| `reviewer_prompt.md` + `packets/faces_{b_c35,b_face,hb_c35,hb_face}/` | R17 fresh-reviewer read test packets (6 unlabelled 1× crops each; keys outside the repo) | For the orchestrator to run; pass = ≥ 5/6 and no confused pair |
