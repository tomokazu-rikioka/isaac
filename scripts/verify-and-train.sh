#!/bin/bash
set -euo pipefail

echo "=== SO-ARM101 Training ==="

cd /workspace/isaaclab

TRAIN_SCRIPT=$(find /workspace/projects/isaac_so_arm101 -name "train.py" -path "*/rsl_rl/*" | head -1)
echo "Train script: $TRAIN_SCRIPT"

./isaaclab.sh -p "$TRAIN_SCRIPT" --task SO-ARM100-Reach-v0 --headless
