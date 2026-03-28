#!/bin/bash
set -e

PYTHON=/workspace/isaaclab/_isaac_sim/kit/python/bin/python3
PIP="$PYTHON -m pip"

# Install missing Python deps
$PIP install toml 2>&1 | tail -1

# Install RL frameworks via isaaclab.sh
echo "=== Installing RL dependencies ==="
cd /workspace/isaaclab
./isaaclab.sh --install rsl_rl 2>&1 | tail -10

# Install SO-ARM101 package
echo "=== Installing SO-ARM101 ==="
cd /mnt/isaac/isaac_so_arm101
rm -rf .venv
$PIP install -e . --no-deps 2>&1 | tail -3

# Verify
echo "=== Isaac Lab version ==="
$PYTHON -c "import isaaclab; print(isaaclab.__version__)"

echo "=== SO-ARM101 environments ==="
$PYTHON << 'PYEOF'
import gymnasium as gym
import isaac_so_arm101
envs = [e for e in gym.envs.registry if "SO" in e.upper() or "ARM" in e.upper()]
for e in envs:
    print(f"  {e}")
if not envs:
    print("  (none found)")
PYEOF
