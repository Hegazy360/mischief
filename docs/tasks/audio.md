# Stage-1 brief: `audio` — procedural sound, Bellows' voice, the crowd, the pit orchestra, the Audio autoload

Half of slapstick is sound: the woodblock on the contact frame, the slide whistle on the fall, the crowd starting
to laugh at the top of the hold, a baritone bellowing "PIPE DOWN!", a rubber chicken's squeak against all that
pomp. Everything is synthesised by our own Python DSP (no samples), so it must be crafted with care and verified by
ear-proxies (spectra, loudness, onset timing) and by the owner's A/B choice.

## 1. Read first
1. `/home/user/mischief/CLAUDE.md`
2. `docs/GDD.md` §1.2 (voices of the cast), §2.3 (the Prologue sound beats), §5.6 (squeaks), §6.5 (laugh tiers +
   specials — binding), §9.5 (audio direction — binding), §10.4–§10.5 (A/B risks R5).
3. `docs/TECH.md` §5.8 (Audio API + cues — your contract), §3.8 (sim event names for `cues.json`), §9 (size budget),
   §12, §13, §14 (audio id conventions).
4. `docs/research/comedy.md` §3 (SFX palette, laugh tiers, adaptive music, gibberish voices — recipes and numbers).
5. Booby's proven pipeline to **port** (rename to Mischief; keep recipes that fit, drop Booby-specific ones):
   `/home/user/ideaboard/booby/tools/audio/{synth,registry,gen_audio,aliases,sfx_foley,sfx_musical,sfx_stings,
   sfx_voices,voice_lines,music}.py` and `/home/user/ideaboard/booby/game/autoload/audio.gd` (pool, buses, stems,
   ducking, no-repeat). numpy 2.4 and Pillow are installed; there is **no ffmpeg/oggenc** — output WAV and rely on
   Godot's import compression (QOA).

## 2. You own
- `tools/audio/**`, `tools/scripts/gen_audio.sh`
- `game/audio/**` (`sfx/`, `voice/`, `music/`, `sfx_map.json`), `game/default_bus_layout.tres`
- `game/autoload/audio.gd` (registered by the orchestrator after Stage 1; tests instantiate it)
- `game/data/audio/cues.json`
- `game/tests/audio/**`, `docs/review/audio/`

## 3. Specs
### 3.1 Pipeline
`python3 tools/audio/gen_audio.py` renders everything deterministically (seeded per sound name) to 22.05 kHz mono
16-bit WAV; `--check` verifies (every registered sound exists, durations/levels in range, no clipping, peak ≤ −1 dBFS,
loudness targets per category, `sfx_map.json` consistent); `--only a,b`, `--report`. `tools/scripts/gen_audio.sh`
wraps render + check. Music loops must loop sample-exact.

### 3.2 The slice sound set (≈ 60 SFX; ids `snake_case`)
Footsteps: Hush pizzicato tiptoe notes walking up a scale (8 notes), Hush run patter, Bellows slippers "fwip" on
wood / tile, stair creaks × 3. Doors: front door, back door, cupboard, door-handle jiggle. Treg-Brown kit: woodblock
bonk, boing × 3 (pitch by size), slide whistle up/down, whoosh/zip, crash + tail (300 ms silence then a pan spinning
to rest), record scratch, dizzy tweets, stamp thunk. Per slice prank/archetype: pepper shake, sneeze ah1/ah2/ah3 +
CHOO + stool zip, sink splash, spray-tap blast + hose wrestle, kettle squeak-melody + lid "boink", jar strain creak +
onion pop + pinball bonks × 3, slip whoosh + thud, gramophone speed-up screech + ×3 babble, recliner twang + catapult
whoosh + chandelier jingle + log-basket crash, newspaper rustle / rip, magnifier eye-balloon boing, fish flop + slap × 2,
phone ring, clock machine-gun chimes + pendulum smack, coat-stand spin, fridge avalanche clatter + jelly splat, mirror
glass lift, flour POOF, bellows pump, fire crackle. Stealth: "?" rising sting, "!" alert sting, harp glissando (near
miss), dive whoosh-thump, pop out, freeze woodblock "clack", door slam bonk, knocker bonk, tomato splat, curtain rise /
fall, roses thrown. Clarence: 5 squeak pitches + a falling wheeze (1.5 s) + a "smitten" double squeak. UI: tap tick,
button press, ring 50 % tick, rig-done ding, pause, card whoosh.

### 3.3 Voices (formant synth; phrase banks, never runtime singing)
- **Bellows** (`vo_bellows_*`, baritone f0 90–110 Hz, 5.5 Hz vibrato ±40 cents, drive on shouts; gibberish syllables,
  never real words except the shaped "PIPE DOWN!"): warm-up scales "MI-MI-MIII" × 6 (incl. the note that cracks into a
  yodel), short aria phrases × 6 (after public-domain melodies), "PIPE DOWN!" × 4, the Lecture (3 sung scoldings,
  2.2 s each, finger-wag rhythm), nonverbals × 12 × 3 (hmph, huh?, WHA!, yow, grr, ahem, ooh, hah, tut, pff, ugh, oof),
  sneeze parts, humming × 4, "…the pipes." × 2, "pardon" × 2, "WHO SQUEAKED?!" × 1, wheeze, dizzy babble; chipmunk
  (+12 st) variants of the aria/shout sets for SQUEAKY.
- **Fallback "talking tuba"** (`vo_bellows_tuba_*`): the same bank as a muted-brass instrumental voice following the
  same pitch/rhythm contours (the owner A/B-tests it in Gate 0). `Audio.set_voice_style("formant"|"tuba")`.
- **Hush has no voice:** her sounds are instruments (slide-whistle take, woodblock clack, breathy "hff-hff" silent
  laugh).
- Stage 3 will add Delphine and Beryl; keep the recipe structure ready (speaker presets).

### 3.4 The crowd (the Stalls)
Formant laughter tiers with ≥ 3 variants each: T0 titter (2–3 voices, 0.6 s, −18 dB), T1 chuckle (5–6 voices, 1.2 s),
T2 laugh (12–14 voices + one "HA!", 2 s), T3 laugh + applause (20+ voices, 3 s), T4 roar + whistles + stomps (4–5 s).
Specials: "Ooooh!", gasp, "Awww", "shhh", "BEHIND YOU!" (chanted, universal — no "oh yes he is"), the "PIPE-DOWN!"
chant, playful boo, relief laugh, curtain cheer. **Fallback crowd** set (applause-only, whistles, "ooh", a kazoo
"ha-ha" choir) with the same ids under `crowd_fb_*`; `Audio.set_crowd_style("formant"|"fallback")`.

### 3.5 Music (pit orchestra: piano, pizzicato, clarinet, bassoon, tuba, timpani, woodblock, slide whistle)
`mus_sneak` (pizzicato, sparse, 60–90 s loop) + `mus_suspense` (tremolo + ticking layer, same tempo and length —
played synchronised), `mus_chase` (an arrangement of Offenbach's *Galop infernal*), `mus_chain_1..4` (Grieg's *In
the Hall of the Mountain King* as four sections at stepped tempos: creeping bassoon + pizz → + clarinet → faster +
brass → full climax), `mus_curtain` (a 4 s overture sting for curtain up and the title slam), `mus_results` (a 20 s
curtain-call waltz loop). BPM and bar length recorded in `sfx_map.json` so chain switches land on bar lines.
Stingers (≤ 1.5 s): `sting_rigged` (ding + 3 pizz), `sting_bit` (rim-shot), `sting_fizzle` (tuba wah-wah),
`sting_caught` (sad trombone), `sting_near_miss` (harp), `sting_combo` (brass), `sting_new` (celesta),
`sting_meltdown` (timpani roll + kettle whistle), `sting_link2`, `sting_link3` (rising brass).

### 3.6 `autoload/audio.gd` (TECH §5.8, exactly)
`play_sfx(id, pan, vol_db, pitch)`, `play_voice(bank)` (random variant, never the same file twice in a row),
`crowd(kind)`, `music_state(state)` (curtain, sneak, suspense, chase, results, silence — crossfades; sneak/suspense
via `AudioStreamSynchronized`), `chain_section(n)` (switch on the next bar), `sting(id)` (ducks Music −6 dB for its
length), `set_bus_volume(bus, linear)`, `has_sfx(id)`, `set_voice_style`, `set_crowd_style`. Buses in
`default_bus_layout.tres`: Master ← Music, SFX, Voice, Crowd, UI; Crowd ducks −6 dB under Voice. Volumes follow
`Settings` keys `music_vol, sfx_vol, voice_vol, crowd_vol` (soft: `has_method`). SFX pool of 12 players (voice-stealing
by age), 3 voice players, 2 crowd players. Unknown ids are silent no-ops (debug warning once). Sounds resolve through
`sfx_map.json` aliases.

### 3.7 `data/audio/cues.json`
Maps sim events (TECH §3.8 names) to actions for the view's AudioDirector: e.g. `rigged → sting_rigged + crowd t0`,
`spot_start → "?" sting + music suspense`, `near_miss → sting_near_miss + crowd relief`, `caught → sting_caught +
crowd aww`, `prank_fire` (per archetype: the prop SFX set), `running_gag {link} → chain_section(link)`,
`meltdown_start → sting_meltdown + crowd chant`, `entry_warning → door jiggle + footsteps`, `squeak → clarence squeak`,
`squeak_bit → per-bit SFX + sting_bit`; plus `laugh_tiers` thresholds (T1 < 120 tenths, T2 ≤ 240, T3 > 240 or link 2,
T4 link ≥ 3 / Meltdown / signature).

### 3.8 Budget
Slice audio ≤ 15 MB of WAV in the repo; v1 total ≤ 40 MB after import compression. Mark music for QOA import in the
`.import` defaults (report the import settings the orchestrator must apply if you can't set them yourself).

## 4. Tests (`game/tests/audio/`)
Audio autoload: unknown ids no-op without errors; no immediate repeats over 50 calls; bus volume mapping; sting
ducking restores; chain switching schedules on the next bar boundary (pure helper function); music state machine
transitions; `cues.json` keys ⊆ TECH §3.8 event names and every referenced id exists in `sfx_map.json`.

## 5. Verify and listen (by proxy)
```
tools/scripts/gen_audio.sh            # render + --check
python3 tools/audio/gen_audio.py --report > /tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/audio/report.txt
tools/scripts/test_game.sh audio -- audio/
```
Make spectrogram/waveform PNGs (Pillow) of the key sounds (the sneeze sequence, the "PIPE DOWN!" shout, T2/T4
laughs, Clarence, a chain section) and look at them: clean onsets, no clicks at loop points, formants where
intended, loudness consistent. Write `docs/review/audio/index.md` with the **A/B pages**: Bellows formant vs tuba
(same lines), crowd formant vs fallback (same tiers), plus the 10 most important SFX — copy those WAVs (≤ 8 MB total)
to `docs/review/audio/ab/` so the owner can listen at Gate 0.

## 6. Acceptance
- [ ] Pipeline ported, deterministic, `--check` green; all sounds above rendered.
- [ ] Audio autoload API exactly TECH §5.8 (+ style switches); buses; tests green.
- [ ] `cues.json` complete for every Stage-1 sim event; ids resolve.
- [ ] Budget met; review index with A/B files and spectrogram PNGs looked at.
- [ ] Report `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/reports/audio.md`: files, ids, import settings needed, requests.

---
## Standing rules for every Stage-1 task (from TECH §13 — binding)
- Repo: `/home/user/mischief` (paths in this brief are relative to it). Scratch: `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/audio/`.
  Report: `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/reports/audio.md` (the same text as your final answer).
- Create/modify **only** the paths you own (§2 above). Other agents are editing other paths right now. Need a change
  elsewhere? Write a precise request (file, change, reason) in your report. Never run git write commands.
- Code against the contracts in `docs/TECH.md`; when a module you depend on may not exist yet, use a **soft hook**
  (`ResourceLoader.exists` + `load`, `has_method`) and make tests `skip()` with a reason instead of failing.
- Run Godot **only** through `tools/scripts/test_game.sh audio [-- filter]`, `tools/scripts/sandbox.sh audio …` and
  `tools/scripts/shot.sh <res://scene.tscn> <out.png> [frames] audio [-- user args]` (1200×540 = a 20:9 phone;
  `--shot-seq=/abs/dir --every=N --count=K` for frame sequences). Never run Godot on `game/` directly.
- Typed GDScript, tabs, `##` doc comments on public API; JSON per TECH §2; no placeholder TODOs where an
  implementation is asked for; 60 fps discipline (pools, no per-frame allocations in hot paths).
- New assets/scripts will get their `.import`/`.uid` sidecars from the orchestrator's import pass; don't hand-write
  them. Autoload registration and `project.godot` edits are the orchestrator's (request them).
- **Look at what you make** (Read the PNGs), judge it at phone scale, iterate. Put final review artefacts in
  `docs/review/audio/` with an `index.md`.
- Final answer = concise report: what you built (files), exact public APIs other agents must use, verification
  (tests + artefact paths + what they show), deviations from the docs (with reasons), requests for other owners,
  known gaps.
