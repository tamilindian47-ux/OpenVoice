FROM pytorch/pytorch:2.1.2-cuda12.1-cudnn8-runtime

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ffmpeg \
    wget \
    unzip \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# OpenVoice V2 was released for Python 3.9.
# Create precisely that environment; avoid OpenVoice's TTS-only dependencies.
RUN conda create -y -n openvoice python=3.9 && conda clean -afy

SHELL ["conda", "run", "-n", "openvoice", "/bin/bash", "-c"]

RUN python -m pip install --upgrade "pip<24.1" "setuptools<70" wheel

RUN git clone --depth 1 https://github.com/myshell-ai/OpenVoice.git /app/OpenVoice

WORKDIR /app/OpenVoice

# Only dependencies needed by ToneColorConverter / se_extractor for V2V.
# No `pip install -e .`: it installs the problematic full TTS stack.
RUN pip install \
    "numpy==1.22.0" \
    "librosa==0.9.1" \
    "soundfile==0.12.1" \
    "pydub==0.25.1" \
    "faster-whisper==0.9.0" \
    "unidecode==1.3.7" \
    "eng_to_ipa==0.0.2" \
    "inflect==7.0.0" \
    "runpod==1.7.0"

# Fetch the official V2 converter weights.
RUN wget -q --show-progress \
    https://myshell-public-repo-hosting.s3.amazonaws.com/openvoice/checkpoints_v2_0417.zip \
    -O /tmp/openvoice-v2.zip && \
    unzip -q /tmp/openvoice-v2.zip -d /app/OpenVoice && \
    rm /tmp/openvoice-v2.zip

COPY handler.py /app/OpenVoice/handler.py

CMD ["conda", "run", "--no-capture-output", "-n", "openvoice", \
     "python", "-u", "/app/OpenVoice/handler.py"]
