#!/usr/bin/env bash
# clipsheet.sh <out.png> <who> <anim> <yaw> <t1,t2,...> [spacing=1.1] [cz] [ortho]  : frames of one clip side by side
set -euo pipefail
R="$(cd "$(dirname "$0")" && pwd)"; B=$R/build
OUT=$1; WHO=$2; A=$3; YAW=$4; TS=$5; SP=${6:-1.1}; CZ=${7:-0.85}; OS=${8:-2.0}
IFS=, read -ra T <<< "$TS"; n=${#T[@]}; figs=""
for i in "${!T[@]}"; do x=$(python3 -c "print(round(($i-($n-1)/2)*$SP,3))"); figs="$figs --fig=$B/${WHO}_toy.glb@$x,0@$YAW@$A@${T[$i]}"; done
W=$(python3 -c "print(int(min(2400, max(900, 540*($n*$SP+0.4)/$OS))))")
SHOT_SIZE=${W}x540 NO_IMPORT=1 "$R/proj/tools/shot3d.sh" "$R/proj" res://toy/ToyStudio.tscn "$OUT" 6 -- $figs --cam=ortho,$OS,0,$CZ ${STUDIO_ARGS:-} 2>&1 | grep -E "ERROR|SCRIPT" || true
echo "$OUT"
