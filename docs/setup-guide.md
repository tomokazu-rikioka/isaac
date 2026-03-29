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

## Phase 4: SO-ARM101 トレーニング・評価

カスタム Docker イメージ（`isaac-lab:2.3.2`）には SO-ARM101 がプリインストール済み。

### 4.1 トレーニング

```bash
cd ~/isaac && sbatch slurm/train.sh

# タスクを指定する場合:
cd ~/isaac && sbatch slurm/train.sh Isaac-SO-ARM101-Reach-v0
```

### 4.2 学習済みポリシーの評価（動画生成）

```bash
cd ~/isaac && sbatch slurm/play.sh
```

### 4.3 ジョブの確認

```bash
# ジョブ状態確認
squeue -u $(whoami)

# ログ確認
tail -f ~/isaac/logs/train_*.out
tail -f ~/isaac/logs/play_*.out

# ジョブキャンセル（必要な場合）
scancel <jobid>
```

### 4.4 結果の転送

```bash
# Mac側
scp -r a100-highreso:~/isaac/logs/ ./logs/
```

