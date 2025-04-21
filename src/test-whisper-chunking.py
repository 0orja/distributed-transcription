import torchaudio
from transformers import pipeline
from datasets import Audio
import soundfile as sf
import sys
import os

input_file = sys.argv[1]
print(sys.argv)
outdir = sys.argv[2] if len(sys.argv) > 2 else "nfs"

pipe = pipeline(
    "automatic-speech-recognition",
    model="openai/whisper-small",
    chunk_length_s=30,  # Split audio into 30-second chunks
    device="cpu",
)

# Load your own audio file (e.g., "test.mp3")
audio_path = input_file
path_parts = os.path.normpath(audio_path).split(os.sep)
parent_dir = path_parts[-2]
filename = os.path.splitext(path_parts[-1])[0] # removes extension
output_relative_path = os.path.join(parent_dir, filename + ".txt")

# Convert to the required format (WAV, 16 kHz) using soundfile
audio, sampling_rate = sf.read(audio_path)

# Create a Hugging Face Audio object from your file
sample = {"array": audio, "sampling_rate": sampling_rate}

# Perform transcription with chunking
prediction = pipe(sample, batch_size=8)["text"]

output_file = os.path.join(outdir, output_relative_path)
os.makedirs(os.path.dirname(output_file), exist_ok=True)
with open(output_file, "w") as f:
    f.write(prediction)
print(f"Transcription written to {output_file}")
