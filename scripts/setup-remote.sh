#!/bin/bash
#
# リモートホスト（A100 highreso）初期セットアップスクリプト
#
# 使い方: ssh a100-highreso で接続後に実行
#   bash setup-remote.sh
#
# このスクリプトは以下を行う:
#   1. 環境確認（Docker, GPU, Slurm）
#   2. プロジェクトディレクトリ作成
#   3. Docker イメージのpull & build
#

set -euo pipefail

echo "============================================"
echo "  Isaac Lab Remote Setup"
echo "============================================"
echo ""

# --- 環境確認 ---
echo "[1/6] Checking environment..."

echo -n "  Docker: "
if command -v docker &>/dev/null; then
    docker --version
else
    echo "NOT FOUND - Docker is required"
    exit 1
fi

echo -n "  Docker Compose: "
if docker compose version &>/dev/null; then
    docker compose version
else
    echo "NOT FOUND - Docker Compose is required"
    exit 1
fi

echo -n "  NVIDIA GPU: "
if command -v nvidia-smi &>/dev/null; then
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null || echo "Available (details in compute node)"
else
    echo "nvidia-smi not found on login node (may be available on compute nodes)"
fi

echo -n "  Slurm: "
if command -v sinfo &>/dev/null; then
    echo "Available"
    echo "  Partitions:"
    sinfo --format="    %P %l %D %G" 2>/dev/null || echo "    (could not list partitions)"
else
    echo "NOT FOUND"
fi

# --- ディスク容量確認 ---
echo ""
echo "[2/6] Checking disk space..."
df -h "${HOME}" | tail -1
echo "  (Isaac Lab image requires ~15GB+)"

# --- プロジェクトディレクトリ ---
echo ""
echo "[3/6] Setting up project directory..."
PROJECT_DIR="${HOME}/isaac"
mkdir -p "${PROJECT_DIR}/docker"
mkdir -p "${PROJECT_DIR}/slurm"
mkdir -p "${PROJECT_DIR}/scripts"
mkdir -p "${PROJECT_DIR}/logs"
echo "  Created: ${PROJECT_DIR}"

# --- ファイルコピー確認 ---
echo ""
echo "[4/6] Checking project files..."
if [ -f "${PROJECT_DIR}/docker/Dockerfile" ]; then
    echo "  Project files found."
else
    echo "  WARNING: Project files not found in ${PROJECT_DIR}/docker/"
    echo "  Please clone the repository first:"
    echo "    git clone git@github.com:tomokazu-rikioka/isaac.git ~/isaac"
    exit 1
fi

# --- Docker イメージ pull ---
echo ""
echo "[5/6] Pulling base Isaac Lab image (this may take 20-40 minutes)..."
echo "  Image: nvcr.io/nvidia/isaac-lab:2.3.2"
docker pull nvcr.io/nvidia/isaac-lab:2.3.2

# --- Docker イメージ build ---
echo ""
echo "[6/6] Building Isaac Lab image..."
cd "${PROJECT_DIR}/docker"

docker compose build isaac-lab

echo ""
echo "============================================"
echo "  Setup complete!"
echo "============================================"
echo ""
echo "  次のステップ:"
echo "  1. トレーニングジョブ実行:"
echo "     sbatch ~/isaac/slurm/train.sh"
echo ""
echo "  2. ログ確認:"
echo "     tail -f ~/isaac/logs/train_*.out"
echo ""
echo "  3. 動画・モデル転送（Mac側）:"
echo "     scp -r a100-highreso:~/isaac/logs/ ./logs/"
echo "============================================"
