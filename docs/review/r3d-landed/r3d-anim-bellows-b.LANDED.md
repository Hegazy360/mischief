# r3d-anim-bellows-b — LANDED
2026-09-30T19:21Z START (queue launch, priority 6). Time box 10 h (R19: cut line at 7.5 h active). List: FINAL bit_warmup, bit_tea, st_head_turn, st_double_take, st_specs_on; then st_suspicious, st_look, st_look_back, st_smirk, st_straighten_cravat, mg_hum, mg_trill, mg_conduct_air, mg_admire_reflection_horn, mg_pinkie_up, mg_admire_in_kettle, mg_comb_flourish, mg_cravat_tug, mg_walk_hum, mg_walk_scale.
DONE bellows/bit_warmup 2b1062d9e79d3f8b3b52c3d922dc73c07fa38dde88d1f0b3a7333a439eabb65e
DONE bellows/bit_tea 6bf66d5c7b47c33052847ae93a1ca938b9d345bd83504245de05eadb1f2ff4db
19:55Z LANDED bellows/bit_warmup (90 f, lock sim, base, FINAL) + bellows/bit_tea (100 f, lock sim, base, on the stool, FINAL) — tools/art3d/anim/bellows/<clip>.py → game/art3d/anim/bellows/<clip>.res + game/data/anim/bellows3d/<clip>.json, lint --strict clean; staged (bit_warmup st_gramophone x 8.65 z -1.4 facing -1 cheat 35; bit_tea tea_stage()); face beats baked to the camera + sidecar gaze (D8); own sounds (no audio-table row: bit_warmup 8 vo_bellows_yodel, 46 vo_bellows_the_pipes; bit_tea 4 tea_slurp, 17 vo_bellows_pff, 28 vo_bellows_ugh, 58 sniffle) for r3d-integrate. MAP ROWS for -a: none needed (clip_rules bit:* → bellows/{id}).
DONE bellows/bit_warmup 0d8f02624ffb982b20a2d4d5e34fdc20f36a1e597a54cf3334c2237137eaff94
DONE bellows/bit_tea e6d03f758c5b5636f1eb13d1186bfbdcbfb512bb727841f1bf58e0d67471a5cc
DONE bellows/st_head_turn 69282d52379ee61c1f299b74d77beceb7d9dcf7bca6a4a8d4bf1d379b386acf0
DONE bellows/st_specs_on fc555e553364ef7e961dbb7abf176bf9e87e1c4e42e1e572d90312aef346871d
DONE bellows/st_double_take 7d0bce6da18f49c1fa9ca53f3ddb690ed22d1495f7bdd6f910b8ee215980a798
20:06Z LANDED (FINAL) bellows/st_head_turn (60 f overlay head, lock sim: the listening ear-cock, facing-proof), bellows/st_specs_on (12 f overlay upper: specs slapped on at f4 = prop show specs), bellows/st_double_take (18 f base, ends on a held take: gloves out palms-front, eyes popped — the N1/N2 reaction fallback); bit_warmup + bit_tea re-baked: every key carries the FX bones (fx_choo/fx_stars/fx_notes) at scale 0 (an overlay's unkeyed rest scale showed the CHOO puff + stars). All lint --strict clean. Event-level sounds (cues.json: head_turn huh, specs tink, spotted wha) are NOT duplicated in the clips (L12).
DONE bellows/st_suspicious 028113498385f7b6d45179f457c64ab85888a702869bdbd43578a06ab38d2f99
DONE bellows/st_look 5833ed933f81bfec9ed9253038de07b54f506a59227487bf7b76a0252ad4bb25
DONE bellows/st_look_back 376677c969e2ec34e596ce528602518f44217ac732b22343c06a24dec273aa8b
DONE bellows/st_smirk 2e72ebdc3da3162e450a91b0c0b71aea7ee9362fc4579ff26d0744ec6f4a4bfb
DONE bellows/st_straighten_cravat 4f3d12a147c2649fe4e4757a597a22812edb4991846f8b595bcaf71fb37a0835
20:16Z LANDED bellows/st_suspicious (60 base: halt, sniff, chin-out lean-in + chin stroke), st_look (180 loop base: peer left / right / floor + shrug; specs from the sim state), st_look_back (60 base: a double look back over BOTH shoulders so one always gives the face to the camera), st_smirk (30 overlay upper: the smug belly-pat chuckle), st_straighten_cravat (60 loop base: the doorway-pause cravat tug, own sfx cravat_tug f14) — lint --strict clean.
