#!/bin/bash
#
# コンテナ内でチュートリアルを実行するヘルパースクリプト
#
# 使い方:
#   docker exec -it isaac-lab bash /workspace/scripts/run-in-container.sh [command]
#
# コマンド:
#   test          - 基本動作確認（ヘッドレス）
#   cartpole      - Cart-Poleチュートリアル（ヘッドレス）
#   soarm-setup   - SO-ARM101プロジェクトセットアップ
#   soarm-train   - SO-ARM101トレーニング（ヘッドレス）
#   soarm-play    - SO-ARM101評価（ヘッドレス + 動画生成）
#   soarm-list    - 利用可能な環境一覧
#

set -euo pipefail

export PATH="${HOME}/.local/bin:${PATH}"

COMMAND="${1:-help}"
ISAACLAB_DIR="/workspace/isaaclab"
SOARM_DIR="/workspace/projects/isaac_so_arm101"

case "${COMMAND}" in
    test)
        echo "=== Running basic test (headless) ==="
        cd "${ISAACLAB_DIR}"
        ./isaaclab.sh -p scripts/tutorials/00_sim/log_time.py --headless
        echo "=== Test passed! ==="
        ;;

    cartpole)
        echo "=== Running Cart-Pole tutorial (headless) ==="
        cd "${ISAACLAB_DIR}"
        ./isaaclab.sh -p scripts/tutorials/01_assets/run_articulation.py --headless
        ;;

    soarm-setup)
        echo "=== Setting up SO-ARM101 project ==="
        mkdir -p /workspace/projects

        if [ ! -d "${SOARM_DIR}" ]; then
            echo "Cloning isaac_so_arm101..."
            cd /workspace/projects
            git clone https://github.com/MuammerBay/isaac_so_arm101.git
        else
            echo "Repository already exists. Pulling latest..."
            cd "${SOARM_DIR}"
            git pull
        fi

        cd "${SOARM_DIR}"

        echo "Installing dependencies with uv..."
        uv sync 2>/dev/null || {
            echo "uv sync failed. Relaxing version pin..."
            sed -i 's/isaaclab\[all,isaacsim\]==2.3.0/isaaclab[all,isaacsim]>=2.3.0,<2.4.0/' pyproject.toml
            uv sync
        }

        echo ""
        echo "=== Setup complete! ==="
        echo "Available environments:"
        uv run list_envs
        ;;

    soarm-train)
        TASK="${2:-SO-ARM100-Reach-v0}"
        echo "=== Training SO-ARM101: ${TASK} (headless) ==="
        cd "${SOARM_DIR}"
        uv run train --task "${TASK}" --headless
        ;;

    soarm-play)
        TASK="${2:-SO-ARM100-Reach-Play-v0}"
        echo "=== Playing SO-ARM101: ${TASK} (headless + video) ==="
        cd "${SOARM_DIR}"
        uv run play --task "${TASK}" --headless --video --video_length 200
        echo "Video saved. Transfer to Mac: scp -r a100-highreso:~/isaac/logs/ ./logs/"
        ;;

    soarm-list)
        echo "=== Available SO-ARM101 environments ==="
        cd "${SOARM_DIR}"
        uv run list_envs
        ;;

    help|*)
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  test          - Basic headless test"
        echo "  cartpole      - Cart-Pole tutorial (headless)"
        echo "  soarm-setup   - Setup SO-ARM101 project"
        echo "  soarm-train   - Train SO-ARM101 (headless)"
        echo "  soarm-play    - Evaluate SO-ARM101 (headless + video)"
        echo "  soarm-list    - List available environments"
        ;;
esac
