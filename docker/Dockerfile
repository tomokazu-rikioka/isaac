FROM nvcr.io/nvidia/isaac-lab:2.3.2

ENV DEBIAN_FRONTEND=noninteractive

# ユーティリティ
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg git curl \
    && rm -rf /var/lib/apt/lists/*

# uv のインストール
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# 不足している toml を追加し、RL 依存パッケージをビルド時にインストール
# isaaclab.sh --install が numpy を壊すことがあるため再インストール
ENV UV_PYTHON="/workspace/isaaclab/_isaac_sim/kit/python/bin/python3"
RUN uv pip install --system toml \
    && cd /workspace/isaaclab && ./isaaclab.sh --install rsl_rl \
    && uv pip install --system numpy

# SO-ARM101 のインストール
COPY pyproject.toml /workspace/isaac_so_arm101/
COPY src /workspace/isaac_so_arm101/src
RUN cd /workspace/isaac_so_arm101 \
    && rm -rf .venv \
    && uv pip install --system --no-deps -e .

ENTRYPOINT []
CMD ["bash"]
