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
DONE bellows/mg_hum 03475e598f327463f693fba998599e4be542210073fdfeb2f3e3601bb70c7d4b
DONE bellows/mg_trill e6f529a4be38953bcfb396f12a3caca00d1688916e49e248bdea6c0c40c59e28
DONE bellows/mg_conduct_air 9bf4c38a7e6642637cff3836cabb234f9199430e4e4ef3d88d43d984b147edbf
DONE bellows/mg_admire_reflection_horn da396b5cdbf4a6cfe271fd80c1193423e624049514ba3b97491b7f76767ab892
DONE bellows/mg_pinkie_up 7e8ec908afb95719773293d9b7a0b25328447985aaa356ce6e250a0d3e969bfc
DONE bellows/mg_admire_in_kettle 4aaebf2ab43b8838cd3001dfe303e07a85eb8373614e0587fb1d51b82eeafd33
DONE bellows/mg_comb_flourish a5b2e1bc32aa4e8b0f9ba25107919a20a87dc19043da30f14ab7464a68f8e976
DONE bellows/mg_cravat_tug 2932130d4c73e02ce969bdeacbd83dbdee7464188d0d5c724cbdb4da85d9830b
DONE bellows/mg_walk_hum 1496bc8e72e6f66127d66874e26eb75d39330456d9bb65d09a67ece8efae8c9c
DONE bellows/mg_walk_scale 9875e28b5234927fff5772f05d09d54c138d9455cd5a2b3248ae7f4960c25b14
20:28Z LANDED the 10 micro-gags (overlays; warm-up 4 + tea 2 staged at st_gramophone / the stool with their audio-table rows; mg_comb_flourish at st_hall_mirror facing +1; walking 3 facing-proof, own sounds): all lint --strict clean. mg_admire_in_kettle is authored for mask head (the mg fires at tea 2.0 s = act_tea f120, the honey beat) — see REQUESTS. ALL 20 CLIPS OF THE LIST BAKED (no drafts).
DONE bellows/bit_warmup 60a37c1ce16fb0093bc80d47c58051b617524a94127d966ed1e704b880f17ba0
DONE bellows/mg_admire_in_kettle ed0423f9d2b79699a63011c60c9599f8782c713c7bada821b10401ed1fb496af
DONE bellows/st_straighten_cravat bac054f24bfbba98e07cbfa097b8daa4a52774deddd9468c615fc294b9dcd7f3
21:29Z FINISH — all 20 clips final (no drafts; R19 cut line 02:51Z never reached). Current DONE set (the spec sha256 of every clip as landed):
  DONE bellows/bit_warmup 60a37c1ce16fb0093bc80d47c58051b617524a94127d966ed1e704b880f17ba0
  DONE bellows/bit_tea e6d03f758c5b5636f1eb13d1186bfbdcbfb512bb727841f1bf58e0d67471a5cc
  DONE bellows/st_head_turn 69282d52379ee61c1f299b74d77beceb7d9dcf7bca6a4a8d4bf1d379b386acf0
  DONE bellows/st_specs_on fc555e553364ef7e961dbb7abf176bf9e87e1c4e42e1e572d90312aef346871d
  DONE bellows/st_double_take 7d0bce6da18f49c1fa9ca53f3ddb690ed22d1495f7bdd6f910b8ee215980a798
  DONE bellows/st_suspicious 028113498385f7b6d45179f457c64ab85888a702869bdbd43578a06ab38d2f99
  DONE bellows/st_look 5833ed933f81bfec9ed9253038de07b54f506a59227487bf7b76a0252ad4bb25
  DONE bellows/st_look_back 376677c969e2ec34e596ce528602518f44217ac732b22343c06a24dec273aa8b
  DONE bellows/st_smirk 2e72ebdc3da3162e450a91b0c0b71aea7ee9362fc4579ff26d0744ec6f4a4bfb
  DONE bellows/st_straighten_cravat bac054f24bfbba98e07cbfa097b8daa4a52774deddd9468c615fc294b9dcd7f3
  DONE bellows/mg_hum 03475e598f327463f693fba998599e4be542210073fdfeb2f3e3601bb70c7d4b
  DONE bellows/mg_trill e6f529a4be38953bcfb396f12a3caca00d1688916e49e248bdea6c0c40c59e28
  DONE bellows/mg_conduct_air 9bf4c38a7e6642637cff3836cabb234f9199430e4e4ef3d88d43d984b147edbf
  DONE bellows/mg_admire_reflection_horn da396b5cdbf4a6cfe271fd80c1193423e624049514ba3b97491b7f76767ab892
  DONE bellows/mg_pinkie_up 7e8ec908afb95719773293d9b7a0b25328447985aaa356ce6e250a0d3e969bfc
  DONE bellows/mg_admire_in_kettle ed0423f9d2b79699a63011c60c9599f8782c713c7bada821b10401ed1fb496af
  DONE bellows/mg_comb_flourish a5b2e1bc32aa4e8b0f9ba25107919a20a87dc19043da30f14ab7464a68f8e976
  DONE bellows/mg_cravat_tug 2932130d4c73e02ce969bdeacbd83dbdee7464188d0d5c724cbdb4da85d9830b
  DONE bellows/mg_walk_hum 1496bc8e72e6f66127d66874e26eb75d39330456d9bb65d09a67ece8efae8c9c
  DONE bellows/mg_walk_scale 9875e28b5234927fff5772f05d09d54c138d9455cd5a2b3248ae7f4960c25b14
  Changes since the first DONE lines: st_straighten_cravat 60 → 92 f (the doorway pause is 90 − eta + 1 ticks and the view frame-locks one-shots without wrapping); mg_admire_in_kettle restaged (11 f glance at the kettle, the wink played to the house); bit_warmup clutch keeps the face clear. Verify: bake --strict all OK; lint_anim --format=3d --rig=bellows --scope=g0,p00 --strict 42 clips 0 errors; anim3d/test_bellows 9/9 (0 skips); full suite 1496/1496 (21:15Z, before the cravat re-length; anim3d/ re-run after it: only r3d-anim's hush/act_squeak L10 fails); lint.sh rc 0. Review: docs/review/r3d-anim-bellows-b/ (index.md, rubric.md, boards/, sheets/). Report: <SP>/reports/r3d-anim-bellows-b.md
REQUESTS (details in the report):
  r3d-rig → r3d-integrate: RigPlayer3D must honour sidecar "gaze" (look_at_point(camera, weight) over [f0,f1], base AND overlay) — D8 for every facing-proof face beat depends on it; sheet3d.gd fails on overlay clips (plan() null at line 126) and its phone pass ignores facing/z.
  r3d-view3d → r3d-integrate: _play_overlay should use the sidecar mask (mg_admire_in_kettle = head); the squeak noise-gaze turns his face away from the house (bias toward the camera); frame-locked loop one-shots are clamped, not wrapped.
  r3d-integrate: new audio-table rows for bit_warmup, bit_tea, st_suspicious, st_straighten_cravat, mg_comb_flourish, mg_cravat_tug, mg_walk_hum, mg_walk_scale.
  r3d-anim-bellows-a: map rows optional (everything resolves through default_maps/bellows.json).
