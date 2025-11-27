#!/bin/bash

# Kubernetes Setup Script for vLLM Benchmarks
# This script sets up the necessary Kubernetes resources

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$SCRIPT_DIR/../k8s"

echo "Setting up Kubernetes resources for vLLM benchmarks..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ Error: kubectl is not installed or not in PATH"
    exit 1
fi

# Check if we have cluster access
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Error: No Kubernetes cluster access. Please configure kubectl first."
    exit 1
fi

echo "Kubernetes cluster access confirmed"

# Apply the Hugging Face secret and ConfigMap
echo "📦 Applying Kubernetes resources..."
kubectl apply -f "$K8S_DIR/huggingface-secret.yaml"

# Verify resources are created
echo "Verifying resources..."
kubectl get secret huggingface-token
kubectl get configmap benchmark-script

echo "Kubernetes setup completed successfully!"
echo ""
echo "Next steps:"
echo "1. Update the Hugging Face token in the secret:"
echo "   kubectl patch secret huggingface-token -p='{\"data\":{\"token\":\"<base64-encoded-token>\"}}'"
echo "2. Run benchmarks: ./scripts/run-benchmarks.sh"
