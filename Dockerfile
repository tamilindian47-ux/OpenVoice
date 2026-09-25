FROM pytorch/pytorch:2.2.2-cuda12.1-cudnn8-runtime

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# 1. System audio dependencies & tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ffmpeg \
    wget \
    unzip \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 2. Clone OpenVoice repository
RUN git clone https://github.com/myshell-ai/OpenVoice.git /app/OpenVoice

WORKDIR /app/OpenVoice

# 3. Install OpenVoice and serverless packages
RUN pip install --no-cache-dir -e . \
    && pip install --no-cache-dir runpod torchaudio librosa soundfile

# 4. Download OpenVoice V2 official model checkpoint (~200MB)
RUN wget -q https://myshell-public-repo-hosting.s3.amazonaws.com/openvoice/checkpoints_v2_0417.zip -O /tmp/checkpoints.zip && \
    unzip -q /tmp/checkpoints.zip -d /app/OpenVoice/ && \
    rm /tmp/checkpoints.zip

COPY handler.py /app/OpenVoice/handler.py

CMD ["python", "-u", "/app/OpenVoice/handler.py"]
