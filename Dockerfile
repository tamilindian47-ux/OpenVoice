FROM pytorch/pytorch:2.2.2-cuda12.1-cudnn8-runtime

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1

WORKDIR /app

# 1. System audio dependencies & tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    curl \
    tar \
    && rm -rf /var/lib/apt/lists/*

# 2. Download OpenVoice source via tarball with retries (bypasses git clone exit 128)
RUN mkdir -p /app/OpenVoice && \
    curl -fsSL --retry 5 https://github.com/myshell-ai/OpenVoice/archive/refs/heads/main.tar.gz | \
    tar -xz --strip-components=1 -C /app/OpenVoice

WORKDIR /app/OpenVoice

# 3. Install only pre-compiled Python wheels
RUN pip install --no-cache-dir \
    "soundfile>=0.12.1" \
    "librosa>=0.10.0" \
    "pydub>=0.25.1" \
    "wavmark>=0.0.3" \
    "runpod>=1.7.0" \
    "huggingface_hub>=0.22.0"

# 4. Download OpenVoice V2 official weights from Hugging Face
RUN python3 -c "from huggingface_hub import snapshot_download; snapshot_download('myshell-ai/OpenVoiceV2', local_dir='checkpoints_v2')"

ENV PYTHONPATH="/app/OpenVoice:${PYTHONPATH}"

COPY handler.py /app/OpenVoice/handler.py

CMD ["python3", "-u", "/app/OpenVoice/handler.py"]
