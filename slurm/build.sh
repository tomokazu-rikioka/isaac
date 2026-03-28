#!/bin/bash
#
# バッチジョブ: Docker イメージの pull & build
#
# 使い方:
#   cd ~/isaac && sbatch slurm/build.sh
#
#SBATCH --job-name=isaac-build
#SBATCH --gpus=1
#SBATCH --time=02:00:00
#SBATCH --output=logs/build_%j.out
#SBATCH --error=logs/build_%j.err

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/.."

mkdir -p "${PROJECT_DIR}/logs"

echo "============================================"
echo "  Isaac Lab Docker Build"
echo "============================================"
echo "  Node  : $(hostname)"
echo "  GPU   : CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-not set}"
echo "  Start : $(date)"
echo "============================================"

# --- Docker イメージ pull ---
echo ""
echo "[1/2] Pulling base Isaac Lab image (20-40 min)..."
echo "  Image: nvcr.io/nvidia/isaac-lab:2.3.2"
docker pull nvcr.io/nvidia/isaac-lab:2.3.2

# --- Docker イメージ build ---
echo ""
echo "[2/2] Building custom Isaac Lab image..."
cd "${PROJECT_DIR}/docker"
docker compose build isaac-lab

echo ""
echo "============================================"
echo "  Build complete: $(date)"
echo "============================================"
echo ""
echo "  確認:"
echo "    docker images | grep isaac-lab"
echo ""
echo "  次のステップ:"
echo "    cd ~/isaac && sbatch slurm/train.sh"
echo "============================================"
