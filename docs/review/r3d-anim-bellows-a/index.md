# r3d-anim-bellows-a — review index

Horace Bellows' Gate-0 3D clips (12, all FINAL): the sneeze, the tea and warm-up activities, the mirror fix-up, the
locomotion set, the stun, and the curtain-call wander-on / slow burn. Captures are the game at 1200×540, fixed 60 fps.

| artefact | what it shows | what to judge |
|---|---|---|
| `sneeze_strip.png`, `sneeze_strip_2.png` | `rx_sneeze_blast_a` in game (ViewSandbox3D `--sim --episode=g0_sneeze`, ideal commands, seek 1040), every 2nd engine frame 25–205; engine f = clip f + 29 (+ 5 after the f 94 hit-stop); cells outlined: key f0 (the sip), anticipation 74, ACCENT 94, hold 97, contact 112 (the sink), settle 145, release 165 | does the face stay on the camera through the build (f29–122)? Is CHOO (f123) the loudest frame of the Night? The stool, the flight, the landing in the sink |
| `sneeze.gif`, `sneeze_mute.gif` | the same run as a GIF (720 px, 30 fps, 3.4 MB) and its mute copy | the whole gag in real time, with and without the audio-driven captions |
| `tea_strip.png`, `tea_strip_2.png` | `act_tea` in game (seek 600), every 6th engine frame 50–476; engine f = clip f + 50; contact = the hand-offs (kettle lend 14 / return 78, honey lend 104 / return 148), accent = the lid flip (126) and THE SIP (420 = the sneeze's f0, engine 470) | is the teacup readable in every frame? Do the kettle pour and the spoon-in-the-jar beat read? NB engine f174–190: -b's `mg_admire_in_kettle` overlay turns his head away |
| `sheets/<clip>_contact.png` | r3d-rig's contact sheet per clip (every 3 f + beat boundaries, side camera, events printed) — 12 clips | the key poses and where each event sits |
| `sheets/<clip>_phone.jpg` | the 1200×540 game framing every 3 f | reads at phone size? |
| `sheets/<clip>_onion.png`, `_curves.png` / `.json` | onion strip; per-bone angular speed curves | arcs and spacing; no spikes outside pop frames |
| `sheets/<clip>_sil64.png` | 64 px silhouettes of the beat frames + IoU matrix | every beat its own outline (the sneeze: IoU 0.24–0.63) |
| `sheets/<clip>_lint.txt` | r3d-anim's 3D lint for the clip | 0 errors, 0 warnings |
| `rubric.md` | the TECH §11 rubric per clip with frame numbers and funny / readable / fresh scores | the bar: sneeze ≥ 4 funny and readable, every clip ≥ 3 |
| `reviewer_answers_r1.md`, `verdict_r1.md` | round 1 of the mute fresh review (orchestrator-run): sneeze funny 4 / readable 4 / fresh 3; tea 1 / 2 / 2 → act_tea v2 | what a stranger reads at phone size |
| `packets/` + `reviewer_prompt.md` | round 2 packet: the current sneeze and the reworked tea as unlabeled frame sheets, scored funny / readable / fresh | pending review (the orchestrator runs it; the answer key is in the task's scratch dir) |
