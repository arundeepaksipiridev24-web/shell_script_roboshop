#!/bin/bash

# Cron uses a smaller PATH than an interactive terminal.
PATH=/usr/local/bin:/usr/bin:/bin

SOURCE_DIR=$1
DEST_DIR=$2
DAYS=${3:-14}

if [ -z "$SOURCE_DIR" ] || [ -z "$DEST_DIR" ]; then
    echo "Usage: bash cleanup.sh <source_dir> <destination_dir> [days]"
    exit 1
fi

if [ ! -d "$SOURCE_DIR" ]; then
    echo "Source directory does not exist: $SOURCE_DIR"
    exit 1
fi

if [ ! -d "$DEST_DIR" ]; then
    echo "Destination directory does not exist: $DEST_DIR"
    exit 1
fi

FILE_LIST=$(mktemp)
find "$SOURCE_DIR" -type f -name '*.log' -mmin +$((DAYS * 24 * 60)) -print0 > "$FILE_LIST"

if [ ! -s "$FILE_LIST" ]; then
    echo "No .log files found older than $DAYS days in $SOURCE_DIR"
    rm -f "$FILE_LIST"
    exit 0
fi

ARCHIVE_FILE="$DEST_DIR/logs-$(date +%Y-%m-%d-%H-%M-%S).tar.gz"

if tar --null -czf "$ARCHIVE_FILE" --files-from="$FILE_LIST"; then
    xargs -0 rm -f < "$FILE_LIST"
    echo "Archive created: $ARCHIVE_FILE"
    echo "Old log files deleted from: $SOURCE_DIR"
else
    echo "Archive failed. Source log files were not deleted."
    rm -f "$ARCHIVE_FILE"
    rm -f "$FILE_LIST"
    exit 1
fi

rm -f "$FILE_LIST"
