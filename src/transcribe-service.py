import sys
import os
import time
import shutil

import torch
import torchaudio
from torch.nn.attention import SDPBackend, sdpa_kernel
from transformers import AutoModelForSpeechSeq2Seq, AutoProcessor, pipeline

# input_file = sys.argv[1]
out_dir = sys.argv[1] if len(sys.argv) > 1 else "nfs/transcribed"

torch.set_float32_matmul_precision("high")

model = AutoModelForSpeechSeq2Seq.from_pretrained(
    "openai/whisper-small", torch_dtype=torch.float32, low_cpu_mem_usage=False
).to("cpu")

# Enable static cache and compile the forward pass
model.generation_config.cache_implementation = "static"
model.generation_config.max_new_tokens = 256
model.forward = torch.compile(model.forward, mode="reduce-overhead", fullgraph=True)

processor = AutoProcessor.from_pretrained("openai/whisper-small")

pipe = pipeline(
    "automatic-speech-recognition",
    model=model,
    tokenizer=processor.tokenizer,
    feature_extractor=processor.feature_extractor,
    torch_dtype=torch.float32,
    device="cpu",
)

generate_kwargs = {
    "max_new_tokens": 256,
    "language": "en",
}

processed_files = set()
failed_files = set()
pending_copy = False # flag to check if we have processed any files
# Forward pass
while True:
    # look for task file
    watch_dir = f"nfs/tasks_inprogress/{os.uname().nodename}"
    temp_out_dir = f"transcribed_{os.getpid()}"
    os.makedirs(temp_out_dir, exist_ok=True)
    for root, dirs, files in os.walk(watch_dir):
        for taskfile in files:
            task_path = os.path.join(root, taskfile)
            task_rel_path = os.path.relpath(task_path, watch_dir)

            if task_rel_path in processed_files or task_rel_path in failed_files:
                continue
            if not taskfile.endswith('.task'):
                continue
            print(f"found task file: {task_path}")
            with open(task_path, "r") as f:
                input_file = f.read().strip() # contains the path to the input file i.e. chunk

            # transcribe
            print(f"Transcribing {input_file}")
            try:
                waveform, sampling_rate = torchaudio.load(input_file)
                sample = waveform[0].numpy()

                with sdpa_kernel(SDPBackend.MATH):
                    result = pipe(
                        {"raw": sample, "sampling_rate": sampling_rate},
                        generate_kwargs=generate_kwargs,
                    )
                print("===done===")
                #print(result["text"])

                rel_dir = os.path.relpath(os.path.dirname(input_file), "nfs/preprocessed")
                # Create output directory with same structure

                temp_out_subdir = os.path.join(temp_out_dir, rel_dir)
                os.makedirs(temp_out_subdir, exist_ok=True)

                out_file = os.path.basename(input_file).replace(".wav", ".txt")
                out_path = os.path.join(temp_out_subdir, out_file)
                with open(out_path, "w") as f:
                    f.write(result["text"])
                pending_copy = True 
                processed_files.add(task_rel_path) 
                os.remove(task_path) # remove task file to unblock slurm
            except Exception as e:
                print(f"Error processing {input_file}: {e}")
                error_log_path = os.path.join(out_dir, "transcription_error_log.txt")
                with open(error_log_path, "a") as error_log:
                    error_log.write(f"Error processing {input_file}: {e}\n")
                failed_files.add(task_rel_path)
                os.remove(task_path)
        if pending_copy:
            shutil.copytree(
                temp_out_dir,
                out_dir,
                dirs_exist_ok=True,
            )
            pending_copy = False
    print("Sleeping for 5 seconds...")
    time.sleep(5) # wait before checking for new tasks
