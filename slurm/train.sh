#!/bin/bash
#
# バッチジョブ: SO-ARM101 RL トレーニング（ヘッドレス）
#
# 使い方:
#   cd ~/isaac && sbatch slurm/train.sh
#   cd ~/isaac && sbatch slurm/train.sh Isaac-SO-ARM101-Reach-v0
#   cd ~/isaac && sbatch slurm/train.sh Isaac-SO-ARM101-Lift-Cube-v0 --video
#
#SBATCH --job-name=isaac-train
#SBATCH --gpus=1
#SBATCH --output=logs/train_%j.out
#SBATCH --error=logs/train_%j.err

set -euo pipefail

PROJECT_DIR="${SLURM_SUBMIT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
source "${PROJECT_DIR}/scripts/env.sh"
[ -f "${PROJECT_DIR}/.env" ] && set -a && source "${PROJECT_DIR}/.env" && set +a

mkdir -p "${PROJECT_DIR}/logs"

TASK="${1:-Isaac-SO-ARM101-Reach-v0}"
shift || true
EXTRA_ARGS="$*"

echo "============================================"
echo "  Isaac Lab Batch Training"
echo "============================================"
echo "  Node  : $(hostname)"
echo "  Task  : ${TASK}"
echo "  Args  : ${EXTRA_ARGS:-(none)}"
echo "  GPU   : CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-not set}"
echo "  Start : $(date)"
echo "============================================"

HOST_UID=$(id -u)
HOST_GID=$(id -g)

docker run --rm \
    --name "isaac-train-${USER}-$$" \
    --gpus "device=${CUDA_VISIBLE_DEVICES}" \
    -e ACCEPT_EULA=Y \
    -e PRIVACY_CONSENT=Y \
    ${WANDB_API_KEY:+-e WANDB_API_KEY} \
    -v "${PROJECT_DIR}/logs:/workspace/isaac_so_arm101/logs" \
    -v "${PROJECT_DIR}/scripts:/workspace/scripts:ro" \
    --entrypoint bash \
    "${IMAGE}" \
    -c "source /isaac-sim/setup_conda_env.sh && source /workspace/scripts/env.sh && cd \${SOARM_DIR} && \${PYTHON} -m isaac_so_arm101.scripts.rsl_rl.train --task ${TASK} --headless ${EXTRA_ARGS}; chown -R ${HOST_UID}:${HOST_GID} /workspace/isaac_so_arm101/logs"

echo ""
echo "============================================"
echo "  Training complete: $(date)"
echo "============================================"
