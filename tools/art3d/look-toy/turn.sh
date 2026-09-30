#!/usr/bin/env bash
# turn.sh <out_prefix> [anim] [t] : turnaround rows (front, 3/4, side, back) for both characters
set -euo pipefail
R="$(cd "$(dirname "$0")" && pwd)"; B=$R/build; O=${1:?}; A=${2:-Toy_Idle_Loop}; T=${3:-0}
for who in hush bellows; do
  figs=""; i=0
  for yaw in 0 35 90 180; do x=$(python3 -c "print(-1.95+1.3*$i)"); figs="$figs --fig=$B/${who}_toy.glb@$x,0@$yaw@$A@$T"; i=$((i+1)); done
  cz=$([ $who = hush ] && echo 0.84 || echo 0.9)
  SHOT_SIZE=1800x640 NO_IMPORT=${NO_IMPORT:-} "$R/proj/tools/shot3d.sh" "$R/proj" res://toy/ToyStudio.tscn "${O}_$who.png" 6 -- $figs --cam=ortho,1.95,0,$cz ${STUDIO_ARGS:-} 2>&1 | grep -E "ERROR|SCRIPT" || true
done
python3 -c "
from PIL import Image; a=Image.open('${O}_hush.png'); b=Image.open('${O}_bellows.png')
S=Image.new('RGB',(a.width,a.height+b.height)); S.paste(a,(0,0)); S.paste(b,(0,a.height)); S.save('${O}.png')"
echo "${O}.png"
