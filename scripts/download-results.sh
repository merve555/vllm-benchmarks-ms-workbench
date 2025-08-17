#!/bin/bash

# Download Results Script
# This script downloads benchmark results from GCS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../configs/benchmark-config.yaml"

# Parse configuration
GCS_BUCKET=$(grep "bucket_name:" "$CONFIG_FILE" | cut -d'"' -f2)
RESULTS_PREFIX=$(grep "results_prefix:" "$CONFIG_FILE" | cut -d'"' -f2)

RESULTS_DIR="gs://$GCS_BUCKET/$RESULTS_PREFIX"
LOCAL_RESULTS_DIR="$SCRIPT_DIR/../results"

echo "Downloading benchmark results from GCS..."
echo "Source: $RESULTS_DIR"
echo "Destination: $LOCAL_RESULTS_DIR"

# Create local results directory
mkdir -p "$LOCAL_RESULTS_DIR"

# Download all results
gsutil -m cp -r "$RESULTS_DIR" "$LOCAL_RESULTS_DIR/"

echo "Results downloaded successfully!"
echo "Local results available at: $LOCAL_RESULTS_DIR"

# List downloaded results
echo ""
echo "Downloaded benchmark runs:"
ls -la "$LOCAL_RESULTS_DIR/$RESULTS_PREFIX/" 2>/dev/null || echo "No results found"
