#!/bin/bash

# Test GCS access from a pod
# This script creates a test pod to verify GCS upload works

set -e

echo "Testing GCS access from Kubernetes pod..."

# Create a test pod
kubectl run gcs-test-pod --image=google/cloud-sdk:latest --rm -it --restart=Never -- \
    bash -c "
    echo 'Testing gsutil...'
    gsutil ls gs://merves-vllm-bm-results/ || echo 'gsutil failed'
    
    echo ''
    echo 'Testing gcloud storage...'
    gcloud storage ls gs://merves-vllm-bm-results/ || echo 'gcloud storage failed'
    
    echo ''
    echo 'Testing Python google-cloud-storage...'
    pip install -q google-cloud-storage
    python3 << 'PYTHON'
from google.cloud import storage
try:
    client = storage.Client()
    bucket = client.bucket('merves-vllm-bm-results')
    print(f'Bucket exists: {bucket.exists()}')
    print('Python google-cloud-storage works!')
except Exception as e:
    print(f'Python failed: {e}')
PYTHON
"

