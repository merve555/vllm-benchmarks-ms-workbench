#!/bin/bash

# Script to run GPU benchmark on existing GKE cluster
# Cluster: ray-tpu-test-cluster in europe-west4

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$SCRIPT_DIR/../k8s"
CLUSTER_NAME="ray-tpu-test-cluster"
CLUSTER_REGION="europe-west4"
PROJECT_ID="ashires-e7aaot"

echo "Setting up GPU benchmark on existing cluster..."
echo "Cluster: $CLUSTER_NAME"
echo "Region: $CLUSTER_REGION"
echo "Project: $PROJECT_ID"

# Get cluster credentials
echo "Getting cluster credentials..."
gcloud container clusters get-credentials "$CLUSTER_NAME" \
    --region="$CLUSTER_REGION" \
    --project="$PROJECT_ID" \
    --dns-endpoint

# Verify cluster access
if ! kubectl cluster-info &> /dev/null; then
    echo "Error: No Kubernetes cluster access. Please check credentials."
    exit 1
fi

echo "Cluster access confirmed"

# Create ConfigMap with the benchmark script
echo "Creating ConfigMap with benchmark script..."
kubectl create configmap benchmark-script \
    --from-file=auto_tune_benchmark.sh="$SCRIPT_DIR/vllm_auto_tune.sh" \
    --dry-run=client -o yaml | kubectl apply -f -

# Check if Hugging Face secret exists, create if not
if ! kubectl get secret huggingface-token &> /dev/null; then
    echo "Hugging Face secret not found. Creating placeholder..."
    echo "Please update it with: kubectl patch secret huggingface-token -p='{\"data\":{\"token\":\"<base64-encoded-token>\"}}'"
    kubectl create secret generic huggingface-token \
        --from-literal=token="your-hf-token-here" \
        --dry-run=client -o yaml | kubectl apply -f -
fi

# Delete existing job if it exists
echo "Cleaning up any existing benchmark job..."
kubectl delete job vllm-gpu-benchmark --ignore-not-found=true

# Apply the GPU job
echo "Starting GPU benchmark job..."
kubectl apply -f "$K8S_DIR/job-gpu.yaml"

echo "Benchmark job started!"
echo ""
echo "Monitor the job with:"
echo "  kubectl logs -f job/vllm-gpu-benchmark"
echo ""
echo "Check job status with:"
echo "  kubectl get job vllm-gpu-benchmark"
echo "  kubectl get pods -l job-name=vllm-gpu-benchmark"

