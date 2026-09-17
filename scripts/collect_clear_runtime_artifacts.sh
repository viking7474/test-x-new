#!/bin/sh
# Export AppDataCleaner runtime evidence without scanning for or mutating app-owned data.
#
# Usage on the device (or against a mounted device filesystem):
#   sh collect_clear_runtime_artifacts.sh <host-app-data-container> <output-directory>
#
# Example:
#   sh collect_clear_runtime_artifacts.sh \
#     /var/mobile/Containers/Data/Application/KNOWN-HOST-UUID \
#     /var/mobile/Documents/clear-runtime-export
#
# The caller must supply the already-known host app container. This script deliberately
# does not search container roots or infer ownership from bundle/name substrings.

set -eu

if [ "$#" -ne 2 ]; then
    echo "usage: $0 <host-app-data-container> <output-directory>" >&2
    exit 64
fi

HOST_CONTAINER=$1
OUTPUT_DIR=$2
LOG_PATH=/var/mobile/Documents/AppDataCleaner.log
JOURNAL_DIR="$HOST_CONTAINER/Library/Application Support/PXClearJournal"

case "$HOST_CONTAINER" in
    /*) ;;
    *)
        echo "host app data container must be an absolute path" >&2
        exit 64
        ;;
esac

case "$OUTPUT_DIR" in
    /*) ;;
    *)
        echo "output directory must be an absolute path" >&2
        exit 64
        ;;
esac

if [ ! -f "$LOG_PATH" ] || [ -L "$LOG_PATH" ]; then
    echo "AppDataCleaner.log is missing, not a regular file, or is a symlink: $LOG_PATH" >&2
    exit 66
fi

if [ ! -d "$HOST_CONTAINER" ] || [ -L "$HOST_CONTAINER" ]; then
    echo "host app data container is missing, not a real directory, or is a symlink: $HOST_CONTAINER" >&2
    exit 66
fi

if [ ! -d "$JOURNAL_DIR" ] || [ -L "$JOURNAL_DIR" ]; then
    echo "PXClearJournal is missing, not a real directory, or is a symlink: $JOURNAL_DIR" >&2
    exit 66
fi

mkdir -p "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/PXClearJournal"
cp -p "$LOG_PATH" "$OUTPUT_DIR/AppDataCleaner.log"

FOUND=0
for ENTRY in "$JOURNAL_DIR"/*.plist; do
    [ -e "$ENTRY" ] || continue
    if [ ! -f "$ENTRY" ] || [ -L "$ENTRY" ]; then
        echo "refusing non-regular/symlink journal entry: $ENTRY" >&2
        exit 65
    fi
    cp -p "$ENTRY" "$OUTPUT_DIR/PXClearJournal/"
    FOUND=1
done

if [ "$FOUND" -ne 1 ]; then
    echo "PXClearJournal contains no plist entries" >&2
    exit 66
fi

{
    echo "source_log=$LOG_PATH"
    echo "source_journal=$JOURNAL_DIR"
    echo "host_container=$HOST_CONTAINER"
    echo "collector_version=1"
} > "$OUTPUT_DIR/manifest.txt"

echo "Clear runtime artifacts exported to: $OUTPUT_DIR"
