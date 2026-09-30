# r3d-anim-bellows-c — review index (Bellows' 10 Prologue-only clips in 3D)

All 10 clips are real clips: no drafts, lint `--strict` clean, DONE lines in the task's LANDED.md. Scores and
per-take notes are in `rubric.md`. Every strip and board is at the game camera in the real P00 parlour (AnimViewer3D
`--room=parlour --episode=p00_curtain_up`, fixed 60 fps), cropped from 1200×540 frames, so they show phone scale.

| Artefact | What it shows | What to judge |
|---|---|---|
| `rubric.md` | TECH §11 rubric per take, with frame numbers and scores (funny / readable / fresh) | whether the scores are right; the weak spots listed for each clip |
| `dizzy_strip.png` | `rx_dizzy_spin_a` (169 f, FINAL), every 2nd frame at st_gramophone, facing −1, cheat 35, beats marked | does the toe spin read as a spinning top (front, back, front, f40–70)? Does the collapse on f86 hit? Does the dazed face read under the notes (f89–149)? |
| `dizzy.gif` / `dizzy_mute.gif` | the same take at 30 fps (0.56 MB), with and without the sound events | timing: the needle screech flinch, the babble, the spin, the wobble, the collapse, sitting up |
| `cue_doorframe_bonk_strip.png` | `cue_doorframe_bonk` (36 f, FINAL) every frame, overlay `upper` over `loco_blind_shuffle`, bouffant flipped | does the bonk (f3–7: arms up, head snapped back) read while he is blind? Does the brow rub read with his eyes hidden? |
| `cue_picture_bonk_strip.png` | `cue_picture_bonk` (48 f, FINAL) every frame, overlay `upper` over `loco_stomp`, livid tint | the squash on f11–15 and the framed slow burn (f30–40); the picture itself is the view's (it does not hang on him yet, see the rubric) |
| `boards/ingame_dizzy.jpg` | the dizzy spin in the real game (`e2e.sh prologue_ideal`, rendered frames 654–692) | the collapse on the ALLEGRO-GO-GO! label and the punch-in; the dazed hold filling the punch-in |
| `boards/ingame_cues.jpg` | the two cue bonks in the real game (CueStager3D, top: door frame, bottom: picture) | do the bonks read at the wide hall camera? |
| `boards/peer_under_piano.jpg` | `mg_peer_under_piano` (60 f) every 4th frame, overlay `upper` over the stomp, next to the piano | bent double toward the piano (f8–40), the "Hmm." (f38), up with the face back (f44–60) |
| `boards/dignity_facings.jpg` | `beat_dignity_fail` after review pass 3, facing +1 (top) and facing −1 (bottom) | the "ahem" survey (f26–46) keeps the face in view in BOTH facings (before, it turned to the back of the bouffant at facing +1) |
| `sheets/<clip>_contact.png` | r3d-rig's sheet: a profile cell every 3 f + every beat boundary, beats outlined, events listed (the 7 base clips) | poses and spacing; **f0–f7 are a tool artefact**: a crossfade from the clip's last pose (see the rubric caveat) |
| `sheets/<clip>_phone.jpg` | the 1200×540 game framing every 3 f, **facing +1** (the other facing from my strips) | does the face stay in view in the other facing? |
| `sheets/<clip>_onion.png`, `_sil64.png`, `_curves.png/.json` | onion skins per beat, 64 px silhouettes at the beat boundaries, bone-angle curves | silhouette change per beat; no spikes except the keyed pops |
| `sheets/<clip>_lint.txt` | the 3D animation lint of each of the 10 clips (0 errors, 0 warnings; the INFO lines are the new sound rows for r3d-integrate) | clean |

Overlays (`cue_doorframe_bonk`, `cue_picture_bonk`, `mg_peer_under_piano`) have only a lint file in `sheets/`:
sheet3d has no overlay mode, so they are reviewed over their base clip in the strips and boards above.
