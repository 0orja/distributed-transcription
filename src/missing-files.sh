#!/bin/bash

# Get list of files with missing chunks
MISSING_FILES=$(grep -l "ON workernode4 CANCELLED AT" nfs/concat-logs/*)

for file in $MISSING_FILES; do
# Derive the corresponding .out file name
    out_file="${file%.err}.out"
    # Extract first line from the file
    first_line=$(head -n 1 "$out_file")
    
    # Extract the file path pattern and chunk number
    if [[ $first_line =~ Waiting\ for\ (.+)_([0-9]+)\.txt ]]; then
        file_pattern="${BASH_REMATCH[1]}"
        last_chunk="${BASH_REMATCH[2]}"
        
        # Increment by 1 to get total chunks
        total_chunks=$((last_chunk + 1))
        
        echo "Processing: $file_pattern with $total_chunks chunks"
        
        # Run the concatenate script with extracted parameters
        ./concatenate-test.sh "$file_pattern" "$total_chunks"
    else
        echo "Could not extract pattern from file: $out_file"
        echo "First line was: $first_line"
    fi
done