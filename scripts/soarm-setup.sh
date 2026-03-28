#!/bin/bash
# SO-ARM101 ランタイムセットアップ（Dockerfile で既にインストール済みの場合は不要）
# ベースイメージから直接使う場合、または再セットアップが必要な場合に利用
set -euo pipefail

PYTHON=/workspace/isaaclab/_isaac_sim/kit/python/bin/python3

# Install missing Python deps
uv pip install --system toml 2>&1 | tail -1

# Install RL frameworks via isaaclab.sh
echo "=== Installing RL dependencies ==="
cd /workspace/isaaclab
./isaaclab.sh --install rsl_rl 2>&1 | tail -10

# Install SO-ARM101 package
echo "=== Installing SO-ARM101 ==="
cd /workspace/projects/isaac_so_arm101
rm -rf .venv
uv pip install --system --no-deps -e . 2>&1 | tail -3

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
