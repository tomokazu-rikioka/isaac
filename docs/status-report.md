# Isaac Lab on A100 highreso 環境 - 現状レポート

## 環境情報

| 項目 | 値 |
|------|-----|
| リモート | `ssh a100-highreso` → `t-40-8-d-02` (172.30.35.49) |
| GPU | NVIDIA A100-PCIE-40GB x8 |
| Driver | 550.54.15 / CUDA 12.4 |
| Docker | 24.0.6 / Compose v2.29.7 |
| NVIDIA Runtime | `nvidia` (デフォルトは `runc`) |
| Slurm | シングルノード（login = compute） |
| Docker Image | `isaac-lab-headless:2.3.2` (ビルド済み) |
| SSH接続 | Mac → bastion (as-highreso.com:30022) → A100 (172.30.35.49:10022) |

## 成功した項目

### 1. Docker + Slurm GPU管理 ✅
- `sbatch` でSlurm経由のGPU割当が動作（`#SBATCH --gpus=1`）
- `docker run --gpus "device=${CUDA_VISIBLE_DEVICES}"` でSlurm割当GPUのみコンテナに渡せる
- 1台のA100のみが見える（他ユーザーのGPUに影響しない）

```bash
sbatch ~/isaac/slurm/train.sh
# → Slurm割当の1台のみ使用してトレーニング実行
```

### 2. Isaac Lab ヘッドレス実行 ✅
- `log_time.py --headless` → 正常動作、ログ出力確認
- `run_articulation.py --headless` → Cart-Poleシミュレーション実行確認
- 初回起動: シェーダーコンパイルに約30-60秒（キャッシュ後は8秒）
- GPU メモリ: 約18GB使用

### 3. WebRTC ストリーミングサーバー起動 ✅
- ベースイメージの `runheadless.sh` でWebRTCストリーミングが正常起動
- `Isaac Sim Full Streaming App is loaded.` 確認済み
- サーバー側は完全に動作（接続経路の問題で映像が届かない）

## リアルタイム可視化: 試行と失敗の記録

### 試行1: VNC (Xvfb) ❌

**方法**: Xvfb（ソフトウェアX11仮想ディスプレイ） + x11vnc + fluxbox

**結果**: VNCデスクトップは表示されたが、Isaac Simのウィンドウは描画されない

**原因**: Isaac SimはVulkan APIでGPUレンダリングするが、**XvfbはVulkan/GPUレンダリングを一切サポートしない**。XvfbはCPUベースのソフトウェアX11バッファであり、Vulkan Window System Integration (WSI) に対応していない。

**エラー**:
```
[Error] [omni.kit.renderer.plugin] advanceCurrentFrame: backbuffers are not initialized!
```

### 試行2: WebRTC ストリーミング + SSHトンネル ❌

**方法**: Isaac Sim内蔵WebRTCストリーミング + SSHポートフォワーディング

**結果**: ブラウザでWebビューア(8211)のページは読み込めるが映像が表示されない

**原因**: WebRTCのメディアストリームは**UDP (port 47998)** を使用するが、**SSHトンネルはTCPのみ対応**。シグナリング(TCP:49100)はSSH経由で届くが、映像データ(UDP:47998)が届かない。

### 試行3: socat UDP-TCPブリッジ ❌

**方法**: リモート側で `socat TCP4-LISTEN:47999,fork UDP4:localhost:47998`、Mac側で `socat UDP4-LISTEN:47998,fork TCP4:localhost:47999`、SSHトンネルでTCP:47999を転送

**結果**: 接続失敗

**原因**: WebRTCのICE (Interactive Connectivity Establishment) プロトコルは接続先のIPアドレスを動的にネゴシエーションする。SSH + socatブリッジ環境では、ICE candidateが実際のネットワーク経路と一致せず、メディアセッションを確立できない。

### 試行4: Xorg + NVIDIA GPUドライバ ❌

**方法**: Xvfbの代わりにXorgサーバーをNVIDIA GPUドライバで起動し、Vulkan WSI対応の仮想ディスプレイを作成

**結果**: Xorgは起動したが、NVIDIAカーネルモジュール初期化に失敗。Isaac Sim起動時に同じbackbuffersエラー。

**原因**: **NVIDIAドライバーバージョン不一致**。apt install版のXorg用NVIDIAドライバは**580.126.09**だが、ホストのカーネルモジュールは**550.54.15**。Dockerのnvidia-container-runtimeはCUDAライブラリのみをコンテナに注入し、Xorg用ドライバは注入しない。コンテナ内aptでインストールしたドライバはホストのカーネルモジュールと不一致となり、初期化に失敗する。

**エラー**:
```
(EE) NVIDIA: Failed to initialize the NVIDIA kernel module.
```

### 試行5: sshuttle (SSH VPN) ❌

**方法**: sshuttleでMac→リモート間にVPN的トンネルを張り、WebRTCの全通信を透過的にルーティング

**結果**: SSH接続自体が失敗

**原因**: sshuttleは`sudo`が必要だが、sudo環境ではユーザーの`~/.ssh/config`や秘密鍵が参照されない（rootの`/var/root/.ssh/`を参照する）。`--ssh-cmd`で設定ファイルを指定しても、ProxyJump経由の多段SSH接続ではbastion用の秘密鍵パスも`~/`で解決されるため、全ての鍵パスを絶対パスに書き換える必要がある。また、**sshuttleはTCPのみ対応でUDPは非対応**のため、仮に接続できてもWebRTCのUDPメディアは通らない。

## 根本原因のまとめ

Isaac Simのリアルタイム可視化には以下の2つの方法しかない:

1. **Vulkan対応ディスプレイ** → Xorgが必要だがDockerコンテナ内でのNVIDIAドライバ不一致問題で不可
2. **WebRTCストリーミング** → UDPが必要だがSSHトンネル環境でUDP転送ができない

**共通のボトルネック**: bastion経由のSSHトンネルという接続方式では、GPU描画結果をリアルタイムでMacに届ける手段がない。

**解決できる可能性がある条件**:
- 環境管理者にWebRTCポート (49100/TCP, 47998/UDP) の外部開放を依頼できる場合
- ホストのNVIDIAドライバと一致するXorg用ドライバ(550.54.15)を手動インストールできる場合
- bastion経由でないVPN接続が利用可能な場合

## 現在の方針

**ヘッドレス実行 + 動画ファイル転送**で進める。

- RL学習: `--headless` で実行
- 結果確認: `--video` フラグで動画生成 → scpでMacに転送して視聴
- チュートリアル: SO-ARM101 のReachタスクを採用
