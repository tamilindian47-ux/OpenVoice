FROM pytorch/pytorch:2.2.2-cuda12.1-cudnn8-runtime

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1

WORKDIR /app

# 1. Install system tools and ffmpeg
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ffmpeg \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# 2. Clone OpenVoice repository
RUN git clone --depth 1 https://github.com/myshell-ai/OpenVoice.git /app/OpenVoice

WORKDIR /app/OpenVoice

# 3. Install only pre-compiled wheels needed for tone conversion
# (Omitting faster-whisper/av to eliminate build-from-source errors)
RUN pip install --no-cache-dir \
    "soundfile>=0.12.1" \
    "librosa>=0.10.0" \
    "pydub>=0.25.1" \
    "wavmark>=0.0.3" \
    "runpod>=1.7.0"

# 4. Download OpenVoice V2 official checkpoint
RUN wget -q https://myshell-public-repo-hosting.s3.amazonaws.com/openvoice/checkpoints_v2_0417.zip -O /tmp/checkpoints.zip && \
    unzip -q /tmp/checkpoints.zip -d /app/OpenVoice/ && \
    rm /tmp/checkpoints.zip

ENV PYTHONPATH="/app/OpenVoice:${PYTHONPATH}"

COPY handler.py /app/OpenVoice/handler.py

CMD ["python", "-u", "/app/OpenVoice/handler.py"]
