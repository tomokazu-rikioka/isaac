# Isaac Lab on Remote A100 GPU (Slurm + Docker) セットアップガイド

リモートA100 GPU（highreso環境）上でIsaac Labをdockerコンテナで動かし、ヘッドレス実行と動画ファイル転送でRL学習・評価を行う手順書。

## アーキテクチャ概要

```
Mac (local)                   Login Node                Compute Node (A100 GPU)
+----------+                  +----------+              +---------------------+
| Terminal |--SSH / git--->   | bastion  | ---------->  | Docker Container    |
|          |                  |          |              | +-- Isaac Lab 2.3.2 |
+----------+                  +----------+              | +-- rsl_rl          |
                                                        | +-- SO-ARM101       |
                                                        +---------------------+
```

## Phase 1: リモート環境の確認

### 前提条件

- `~/.ssh/config` に `a100-highreso` のホスト設定が済んでいること
- SSH 鍵認証でログインできること

### 1.1 ログインノードに接続

```bash
ssh a100-highreso
```

---

## Phase 2: プロジェクトファイルの配置

### 2.1 リモート側でクローン or 更新

初回:
```bash
git clone git@github.com:tomokazu-rikioka/isaac.git ~/isaac
```

2回目以降:
```bash
cd ~/isaac && git pull
```

### 2.2 初期セットアップ（初回のみ）

環境確認（Docker, GPU, Slurm）とディレクトリ作成を行う:

```bash
bash ~/isaac/scripts/setup-remote.sh
```

---

## Phase 3: Docker イメージの構築

### 3.1 ビルドジョブの投入

バッチジョブでベースイメージのpullとカスタムイメージのビルドを実行:

```bash
cd ~/isaac && sbatch slurm/build.sh
```

### 3.2 ビルド状況の確認

```bash
# ジョブ状態確認
squeue -u $(whoami)

# ログ確認
tail -f ~/isaac/logs/build_*.out
```

ビルド完了後、イメージを確認:
```bash
docker images | grep isaac-lab
# isaac-lab   2.3.2   ...
```

### 3.3 コンテナ内のディレクトリ構成

Docker イメージ内では以下の配置になる:

```
/workspace/
├── isaaclab/                # Isaac Lab 2.3.2 (ベースイメージ)
└── isaac_so_arm101/         # SO-ARM101 パッケージ (editable install)
    ├── pyproject.toml
    └── src/isaac_so_arm101/
```

---

## Phase 4: トレーニング・評価

カスタム Docker イメージ（`isaac-lab:2.3.2`）には SO-ARM101 がプリインストール済み。

### 4.1 Reach タスク（目標位置への到達）

エンドエフェクタ（グリッパー先端）を指定された目標位置に到達させるタスク。

**トレーニング:**

```bash
cd ~/isaac && sbatch slurm/train.sh
# または明示的に:
cd ~/isaac && sbatch slurm/train.sh Isaac-SO-ARM101-Reach-v0
```

**評価（動画生成）:**

```bash
cd ~/isaac && sbatch slurm/play.sh
# または明示的に:
cd ~/isaac && sbatch slurm/play.sh Isaac-SO-ARM101-Reach-Play-v0
```

| パラメータ | 値 |
|-----------|-----|
| 並列環境数 | 4096 (トレーニング) / 50 (評価) |
| max_iterations | 1000 |
| experiment_name | `reach` |
| ネットワーク構造 | [64, 64] |
| 学習率 | 1e-3 |
| エピソード長 | 12.0 秒 |

### 4.2 Lift タスク（キューブの持ち上げ）

キューブをグリッパーで掴み、目標位置まで持ち上げるタスク。Reach より複雑なため、大きなネットワーク（[256, 128, 64]）と多くのイテレーション（1500）を使用する。

**トレーニング:**

```bash
cd ~/isaac && sbatch slurm/train.sh Isaac-SO-ARM101-Lift-Cube-v0
```

**評価（動画生成）:**

```bash
cd ~/isaac && sbatch slurm/play.sh Isaac-SO-ARM101-Lift-Cube-Play-v0
```

| パラメータ | 値 |
|-----------|-----|
| 並列環境数 | 4096 (トレーニング) / 50 (評価) |
| max_iterations | 1500 |
| experiment_name | `lift` |
| ネットワーク構造 | [256, 128, 64] |
| 学習率 | 1e-4 |
| エピソード長 | 5.0 秒 |

### 4.3 出力ディレクトリ構成

学習・評価の出力は以下に保存される:

```
~/isaac/logs/rsl_rl/
├── reach/                          # Reach の experiment_name
│   └── YYYY-MM-DD_HH-MM-SS/       # タイムスタンプ付き実行ディレクトリ
│       ├── model_*.pt              # チェックポイント（50 iteration 毎）
│       ├── params/                 # ハイパーパラメータ（YAML）
│       └── videos/                 # 動画（play.sh 実行時のみ）
│           └── play/
│               └── rl-video-step_*.mp4
└── lift/                           # Lift の experiment_name
    └── YYYY-MM-DD_HH-MM-SS/
        └── ...
```

### 4.4 ジョブの確認

```bash
# ジョブ状態確認
squeue -u $(whoami)

# ログ確認
tail -f ~/isaac/logs/train_*.out
tail -f ~/isaac/logs/play_*.out

# ジョブキャンセル（必要な場合）
scancel <jobid>
```

### 4.5 結果の転送

```bash
# Mac側
scp -r a100-highreso:~/isaac/logs/ ./logs/
```

### 4.6 CLI 引数によるカスタマイズ

`slurm/train.sh` / `slurm/play.sh` は内部で `train.py` / `play.py` を実行する。コンテナ内で直接実行する場合、以下の引数が利用可能:

**train.py 主要引数:**

| 引数 | 説明 | デフォルト |
|------|------|-----------|
| `--task` | タスク名 | `Isaac-SO-ARM101-Reach-v0` |
| `--headless` | ヘッドレスモード | off |
| `--video` | 学習中の動画記録 | off |
| `--video_interval` | 動画記録間隔（ステップ） | 2000 |
| `--num_envs` | 並列環境数の上書き | タスク定義に依存 |
| `--max_iterations` | 学習イテレーション数 | タスク定義に依存 |
| `--seed` | 乱数シード | None |
| `--resume` | チェックポイントから再開 | off |
| `--load_run` | 再開する実行フォルダ名 | None |
| `--checkpoint` | 再開するチェックポイントファイル | None |

**play.py 主要引数:**

| 引数 | 説明 | デフォルト |
|------|------|-----------|
| `--task` | タスク名 | `Isaac-SO-ARM101-Reach-Play-v0` |
| `--headless` | ヘッドレスモード | off |
| `--video` | 動画記録 | off |
| `--video_length` | 動画長（ステップ） | 200 |
| `--load_run` | 評価する実行フォルダ名 | None |
| `--checkpoint` | 評価するチェックポイント | None |

---

## Phase 5: トラブルシューティング

### Docker イメージが見つからない

```bash
docker images | grep isaac-lab
# 出力がない場合、ビルドジョブを再実行:
cd ~/isaac && sbatch slurm/build.sh
```

### GPU メモリ不足

環境数を減らして再実行（コンテナ内で直接実行する場合）:

```bash
$PYTHON -m isaac_so_arm101.scripts.rsl_rl.train \
    --task Isaac-SO-ARM101-Reach-v0 --headless --num_envs 1024
```

### ジョブが PENDING のまま動かない

```bash
squeue -u $(whoami)           # ジョブ状態確認
sinfo                         # パーティション・ノード状態確認
scancel <jobid>               # 必要に応じてキャンセル
```

### 評価時に「No checkpoint found」エラー

学習ログが存在するか確認:

```bash
ls ~/isaac/logs/rsl_rl/reach/     # Reach の学習ログ
ls ~/isaac/logs/rsl_rl/lift/      # Lift の学習ログ
```

特定の実行を指定して評価する場合は `--load_run` でフォルダ名を指定する（コンテナ内で直接実行）。

### シェーダーコンパイルが長い

初回起動時はシェーダーコンパイルに 30〜60 秒かかる。2回目以降はキャッシュにより短縮される。長時間かかる場合はログを確認:

```bash
tail -f ~/isaac/logs/train_*.out
```
