import os
from pathlib import Path

import librosa
import matplotlib.pyplot as plt
import numpy as np
from tqdm import tqdm

dataset_dir = "./nfs/ww2-audio/"


# get all mp3s in dir and subdirs
def get_mp3s_in_dir(dir):
    mp3s = []
    for root, dirs, files in os.walk(dir):
        for file in files:
            if file.endswith(".mp3"):
                mp3s.append(os.path.join(root, file))
    return mp3s


# get duration of all mp3s
durations = []
for mp3_path in tqdm(get_mp3s_in_dir(dataset_dir)):
    try:
        duration = librosa.get_duration(path=mp3_path)
        durations.append(duration)
    except Exception as e:
        print(f"Error loading {mp3_path}: {e}")
print(
    f"Total duration: {sum(durations) / 60:.2f} minutes "
    + f"or {sum(durations) / 3600:.2f} hours "
    + f"or {sum(durations) / 86400:.2f} days"
)

# plot histogram of durations
plt.figure(figsize=(10, 5))
plt.hist(durations, bins=1000)
plt.xlabel("Duration (s)")
plt.ylabel("Count")
plt.title("Histogram of audio track Durations")
plt.xlim(0, 300)
plt.ylim(0, 100)
plt.grid()
plt.tight_layout()
plt.savefig("duration_histogram.png")
