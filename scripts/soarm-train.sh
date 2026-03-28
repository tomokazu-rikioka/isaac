#!/bin/bash
set -e

PYTHON=/workspace/isaaclab/_isaac_sim/kit/python/bin/python3
TASK="${1:-SO-ARM100-Reach-v0}"

echo "=== SO-ARM101 Training ==="
echo "Task: $TASK"
echo "GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null)"

# Verify environment exists
echo "=== Checking environments ==="
$PYTHON -c "
import gymnasium as gym
import isaac_so_arm101
envs = [e for e in gym.envs.registry if 'SO' in e.upper() or 'ARM' in e.upper()]
for e in envs:
    print(f'  {e}')
"

# Run training
echo "=== Starting training ==="
cd /workspace/isaac_so_arm101
$PYTHON -m isaac_so_arm101.scripts.rsl_rl.train --task "$TASK" --headless
