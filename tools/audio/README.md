# Mischief Next Door — procedural audio

Every sound in the game is synthesised by this numpy-only generator (ported from the owner's
earlier game's pipeline and re-voiced for a stage farce): no samples, no licences, one
cartoon palette. Output goes to `game/audio/` as 22.05 kHz mono 16-bit PCM WAV; Godot's
default import compresses it to QOA (≈ 3.2 bits/sample) and reads music loop points from
each loop's `smpl` chunk ("Detect From WAV").

| Output | What |
|---|---|
| `game/audio/sfx/*.wav` | ~110 SFX (Treg-Brown kit, footsteps, doors, every slice prank prop, stealth feedback, Clarence, UI), 12 stingers `sting_*`, the Stalls `crowd_*` (formant) and `crowd_fb_*` (fallback) |
| `game/audio/voice/*.wav` | Bellows' phrase bank: `vo_bellows_*` (formant), `vo_bellows_tuba_*` (talking-tuba fallback, same bank), `vo_bellows_squeaky_*` (+12 st, the SQUEAKY residue); Stage 3: `vo_delphine_*` (soprano "HORACE!" ×2, the high-C "INTRUDER!" with a glass-crack tail) and `vo_beryl_*` ("MEH!", the Besotted bleat ×3: formant + FM buzz) |
| `game/audio/music/*.wav` | `mus_sneak` + `mus_suspense` (synchronised stems), `mus_chase`, `mus_chain_1..4`, `mus_curtain` (one-shot), `mus_results` |
| `game/audio/sfx_map.json` | `files` (id → path, bus, length), `banks` (id → variants), `aliases`, `music` (bpm, beats per bar, bars, samples per beat), `stems`, `vary` (pitch jitter) |

## Commands (from the repo root)

```bash
tools/scripts/gen_audio.sh                     # render everything (~40 s on 4 cores) + map + check
tools/scripts/gen_audio.sh --check             # verify only (CI); exit 1 on any error
tools/scripts/gen_audio.sh --pack              # also rebuild docs/review/audio (PNGs, A/B WAVs, demos)
python3 tools/audio/gen_audio.py --only sting_rigged,sneak   # re-render recipes and/or music jobs
python3 tools/audio/gen_audio.py --map-only    # rescan content, rewrite sfx_map.json (no rendering)
python3 tools/audio/gen_audio.py --report      # table: duration, KB, peak, loudness vs target, onset
python3 tools/audio/gen_audio.py --list        # every recipe with category, length cap, description
python3 tools/audio/review.py some.wav --out DIR   # spectrogram + waveform PNG of any WAV
```

Deterministic: every recipe's RNG is seeded from its name, so a re-render is byte-identical.

## What `--check` verifies

1. Every registered recipe and music file exists; no stale files.
2. `sfx_map.json` is current (files, banks, music, stems, vary) and every alias / bank member reaches a file.
3. Every audio id referenced by content resolves: clip events `{"type": "sfx"|"voice", "id"|"bank"}` and any
   `sfx` / `*_sfx` / `bank` key under `game/data/**`, plus every id, sting, crowd kind and music state in
   `game/data/audio/cues.json`. Unknown names get a keyword alias on the next full render or `--map-only`
   (`aliases.py` `RULES`); a name nothing matches is an **error** (there is no catch-all "bonk").
4. Format (PCM 22050 Hz mono 16-bit), per-recipe length caps, no clipping, **peak ≤ −1 dBFS**, loudness
   within −4.5 / +1.5 dB of its category target (loudest 50 ms of a phone-weighted signal).
5. Music: every loop has a `smpl` forward loop over the whole file, its length is exactly
   bars × beats per bar × samples per beat, and the seam has no jump; the stem set sums (with the
   shorter stem tiled) to ≤ −1 dBFS.
6. Budgets: slice audio ≤ 15 MB of WAV (the A/B alternates `vo_bellows_tuba_*` / `crowd_fb_*` and the
   later-Night content are counted separately: `vo_bellows_squeaky_*` (Night 3) and the Stage-3 voices
   `vo_beryl_*`, `vo_delphine_*`, `vo_bellows_beryl*`, `vo_bellows_ha_ha_my_dear` — see `LATER_PREFIXES`),
   A/B alternates ≤ 6.5 MB, estimated shipped audio ≤ 40 MB after QOA.

## Loudness targets (categories in `registry.py`)

| Category | Target | Ceiling | Bus | Used for |
|---|---|---|---|---|
| `sfx` | −14 | −1 | SFX | world one-shots |
| `soft` | −21 (per recipe −17…−21) | −1.5 | SFX | footsteps, creaks, rustles, Hush's snicker |
| `ambient` | −19 | −1.5 | SFX | fire crackle, house lights |
| `ui` | −20 | −3 | UI | taps, ring tick, rig done, Figgis psst |
| `sting` | −14.5 | −1 | SFX | stingers (the autoload ducks music under them) |
| `voice` | −14 (per line −11.5…−21) | −1 | Voice | Bellows; the sneeze builds ah −21 → ahh −18 → AHHH −15.5 → CHOO −11.5 |
| `crowd` | T0 −18, T1 −16, T2 −14.5, T3 −13.5, T4 −12.5, specials −13…−17 | −1 | Crowd | the Stalls |
| music | sneak −21, suspense −21, chain −19…−15, chase −16, results −18, curtain −14 (integrated) | −1.2 | Music | loops |

## Modules

- `synth.py` — the DSP kit (oscillators, FFT biquads, SVF, STFT noise bands, formant voice, reverb, limiter).
- `instruments.py` — the pit orchestra: pizzicato, bowed/tremolo strings, clarinet, bassoon, flute/piccolo,
  tuba, trombone, trumpet, horn, timpani (+ roll), woodblock, celesta, harp, xylophone, glockenspiel,
  triangle, slide whistle, kazoo, drums.
- `sfx_foley.py` — footsteps (incl. the SOAKED `squelch` bank), doors, the Treg-Brown kit, every slice prank prop.
- `sfx_stealth.py` — stealth feedback, Clarence, Hush (the pit plays her), UI, flow cues.
- `stings.py` — `sting_*`.
- `voices.py` — the score language (`Syl`, `Line`), the formant and talking-tuba engines, `SPEAKERS`
  and every speaker's lines: `lines_bellows()`, `lines_delphine()`, `lines_beryl()` (Beryl renders through
  `render_bleat`: the formant bleat plus an FM nasal buzz on the same pitch curve).
- `crowd.py` — laughers, applause, whistles, stomps, chants; the formant tiers + specials and the fallback set.
- `music.py` — the loops (`META` timing is written into the map; the autoload's bar maths read it).
- `aliases.py` — `EXPLICIT` names, keyword `RULES`, the content scanner.
- `gen_audio.py` — render / map / check / report. `review.py` — PNGs and the Stage-1 A/B pack.
- `sfx_slice.py` — the Stage-2 sounds that live inside clips (the sneeze foley, the tea, the warm-up, micro-gags,
  last beats, Hush's tinkering) + the command-feedback UI ticks.
- `clip_events.py` — the clip-event frame table (ruling L12): writes `docs/review/s2-sound/clip_events.md` and
  `game/data/audio/clip_events.json` (rewritten after every render; `--check` fails when stale, when a voice line
  would overlap another inside a clip, or when an activity's voice collides with its micro-gag overlays).
- `sequences.py` — `cycles` (Hush's `step_pizz_up` walks up the scale) and preview `sequences` (the sneeze pair).
- `gate0.py` — the Gate-0 in-context A/B pack `docs/review/s2-sound/gate0/` (mixes built like the game plays
  them: clip rows at their frames + hit-stop, event-level crowd, bus defaults, ducking, limiter; LUFS / true peak).

## Adding sounds

- A new SFX: add `@sfx("name", cat=..., max_dur=..., desc=...)` to the module that fits and run
  `python3 tools/audio/gen_audio.py --only name`. Variants: register `name_1..n` with `bank="name"`.
- A new Bellows line: add a `Line` to `voices.lines_bellows()`; the formant and tuba files register
  themselves (`vo_bellows_<id>`, `vo_bellows_tuba_<id>`; `_n` suffixes form banks).
- A new speaker: a `Speaker` preset in `SPEAKERS`, its own `lines_<speaker>()` in `LINES` and a loudness
  table in `LEVELS`; files register as `vo_<speaker>_<line>[_n]` (formant only — the tuba A/B is Bellows').
- A name used by content: nothing to do if a `RULES` keyword fits; otherwise add an `EXPLICIT` alias.
