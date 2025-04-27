import sys
import os
import time
import shutil
import redis

import torch
import torchaudio
from torch.nn.attention import SDPBackend, sdpa_kernel
from transformers import AutoModelForSpeechSeq2Seq, AutoProcessor, pipeline

# input_file = sys.argv[1]
out_dir = sys.argv[1] if len(sys.argv) > 1 else "nfs/run2-transcribed"

redis_client = redis.Redis(host='workernode1', port=6379, db=0)

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
local_outdir = f"transcribed_{os.getpid()}"
os.makedirs(local_outdir, exist_ok=True)
while True:
    # look for task file
    popped = redis_client.brpop('transcribe_queue', timeout=5)
    if popped:
        _, task = popped
        input_file, file_pattern, total_chunks = (task.decode('utf-8').split('|'))

    else:
        print("No tasks in queue, sleeping...")
        continue
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

        rel_dir = os.path.relpath(os.path.dirname(input_file), "nfs/run2-preprocessed")
        # Create output directory with same structure

        temp_out_subdir = os.path.join(local_outdir, rel_dir)
        os.makedirs(temp_out_subdir, exist_ok=True)

        out_file = os.path.basename(input_file).replace(".wav", ".txt")
        out_path = os.path.join(temp_out_subdir, out_file)
        with open(out_path, "w") as f:
            f.write(result["text"])
        pending_copy = True 
        os.remove(input_file)
        completed = redis_client.incr(f"completion:{file_pattern}")
        total = int(redis_client.get(f"chunks:{file_pattern}"))
        if total == completed:
            print(f"Completed all chunks for {file_pattern}")
            redis_client.lpush("concat_queue", file_pattern)
    except Exception as e:
        print(f"Error processing {input_file}: {e}")
        error_log_path = os.path.join(out_dir, "transcription_error_log.txt")
        with open(error_log_path, "a") as error_log:
            error_log.write(f"Error processing {input_file}: {e}\n")
        # reconstruct the failed task
        # full_task = f"{input_file}|{file_pattern}|{total_chunks}"
        # print(f"Requeuing failed task: {full_task}")
        # redis_client.lpush("transcribe_queue", full_task)
    if pending_copy:
        shutil.copytree(
            local_outdir,
            out_dir,
            dirs_exist_ok=True,
        )
        pending_copy = False
        shutil.rmtree(local_outdir)
        os.makedirs(local_outdir, exist_ok=True)
