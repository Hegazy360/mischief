#!/usr/bin/env bash
# make_boards.sh : rebuild the characters and regenerate every look-dev deliverable in this folder.
set -euo pipefail
R="$(cd "$(dirname "$0")" && pwd)"; cd "$R"; B=$R/build
./build.sh
blender -b --python src/build_props.py -- --build build >/dev/null 2>&1
blender -b --python src/build_props.py -- --build build --pepper >/dev/null 2>&1
NO_IMPORT=1 ./turn.sh out/turn_final >/dev/null
./heads.sh hush out/heads_hush neutral sneaky shock furious sneeze_build dazed
./heads.sh bellows out/heads_bellows neutral pompous shock furious sneeze_build dazed
python3 src/compose.py turnaround turnaround.png
python3 src/compose.py expressions expressions.png
mkdir -p out/poses
./still.sh out/poses/1_tiptoe.png 0.02 --char=$B/hush_toy.glb@gramophone@Toy_Tiptoe_Loop@65 --place=0@4.3,-1.05@65 --camx=4.35,1.9,0.95 &
./still.sh out/poses/2_pour.png 0.2 --char=$B/hush_toy.glb@stool@Toy_Pour_Loop@90 --place=0@7.66,-1.45@90 --prop=$B/honey_jar_pepper.glb@8.13,0.66,-1.35@0 --camx=7.9,1.9,0.95 &
./still.sh out/poses/3_peek.png 0.3 --char=$B/hush_toy.glb@pantry@Toy_Peek_Loop@0 --camx=10.55,1.9,1.2 &
./still.sh out/poses/4_statue.png 0.5 --char=$B/hush_toy.glb@doorway@Toy_Freeze_Statue@30 --place=0@6.95,-1.1@30 --camx=6.95,1.9,0.95 &
wait
./still.sh out/poses/5_tea.png 0.8 --char=$B/bellows_toy.glb@stool@Toy_Tea_Sit_Loop@-38 --camx=8.15,2.1,1.1 &
./still.sh out/poses/6_choo.png 2.26 --char=$B/bellows_toy.glb@stool@Toy_Sneeze@-38 --camx=8.35,2.3,1.15 &
./still.sh out/poses/7_sink.png 0.4 --char=$B/bellows_toy.glb@stool@Toy_Dazed_Sink_Loop@-38 --camx=9.2,2.1,1.1 &
./still.sh out/poses/8_snicker.png 0.85 --char=$B/hush_toy.glb@kettle@Toy_Snicker@15 --place=0@7.3,-1.2@15 --camx=7.3,1.9,0.95 &
wait
python3 - <<'PY'
import json
from PIL import Image
cells=[("out/poses/1_tiptoe.png","Hush · tiptoe (sneaky, glancing at the Stalls)"),("out/poses/2_pour.png","Hush · rigging: pepper into the honey"),
("out/poses/3_peek.png","Hush · peeking from the pantry"),("out/poses/4_statue.png","Hush · frozen statue (caught!)"),
("out/poses/5_tea.png","Bellows · tea on the stool, pinkie up"),("out/poses/6_choo.png","Bellows · ah-ah-CHOO! launched back"),
("out/poses/7_sink.png","Bellows · dazed in the sink"),("out/poses/8_snicker.png","Hush · the snicker at the audience")]
for p,_ in cells:
    im=Image.open(p); w,h=im.size; im.crop((w//2-330,0,w//2+330,h)).save(p.replace('.png','_c.png'))
json.dump({"out":"poses.png","title":"Toy Box — poses in the diorama","sub":"Godot renders in the shared set (1200x540 frames, centre crop, close camera). Game scale: ingame_*.png.",
 "cells":[[p.replace('.png','_c.png'),l] for p,l in cells],"cols":4,"cw":560,"ch":458},open("out/poses.json","w"))
PY
python3 src/compose.py grid out/poses.json
./still.sh ingame_kitchen.png 0.8 --char=$B/bellows_toy.glb@stool@Toy_Tea_Sit_Loop@-38 --char=$B/hush_toy.glb@kettle@Toy_Tiptoe_Loop@62 --place=1@7.05,-1.05@62 --seekc=1@0.02 --camx=8.3,3.9,1.42 &
./still.sh ingame_wide.png 0.3 --char=$B/bellows_toy.glb@gramophone@Toy_Walk_Loop@62 --place=0@3.9,-1.15@62 --char=$B/hush_toy.glb@doorway@Toy_Freeze_Statue@35 --place=1@7.2,-1.1@35 --camx=5.6,3.9,1.42 &
wait
mkdir -p out/strip; i=0
for spec in "0.3|peek|0.3" "1.2|peek|0.9" "1.75|peek|1.5" "2.12|peek|1.9" "2.25|peek|0.2" "2.6|peek|0.5" "3.05|snicker|0.35" "4.2|snicker|1.0"; do
  IFS='|' read t hc ht <<< "$spec"
  if [ $hc = peek ]; then H="--char=$B/hush_toy.glb@pantry@Toy_Peek_Loop@0"; else H="--char=$B/hush_toy.glb@pantry_front@Toy_Snicker@10 --place=1@10.4,-1.25@10"; fi
  ./still.sh out/strip/f$i.png $t --char=$B/bellows_toy.glb@stool@Toy_Sneeze@-38 $H --seekc=1@$ht --camx=8.3,3.9,1.42 &
  i=$((i+1)); while [ $(jobs -r | wc -l) -ge 4 ]; do sleep 0.5; done
done; wait
python3 - <<'PY'
from PIL import Image, ImageDraw, ImageFont
F=ImageFont.truetype("/home/user/mischief/game/ui/theme/fonts/LilitaOne-Regular.ttf", 30)
S2=ImageFont.truetype("/home/user/mischief/game/ui/theme/fonts/Nunito-ExtraBold.ttf", 20)
labs=["1 · sip, pinkie up","2 · nose twitch... ah","3 · ah-ah...","4 · AHHH (hold)","5 · CHOO!","6 · launched backwards","7 · splash into the sink","8 · dazed · Hush snickers"]
W,H=600,270
S=Image.new("RGB",(W*4+5*10, 70+2*(H+40)),(46,37,64)); d=ImageDraw.Draw(S)
d.text((16,14),"Toy Box — ah-ah-CHOO! (game scale; 1200x540 frames shown at 50%)",font=F,fill=(255,240,214))
for i in range(8):
    im=Image.open(f"out/strip/f{i}.png").convert("RGB")
    im.save(f"sneeze_frames/f{i}.png") if False else None
    im=im.resize((W,H),Image.LANCZOS)
    x=10+(i%4)*(W+10); y=70+(i//4)*(H+40)
    S.paste(im,(x,y)); d.text((x+4,y+H+6),labs[i],font=S2,fill=(255,240,214))
S.save("sneeze_strip.png")
PY
rm -rf out/seq
SHOT_TIMEOUT=400 NO_IMPORT=1 proj/tools/shot3d_fixed.sh proj res://toy/ToyShot.tscn $R/out/seq_last.png 300 -- --char=$B/bellows_toy.glb@stool@Toy_Sneeze@-38 --char=$B/hush_toy.glb@pantry@Toy_Peek_Loop@0 --camx=8.3,3.9,1.42 --shot-seq=$R/out/seq --every=4 --count=72 >/dev/null 2>&1
python3 -c "
from PIL import Image;import glob
f=[Image.open(p).convert('RGB').resize((600,270),Image.LANCZOS) for p in sorted(glob.glob('out/seq/frame_*.png'))]
f[0].save('sneeze.gif',save_all=True,append_images=f[1:]+[f[-1]]*8,duration=67,loop=0)"
echo BOARDS_OK
