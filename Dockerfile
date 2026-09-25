FROM pytorch/pytorch:2.1.2-cuda12.1-cudnn8-runtime

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# 1. System audio dependencies, compilers, and pkg-config
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ffmpeg \
    wget \
    unzip \
    build-essential \
    pkg-config \
    libavformat-dev \
    libavcodec-dev \
    libavdevice-dev \
    libavutil-dev \
    libswscale-dev \
    libswresample-dev \
    libavfilter-dev \
    && rm -rf /var/lib/apt/lists/*

# 2. Python 3.9 Conda environment
RUN conda create -y -n openvoice python=3.9 && conda clean -afy

SHELL ["conda", "run", "-n", "openvoice", "/bin/bash", "-c"]

# 3. Install PyAV pre-compiled via conda (prevents pip C-compilation failure)
RUN conda install -y -c conda-forge "av>=10.0.0" && conda clean -afy

RUN python -m pip install --upgrade "pip<24.1" "setuptools<70" wheel

# 4. Clone OpenVoice repository
RUN git clone --depth 1 https://github.com/myshell-ai/OpenVoice.git /app/OpenVoice

WORKDIR /app/OpenVoice

# 5. Install runtime dependencies
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

# 6. Download model checkpoint weights (~200MB)
RUN wget -q --show-progress \
    https://myshell-public-repo-hosting.s3.amazonaws.com/openvoice/checkpoints_v2_0417.zip \
    -O /tmp/openvoice-v2.zip && \
    unzip -q /tmp/openvoice-v2.zip -d /app/OpenVoice && \
    rm /tmp/openvoice-v2.zip

COPY handler.py /app/OpenVoice/handler.py

CMD ["conda", "run", "--no-capture-output", "-n", "openvoice", \
     "python", "-u", "/app/OpenVoice/handler.py"]
