#!/bin/bash
#
# バッチジョブ: SO-ARM101 RL トレーニング（ヘッドレス）
#
# 使い方:
#   cd ~/isaac && sbatch slurm/train.sh
#   cd ~/isaac && sbatch slurm/train.sh Isaac-SO-ARM101-Reach-v0
#
#SBATCH --job-name=isaac-train
#SBATCH --gpus=1
#SBATCH --output=logs/train_%j.out
#SBATCH --error=logs/train_%j.err

source "${SLURM_SUBMIT_DIR}/slurm/_run.sh"

TASK="${1:-Isaac-SO-ARM101-Reach-v0}"

print_banner "Isaac Lab Batch Training" "${TASK}"

run_in_container "isaac-train-${USER}-$$" \
    "\${PYTHON} -m isaac_so_arm101.scripts.rsl_rl.train --task ${TASK} --headless"

echo ""
echo "============================================"
echo "  Training complete: $(date)"
echo "============================================"
