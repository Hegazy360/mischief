#!/usr/bin/env bash
# expr.sh <out.png> <who> <p1,..,p6> [flags per preset "p=flags"...] : 3x2 head sheet (3/4 view)
set -euo pipefail
R="$(cd "$(dirname "$0")" && pwd)"; B=$R/build; OUT=$1; WHO=$2; IFS=, read -ra P <<< "$3"
HY=$([ $WHO = hush ] && echo 1.17 || echo 1.3); SP=0.82; ROW=1.0
figs=""
for i in "${!P[@]}"; do
  pr=${P[$i]}; col=$((i%3)); row=$((i/3))
  x=$(python3 -c "print(round(($col-1)*$SP,3))"); y=$(python3 -c "print(round(-$row*$ROW,3))")
  fl=""
  if [ $WHO = bellows ]; then
    case $pr in shock|furious|suspicious) fl="bone:specs_face:1;bone:specs_chest:0.001";; esac
    case $pr in furious) fl="$fl;bone:sideburn_l:1.25;bone:sideburn_r:1.25";; esac
  fi
  figs="$figs --fig=$B/${WHO}_toy.glb@$x,0,$y@18@Toy_Idle_Loop@0@$pr@$fl"
done
CY=$(python3 -c "print(round($HY-$ROW/2,3))")
SHOT_SIZE=1500x1000 NO_IMPORT=1 "$R/proj/tools/shot3d.sh" "$R/proj" res://toy/ToyStudio.tscn "$OUT" 6 -- $figs --cam=ortho,2.0,0,$CY --floor=none --bg=${BG:-#3a3050} 2>&1 | grep -E "ERROR|SCRIPT" || true
