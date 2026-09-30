#!/usr/bin/env bash
# heads.sh <who> <outdir> <preset...> : one 3/4 head close-up per preset (studio, ortho)
set -euo pipefail
R="$(cd "$(dirname "$0")" && pwd)"; B=$R/build; WHO=$1; OD=$2; shift 2; mkdir -p $OD
if [ $WHO = hush ]; then CAM=ortho,0.88,0.0,1.2; else CAM=ortho,1.0,0.0,1.33; fi
for pr in "$@"; do
  fl=""
  if [ $WHO = bellows ]; then
    case $pr in shock|furious|suspicious) fl="bone:specs_face:1;bone:specs_chest:0.001";; esac
    case $pr in furious) fl="$fl;bone:sideburn_l:1.3;bone:sideburn_r:1.3;bone:bouffant:1.06";; esac
    case $pr in sneeze_build) fl="bone:nose:1.25;bone:sideburn_l:1.15;bone:sideburn_r:1.15";; esac
  fi
  ( SHOT_SIZE=560x560 NO_IMPORT=1 "$R/proj/tools/shot3d.sh" "$R/proj" res://toy/ToyStudio.tscn "$OD/$pr.png" 6 -- \
      --fig=$B/${WHO}_toy.glb@0,0@20@Toy_Idle_Loop@0@$pr@$fl --cam=$CAM --floor=none --bg=#3a3050 --outline=3.2 2>&1 | grep -E "ERROR|SCRIPT" || true ) &
  while [ $(jobs -r | wc -l) -ge 4 ]; do sleep 0.5; done
done
wait
