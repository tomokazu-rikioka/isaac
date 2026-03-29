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

source "$(dirname "$0")/_run.sh"

TASK="${1:-Isaac-SO-ARM101-Reach-Play-v0}"

print_banner "Isaac Lab Policy Evaluation" "${TASK}"

run_in_container "isaac-play-${USER}-$$" \
    "\${PYTHON} -m isaac_so_arm101.scripts.rsl_rl.play --task ${TASK} --headless --video --video_length 200"

echo ""
echo "============================================"
echo "  Evaluation complete: $(date)"
echo "============================================"
echo ""
echo "  動画転送（Mac側）:"
echo "    scp -r a100-highreso:~/isaac/logs/ ./logs/"
echo "============================================"
