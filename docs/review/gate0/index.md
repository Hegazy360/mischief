# Gate 0: "Sneeze & Cast"

This page is for the owner. Everything below comes from the build you will install. All shots are 1200 × 540, the shape of a 20:9 phone held sideways.

## The build

- **APK:** `build/android/mischief-debug.apk`. It is a debug build, 66.4 MiB (69,671,086 bytes).
  - sha256 `d0aa531d00632dacc8b1e70b6b0abe0f979215b58c17250489ad9c18997d17a1`
  - Android 7 or later (min SDK 24, target 36), arm64 and armv7, landscape only.
  - The only permission is VIBRATE.
- **Install:** `adb install -r mischief-debug.apk`, or copy the file to the phone and allow "install unknown apps".
- **What opens:** the stage door (`boot_config.json` = `stage_door`).
- **The playable part:** only Gate 0 is final. The Prologue and Nights 1–2 play from start to end, but about 100 of Bellows' clips are not made yet (they are batch 2). While those play he freezes in a pose.

## What to judge (G1–G7)

| # | What it is | Where | What to judge |
|---|---|---|---|
| **G1** | **ACHOO-RIA! playable** | On the phone, tap **Gate 0: the Sneeze**. A 3-icon card shows (tap the honey → hold RIG → hide in the pantry). Then you play. The sneeze comes about 20 s after the curtain rises, and the curtain call 3 s after it. Tap **Again ▶** to replay. | Does the set-up → wait → payoff land in your hand? Is it clear what to do? Is it funny the first time, and still funny on the third **Again ▶**? |
| **G2** | **The sneeze in the game**, captured from the real game | [`sneeze_closeup.gif`](sneeze_closeup.gif) (the sneeze with the sound strip) + [`sneeze_closeup.wav`](sneeze_closeup.wav) · [`sneeze_closeup_strip.png`](sneeze_closeup_strip.png) / [`_2`](sneeze_closeup_strip_2.png) (every 2nd frame from f1040 to f1260; CHOO = **f1167**) · the whole 40 s run: [`sneeze.gif`](sneeze.gif), [`sneeze_mute.gif`](sneeze_mute.gif), [`sneeze_strip.png`](sneeze_strip.png) (every 60th frame) · the clip sheets: [`../s2-anim-bellows/`](../s2-anim-bellows/index.md) (T1/T2/T3 contact, onion, curves) | Is the "ah… ahh… AHHH… hm." build-up (f1073–f1167, 1.6 s) the right length? Does the CHOO hit hard? Watch the stool, the flight into the sink, the spray, and the Stalls jumping up. Ignore the note at the top of the s2-anim-bellows page about the mirrored sneeze: that bug is fixed. |
| **G3** | **Cast sheet** | [`cast.png`](cast.png) (the live Cast page) · [`../s2-anim-hush/cast_sheet.png`](../s2-anim-hush/cast_sheet.png) · [`../s2-anim-hush/cast_hush_vs_pip.gif`](../s2-anim-hush/cast_hush_vs_pip.gif) · on the phone: **Cast** (Next cycles idle → snicker → freeze → take; **Hush / Pip** swaps the skin) | **D2:** the mime (Hush) or Pip? Which one is warmer, and funnier in motion? |
| **G4** | **Voice A/B**: A is the formant baritone, B is the talking tuba | [`voice_ab.png`](voice_ab.png) · the desktop pack [`../s2-sound/gate0/index.md`](../s2-sound/gate0/index.md) (in-context WAVs) · on the phone: **Gate 0 · voice A** / **Gate 0 · voice B** (the whole scene in that voice), or **Voice A/B** (each line alone) | **D3:** the words must be understood through a phone speaker at half volume. Is he a pompous man you laugh at? |
| **G5** | **Crowd A/B**: A is the formant crowd, B is the fallback crowd | [`crowd_ab.png`](crowd_ab.png) · the same desktop pack · on the phone: **Gate 0 · crowd A / B**, or **Crowd A/B** | **D4:** does the laugh feel like a live theatre, and does it never step on the CHOO? |
| **G6** | Camera and lint evidence | [`../s2-view/g0_sneeze_sheet_1.jpg`](../s2-view/g0_sneeze_sheet_1.jpg), [`_2`](../s2-view/g0_sneeze_sheet_2.jpg), [`g0_choo_zoom.jpg`](../s2-view/g0_choo_zoom.jpg), [`g0_landing_zoom.jpg`](../s2-view/g0_landing_zoom.jpg) · `lint_anim --strict`: 41 clips, 0 errors, 0 warnings | Does the push-in on the CHOO help? Does the caption land on the accent frame, clear of the HUD? |
| **G7** | What one prank costs | The task reports | Content work for ACHOO-RIA! alone: about **4.9 h** (animation 3.5 h, audio 0.9 h, episode data and route 0.5 h). On top of that, the Phase-G totals were: Bellows 5.7 h, Hush + cast 2 h, sound 1.4 h, and the Gate-0 fix round about 4.3 h. The shared engine work (night, view, rig, UI, art, sim: about 24 h) is paid once, not per prank. |
| — | The stage door | [`stage_door.png`](stage_door.png) | Every Gate-0 check starts here. |

**Tips for the phone:**
- **Gate 0 · voice/crowd A or B** saves that style. Plain **Gate 0: the Sneeze** keeps using the last style you picked. The **Voice A/B** and **Crowd A/B** pages mark the current one with ✓.
- The Android back button goes from a sub-page back to the menu. During a Night it opens the pause menu.

## Your four decisions (G8)

- [ ] **D2: mime (Hush) or Pip**, for the heroine's look.
- [ ] **D3: voice A (formant baritone) or voice B (talking tuba)**, for Bellows.
- [ ] **D4: crowd A (formant) or crowd B (fallback)**, for the Stalls.
- [ ] **D5: is the sneeze funny?** Answer pass or fail, with notes: timing, readability, sound, and what you would change.

If the sneeze passes, mass animation (batch 2) starts with your choices. If it fails, your notes go back to the animation, sound and view tasks, and Gate 0 repeats.

## Known rough edges in this build (all known, none blocking)

- **The kettle is hidden behind Bellows during the tea.** He sits in front of it. You see it the moment he flies off. Until then, his "admire himself in the kettle" beat reads as admiring nothing. The fix means moving his tea spot and re-timing the sneeze's flight, and it is planned (s2-fix #12).
- **Some of his other beats freeze.** In Gate 0 that is 3 short moments: the mirror fix-up and a walking hum. In the Nights it is about 100 clips, all batch 2.
- **The curtain call's Gag Reel box is empty for about 1 s**, then it replays the sneeze small.
- **The app icon is Godot's default** (no game icon yet). The launcher label reads "Mischief Next Door".
- **On a 4:3 tablet** the ACHOO-RIA! caption can overlap the top of his wig at the sink landing. Phone shapes (20:9, 16:9) are clear.
- **Desktop proxy for CPU:** Bellows costs 0.29 ms per frame against the 0.25 ms budget. The real 60 fps check is the Fun-Gate build on your phone.

## Verification of this build (desktop, 2026-09-29)

| Check | Result |
|---|---|
| Import metadata | OK: 1220 `.import`, 362 `.uid` |
| Full test suite (under load: fuzz + APK build alongside) | **1098 / 1098** passed, 0 failed, 0 skipped |
| `lint.sh` / `lint_all.sh --no-godot` | OK / OK. `--strict` fails only on the 103 batch-2 clips that are not made yet. |
| Solver, every route | **14 / 14 OK**. `--auto` proofs: N01, N02 and P00 OK. |
| Fuzz, 20 runs × 4 bots × 3 Nights | **240 / 240 OK**, 0 soft-locks |
| e2e `g0_sneeze`, rendered | PASS: 0 errors; draw calls p95 89 / max 111; texture peak 206.9 MB (limit 256); build + warm 1.23 + 0.10 s |
| e2e P00 ideal / slow; N01 ideal / caught; N02 ideal | All PASS. Texture peak 224–250 MB. Draw calls p95 92–117, max ≤ 167. The 4 laugh cues are staged, with the crowd 0.03–0.29 s later. `n01_caught` has 0 engine errors. |
| APK | `verify_android: OK`. **787 raw SVGs** shipped (`MndRawSvg: shipped 787`: every `art/**` SVG except the `_mannequin` dev folder; `ui/` has no SVG sources). No tests, tools or dev scenes. Signatures v2 + v3. |
