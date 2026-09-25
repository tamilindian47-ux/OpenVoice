FROM pytorch/pytorch:2.2.2-cuda12.1-cudnn8-runtime

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1

WORKDIR /app

# 1. System audio dependencies & ffmpeg
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ffmpeg \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 2. Clone OpenVoice repository
RUN git clone --depth 1 https://github.com/myshell-ai/OpenVoice.git /app/OpenVoice

WORKDIR /app/OpenVoice

# 3. Install only pre-compiled Python wheels & Hugging Face CLI
RUN pip install --no-cache-dir \
    "soundfile>=0.12.1" \
    "librosa>=0.10.0" \
    "pydub>=0.25.1" \
    "wavmark>=0.0.3" \
    "runpod>=1.7.0" \
    "huggingface_hub>=0.22.0"

# 4. Download OpenVoice V2 official weights directly from Hugging Face
RUN python -c "from huggingface_hub import snapshot_download; snapshot_download('myshell-ai/OpenVoiceV2', local_dir='checkpoints_v2')"

ENV PYTHONPATH="/app/OpenVoice:${PYTHONPATH}"

COPY handler.py /app/OpenVoice/handler.py

CMD ["python", "-u", "/app/OpenVoice/handler.py"]
