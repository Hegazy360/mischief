# art-bellows — Horace Bellows review sheets

Everything is generated: `python3 tools/art/bellows/build.py` (SVGs + rig/poses/faces.json),
`python3 tools/art/bellows/validate.py` (rules + FK checks), `python3 tools/art/bellows/preview.py --out <dir>`
(these sheets, Python FK compositor), `tools/scripts/anim_sheet.sh bellows --poses|--rig <dir>` (the game's own
RigPlayer). Every sheet has a `_phone.png` copy at 1200 px wide. PNGs are palette-quantised.

| file | what it shows | what to judge |
|---|---|---|
| `phone_scene.png` | TRUE phone scale: a 2400×1080 logical frame at 1200×540 — stand, wild take, soaked slow burn, CHOO at tier 2, tutu on pointe, frazzled blind bumble, livid meltdown with specs on, Hush beside him | Does he read and is he funny at the real size? (He is ~35 % of screen height.) |
| `rest.png` | rest pose `b_stand`, the joints (red dots), every part texture with its pivot | proportions: "a dandelion clock on a barrel", 382 px tall, head ≈ 140 |
| `poses.png` / `_phone` | all 80 poses (72 binding + 8 extras), each with a solid-black 50 px silhouette, airborne poses lifted into view | takes pop (antic → accent bbox +74 %), sneeze rule of three, slow burn stare, no hand over the eyes |
| `engine_poses_phone.png` | the same 80 poses rendered by the game's `RigPlayer` via `anim_sheet.sh` ("errors: 0") | the data is consumed as intended (FK, limbs, lids, face presets, specs on the chain) |
| `engine_rig.png` | the game's rig sheet: 34 parts (13 face slots), every texture, pivots (red +), sockets (blue ●) | pivots / sockets land where the art expects |
| `expressions.png` / `_phone` | the head at ~1.5× for all 36 `faces.json` presets | wild take vs shock vs terrified escalate; slow burn = flat half-lidded stare at the Stalls; the singing O in 3 sizes |
| `residues.png` / `_phone` | clean + the 7 residues, FRAZZLED-blind, the 7 COSTUME variants and the 4 combos, on the slow-burn pose (tutus on pointe) | soaked (wet comb-over on a shiny dome) vs floured (ghost white) vs frazzled (spiky star) read instantly; face stays readable |
| `temper.png` / `_phone` | Calm / Irked / Steaming / Livid tints on head, nose, hands and lids (peach → salmon → red → beetroot `#B8324B`), with the sideburn tells (flat / bristle / bristle / puffed) and specs jammed on at Livid | the Livid face still reads (face slots are never tinted) |
| `props.png` / `_phone` | every prop state (specs dangling/on/buttered/magnifier, teacup, newspaper closed/open, comb, baton, phone handset, kipper, pickled onion, kettle lid, jelly helmet, sausage boa, megaphone) + 12 poses holding them | grip orientation, props at the lips / cheek / nose read |
| `scale.png` / `_phone` | Bellows (382 px) beside Hush (her real rig, 340 px) with rulers | cast scale and style match |

## Self-assessment
- **Funny, not grotesque:** pompous rest (chest out, chin up, hands behind his back), a potato nose, fluffy mutton
  chops, a gold cravat and a straining shirt front. The laughs are in the takes: the bouffant leaping clean off his
  bald dome on the wild take, the wet comb-over, the tutu on pointe, the dough-ball head, the poodle pom-pom.
- **Readability:** eyes 30×34 px whites, pupils 17/15 px, 8–9 px brows, open mouths 40–64 px wide. Raised near
  arms go up-and-back; hand-to-face gestures use a folded arm below the eyes.
- **Weak spots:** idle/activity silhouettes are similar at 50 px (barrel + cloud — the takes differ strongly);
  stride is short (48 px legs); `b_sneeze_choo` is a flat forward lunge; long johns and the STICKY spoon are small
  at phone scale; hand-to-face poses (phone, tea sip, preen) cover the lower face.
