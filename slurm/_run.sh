#!/bin/bash
#
# Slurm バッチジョブ共通処理
# train.sh / play.sh から source して使用する（直接実行しない）

set -euo pipefail

PROJECT_DIR="${SLURM_SUBMIT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
source "${PROJECT_DIR}/scripts/env.sh"

mkdir -p "${PROJECT_DIR}/logs"

# バナー出力
# Usage: print_banner "Isaac Lab Batch Training" "${TASK}"
print_banner() {
    local title="$1"
    local task="$2"
    echo "============================================"
    echo "  ${title}"
    echo "============================================"
    echo "  Node  : $(hostname)"
    echo "  Task  : ${task}"
    echo "  GPU   : CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-not set}"
    echo "  Start : $(date)"
    echo "============================================"
}

# Docker コンテナ内でコマンドを実行
# Usage: run_in_container "コンテナ名" "実行コマンド"
run_in_container() {
    local container_name="$1"
    local cmd="$2"
    docker run --rm \
        --name "${container_name}" \
        --gpus "device=${CUDA_VISIBLE_DEVICES}" \
        -e ACCEPT_EULA=Y \
        -e PRIVACY_CONSENT=Y \
        -v "${PROJECT_DIR}/logs:/workspace/isaac_so_arm101/logs" \
        -v "${PROJECT_DIR}/scripts:/workspace/scripts:ro" \
        --entrypoint bash \
        "${IMAGE}" \
        -c "source /isaac-sim/setup_conda_env.sh && source /workspace/scripts/env.sh && cd \${SOARM_DIR} && ${cmd}"
}
