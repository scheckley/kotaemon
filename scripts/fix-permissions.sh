#!/bin/bash

# Set up error handling that doesn't exit on failures
set +e

# Target directories
STORAGE_DIR="/storage"
KTEM_APP_DATA_DIR="/storage/ktem_app_data"
GRADIO_TMP_DIR="/storage/ktem_app_data/gradio_tmp"

# Ensure directories exist
mkdir -p "$STORAGE_DIR" || true
mkdir -p "$KTEM_APP_DATA_DIR" || true
mkdir -p "$GRADIO_TMP_DIR" || true

# Try to set permissions, but don't fail if we can't
chmod -R 775 "$STORAGE_DIR" 2>/dev/null || true
chmod -R 775 "$KTEM_APP_DATA_DIR" 2>/dev/null || true
chmod -R 775 "$GRADIO_TMP_DIR" 2>/dev/null || true

# Print current permissions for debugging
ls -ld "$STORAGE_DIR" 2>/dev/null || true
ls -ld "$KTEM_APP_DATA_DIR" 2>/dev/null || true
ls -ld "$GRADIO_TMP_DIR" 2>/dev/null || true

# Exit successfully regardless of any failures
exit 0
