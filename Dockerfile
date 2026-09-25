FROM maximofn/open_voice_v2:latest

# Install runpod serverless SDK into the pre-existing environment
RUN pip install --no-cache-dir runpod

WORKDIR /workspace/OpenVoice
COPY handler.py /workspace/OpenVoice/handler.py

CMD ["python3", "-u", "/workspace/OpenVoice/handler.py"]
