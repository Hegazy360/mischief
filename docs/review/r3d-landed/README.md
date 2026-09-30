# r3d-landed — the landed mirror (R3D index §3.7, ruling R16)

Restart insurance for the R3D build. Every WIP commit (every 60–90 min during B1 and the queue) copies:

- `<SP>/work/r3d-<key>/LANDED.md` → `<key>.LANDED.md`
- `<SP>/reports/r3d-<key>.md` → `reports/`
- every `<SP>/work/<key>/solve_before.json` → `solve_before/<key>.json` (the R10 baselines; `r3d-pre` = the
  pre-flight baseline on `r3d` at 67c7276 + pre-flight P)

After a container restart the orchestrator runs `tools/art3d/setup_blender.sh` and `tools/ci/setup_godot.sh`, restores
the LANDED.md files, reports and baselines from here, and relaunches the tasks that were running (each resumes).
