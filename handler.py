import os
import sys
import base64
import tempfile
import torch
import torchaudio
import runpod
from pathlib import Path

# Add OpenVoice to Python path
sys.path.append("/workspace/OpenVoice")

from openvoice import se_extractor
from openvoice.api import ToneColorConverter

DEVICE = "cuda:0" if torch.cuda.is_available() else "cpu"
CKPT_DIR = "/workspace/OpenVoice/checkpoints_v2/converter"

# Load converter once at boot
print(f"Loading OpenVoice V2 onto {DEVICE}...")
tone_color_converter = ToneColorConverter(f"{CKPT_DIR}/config.json", device=DEVICE)
tone_color_converter.load_ckpt(f"{CKPT_DIR}/checkpoint.pth")
print("OpenVoice V2 loaded and ready!")

def handler(job):
    job_input = job.get("input", {})
    source_b64 = job_input.get("source_b64")
    reference_b64 = job_input.get("reference_b64")

    if not source_b64 or not reference_b64:
        return {"error": "Missing 'source_b64' or 'reference_b64' audio files."}

    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        src_raw = tmp / "src_raw.audio"
        ref_raw = tmp / "ref_raw.audio"
        src_wav = tmp / "source.wav"
        ref_wav = tmp / "reference.wav"
        out_wav = tmp / "converted.wav"
        out_mp3 = tmp / "converted.mp3"

        src_raw.write_bytes(base64.b64decode(source_b64))
        ref_raw.write_bytes(base64.b64decode(reference_b64))

        # Standardize both to 16kHz mono WAV using pre-installed ffmpeg
        os.system(f"ffmpeg -y -i {src_raw} -ac 1 -ar 16000 {src_wav} >/dev/null 2>&1")
        os.system(f"ffmpeg -y -i {ref_raw} -ac 1 -ar 16000 {ref_wav} >/dev/null 2>&1")

        # Extract speaker embeddings
        source_se, _ = se_extractor.get_se(str(src_wav), tone_color_converter, vad=False)
        target_se, _ = se_extractor.get_se(str(ref_wav), tone_color_converter, vad=False)

        # Tone color conversion
        tone_color_converter.convert(
            audio_src_path=str(src_wav),
            src_se=source_se,
            tgt_se=target_se,
            output_path=str(out_wav),
            message="@MyShell"
        )

        if not out_wav.exists() or out_wav.stat().st_size == 0:
            return {"error": "Conversion failed to generate audio output."}

        # Compress output to MP3 for quick transfer
        os.system(f"ffmpeg -y -i {out_wav} -codec:a libmp3lame -qscale:a 2 {out_mp3} >/dev/null 2>&1")
        out_b64 = base64.b64encode(out_mp3.read_bytes()).decode("ascii")

        return {
            "audio_b64": out_b64,
            "filename": "openvoice_converted.mp3"
        }

if __name__ == "__main__":
    runpod.serverless.start({"handler": handler})
