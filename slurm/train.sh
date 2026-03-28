#!/bin/bash
#
# バッチジョブ: SO-ARM101 RL トレーニング（ヘッドレス）
#
# 使い方:
#   cd ~/isaac && sbatch slurm/train.sh
#   cd ~/isaac && sbatch slurm/train.sh SO-ARM100-Reach-v0
#
#SBATCH --job-name=isaac-train
#SBATCH --gpus=1
#SBATCH --output=logs/train_%j.out
#SBATCH --error=logs/train_%j.err

set -euo pipefail

PROJECT_DIR="${SLURM_SUBMIT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
source "${PROJECT_DIR}/scripts/env.sh"

TASK="${1:-SO-ARM100-Reach-v0}"
CONTAINER_NAME="isaac-train-${USER}-$$"

# ログディレクトリの確保（SBATCH --output の相対パス用）
mkdir -p "${PROJECT_DIR}/logs"

echo "============================================"
echo "  Isaac Lab Batch Training"
echo "============================================"
echo "  Node  : $(hostname)"
echo "  Task  : ${TASK}"
echo "  GPU   : CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-not set}"
echo "  Start : $(date)"
echo "============================================"

docker run --rm \
    --name "${CONTAINER_NAME}" \
    --gpus "device=${CUDA_VISIBLE_DEVICES}" \
    -e ACCEPT_EULA=Y \
    -e PRIVACY_CONSENT=Y \
    -v "${PROJECT_DIR}/logs:/workspace/isaaclab/logs" \
    -v "${PROJECT_DIR}/scripts:/workspace/scripts:ro" \
    --entrypoint bash \
    "${IMAGE}" \
    -c "source /isaac-sim/setup_python_env.sh && source /workspace/scripts/env.sh && cd \${SOARM_DIR} && \${PYTHON} -m isaac_so_arm101.scripts.rsl_rl.train --task ${TASK} --headless"

echo ""
echo "============================================"
echo "  Training complete: $(date)"
echo "============================================"
