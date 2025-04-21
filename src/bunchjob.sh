#!/bin/bash
#SBATCH --job-name=array_job
#SBATCH --output=nfs/job_%A.out
#SBATCH --error=nfs/job_%A.err
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=1
#SBATCH --distribution=cyclic:cyclic


echo "Running on $(hostname)"

# Generate the list of files using ls command
readarray -t files <nfs/full_filelist

# Get the number of files
num_files=${#files[@]}

echo "SLURM_ARRAY_TASK_ID = $SLURM_ARRAY_TASK_ID"

# Define batch size
BATCH_SIZE=10

# Calculate start and end indices for this task
start_idx=$(( (SLURM_ARRAY_TASK_ID-1) * BATCH_SIZE ))
end_idx=$(( start_idx + BATCH_SIZE - 1 ))

# Make sure end_idx doesn't exceed the number of files
if [ $end_idx -ge $num_files ]; then
    end_idx=$(( num_files - 1 ))
fi

echo "Processing files from index $start_idx to $end_idx"

# Activate the environment once
source whisper_env/bin/activate

# Process each file in this batch using parallel execution with GNU Parallel
for (( idx=start_idx; idx<=end_idx; idx++ )); do
    if [ $idx -lt $num_files ]; then
        current_file=${files[$idx]}
        echo "Submitting file: $(basename "$current_file")"
        # Use & to run processes in background
        python nfs/test-whisper-chunking.py "$current_file" nfs/ww2-radio-out &
        
        # Limit number of parallel processes to match available tasks
        if (( (idx - start_idx + 1) % 4 == 0 )); then
            wait
        fi
    fi
done

# Wait for all background processes to complete
wait

echo "All files in this batch have been processed"

# # if [ $start_idx -ge $num_files ]; then
# if [ $idx -ge $num_files ]; then
#     echo "No files to process in this task. Exiting."
#     exit 0
# fi

# # Initialize an empty string to store file paths
# # file_batch=""

# # # Add up to 4 files to the batch, checking we don't go beyond array bounds
# # for i in $(seq 0 3); do
# #   idx=$(( start_idx + i ))
# #   if [ $idx -lt $num_files ]; then
# #     echo "Adding file: ${files[$idx]}"
# #     file_batch+="${files[$idx]} "
# #   fi
# # done
# # echo "Final batch contains: '$file_batch'"

# current_file=${files[$idx]}


# # do something

# # echo "Processing files: $file_batch"
# echo "Processing file: $(basename "$current_file")"
# source whisper_env/bin/activate
# # python nfs/test-whisper-chunky.py $file_batch nfs/ww2-tiny-out
# python nfs/test-whisper-chunking.py "$current_file" nfs/ww2-radio-out