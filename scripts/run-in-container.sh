#!/bin/bash
#
# コンテナ内操作の単一エントリポイント
#
# 使い方:
#   docker exec -it isaac-lab bash /workspace/scripts/run-in-container.sh [command]
#
# コマンド:
#   test          - 基本動作確認（ヘッドレス）
#   cartpole      - Cart-Poleチュートリアル（ヘッドレス）
#   soarm-setup   - SO-ARM101を最新に更新・再インストール
#   soarm-train   - SO-ARM101トレーニング（ヘッドレス）
#   soarm-play    - SO-ARM101評価（ヘッドレス + 動画生成）
#   soarm-list    - 利用可能な環境一覧
#

set -euo pipefail

export PATH="${HOME}/.local/bin:${PATH}"

COMMAND="${1:-help}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/env.sh"

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
        echo "=== SO-ARM101 更新・再インストール ==="
        if [ ! -d "${SOARM_DIR}" ]; then
            echo "ERROR: ${SOARM_DIR} が見つかりません。Docker イメージを再ビルドしてください。"
            exit 1
        fi
        cd "${SOARM_DIR}"
        echo "最新コードを取得中..."
        git pull
        echo "再インストール中..."
        rm -rf .venv
        uv pip install --system --no-deps -e .
        echo ""
        echo "=== 更新完了 ==="
        echo "利用可能な環境:"
        $PYTHON -c "import gymnasium as gym; import isaac_so_arm101; [print(f'  {e}') for e in gym.envs.registry if 'SO' in e.upper() or 'ARM' in e.upper()]"
        ;;

    soarm-train)
        TASK="${2:-SO-ARM100-Reach-v0}"
        echo "=== Training SO-ARM101: ${TASK} (headless) ==="
        cd "${SOARM_DIR}"
        $PYTHON -m isaac_so_arm101.scripts.rsl_rl.train --task "${TASK}" --headless
        ;;

    soarm-play)
        TASK="${2:-SO-ARM100-Reach-Play-v0}"
        echo "=== Playing SO-ARM101: ${TASK} (headless + video) ==="
        cd "${SOARM_DIR}"
        $PYTHON -m isaac_so_arm101.scripts.rsl_rl.play --task "${TASK}" --headless --video --video_length 200
        echo "Video saved. Transfer to Mac: scp -r a100-highreso:~/isaac/logs/ ./logs/"
        ;;

    soarm-list)
        echo "=== Available SO-ARM101 environments ==="
        cd "${SOARM_DIR}"
        $PYTHON -c "import gymnasium as gym; import isaac_so_arm101; [print(f'  {e}') for e in gym.envs.registry if 'SO' in e.upper() or 'ARM' in e.upper()]"
        ;;

    help|*)
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  test          - Basic headless test"
        echo "  cartpole      - Cart-Pole tutorial (headless)"
        echo "  soarm-setup   - Update & reinstall SO-ARM101"
        echo "  soarm-train   - Train SO-ARM101 (headless)"
        echo "  soarm-play    - Evaluate SO-ARM101 (headless + video)"
        echo "  soarm-list    - List available environments"
        ;;
esac
