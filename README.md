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

## 強化学習の全体像

本プロジェクトでは、NVIDIA Isaac Lab の `ManagerBasedRLEnv` フレームワークと RSL-RL ライブラリ（PPO アルゴリズム）を使用して、SO-ARM101 ロボットアームをシミュレーション上で学習させる。

### パイプライン

```
┌─────────────────────────────┐      ┌───────────────────────────┐
│  環境 (Isaac Lab)            │      │  エージェント (RSL-RL)     │
│                             │      │                           │
│  Scene (ロボット + オブジェクト)│      │  Actor-Critic ニューラル   │
│  Observations (観測)    ─────┼─────>│  ネットワーク (MLP)         │
│  Rewards (報酬)         <────┼──────│  Policy → Actions (行動)  │
│  Terminations (終了条件)     │      │  Value → 状態価値推定      │
│  Curriculum (カリキュラム)    │      │                           │
│  Commands (目標生成)         │      │  PPO で方策を更新          │
└─────────────────────────────┘      └───────────────────────────┘
```

### 学習ループ

1. **ロールアウト収集**: 4096 個の並列環境でポリシーを実行し、観測・行動・報酬のデータを収集
2. **アドバンテージ推定**: GAE (Generalized Advantage Estimation) でアドバンテージを計算
3. **ポリシー更新**: PPO のクリップされた目的関数で Actor-Critic ネットワークを更新
4. **繰り返し**: 指定イテレーション数（Reach: 1000 / Lift: 1500）まで 1-3 を繰り返す

### MDP の構成要素

各タスクは以下の要素で構成される（Isaac Lab の Manager-Based 環境アーキテクチャ）:

| 要素 | 役割 | 設定クラス |
|------|------|-----------|
| **Scene** | ロボット・テーブル・オブジェクトの配置 | `InteractiveSceneCfg` |
| **Observations** | ポリシーへの入力（関節角度、速度など） | `ObservationsCfg` |
| **Actions** | ポリシーの出力（関節位置指令） | `ActionsCfg` |
| **Rewards** | 行動の良し悪しを評価するスカラー値 | `RewardsCfg` |
| **Terminations** | エピソード終了条件 | `TerminationsCfg` |
| **Curriculum** | 学習の進行に応じた報酬重みの変更 | `CurriculumCfg` |
| **Commands** | ランダムな目標位置の生成 | `CommandsCfg` |

## 準備するもの

### ロボット: SO-ARM101

6 自由度 + グリッパーの小型ロボットアーム。URDF で定義され、Isaac Lab 内で物理シミュレーションされる。

- **URDF**: `src/isaac_so_arm101/robots/so_arm101/urdf/so_arm101.urdf`
- **設定**: `src/isaac_so_arm101/robots/so_arm101/so_arm101.py`

#### 関節構成

| 関節名 | 役割 | 初期角度 (rad) | Stiffness | Damping |
|--------|------|---------------|-----------|---------|
| `shoulder_pan` | ベース回転 | 0.0 | 200.0 | 80.0 |
| `shoulder_lift` | 肩ピッチ | 0.0 | 170.0 | 65.0 |
| `elbow_flex` | 肘屈曲 | 0.0 | 120.0 | 45.0 |
| `wrist_flex` | 手首ピッチ | 1.57 | 80.0 | 30.0 |
| `wrist_roll` | 手首回転 | 0.0 | 50.0 | 20.0 |
| `gripper` | グリッパー開閉 | 0.0 | 60.0 | 20.0 |

- **制御方式**: PD 制御（`ImplicitActuatorCfg`）
- **ベース**: 固定（`fix_base=True`）
- **自己衝突**: 有効（`enabled_self_collisions=True`）
- **Stiffness / Damping**: 根元ほど高く、先端ほど低い（各関節が動かす質量に比例）

### シーン構成

- **地面**: GroundPlane（z = -1.05 m）
- **テーブル**: Seattle Lab Table
- **照明**: DomeLight（強度 2500〜3000）
- **環境間隔**: 2.5 m
- **並列環境数**: 学習時 4096 / 評価時 50
- **シミュレーション周波数**: Reach 約 60Hz / Lift 100Hz（`decimation=2` でポリシー実行はその半分）

### 実行環境

- **Docker イメージ**: `nvcr.io/nvidia/isaac-lab:2.3.2` ベース + RSL-RL + isaac-so-arm101
- **GPU**: A100（Slurm バッチジョブで管理）
- **パッケージ管理**: `uv` による editable install

詳細なセットアップ手順は [docs/setup-guide.md](docs/setup-guide.md) を参照。

## タスク詳細

### Reach タスク（`Isaac-SO-ARM101-Reach-v0`）

**目標**: エンドエフェクタ（`gripper_link`）をランダムな 3D 目標位置に到達させる。

#### 観測（Observations）

| 項目 | 関数 | ノイズ | 説明 |
|------|------|--------|------|
| `joint_pos` | `joint_pos_rel` | Uniform ±0.01 | 相対関節位置 |
| `joint_vel` | `joint_vel_rel` | Uniform ±0.01 | 相対関節速度 |
| `pose_command` | `generated_commands` | - | EE 目標位置（6D） |
| `actions` | `last_action` | - | 前ステップの行動 |

#### 行動（Actions）

- **方式**: `JointPositionActionCfg`（関節位置制御）
- **対象関節**: 全 6 関節（`[".*"]`）
- **スケール**: 0.5（ポリシー出力 [-1, 1] → 関節オフセット [-0.5, 0.5] rad）
- **デフォルトオフセット**: 初期関節角度を基準

#### 報酬（Rewards）

| 項目 | 関数 | 重み | 説明 |
|------|------|------|------|
| `position_tracking` | `position_command_error` | -0.2 | EE 位置誤差（L2 距離ペナルティ） |
| `position_fine_grained` | `position_command_error_tanh` | 0.1 | EE 位置誤差（tanh カーネル、std=0.1） |
| `orientation_tracking` | `orientation_command_error` | 0.0 | 姿勢誤差（SO-ARM101 では無効化） |
| `action_rate` | `action_rate_l2` | -0.0001 | 行動変化率ペナルティ |
| `joint_vel` | `joint_vel_l2` | -0.0001 | 関節速度ペナルティ |

- **tanh カーネル**: `1 - tanh(distance / std)` により、目標に近づくほど高い報酬を返す。L2 距離のみだと目標付近で勾配が小さくなるため、tanh で補完する。

#### カリキュラム

| 項目 | 初期重み | 最終重み | ステップ数 |
|------|---------|---------|-----------|
| `action_rate` | -0.0001 | -0.005 | 4500 |
| `joint_vel` | -0.0001 | -0.001 | 4500 |

学習初期はペナルティを小さくして探索を促し、後半はペナルティを大きくして滑らかな動作を学習させる。

#### コマンド生成

ランダムな目標位置を 5 秒ごとに再生成:

| 軸 | 範囲 (m) |
|----|---------|
| x | -0.1 〜 0.1 |
| y | -0.25 〜 -0.1 |
| z | 0.1 〜 0.3 |

姿勢（roll / pitch / yaw）は固定（0.0）。

#### 終了条件

- **タイムアウト**: 12.0 秒

#### PPO ハイパーパラメータ

| パラメータ | 値 |
|-----------|-----|
| ネットワーク構造（Actor / Critic） | [64, 64] |
| 活性化関数 | ELU |
| 学習率 | 1e-3（adaptive schedule） |
| gamma（割引率） | 0.99 |
| lambda（GAE） | 0.95 |
| clip_param | 0.2 |
| entropy_coef | 0.001 |
| num_learning_epochs | 8 |
| num_mini_batches | 4 |
| num_steps_per_env | 24 |
| max_iterations | 1000 |
| save_interval | 50 iterations ごと |

設定ファイル: `src/isaac_so_arm101/tasks/reach/agents/rsl_rl_ppo_cfg.py`

---

### Lift タスク（`Isaac-SO-ARM101-Lift-Cube-v0`）

**目標**: テーブル上のキューブ（DexCube、0.5x スケール）をグリッパーで掴み、ランダムな目標位置まで持ち上げる。

#### 追加シーン要素

- **オブジェクト**: DexCube（初期位置 [0.2, 0.0, 0.015]）
- **EE フレーム**: `FrameTransformerCfg` で `gripper_link` からオフセット [0.01, 0.0, -0.09] を追跡

#### 観測（Observations）

| 項目 | 関数 | 説明 |
|------|------|------|
| `joint_pos` | `joint_pos_rel` | 相対関節位置 |
| `joint_vel` | `joint_vel_rel` | 相対関節速度 |
| `object_position` | `object_position_in_robot_root_frame` | ロボット座標系でのオブジェクト位置（カスタム関数） |
| `target_object_position` | `generated_commands` | オブジェクト目標位置 |
| `actions` | `last_action` | 前ステップの行動 |

`object_position_in_robot_root_frame` はカスタム観測関数で、ワールド座標のオブジェクト位置をロボットのベース座標系に変換する（`src/isaac_so_arm101/tasks/lift/mdp/observations.py`）。

#### 行動（Actions）

2 つのアクショングループ:

| グループ | 方式 | 対象関節 | 詳細 |
|---------|------|---------|------|
| `arm_action` | `JointPositionActionCfg` | `shoulder_*`, `elbow_flex`, `wrist_*`（5 関節） | scale=0.5 |
| `gripper_action` | `BinaryJointPositionActionCfg` | `gripper`（1 関節） | open=0.5 / close=0.0 |

グリッパーはバイナリ制御（開く or 閉じるの 2 値）。

#### 報酬（Rewards）

| 項目 | 関数 | 重み | 説明 |
|------|------|------|------|
| `reaching_object` | `object_ee_distance` | 1.0 | EE とオブジェクトの距離（tanh、std=0.05） |
| `lifting_object` | `object_is_lifted` | 15.0 | オブジェクト高さ > 0.025m で +1 |
| `object_goal_tracking` | `object_goal_distance` | 16.0 | 目標位置との距離（tanh、std=0.3、高さ > 0.025m） |
| `object_goal_fine_grained` | `object_goal_distance` | 5.0 | 目標位置との距離（tanh、std=0.05、高さ > 0.025m） |
| `action_rate` | `action_rate_l2` | -1e-4 | 行動変化率ペナルティ |
| `joint_vel` | `joint_vel_l2` | -1e-4 | 関節速度ペナルティ |

カスタム報酬関数は `src/isaac_so_arm101/tasks/lift/mdp/rewards.py` に定義:
- `object_is_lifted`: オブジェクトの z 座標が閾値以上かどうかの二値報酬
- `object_ee_distance`: `1 - tanh(distance / std)` で EE とオブジェクト間の距離を評価
- `object_goal_distance`: オブジェクトが持ち上がっている場合のみ、目標位置との距離を評価

#### カリキュラム

| 項目 | 初期重み | 最終重み | ステップ数 |
|------|---------|---------|-----------|
| `action_rate` | -1e-4 | -1e-1 | 10000 |
| `joint_vel` | -1e-4 | -1e-1 | 10000 |

Reach より長いカリキュラム期間と大きな最終ペナルティ（タスクがより複雑なため）。

#### コマンド生成

ランダムな目標位置を 5 秒ごとに再生成:

| 軸 | 範囲 (m) |
|----|---------|
| x | -0.1 〜 0.1 |
| y | -0.3 〜 -0.1 |
| z | 0.2 〜 0.35 |

#### 終了条件

- **タイムアウト**: 5.0 秒
- **オブジェクト落下**: z < -0.05 m（テーブルから落下した場合）

#### PPO ハイパーパラメータ

| パラメータ | 値 |
|-----------|-----|
| ネットワーク構造（Actor / Critic） | [256, 128, 64] |
| 活性化関数 | ELU |
| 学習率 | 1e-4（adaptive schedule） |
| gamma（割引率） | 0.98 |
| lambda（GAE） | 0.95 |
| clip_param | 0.2 |
| entropy_coef | 0.006 |
| num_learning_epochs | 5 |
| num_mini_batches | 4 |
| num_steps_per_env | 24 |
| max_iterations | 1500 |
| save_interval | 50 iterations ごと |

設定ファイル: `src/isaac_so_arm101/tasks/lift/agents/rsl_rl_ppo_cfg.py`

---

### Reach と Lift の設計比較

| 項目 | Reach | Lift | 理由 |
|------|-------|------|------|
| ネットワーク | [64, 64] | [256, 128, 64] | Lift は多段階（接近→把持→持上げ）で複雑 |
| 学習率 | 1e-3 | 1e-4 | 複雑なタスクでは低い学習率で安定学習 |
| gamma | 0.99 | 0.98 | Lift はエピソードが短く即時報酬を重視 |
| イテレーション | 1000 | 1500 | タスク複雑性に応じて学習期間を延長 |
| エピソード長 | 12.0 秒 | 5.0 秒 | Lift は把持→持上げの短い行動シーケンス |
| 行動空間 | 全 6 関節 | 腕 5 関節 + グリッパー（バイナリ） | Lift ではグリッパーの開閉制御が必要 |

## 学習結果

### 出力ディレクトリ

学習ログは `logs/rsl_rl/` 以下に保存される:

```
logs/rsl_rl/
├── reach/                          # experiment_name
│   └── YYYY-MM-DD_HH-MM-SS/       # 実行タイムスタンプ
│       ├── model_0.pt              # 初期チェックポイント
│       ├── model_50.pt             # 50 iteration 目
│       ├── model_100.pt            # 100 iteration 目
│       ├── ...
│       └── params/
│           ├── env.yaml            # 環境設定のダンプ
│           └── agent.yaml          # エージェント設定のダンプ
└── lift/
    └── [同構造]
```

### TensorBoard でのログ確認

```bash
# ローカル（ログ転送後）
tensorboard --logdir logs/rsl_rl/reach/
tensorboard --logdir logs/rsl_rl/lift/
```

主要メトリクス:
- **Episode Reward (Mean)**: エピソードあたりの累積報酬
- **Episode Length**: エピソードの長さ
- **Policy Loss / Value Loss**: ポリシーと価値関数の損失

### 評価と動画生成

`play.sh` で評価を実行すると、以下が生成される:

```
logs/rsl_rl/{experiment}/{timestamp}/
├── exported/
│   ├── policy.pt                   # JIT エクスポート（PyTorch）
│   └── policy.onnx                 # ONNX エクスポート（推論デプロイ用）
└── videos/
    └── play/
        └── rl-video-step_0.mp4     # 評価動画（200 フレーム）
```

- **JIT / ONNX エクスポート**: 学習済みポリシーを推論用にエクスポート。実機デプロイやベンチマークに利用可能。
- **動画**: 50 環境で推論を実行し、200 フレームを録画。

### チェックポイントからの再開

```bash
# 最新のチェックポイントから再開
sbatch slurm/train.sh Isaac-SO-ARM101-Reach-v0
# ※ train.py 内で --resume フラグを使用

# 特定の run から再開（Docker 内で直接実行する場合）
python -m isaac_so_arm101.scripts.rsl_rl.train \
    --task Isaac-SO-ARM101-Reach-v0 \
    --headless \
    --load_run YYYY-MM-DD_HH-MM-SS \
    --checkpoint model_500.pt
```

主な CLI オプション:

| オプション | 説明 |
|-----------|------|
| `--resume` | 最新の run から自動再開 |
| `--load_run` | 指定した run ディレクトリから読み込み |
| `--checkpoint` | 特定のチェックポイントファイルを指定 |
| `--max_iterations` | 学習イテレーション数を上書き |
| `--video` | 学習中の動画を記録 |
| `--logger` | ログバックエンド（`tensorboard` / `wandb` / `neptune`） |

## 新しいタスクの追加方法

既存の Reach / Lift タスクをテンプレートとして、新しいタスクを追加する手順。

### 1. タスクディレクトリの作成

```
src/isaac_so_arm101/tasks/{task_name}/
├── __init__.py              # gym.register() でタスクを登録
├── {task_name}_env_cfg.py   # ベース環境設定（Scene, MDP）
├── joint_pos_env_cfg.py     # SO-ARM101 固有の設定
├── agents/
│   ├── __init__.py
│   └── rsl_rl_ppo_cfg.py   # PPO ハイパーパラメータ
└── mdp/                     # （オプション）カスタム MDP 関数
    ├── __init__.py
    ├── rewards.py
    └── observations.py
```

### 2. ベース環境設定の定義

`{task_name}_env_cfg.py` でタスクの MDP を定義する。Reach の `reach_env_cfg.py` または Lift の `lift_env_cfg.py` をコピーして編集:

- **SceneCfg**: ロボット（`MISSING` で抽象化）、テーブル、照明、（必要なら）オブジェクト
- **CommandsCfg**: 目標生成の範囲とリサンプリング間隔
- **ObservationsCfg**: ポリシーへの入力項目（ノイズ設定含む）
- **ActionsCfg**: 関節位置制御やグリッパー制御
- **RewardsCfg**: タスク固有の報酬関数と重み
- **TerminationsCfg**: タイムアウト、落下など
- **CurriculumCfg**: 報酬重みのスケジューリング
- **EnvCfg**: 上記を組み合わせ、`decimation`、`episode_length_s`、`sim.dt` を設定

### 3. SO-ARM101 固有設定

`joint_pos_env_cfg.py` でロボット固有の設定を行う:

```python
from isaac_so_arm101.robots import SO_ARM101_CFG
from .{task_name}_env_cfg import {TaskName}EnvCfg

@configclass
class SoArm101{TaskName}EnvCfg({TaskName}EnvCfg):
    def __post_init__(self):
        super().__post_init__()
        # ロボットの設定
        self.scene.robot = SO_ARM101_CFG.replace(prim_path="{ENV_REGEX_NS}/Robot")
        # 行動空間の設定（対象関節、スケール）
        self.actions.arm_action = mdp.JointPositionActionCfg(
            asset_name="robot", joint_names=[".*"], scale=0.5, use_default_offset=True,
        )
        # EE body 名の設定（報酬やコマンドで使用）
        self.commands.ee_pose.body_name = ["gripper_link"]

# 評価用バリアント
@configclass
class SoArm101{TaskName}EnvCfg_PLAY(SoArm101{TaskName}EnvCfg):
    def __post_init__(self):
        super().__post_init__()
        self.scene.num_envs = 50
        self.observations.policy.enable_corruption = False
```

### 4. PPO ハイパーパラメータの設定

`agents/rsl_rl_ppo_cfg.py`:

```python
from isaaclab_rl.rsl_rl import (
    RslRlOnPolicyRunnerCfg, RslRlPpoActorCriticCfg, RslRlPpoAlgorithmCfg,
)

@configclass
class {TaskName}PPORunnerCfg(RslRlOnPolicyRunnerCfg):
    num_steps_per_env = 24
    max_iterations = 1000  # タスク複雑性に応じて調整
    save_interval = 50
    experiment_name = "{task_name}"
    policy = RslRlPpoActorCriticCfg(
        init_noise_std=1.0,
        actor_hidden_dims=[64, 64],   # 複雑なタスクでは [256, 128, 64] など
        critic_hidden_dims=[64, 64],
        activation="elu",
    )
    algorithm = RslRlPpoAlgorithmCfg(
        learning_rate=1.0e-3,  # 複雑なタスクでは 1e-4 に下げる
        gamma=0.99,
        lam=0.95,
        clip_param=0.2,
        entropy_coef=0.001,
        num_learning_epochs=8,
        num_mini_batches=4,
        schedule="adaptive",
        desired_kl=0.01,
        max_grad_norm=1.0,
    )
```

### 5. タスクの登録

`__init__.py` で Gymnasium に環境を登録:

```python
import gymnasium as gym
from . import agents

gym.register(
    id="Isaac-SO-ARM101-{TaskName}-v0",
    entry_point="isaaclab.envs:ManagerBasedRLEnv",
    kwargs={
        "env_cfg_entry_point": f"{__name__}.joint_pos_env_cfg:SoArm101{TaskName}EnvCfg",
        "rsl_rl_cfg_entry_point": f"{agents.__name__}.rsl_rl_ppo_cfg:{TaskName}PPORunnerCfg",
    },
    disable_env_checker=True,
)

gym.register(
    id="Isaac-SO-ARM101-{TaskName}-Play-v0",
    entry_point="isaaclab.envs:ManagerBasedRLEnv",
    kwargs={
        "env_cfg_entry_point": f"{__name__}.joint_pos_env_cfg:SoArm101{TaskName}EnvCfg_PLAY",
        "rsl_rl_cfg_entry_point": f"{agents.__name__}.rsl_rl_ppo_cfg:{TaskName}PPORunnerCfg",
    },
    disable_env_checker=True,
)
```

タスクは `tasks/__init__.py` の `import_packages()` により自動検出されるため、上記の `__init__.py` を配置するだけで登録される。

### 6. カスタム MDP 関数（オプション）

Isaac Lab 標準の MDP 関数で不足する場合、`mdp/` ディレクトリにカスタム関数を定義する。Lift タスクの例:

```python
# mdp/__init__.py
from isaaclab.envs.mdp import *  # 標準 MDP 関数を全てインポート
from .rewards import *            # カスタム報酬関数を追加
from .observations import *       # カスタム観測関数を追加
```

環境設定の import を `isaac_so_arm101.tasks.{task_name}.mdp as mdp` に変更すると、標準関数とカスタム関数の両方が利用可能になる。

### 7. テスト実行

```bash
# トレーニング
sbatch slurm/train.sh Isaac-SO-ARM101-{TaskName}-v0

# 評価（動画生成）
sbatch slurm/play.sh Isaac-SO-ARM101-{TaskName}-Play-v0
```

## ファイル構成

```
isaac/
├── README.md                              # プロジェクト概要・強化学習の詳細
├── pyproject.toml                         # Python パッケージ定義（isaac-so-arm101 v1.2.0）
├── .dockerignore                          # Docker ビルド時の除外ファイル定義
├── src/isaac_so_arm101/                   # メインソースコード
│   ├── robots/
│   │   └── so_arm101/
│   │       ├── so_arm101.py               # ロボット設定（SO_ARM101_CFG）
│   │       └── urdf/so_arm101.urdf        # URDF ファイル
│   ├── tasks/
│   │   ├── __init__.py                    # import_packages() で全タスク自動検出
│   │   ├── reach/
│   │   │   ├── __init__.py                # gym.register()（Reach-v0, Reach-Play-v0）
│   │   │   ├── reach_env_cfg.py           # ベース環境設定（Scene, MDP）
│   │   │   ├── joint_pos_env_cfg.py       # SO-ARM101 固有設定 + PLAY バリアント
│   │   │   └── agents/rsl_rl_ppo_cfg.py   # PPO ハイパーパラメータ
│   │   └── lift/
│   │       ├── __init__.py                # gym.register()（Lift-v0, Lift-Play-v0）
│   │       ├── lift_env_cfg.py            # ベース環境設定（Scene, MDP）
│   │       ├── joint_pos_env_cfg.py       # SO-ARM101 固有設定 + PLAY バリアント
│   │       ├── agents/rsl_rl_ppo_cfg.py   # PPO ハイパーパラメータ
│   │       └── mdp/                       # カスタム MDP 関数
│   │           ├── observations.py        # object_position_in_robot_root_frame()
│   │           └── rewards.py             # object_is_lifted(), object_ee_distance() 等
│   └── scripts/rsl_rl/
│       ├── train.py                       # 学習スクリプト（エントリポイント: train）
│       ├── play.py                        # 評価スクリプト（エントリポイント: play）
│       └── cli_args.py                    # CLI 引数定義
├── docker/
│   ├── Dockerfile                         # Isaac Lab 2.3.2 カスタムイメージ定義
│   └── docker-compose.yml                 # Docker Compose ビルド設定
├── slurm/
│   ├── _run.sh                            # 共通処理（run_in_container ヘルパー）
│   ├── build.sh                           # Docker イメージビルド
│   ├── train.sh                           # RL トレーニング
│   └── play.sh                            # 評価・動画生成
├── scripts/
│   ├── env.sh                             # 共通環境変数定義
│   └── setup-remote.sh                    # リモート初期セットアップ
├── logs/                                  # 学習ログ・チェックポイント・動画
└── docs/
    ├── setup-guide.md                     # 詳細セットアップ手順書
    └── status-report.md                   # リアルタイム可視化の試行記録
```
