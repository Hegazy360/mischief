# Look-dev "Saturday Cartoon" — sources and licences

Every third-party file used is CC0 1.0 (public domain). Nothing else third-party is used.

| What | Used for | Source | Licence |
|---|---|---|---|
| Quaternius **Universal Base Characters** [Standard], `Superhero_Female_FullBody.gltf`, `Superhero_Male_FullBody.gltf` | the body meshes + skin weights Hush (female base) and Bellows (male base: arms and legs) are built on; heads, hands, feet and Bellows' torso are cut away and replaced | https://quaternius.com -> https://quaternius.itch.io/universal-base-characters (local copy `../assets/quaternius/universal-base-characters/`, `License_Standard.txt`) | CC0 1.0 |
| Quaternius **Universal Animation Library** [Standard], `UAL1_Standard.glb` | the 65-bone UE5-mannequin skeleton and 21 clips (Idle, Walk, Walk_Formal, Jog, Sprint, Crouch x2, Interact, PickUp_Table, Sitting x3, Hit_Head, Idle_Talking, Jump x3, Roll, Dance, Push, Fixing_Kneeling) | https://quaternius.com/packs/universalanimationlibrary.html -> https://quaternius.itch.io/universal-animation-library (`License.txt`) | CC0 1.0 |
| Quaternius **Universal Animation Library 2** [Standard], `UAL2_Standard.glb` | 10 clips (Idle_FoldArms, Idle_No, Yes, Chest_Open, Consume, Walk_Carry, OverhandThrow, Hit_Knockback, LayToIdle, Idle_TalkingPhone) | https://quaternius.itch.io/universal-animation-library-2 (`License.txt`) | CC0 1.0 |

Original work made for Mischief Next Door in this look-dev (no third-party content): the cartoon heads, eyes,
lids, brows, hair, beret, bouffant, mutton chops, gloves/hands, shoes, Bellows' barrel, coat tails, cravat,
collars, specs, buttons, Clarence (metaball clay built in `src/heads.py`, `src/parts.py`, `src/build_char.py`);
the painted textures (`src/paint.py`) and the face decal atlas (`src/face_atlas.py`); every custom clip
(`src/clips_custom.py`: Hush_Idle_Loop, Tiptoe_Loop, Snicker, Freeze_Statue, Rig_Pour_Loop, Peek_Loop,
Pompous_Idle_Loop, Strut_Loop, Tea_Sip_Loop, Sneeze, Dazed_Loop); the hand props (`src/build_props.py`);
the character shader, outline variant, face rig and shot scene (`godot/cartoon/`).

The set is the shared diorama (`../diorama/`, original, see its README). Sheet labels use the project's own
OFL fonts (Lilita One, Nunito) from `/home/user/mischief/game/ui/theme/fonts/`.
