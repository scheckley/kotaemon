#!/bin/bash

# Verbose logging for debugging
set -x

# Target directories
STORAGE_DIR="/storage"
KTEM_APP_DATA_DIR="/storage/ktem_app_data"
GRADIO_TMP_DIR="/storage/ktem_app_data/gradio_tmp"

# User and group IDs to use
TARGET_UID=1001
TARGET_GID=0

# Ensure storage directory exists
mkdir -p "$STORAGE_DIR"

# Change ownership of the entire /storage directory
echo "Attempting to change ownership of $STORAGE_DIR"
chown -R "$TARGET_UID:$TARGET_GID" "$STORAGE_DIR" || {
    echo "WARNING: Could not change ownership of entire storage directory"
}

# Ensure ktem_app_data directory exists
mkdir -p "$KTEM_APP_DATA_DIR"

# Ensure gradio_tmp directory exists
mkdir -p "$GRADIO_TMP_DIR"

# Set specific permissions
chmod -R 775 "$STORAGE_DIR" || echo "WARNING: Could not set permissions on $STORAGE_DIR"
chmod -R 775 "$KTEM_APP_DATA_DIR" || echo "WARNING: Could not set permissions on $KTEM_APP_DATA_DIR"
chmod -R 775 "$GRADIO_TMP_DIR" || echo "WARNING: Could not set permissions on $GRADIO_TMP_DIR"

# Detailed debug output
echo "Storage Directory Permissions:"
ls -ld "$STORAGE_DIR"
echo "KTEM App Data Directory Permissions:"
ls -ld "$KTEM_APP_DATA_DIR"
echo "Gradio Temp Directory Permissions:"
ls -ld "$GRADIO_TMP_DIR"

# Exit successfully
exit 0
