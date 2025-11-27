#!/bin/bash

# Script to copy benchmark results from a completed pod to GCS bucket
# Usage: ./copy-results-to-gcs.sh [pod-name] [timestamp-folder]

set -e

JOB_NAME="${1:-vllm-gpu-benchmark}"
TIMESTAMP="${2:-}"
GCS_BUCKET="merves-vllm-bm-results"
RESULTS_PREFIX="vllm-benchmarks"
SYSTEM="${SYSTEM:-GPU}"

echo "Copying benchmark results to GCS..."
echo "Job: $JOB_NAME"
echo "Bucket: $GCS_BUCKET"

# Get pod name
POD_NAME=$(kubectl get pod -l job-name=$JOB_NAME -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [[ -z "$POD_NAME" ]]; then
    echo "Error: No pod found for job $JOB_NAME"
    echo "Available jobs:"
    kubectl get jobs | grep vllm
    exit 1
fi

echo "Found pod: $POD_NAME"

# Find the results directory
if [[ -z "$TIMESTAMP" ]]; then
    echo "Finding latest results directory..."
    TIMESTAMP=$(kubectl exec $POD_NAME -- ls -t /tmp/auto-benchmark/ 2>/dev/null | head -1 || echo "")
fi

if [[ -z "$TIMESTAMP" ]]; then
    echo "Error: Could not find results directory"
    echo "Available directories in pod:"
    kubectl exec $POD_NAME -- ls -la /tmp/auto-benchmark/ 2>/dev/null || echo "No auto-benchmark directory found"
    exit 1
fi

RESULTS_DIR="/tmp/auto-benchmark/$TIMESTAMP"
GCS_PATH="gs://$GCS_BUCKET/$RESULTS_PREFIX/$SYSTEM/$TIMESTAMP"

echo "Results directory: $RESULTS_DIR"
echo "GCS destination: $GCS_PATH"
echo ""

# Copy results from pod to local temp directory
TEMP_DIR=$(mktemp -d)
echo "Copying results to temporary directory: $TEMP_DIR"

kubectl cp $POD_NAME:$RESULTS_DIR $TEMP_DIR/results

# Upload to GCS
echo "Uploading to GCS..."
gsutil -m cp -r $TEMP_DIR/results/* "$GCS_PATH/"

# Create summary file
cat > $TEMP_DIR/benchmark_summary.txt << EOF
Benchmark Summary
=================
Timestamp: $TIMESTAMP
System: $SYSTEM
Job Name: $JOB_NAME
Pod Name: $POD_NAME
Results Location: $GCS_PATH
Copied at: $(date)
EOF

gsutil cp $TEMP_DIR/benchmark_summary.txt "$GCS_PATH/"

# Cleanup
rm -rf $TEMP_DIR

echo ""
echo "Results successfully uploaded to: $GCS_PATH"
echo ""
echo "View results with:"
echo "  gsutil ls -r $GCS_PATH"
echo "  gsutil cat $GCS_PATH/result.txt"

