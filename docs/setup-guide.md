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

## 前提条件

| 項目 | 要件 |
|------|------|
| Mac | macOS (Terminal + SSH) |
| リモート | A100 GPU, Docker, Slurm |
| SSH | `ssh a100-highreso` で接続可能（`~/.ssh/config`設定済み） |
| ネットワーク | 計算ノードからインターネット接続可能 |

---

## Phase 1: リモート環境の確認

### 1.1 ログインノードに接続

```bash
ssh a100-highreso
```

### 1.2 環境確認

```bash
# Docker
docker --version
# 期待: Docker version 24.0 以上

docker compose version
# 期待: Docker Compose version v2.25.0 以上

# Slurm
sinfo
# 期待: パーティション一覧が表示される

# ディスク容量（15GB以上必要）
df -h ~
```

### 1.3 GPU確認（計算ノードで実行）

ログインノードにGPUがない場合、インタラクティブジョブで確認:

```bash
srun --gres=gpu:1 --time=00:30:00 --pty bash  # GPU確認のみインタラクティブ実行
nvidia-smi
# 期待: NVIDIA A100 が表示される

# Docker GPU対応確認
docker run --rm --gpus all nvidia/cuda:12.4.0-base-ubuntu22.04 nvidia-smi
# 期待: コンテナ内からもA100が見える
exit
```

> **もし `--gpus all` が動かない場合**: CDI方式を試す
> ```bash
> docker run --rm --device nvidia.com/gpu=all nvidia/cuda:12.4.0-base-ubuntu22.04 nvidia-smi
> ```
> 動いた場合、`docker-compose.yml` の `deploy` セクションを以下に変更:
> ```yaml
> devices:
>   - /dev/nvidia0:/dev/nvidia0
>   - /dev/nvidiactl:/dev/nvidiactl
>   - /dev/nvidia-uvm:/dev/nvidia-uvm
> ```

---

## Phase 2: プロジェクトファイルの配置

### 2.1 Mac側で変更をpush

```bash
cd ~/Documents/01_Program/physical-ai/isaac
git add -A && git commit -m "Update Isaac Lab setup" && git push
```

### 2.2 リモート側でクローン or 更新

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

### 3.1 ベースイメージのpull

**インタラクティブジョブで実行**（計算ノードでDockerを使うため）:

```bash
ssh a100-highreso

# インタラクティブジョブを取得
srun --gres=gpu:1 --time=02:00:00 --pty bash  # ビルドのみインタラクティブ実行

# ベースイメージのpull（10-15GB、20-40分程度）
docker pull nvcr.io/nvidia/isaac-lab:2.3.2
```

> **NGC認証が必要な場合**:
> ```bash
> docker login nvcr.io
> # Username: $oauthtoken
> # Password: <NGC API Key>
> ```
> NGC API Keyは https://ngc.nvidia.com/ から取得。

### 3.2 カスタムイメージのビルド

```bash
cd ~/isaac/docker

docker compose build isaac-lab
# 期待: Successfully built isaac-lab:2.3.2

# 確認
docker images | grep isaac-lab
# isaac-lab   2.3.2   ...
```

ビルド完了後、インタラクティブジョブを終了:
```bash
exit
```

---

## Phase 4: Isaac Lab 基本チュートリアル

### 4.1 基本動作確認（ヘッドレス）

リモートのコンテナ内で:

```bash
# コンテナに入る
docker exec -it isaac-lab bash

# Isaac Lab ディレクトリに移動
cd /workspace/isaaclab

# 最もシンプルなテスト
./isaaclab.sh -p scripts/tutorials/00_sim/log_time.py --headless
# 期待: シミュレーション時間のログが出力される（エラーなし）
```

> **初回は5-15分かかる**: シェーダーコンパイルが走るため。
> 2回目以降はキャッシュボリュームにより数秒で起動。

### 4.2 Cart-Pole チュートリアル（ヘッドレス）

```bash
cd /workspace/isaaclab
./isaaclab.sh -p scripts/tutorials/01_assets/run_articulation.py --headless
# 期待: Cart-Poleシミュレーションが実行される
# Ctrl+C で終了
```

---

## Phase 5: SO-ARM101 ロボットアーム チュートリアル

### 5.1 プロジェクトセットアップ

カスタム Docker イメージ（`isaac-lab:2.3.2`）には SO-ARM101 がプリインストール済み。
追加セットアップは不要。

最新版に更新する場合のみ:
```bash
docker exec -it isaac-lab bash /workspace/scripts/run-in-container.sh soarm-setup
```

> **バージョン競合でエラーが出た場合**:
> `isaac_so_arm101` が `isaaclab==2.3.0` を要求し、コンテナには2.3.2が入っている場合:
> ```bash
> cd /workspace/projects/isaac_so_arm101
> sed -i 's/isaaclab\[all,isaacsim\]==2.3.0/isaaclab[all,isaacsim]>=2.3.0,<2.4.0/' pyproject.toml
> uv pip install --system --no-deps -e .
> ```

### 5.2 利用可能な環境の確認

```bash
docker exec -it isaac-lab bash /workspace/scripts/run-in-container.sh soarm-list
# 期待:
#   SO-ARM100-Reach-v0        (トレーニング用)
#   SO-ARM100-Reach-Play-v0   (評価用)
```

### 5.3 トレーニング（ヘッドレス）

```bash
docker exec -it isaac-lab bash /workspace/scripts/run-in-container.sh soarm-train
# デフォルト: SO-ARM100-Reach-v0
# 期待: トレーニングの進捗ログが表示される
# 学習済みモデルは logs/ 以下に保存される

# タスクを指定する場合:
docker exec -it isaac-lab bash /workspace/scripts/run-in-container.sh soarm-train SO-ARM100-Reach-v0
```

> **長時間トレーニングにはバッチジョブを推奨**:
> ```bash
> # ログインノードから
> cd ~/isaac && sbatch slurm/train.sh
> ```

### 5.4 学習済みポリシーの評価（ヘッドレス + 動画生成）

```bash
docker exec -it isaac-lab bash /workspace/scripts/run-in-container.sh soarm-play
# デフォルト: SO-ARM100-Reach-Play-v0
# 期待: 動画ファイルが logs/ 以下に生成される
```

動画をMacに転送して確認:
```bash
# Mac側
scp -r a100-highreso:~/isaac/logs/ ./logs/
```

---

## バッチトレーニングの実行

長時間のトレーニングはバッチジョブで実行し、端末を閉じても継続:

```bash
ssh a100-highreso

# トレーニングジョブ投入
cd ~/isaac && sbatch slurm/train.sh

# ジョブ状態確認
squeue -u $(whoami)
# 期待: RUNNING 状態

# ログ確認
tail -f ~/isaac/logs/train_<jobid>.out

# ジョブキャンセル（必要な場合）
scancel <jobid>
```

---

## トラブルシューティング

### Docker イメージの pull が失敗する

```bash
# NGC認証
docker login nvcr.io
# Username: $oauthtoken
# Password: <NGC API Key>

# リトライ
docker pull nvcr.io/nvidia/isaac-lab:2.3.2
```

### コンテナ内で GPU が見えない

```bash
# コンテナ内で確認
nvidia-smi

# 見えない場合、docker-compose.yml の deploy セクションを確認
# --gpus all の代わりに CDI を使う場合がある（Phase 1.3 参照）
```

### Isaac Sim 初回起動が非常に遅い

正常動作。シェーダーコンパイルに5-15分かかる。キャッシュボリューム（`isaac-cache-*`）により2回目以降は高速化される。

```bash
# キャッシュが破損した場合のリセット
cd ~/isaac/docker
docker compose down -v   # ボリュームも削除
docker compose build isaac-lab
```

### Vulkan エラーで Isaac Sim がクラッシュ

```bash
# ホストのNVIDIAドライバーバージョン確認
nvidia-smi | head -3
# ドライバー 535 以上が推奨

# Vulkan 動作確認
docker exec isaac-lab vulkaninfo --summary 2>&1 | head -20
```

### SSH 接続が切断される

Mac の `~/.ssh/config` に以下を追加:

```
Host a100-highreso
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

### バージョン競合でインストールが失敗する

```bash
# pyproject.toml のバージョンピンを緩和
cd /workspace/projects/isaac_so_arm101
sed -i 's/isaaclab\[all,isaacsim\]==2.3.0/isaaclab[all,isaacsim]>=2.3.0,<2.4.0/' pyproject.toml
uv pip install --system --no-deps -e .
```

### ディスク容量不足

```bash
# Docker リソース確認
docker system df

# 不要なイメージ・ボリューム削除
docker system prune -a
```

---

## ファイル構成

```
isaac/
├── docker/
│   ├── Dockerfile              # Isaac Lab イメージ
│   └── docker-compose.yml      # ビルド定義
├── slurm/
│   └── train.sh                # バッチトレーニングジョブ
├── scripts/
│   ├── env.sh                  # 共通環境変数定義
│   ├── setup-remote.sh         # リモート初期セットアップ
│   └── run-in-container.sh     # コンテナ内ヘルパー（全操作の単一エントリポイント）
└── docs/
    ├── setup-guide.md          # この手順書
    └── status-report.md        # リアルタイム可視化 試行記録
```

## 使用技術バージョン

| 項目 | バージョン |
|------|-----------|
| Isaac Lab | 2.3.2 |
| Isaac Sim | 5.1.0 (Isaac Lab同梱) |
| Python | 3.11 |
| Docker image | `nvcr.io/nvidia/isaac-lab:2.3.2` |
| SO-ARM101 | [MuammerBay/isaac_so_arm101](https://github.com/MuammerBay/isaac_so_arm101) |

## 参考資料

- [ABEJA Tech Blog: Isaac Sim/Lab入門](https://tech-blog.abeja.asia/entry/isaac-sim-lab-202507)
- [Isaac Lab公式ドキュメント](https://isaac-sim.github.io/IsaacLab/main/)
- [Isaac Lab Docker Deployment](https://isaac-sim.github.io/IsaacLab/main/source/deployment/docker.html)
- [SO-ARM101 Isaac Lab Project](https://github.com/MuammerBay/isaac_so_arm101)
- [Seeed Studio: Training SO-ARM101 with Isaac Lab](https://wiki.seeedstudio.com/training_soarm101_policy_with_isaacLab/)
- [Isaac Lab Articulation Tutorial](https://isaac-sim.github.io/IsaacLab/main/source/tutorials/01_assets/run_articulation.html)
