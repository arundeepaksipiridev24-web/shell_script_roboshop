#!/bin/bash

# Compress log files older than 14 days, then remove the original files.
LOG_DIR=${1:-/var/log/roboshop}
ARCHIVE_DIR=${2:-/var/log/roboshop-archives}
DAYS=${3:-14}

if [ ! -d "$LOG_DIR" ]; then
    echo "Log directory does not exist: $LOG_DIR"
    exit 1
fi

mkdir -p "$ARCHIVE_DIR"

find "$LOG_DIR" -type f -name '*.log' -mmin +$((DAYS * 24 * 60)) -print0 |
while IFS= read -r -d '' LOG_FILE
do
    FILE_NAME=$(basename "$LOG_FILE")
    ZIP_FILE="$ARCHIVE_DIR/${FILE_NAME%.log}-$(date +%F-%H-%M-%S).zip"

    if zip -j "$ZIP_FILE" "$LOG_FILE"; then
        rm -f "$LOG_FILE"
        echo "Archived: $LOG_FILE -> $ZIP_FILE"
    else
        echo "Failed to archive: $LOG_FILE"
    fi
done
