import base64
import subprocess
import tempfile
from pathlib import Path

import runpod
import torch

from openvoice import se_extractor
from openvoice.api import ToneColorConverter

ROOT = Path("/app/OpenVoice")
DEVICE = "cuda:0" if torch.cuda.is_available() else "cpu"
CONVERTER_DIR = ROOT / "checkpoints_v2" / "converter"

print(f"Loading OpenVoice V2 converter on {DEVICE}...")
converter = ToneColorConverter(
    str(CONVERTER_DIR / "config.json"),
    device=DEVICE,
)
converter.load_ckpt(str(CONVERTER_DIR / "checkpoint.pth"))
print("OpenVoice V2 converter ready.")


def to_wav(input_path: Path, output_path: Path):
    result = subprocess.run(
        [
            "ffmpeg", "-y", "-i", str(input_path),
            "-ac", "1", "-ar", "16000",
            str(output_path)
        ],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"Audio conversion failed: {result.stderr[-800:]}")


def handler(job):
    data = job.get("input", {})
    source_b64 = data.get("source_b64")
    reference_b64 = data.get("reference_b64")

    if not source_b64 or not reference_b64:
        return {
            "error": "Provide both 'source_b64' and 'reference_b64'."
        }

    try:
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)

            source_raw = temp / "source.input"
            reference_raw = temp / "reference.input"
            source_wav = temp / "source.wav"
            reference_wav = temp / "reference.wav"
            output_wav = temp / "output.wav"
            output_mp3 = temp / "output.mp3"

            source_raw.write_bytes(base64.b64decode(source_b64))
            reference_raw.write_bytes(base64.b64decode(reference_b64))

            to_wav(source_raw, source_wav)
            to_wav(reference_raw, reference_wav)

            source_se, _ = se_extractor.get_se(
                str(source_wav), converter, vad=False
            )
            target_se, _ = se_extractor.get_se(
                str(reference_wav), converter, vad=False
            )

            converter.convert(
                audio_src_path=str(source_wav),
                src_se=source_se,
                tgt_se=target_se,
                output_path=str(output_wav),
                message="@MyShell",
            )

            result = subprocess.run(
                [
                    "ffmpeg", "-y", "-i", str(output_wav),
                    "-codec:a", "libmp3lame", "-q:a", "2",
                    str(output_mp3)
                ],
                capture_output=True,
                text=True,
            )
            if result.returncode != 0:
                raise RuntimeError(result.stderr[-800:])

            return {
                "audio_b64": base64.b64encode(
                    output_mp3.read_bytes()
                ).decode("ascii"),
                "filename": "openvoice-converted.mp3",
            }

    except Exception as exc:
        return {"error": f"{type(exc).__name__}: {exc}"}


runpod.serverless.start({"handler": handler})
