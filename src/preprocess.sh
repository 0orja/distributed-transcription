#!/bin/bash

#SBATCH --job-name=preprocess
#SBATCH --nodelist=workernode1
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=1
#SBATCH --output=nfs/preprocess-logs/%j.out
#SBATCH --error=nfs/preprocess-logs/%j.err

# Check if both arguments are provided
readarray -t files <nfs/full_filelist

# Get the number of files
num_files=${#files[@]}

echo "SLURM_ARRAY_TASK_ID = $SLURM_ARRAY_TASK_ID"

INPUT_FILE=${files[$SLURM_ARRAY_TASK_ID]}

#INPUT_FILE="$1" # e.g. AmericaLooksAbroad/1940-01-07NbcAmericaLooksAbroad-08RooseveltMessageToCongress.mp3
# OUTPUT_BASE_DIR="$2"
CHUNK_DURATION=30

# Extract the directory and file pattern from output path
PARENT_DIR=$(basename $(dirname "$INPUT_FILE")) # AmericaLooksAbroad
OUTPUT_DIR="nfs/preprocessed/${PARENT_DIR}" # nfs/preprocessed/AmericaLooksAbroad
INPUT_BASE=$(basename "$INPUT_FILE") # 1940-01-07NbcAmericaLooksAbroad-08RooseveltMessageToCongress.mp3
INPUT_BASE=$(echo "$INPUT_BASE" | tr ' ' '-')
OUTPUT_BASE="${INPUT_BASE%.*}"  # 1940-01-07NbcAmericaLooksAbroad-08RooseveltMessageToCongress
OUTPUT_EXT="wav" 

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Get audio duration using ffprobe
DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INPUT_FILE")
DURATION=$(printf "%.0f" "$DURATION") # Round to integer

# Calculate number of chunks needed
NUM_CHUNKS=$(( (DURATION + CHUNK_DURATION - 1) / CHUNK_DURATION ))

echo "Processing file: $INPUT_FILE"
# echo "Output directory: $OUTPUT_DIR"
# echo "Output pattern: ${OUTPUT_BASE}_n.${OUTPUT_EXT}"
# echo "Total duration: $DURATION seconds"
# echo "Splitting into $NUM_CHUNKS chunks of $CHUNK_DURATION seconds each"

# Process each chunk
for (( i=0; i<NUM_CHUNKS; i++ )); do
    START_TIME=$((i * CHUNK_DURATION))
    
    # Format the output filename with index
    OUTPUT_FILE="${OUTPUT_DIR}/${OUTPUT_BASE}_${i}.${OUTPUT_EXT}"
    
    echo "Creating chunk $((i+1))/$NUM_CHUNKS: $OUTPUT_FILE"
    
    # Use ffmpeg to extract and convert the chunk
    # For the last chunk, we don't specify an end time to include all remaining audio
    if [ $i -eq $((NUM_CHUNKS-1)) ]; then
        ffmpeg -y -ss "$START_TIME" -i "$INPUT_FILE" -ar 16000 -ac 1 -c:a pcm_s16le "$OUTPUT_FILE" 2>/dev/null
    else
        END_TIME=$((START_TIME + CHUNK_DURATION))
        ffmpeg -y -ss "$START_TIME" -to "$END_TIME" -i "$INPUT_FILE" -ar 16000 -ac 1 -c:a pcm_s16le "$OUTPUT_FILE" 2>/dev/null
    fi

done

FILE_PATTERN="${PARENT_DIR}/${OUTPUT_BASE}" # AmericaLooksAbroad/1940-01-07NbcAmericaLooksAbroad-08RooseveltMessageToCongress
# start transcription job array
DISPATCH_JOBID=$(sbatch --array=0-$(($NUM_CHUNKS-1))%3 dispatch.sh $FILE_PATTERN | awk '{print $4}')
echo "Submitted array job with ID: $DISPATCH_JOBID"
sbatch --depend=afterok:$DISPATCH_JOBID concatenate.sh $FILE_PATTERN $NUM_CHUNKS