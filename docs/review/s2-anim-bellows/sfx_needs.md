# s2-anim-bellows — sound ids I need (for `s2-sound`)

**Phase G: none missing.** Every sound inside the Phase-G clips is a row of `docs/review/s2-sound/clip_events.md`
(the machine copy `game/data/audio/clip_events.json`), placed on its contact frame ± 1 f, and every id resolves in
`game/audio/sfx_map.json` (checked by `game/tests/anim/test_bellows_clips.gd::test_sounds_are_the_clip_event_rows`).

Frames I own that the table mirrors (so a re-time on either side stays in sync):
- `bellows/act_tea` (480-f loop, sip lip contact f388, the ACHOO-RIA! trigger f420): kettle_pour 40, spoon_clink 169,
  tea_stir 182, spoon_clink −3 dB 243, tea_sniff 270, tea_slurp 388, teacup_clink 462, stool_creak −2 dB 472.
- `bellows/act_warmup` (1200-f loop, your phase-locked recommendation): phrase 1 f0 + nudges 5/15/25/35/46,
  phrase 2 f600 + nudges 604/616/628.

Non-sound events the view should stage (not yours; listed so nothing doubles up): `fx` `drops` at the CHOO (f94, from
the nose), the splash (f112) and the tea poured into his hair (f142); `spring` kicks on the bouffant (f94) and the
belly (f112); `decor` `kitchen_stool` / `kitchen_sink_lip`; `shake`, `hitstop`, `cam` punch at f94.

Phase M will add rows here as they come up (squeak bits, one-shots, the Lecture, the Meltdown).
