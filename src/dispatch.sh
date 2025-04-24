#!/bin/bash
#SBATCH --job-name=dispatch
#SBATCH --ntasks-per-node=1
#SBATCH --exclude=workernode1
#SBATCH --nodes=1
#SBATCH --time=4:00:00
#SBATCH --spread-job
#SBATCH --distribution=cyclic:cyclic
#SBATCH --output=nfs/dispatch-logs/%j.out
#SBATCH --error=nfs/dispatch-logs/%j.err

WORKER=$(hostname)
echo "Running on $WORKER"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <wav_input_dir>"
    echo "Example: $0 nfs/preprocessed"
    exit 1
fi
# Directory setup
FILENAME="$1" # e.g. AmericaLooksAbroad/1940-01-07NbcAmericaLooksAbroad-08RooseveltMessageToCongress
PARENT_DIR=$(dirname $FILENAME) # AmericaLooksAbroad
CHUNKS_DIR="nfs/preprocessed/$PARENT_DIR" # nfs/preprocessed/AmericaLooksAbroad
FILE_PREFIX=$(basename $FILENAME) # 1940-01-07NbcAmericaLooksAbroad-08RooseveltMessageToCongress
TASK_DIR="nfs/tasks_inprogress/$WORKER"
# OUTPUT_DIR="$2"

mkdir -p "$TASK_DIR/$PARENT_DIR" # nfs/tasks_inprogress/workernode1/AmericaLooksAbroad

CHUNK_ID=$SLURM_ARRAY_TASK_ID
CHUNK_FILE="${CHUNKS_DIR}/${FILE_PREFIX}_${CHUNK_ID}.wav" # nfs/preprocessed/AmericaLooksAbroad/1940-01-07NbcAmericaLooksAbroad-08RooseveltMessageToCongress_1.wav

if [ ! -f "$CHUNK_FILE" ]; then
   echo "Error: Chunk file $CHUNK_FILE not found!"
   exit 1
fi

# # Determine which worker to assign this to (round-robin)
# # Get the total number of worker processes
# TOTAL_WORKERS=$(scontrol show job $SLURM_JOB_DEPENDENCY | grep NumCPUs | awk '{print $2}')
# # Simple round-robin distribution
# WORKER_ID=$((SLURM_ARRAY_TASK_ID % TOTAL_WORKERS))

# Create a job file for the whisper service
TASK_FILE="${TASK_DIR}/${FILENAME}_${CHUNK_ID}.task" # nfs/tasks_inprogress/workernode1/AmericaLooksAbroad/1940-01-07NbcAmericaLooksAbroad-08RooseveltMessageToCongress_1.task

# Write the full path to the audio file in the job file
echo "$CHUNK_FILE" > "$TASK_FILE"

echo "Created task file: $TASK_FILE for worker $WORKER_ID"

# Wait for the file to be processed (removed by service)
# timeout=300  # 5 minute timeout
# start_time=$(date +%s)

# while [ -f "$TASK_FILE" ]; do
#    current_time=$(date +%s)
#    elapsed=$((current_time - start_time))
   
#    if [ $elapsed -gt $timeout ]; then
#       echo "Timeout waiting for job to be processed"
#       exit 1
#    fi
   
#    sleep 5
# done

# echo "Job completed for $CHUNK_FILE"