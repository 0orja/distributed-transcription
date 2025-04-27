#!/bin/bash
# /home/almalinux/concat_queue_monitor.sh
LOG_FILE="/home/almalinux/concat_queue_monitor.log"
echo "===== Starting monitor $(date) =====" >> $LOG_FILE

while true; do
    #READY=$(redis-cli -h workernode1 RPOP concat_queue)
    READY=$(redis-cli -h workernode1 RPOP concat_queue 2>> $LOG_FILE)
    POP_STATUS=$?

    if [[ $POP_STATUS -ne 0 ]]; then
        echo "Error: Failed to pop from concat_queue, status $POP_STATUS: $READY" >> $LOG_FILE
    fi

    CHUNKS=$(redis-cli -h workernode1 GET "chunks:${READY}" 2>> $LOG_FILE)
    CHUNKS_STATUS=$?

    if [[ $CHUNKS_STATUS -ne 0 ]]; then
        echo "Error: Failed to get chunks for key $READY, status $CHUNKS_STATUS: $CHUNKS" >> $LOG_FILE
    fi

    if [[ -n "$READY" ]]; then
        CHUNKS=$(redis-cli -h workernode1 GET "chunks:${READY}")
        echo "submitting: sbatch /home/almalinux/concatenate.sh '$READY' '$CHUNKS'" >> $LOG_FILE
        SBATCH_OUTPUT=$(sbatch --chdir=/home/almalinux /home/almalinux/concatenate.sh "$READY" "$CHUNKS" 2>&1)
        SBATCH_STATUS=$?
        echo "Command exit status: $SBATCH_STATUS" >> $LOG_FILE
        echo "Output: $SBATCH_OUTPUT" >> $LOG_FILE
    fi
    sleep 10
done
