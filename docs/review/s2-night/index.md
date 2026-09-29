# s2-night review — NightScene, Boot → curtain → Night, the Night flow, stage door, e2e

All shots at 1200 × 540 (20:9 phone held sideways) unless the name says otherwise; the frame strips are
real game frames from `tools/scripts/e2e.sh` / `shot.sh` (DevShot `--shot-seq`). The characters use the
real Hush / Bellows rigs; Bellows' Phase-G clips were still landing while these were taken (the e2e
reports list the fallbacks per clip id), so some of his beats are the view's static-pose fallback.

| Artefact | What it shows | What a first-time player on a phone would feel |
|---|---|---|
| `boot_contact.jpg` | Boot → the red curtain → the Prologue live under it (every 12th frame, real time) | The curtain is there at once and rises on a lit house with Bellows already singing in the PiP; the first thing asked of the thumb (the Clarence ghost finger) is on screen within the first second of play — no menu in the way. |
| `prologue_first_cue.jpg` | The Prologue's first cue with no FTUE director yet (NightScene's fallback): Figgis card "Clarence → Bellows" + the ghost finger on Clarence | Clear: "press the rubber chicken". The card is small but reads; the finger sits on the button, not near it. |
| `g0_contact_1.jpg`, `g0_contact_2.jpg` | Gate 0 end to end from the replayed ideal route: curtain → walk to the honey → HOLD ring rigging → hide in the pantry (eyes in the dark) → Bellows arrives with his tea → **ACHOO-RIA!** punch-in → the Stalls rise → PIPE DOWN! → the short curtain call with the Gag Reel and **Again ▶** | The whole joke lands in ~25 s of play: set-up, wait under the curtain with the eyes, the sneeze, the crowd. The curtain call comes 3 s after the sneeze and Again ▶ sits under the right thumb. |
| `g0_sneeze_punch.jpg` | The sneeze frame: 1.4× punch-in, caption, frazzled bouffant, the hiding eyes | The payoff reads in half a second, even at thumbnail size. |
| `g0_curtain_call.jpg` | Gate 0's curtain call: Applause, "+NEW! ACHOO-RIA!", the Gag Reel re-playing the real sim frames of the sneeze, Again ▶ / Stage door | Immediate: one big button to do it again. The reel now frames Bellows 1.7× closer than the live camera between punch-ins (the first pass showed the whole kitchen and read as a map). |
| `results_n01.jpg`, `results_n01_16x9.jpg` | A Night's curtain call (N01 ended early from the CLI: 0 lines) — stamps, the why-missed line ("0/6 lines — Bellows still hasn't sung a duet with his kettle"), Bellows on the lower stage band with the valance dropped on his head; 20:9 and 16:9 | The why line tells you exactly what to try next. The valance bonk is a small closing gag; with the real `cc_wander_on` / `beat_slow_burn` clips it will carry more. The empty Gag Reel slot only shows on a Night with no reaction. |
| `tbc.jpg` | "To be continued…" after the last slice Night (dots appear one by one), then the Playbill | A proper sign-off rather than a dead end. |
| `playbill.jpg` | The slice Playbill stub: Prologue, Night 1, Night 2 with Curtain Calls + Play, Night 3 locked "Coming soon" | Obvious and tappable; deliberately no meta yet. |
| `pause_menu.jpg` | The pause menu (INTERVAL) over a live Night, with the debug overlay (three-finger tap): fps / p95, frame ms, draw calls, sim ms, texture MB, the laugh clock, Copy log / Stage door | Pause is instant and the world stays visible behind the dim. The overlay shows 226 draw calls and 619 texture MB under llvmpipe — see the report (requests to s2-view / s2-rig). |
| `pause_safe_left.jpg` | Pause menu with a notch safe area (90 px sides) and left-handed mode | Everything mirrors and stays clear of the notch. |
| `stage_door.jpg`, `stage_door_4x3.jpg` | The debug stage door: Gate 0 first (gold), the in-context "Gate 0 · voice A/B / crowd A/B", Cast, the Nights, Voice/Crowd A/B pages, Hush/Pip, Device log, Reset save (tap twice); 20:9 and 4:3 | Big, flat, unambiguous buttons (≥ 144 px, 24 px gaps) — the owner can run every Gate-0 judgement from here without reading instructions. |
| `stage_door_voice_ab.jpg` | The Voice A/B page from `data/audio/ab.json`: five lines, Play A / Play B, "Use this: A ✓" / B | Quick side-by-side listening; the choice is visible. |
| `cast.jpg` | The Cast page: live RigPlayers of Hush, Bellows and Figgis at 1.45× and the Stalls, with Next (idle → snicker → freeze → take) and the Hush / Pip toggle | The cast reads at phone scale; clips that don't exist yet are named under the actor. |

Not captured as stills here (covered by the e2e reports in the task report instead): the loading card and the
Script slide-in on N01/N02 (they show under the Router's curtain; `s2-ui` shot both in the real scene), the
retry dip (0.3 s fall + 0.5 s rise), the Prologue's title-card slam (the art landed late in the batch; the
procedural fallback card is drawn until then).
