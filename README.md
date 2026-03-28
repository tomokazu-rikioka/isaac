# Isaac Lab on Remote A100 GPU (Slurm + Docker)

リモートA100 GPU（highreso環境、Slurm管理）上でIsaac LabをDockerコンテナで動かし、ヘッドレス実行 + 動画ファイル転送でRL学習・評価を行う環境。

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
sbatch ~/isaac/slurm/train.sh

# 6. ログ・動画をMacに転送
scp -r a100-highreso:~/isaac/logs/ ./logs/
```

## 詳細手順

[docs/setup-guide.md](docs/setup-guide.md) を参照。

## 構成

- **Docker**: Isaac Lab 2.3.2 (ヘッドレス + 動画生成)
- **チュートリアル**: Cart-Pole (基本) / SO-ARM101 Reach (ロボットアーム)
- **Slurm**: バッチジョブ (トレーニング + 動画生成)
- **可視化**: `--video` フラグで動画生成 → ファイル転送

## ファイル構成

```
isaac/
├── README.md                    # プロジェクト概要・クイックスタート
├── docker/
│   ├── Dockerfile               # Isaac Lab 2.3.2 カスタムイメージ定義
│   └── docker-compose.yml       # Docker Compose ビルド設定
├── slurm/
│   ├── build.sh                 # Slurm バッチジョブスクリプト（Docker ビルド）
│   ├── train.sh                 # Slurm バッチジョブスクリプト（RL トレーニング）
│   └── play.sh                  # Slurm バッチジョブスクリプト（評価・動画生成）
├── scripts/
│   ├── env.sh                   # 共通環境変数定義
│   ├── setup-remote.sh          # リモート初期セットアップ（環境確認・Docker ビルド）
│   └── run-in-container.sh      # コンテナ内ヘルパー（test/cartpole/soarm-*）
└── docs/
    ├── setup-guide.md           # 詳細セットアップ手順書
    └── status-report.md         # リアルタイム可視化の試行記録
```
