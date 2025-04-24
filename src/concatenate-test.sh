#!/bin/bash

#SBATCH --job-name=concatenate
#SBATCH --time=00:03:00
#SBATCH --cpus-per-task=1
#SBATCH --output=nfs/concat-logs/%j.out
#SBATCH --error=nfs/concat-logs/%j.err

# Wait for the final output file to exist
OUTPUT_DIR="nfs/transcribed"
FILE_PATTERN=$1 
NUM_CHUNKS=$2
MISSING_FILES=false

MAX_WAIT=30  # 3 minutes
START_TIME=$(date +%s)

if [ ! -f "${OUTPUT_DIR}/${FILE_PATTERN}_full.txt" ]; then

    current_chunk=0
    while [ $current_chunk -lt $NUM_CHUNKS ]; do
        if [ -f "${OUTPUT_DIR}/${FILE_PATTERN}_${current_chunk}.txt" ]; then
            #echo "Found chunk ${current_chunk}/${NUM_CHUNKS-1}"
            current_chunk=$((current_chunk + 1))
            continue
        fi
        
        # Check timeout
        ELAPSED=$(($(date +%s) - START_TIME))
        if [ $ELAPSED -gt $MAX_WAIT ]; then
            echo "ERROR: Timeout waiting for chunk ${current_chunk} after ${MAX_WAIT}s"
            exit 1
        fi
    done


    echo "All chunks are ready. Proceeding to concatenate..."
    # Concatenate all text files into one full transcription
    FULL_TRANSCRIPTION="${FILE_PATTERN}_full.txt"
    TMPFILE=$(basename "$FULL_TRANSCRIPTION")
    > "$TMPFILE" # Clear or create the file

    for (( i=0; i<NUM_CHUNKS; i++ )); do
        TXT_FILE="${OUTPUT_DIR}/${FILE_PATTERN}_${i}.txt"
        if [ -f "$TXT_FILE" ]; then
            cat "$TXT_FILE" >> "$TMPFILE"
        else
            echo "Warning: $TXT_FILE does not exist, skipping..."
            MISSING_FILES=true
            continue
        fi
    done
    if [ "$MISSING_FILES" = true ]; then
        echo "Some files were missing during concatenation."
    else
        echo "cleaning ${OUTPUT_DIR}/$(dirname "$FILE_PATTERN")" -name "$(basename "$FILE_PATTERN")_*.txt"
        rm "${OUTPUT_DIR}/${FILE_PATTERN}"_*\.txt
        cp "${TMPFILE}" "${OUTPUT_DIR}/${FULL_TRANSCRIPTION}" # rename the full transcription
    fi
    echo "Full transcription saved"
else
    echo "Full transcription already exists, skipping concatenation."
fi

# mc cp "${TMPFILE}" "local/transcription/{{ item }}"
# echo "Full transcription saved and uploaded to MinIO"