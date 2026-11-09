# QA guide — the Bakery: the cast (Hush and Gus Thudd)

Round 7: **Hush has expressions too** (shock / daze / grin over her painted neutral — startle,
knocked, get-up, cheer, squeak and two statues use them), and there is a **gameplay sample**:
one scripted Act in the parlour with the GDD's staging (RIG ring, FREEZE in plain sight, Clarence
lure, awareness "?", stare strip, hiding spot, the gag, Stalls + Applause). Round 6 gave Gus his
face and put props in hands (`animation_engine.md` §11–12).

## 1. Bake the cast (~90 seconds, from nothing)

```bash
python3 tools/bakery/run.py --contact
```

Expect `[cast] hush built`, `[cast] gus built`, 44 clips each `=> PASS` (including "planted in
every frame"), and the chain lines (`getup follows knocked` ×2, `sit_idle follows sit`,
`stand follows sit_idle`). Contact sheets: `game/proto/bakery/sheets/{hush,gus}/_contact.png`.
Re-bake one character or clip: `--who gus`, `--only flex,walk`.

## 2. Watch them

```bash
tools/scripts/play.sh res://proto/bakery/Bakery.tscn     # the cast on stage + gallery
tools/scripts/play.sh                                    # Act I — the full scene (67 s, loops)
```

Top: Gus checks his stopwatch, flexes at the mirror, lumbers off, does press-ups, sits; Hush creeps in behind him,
rigs a gag (saw, then mallet) and squeaks Clarence at the Stalls. Gus hears something — Hush snaps into a **ta-da statue** in plain
sight while he looks around, stomps over and lunges at her; she scarpers, the gag lands, he goes flat,
gets up and fumes. Bottom: every clip of both (statues in ice-blue).

What to look for:
* **Is Gus a character you want as the neighbour?** Silhouette, colours, size next to Hush.
* Does his motion carry **weight** (lumbering walk, heavy fall) and suit him (flex, press-ups)?
* Feet never slide or float; fall → get up stays one continuous body.
* **Statues:** does each snap read as a mime freezing (fast, no wobble, then dead still)? Which of
  the eight are funny, which should go? (punch / discus / tiptoe are the closest trio.)
* **Faces:** does Gus read smug → suspicious → shocked → dazed → angry as the scene goes? Is the
  moustache him? Does Hush's shock/daze/grin read as panto, and does her painted neutral stay her?
* **Props:** can you name each item at phone size (Clarence, saw, mallet, stopwatch, apple, kipper)?
  Does Clarence in the braces read as a chicken?
* **Gus's reactions:** does `search` read as looking around, `fume` as livid, `stomp` as angry,
  `grab` as a lunge for her?

## 3. Change Gus

* Colours and costume: `LOOK` and `colour_for` in `tools/bakery/cast/neighbour.py`.
* Shape extras (hair): `add_hair` in the same file.
* Motion: his block in `tools/bakery/clips.json` (`Large_*` = his own library, others = Medium).
* Gus's face / expressions: `add_face` in `tools/bakery/cast/neighbour.py`; which clip shows which: `face` in clips.json.
* A new prop: one builder in `tools/bakery/props.py`; hold it with `"props": [{"item": …, "bone": "handslot.l"}]`
  (`from` / `until` seconds, `rot` / `off` to place it — handslot.l is the hand nearer the camera).
* A new statue: one line in Hush's block — `{"name": "freeze_x", "pose": {"lib": …, "clip": …, "at": secs}}`;
  re-bake with `--who hush --only freeze_x`. Body-axis `tweak`s push a pose further.

## 4. Check nothing in the old build broke

```bash
tools/scripts/test_game.sh mine        # expect 1113 passed, 0 failed
tools/scripts/lint.sh --strict
tools/ci/check_import_meta.sh
```

## 5. The gate

1. Is **Gus** the neighbour — or what should change (age, build, costume, personality)?
2. Does each of them **move like themselves**? Any clip to swap?
3. Should the GDD be rewritten around Gus (it still describes the old neighbour)?
4. Which **statues** stay (GDD wants 8, picked per room/prop)? Any to swap?
5. Faces: any expression to change on either of them?
6. **The gameplay sample:** does the Act's rhythm feel like the game you want (creep → rig → freeze →
   lure → hide → gag → applause)? What should the next sample show — a catch (Busted Cam), a chase,
   the Meltdown, a second room?
