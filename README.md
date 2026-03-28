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

# 4. トレーニング実行
sbatch ~/isaac/slurm/train.sh

# 5. ログ・動画をMacに転送
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
│   └── train.sh                 # Slurm バッチジョブスクリプト（RL トレーニング）
├── scripts/
│   ├── setup-remote.sh          # リモート初期セットアップ（環境確認・Docker ビルド）
│   ├── run-in-container.sh      # コンテナ内ヘルパー（test/cartpole/soarm-*）
│   ├── soarm-setup.sh           # SO-ARM101 依存関係インストール
│   ├── soarm-train.sh           # SO-ARM101 トレーニング実行
│   └── verify-and-train.sh      # トレーニング検証・起動スクリプト
└── docs/
    ├── setup-guide.md           # 詳細セットアップ手順書
    └── status-report.md         # リアルタイム可視化の試行記録
```
