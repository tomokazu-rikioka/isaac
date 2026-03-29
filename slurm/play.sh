#!/bin/bash
#
# バッチジョブ: SO-ARM101 評価（ヘッドレス + 動画生成）
#
# 使い方:
#   cd ~/isaac && sbatch slurm/play.sh
#   cd ~/isaac && sbatch slurm/play.sh Isaac-SO-ARM101-Reach-Play-v0
#
#SBATCH --job-name=isaac-play
#SBATCH --gpus=1
#SBATCH --output=logs/play_%j.out
#SBATCH --error=logs/play_%j.err

set -euo pipefail

PROJECT_DIR="${SLURM_SUBMIT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
source "${PROJECT_DIR}/scripts/env.sh"

mkdir -p "${PROJECT_DIR}/logs"

TASK="${1:-Isaac-SO-ARM101-Reach-Play-v0}"

echo "============================================"
echo "  Isaac Lab Policy Evaluation"
echo "============================================"
echo "  Node  : $(hostname)"
echo "  Task  : ${TASK}"
echo "  GPU   : CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-not set}"
echo "  Start : $(date)"
echo "============================================"

HOST_UID=$(id -u)
HOST_GID=$(id -g)

docker run --rm \
    --name "isaac-play-${USER}-$$" \
    --gpus "device=${CUDA_VISIBLE_DEVICES}" \
    -e ACCEPT_EULA=Y \
    -e PRIVACY_CONSENT=Y \
    -v "${PROJECT_DIR}/logs:/workspace/isaac_so_arm101/logs" \
    -v "${PROJECT_DIR}/scripts:/workspace/scripts:ro" \
    --entrypoint bash \
    "${IMAGE}" \
    -c "source /isaac-sim/setup_conda_env.sh && source /workspace/scripts/env.sh && cd \${SOARM_DIR} && \${PYTHON} -m isaac_so_arm101.scripts.rsl_rl.play --task ${TASK} --headless --video --video_length 200; chown -R ${HOST_UID}:${HOST_GID} /workspace/isaac_so_arm101/logs"

echo ""
echo "============================================"
echo "  Evaluation complete: $(date)"
echo "============================================"
echo ""
echo "  動画転送（Mac側）:"
echo "    scp -r a100-highreso:~/isaac/logs/ ./logs/"
echo "============================================"
