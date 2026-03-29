# Isaac Lab on Remote A100 GPU (Slurm + Docker)

リモートA100 GPU（highreso環境、Slurm管理）上でIsaac LabをDockerコンテナで動かし、SO-ARM101 ロボットアームの強化学習（Reach / Lift タスク）をヘッドレス実行 + 動画ファイル転送で行う環境。

## クイックスタート

```bash
# 1. 変更をpush（Mac側）
git add -A && git commit -m "Update" && git push

# 2. リモートでクローン or 更新
ssh a100-highreso
git clone git@github.com:tomokazu-rikioka/isaac.git ~/isaac  # 初回のみ
cd ~/isaac && git pull                                        # 2回目以降

# 3. 初期セットアップ（初回のみ）
bash ~/isaac/scripts/setup-remote.sh

# 4. Docker イメージのビルド（初回のみ）
cd ~/isaac && sbatch slurm/build.sh

# 5. トレーニング実行
sbatch ~/isaac/slurm/train.sh                                  # Reach（デフォルト）
sbatch ~/isaac/slurm/train.sh Isaac-SO-ARM101-Lift-Cube-v0     # Lift

# 6. 評価（動画生成）
sbatch ~/isaac/slurm/play.sh                                   # Reach（デフォルト）
sbatch ~/isaac/slurm/play.sh Isaac-SO-ARM101-Lift-Cube-Play-v0 # Lift

# 7. ログ・動画をMacに転送
scp -r a100-highreso:~/isaac/logs/ ./logs/
```

## 詳細手順

[docs/setup-guide.md](docs/setup-guide.md) を参照。

## 構成

- **Docker**: Isaac Lab 2.3.2 (ヘッドレス + 動画生成)
- **タスク**: SO-ARM101 Reach (目標位置への到達) / SO-ARM101 Lift (キューブの持ち上げ)
- **Slurm**: バッチジョブ (トレーニング + 評価・動画生成)
- **可視化**: `--video` フラグで動画生成 → ファイル転送

## 利用可能なタスク

| タスク名 | 用途 | 環境数 |
|----------|------|--------|
| `Isaac-SO-ARM101-Reach-v0` | Reach トレーニング | 4096 |
| `Isaac-SO-ARM101-Reach-Play-v0` | Reach 評価 | 50 |
| `Isaac-SO-ARM101-Lift-Cube-v0` | Lift トレーニング | 4096 |
| `Isaac-SO-ARM101-Lift-Cube-Play-v0` | Lift 評価 | 50 |

## ファイル構成

```
isaac/
├── README.md                    # プロジェクト概要・クイックスタート
├── pyproject.toml               # Python パッケージ定義（isaac-so-arm101）
├── .dockerignore                # Docker ビルド時の除外ファイル定義
├── src/isaac_so_arm101/         # SO-ARM101 タスク定義・ロボット設定
├── docker/
│   ├── Dockerfile               # Isaac Lab 2.3.2 カスタムイメージ定義
│   └── docker-compose.yml       # Docker Compose ビルド設定
├── slurm/
│   ├── build.sh                 # Slurm バッチジョブスクリプト（Docker ビルド）
│   ├── train.sh                 # Slurm バッチジョブスクリプト（RL トレーニング）
│   └── play.sh                  # Slurm バッチジョブスクリプト（評価・動画生成）
├── scripts/
│   ├── env.sh                   # 共通環境変数定義
│   └── setup-remote.sh          # リモート初期セットアップ（環境確認・ディレクトリ作成）
├── logs/                        # Slurm ジョブ出力・学習ログ・動画
└── docs/
    ├── setup-guide.md           # 詳細セットアップ手順書
    └── status-report.md         # リアルタイム可視化の試行記録
```
