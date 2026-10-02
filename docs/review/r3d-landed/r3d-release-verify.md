PASS. Every check on this release ran green. I made no fixes and changed no files in game/.

Tree: HEAD 2227745 plus the two polish passes, uncommitted. Pregate tree hash c58fc57493903375.

**APK**
- Path: `/home/user/mischief/build/r3d/mischief-debug.apk`
- Size: 73,534,725 bytes (73.53 MB)
- sha256: `36f335200dcb7fa8986121cf424258c435307c6562fe287f67c7b250bc3d7467`
- Contents: 3279 entries, 78 clip .res files, 81 sidecars. The only permission is VIBRATE; min_sdk 24, orientation 11.
- boot_config: start stage_door, view 3d, bellows_window sim, msaa_3d true, render_scale 1.0, outline true.
- Exported-pack probe: 197 scripts, 0 failed to load; the Night loads in 3D (world_view Node3D, tick 110).

**(1) Import on the real project:** worked on the first try (rc 0, no errors or warnings in the log). It created no new or changed files. `check_import_meta.sh` OK: 1010 .import, 414 .uid.

**(2) Suite and lints**
- Full suite: 1352 passed, 0 failed, 0 skipped, in 140 files. That is 1345 from before plus the 7 new pelmet tests. 0 script errors; the usual ObjectDB leak warning at exit.
- `lint.sh --strict`: OK, 0 lints failed. 72 strict 3D clips with 0 errors, 0 warnings, 0 missing; content has 0 errors.
- `lint_all.sh --no-godot`: OK, with one audio warning: fish_slap_1 loudness is -15.6 against a -14.0 target.

**(3) Pregate (`--rows=13,14,15,20a --force`) and solver**
- **Row 13, Gate 0 strict:** PASS (173 s).
  - It ends on g0_done with 0 engine errors and 0 clip fallbacks.
  - Accent frame 94; hit-stop 83 ms.
  - frame p95 107.9 ms; view p50 2.74 ms and p95 4.11 ms.
  - 0 C8 violations; the PiP is on screen 28 % of the time.
- **Row 14, Prologue strict:** PASS (327 s). All three routes end on prologue_done with 0 doubles, 0 fallbacks and 0 C8 violations.

  | Route | Laughs by 60 s | First laugh | First prank | Worst cue-to-crowd |
  |---|---|---|---|---|
  | ideal | 7 | 3.8 s | 22.9 s | 0.273 s |
  | slow | 7 | 4.3 s | 25.3 s | 0.267 s |
  | required (info only) | 4 | 30.9 s | 30.9 s | 0.274 s |

- **Row 15, `slice_all`:** PASS (493 s). All 13 routes end with ok true and 0 errors.
  - The 4 g0 and Prologue routes have 0 fallbacks.
  - N01 has 18–34 fallbacks and N02 22–60. Those Nights are previews in this slice (D13), so their missing clips are expected.
- **Row 20a, APK export and exported-pack probe:** PASS (47 s). Numbers are in the APK section above.
- **`solve.sh all --route=all`:** 12 runs, 0 failed.
  - The worst dead air with fast-forward is 16.3 % (the N01 chase route); on the ideal, required and slow routes it is 7.8 % at most, and every max gap is 6.2 s or less.
  - Some lines print "d1_lean FAIL". That is an info-only comparison against the lean window mode (the reason it isn't shipped), not a gate.
- **Overall pregate exit was 1, but not because of these rows.** Rows not re-run are marked stale or failed from earlier runs:
  - Rows 16, 17 and 19 are the ones D19 accepted.
  - Rows 1–12 and 18 are only marked STALE because the tree changed.
  - In this pass, rows 1–5 were re-checked directly by the import check, the suite, the two lints and the solver above, all green.

**(4) The polish frames:** I looked at both strips and both zoom sheets from the take pass, plus the take's two-facing sheet. I also looked at the pelmet pass's strip, bonk beats, contact f504 and hold f600.
- **Double take, relief (f3192–3270):** no T-pose anywhere. Glance, look away, then the snap at f3213, and the gloves stay tucked at the chest with the face to camera through f3243.
- **Double take, curtain call (f3900–3990):** clean take around f3939–3951, then the slow burn. These frames were shot at 03:36, after the final take bake (03:26) and the final pelmet code (03:11–03:15), so they show the tree being released.
- **Pelmet:** at f504 the wig is flattened under the fabric, with whack lines and dust and nothing covering the wig. From f525 to f690 the fringe drapes over the wig top with no gap. It no longer hovers.
  - Its frames were shot at 03:24, just before the final take bake, but the bonk plays a different clip (`st_bonk`), so they still hold.

**Release risks the owner pack should list (not blockers):**
- After the take, his last pose stays frozen for about 30 frames.
- The baton sits beside the corner of his mouth.
- The P00 required route has the PiP window on 34 % of the time.
- Row 17, Bellows rig CPU at 0.281 ms against a 0.25 bar, is still judged on the device (D19).

The working tree is unchanged by this pass and no Godot process is left running.

Logs are in `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/`:
- `r3d-release-verify-import1.log`
- `r3d-release-verify-suite.log`
- `r3d-release-verify-lint.log`
- `r3d-release-verify-lintall.log`
- `r3d-release-verify-pregate.log`
- `r3d-release-verify-solve.log`

Pregate results: `/home/user/mischief/build/r3d/pregate.json`, with per-row logs in `/home/user/mischief/build/r3d/logs/`.