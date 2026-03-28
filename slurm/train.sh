#!/bin/bash
#
# バッチジョブ: SO-ARM101 RL トレーニング（ヘッドレス）
#
# 使い方:
#   sbatch ~/isaac/slurm/train.sh
#   sbatch ~/isaac/slurm/train.sh SO-ARM100-Reach-v0
#
#SBATCH --job-name=isaac-train
#SBATCH --gpus=1
#SBATCH --output=logs/train_%j.out
#SBATCH --error=logs/train_%j.err

set -euo pipefail

TASK="${1:-Isaac-SO-ARM100-Reach-v0}"
IMAGE="isaac-lab:2.3.2"
CONTAINER_NAME="isaac-train-${USER}-$$"

echo "============================================"
echo "  Isaac Lab Batch Training"
echo "============================================"
echo "  Node  : $(hostname)"
echo "  Task  : ${TASK}"
echo "  GPU   : CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-not set}"
echo "  Start : $(date)"
echo "============================================"

TRAIN_SCRIPT="/workspace/isaac_so_arm101/src/isaac_so_arm101/scripts/rsl_rl/train.py"

docker run --rm \
    --name "${CONTAINER_NAME}" \
    --gpus "device=${CUDA_VISIBLE_DEVICES}" \
    -e ACCEPT_EULA=Y \
    -e PRIVACY_CONSENT=Y \
    -v "${HOME}/isaac:/mnt/isaac" \
    -v "${HOME}/isaac/logs:/workspace/isaaclab/logs" \
    -v "${HOME}/isaac/scripts:/workspace/scripts:ro" \
    --entrypoint bash \
    "${IMAGE}" \
    -c "cd /workspace/isaaclab && ./isaaclab.sh -p ${TRAIN_SCRIPT} --task ${TASK} --headless"

echo ""
echo "============================================"
echo "  Training complete: $(date)"
echo "============================================"
