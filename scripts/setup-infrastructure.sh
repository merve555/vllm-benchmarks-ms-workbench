#!/bin/bash

# vLLM Benchmark Infrastructure Setup Script
# This script sets up GKE clusters and a GCS bucket using Terraform,
# then configures the clusters for GPU workloads.

set -e

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"
HELM_RELEASE_NAME="gpu-operator"
HELM_NAMESPACE="gpu-operator"

echo "🚀 Starting vLLM benchmark infrastructure setup..."

# 1. --- Prerequisite Checks ---
echo "🔎 Checking for required tools: terraform, gcloud, helm..."
if ! command -v terraform &> /dev/null || ! command -v gcloud &> /dev/null || ! command -v helm &> /dev/null; then
    echo "❌ Error: One or more required tools (terraform, gcloud, helm) are not installed."
    echo "Please install them before running this script."
    exit 1
fi

if [ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
    echo "❌ Error: terraform.tfvars not found in $TERRAFORM_DIR"
    echo "Please create it from the example and update the values."
    exit 1
fi

# 2. --- Terraform Deployment with Retries ---
cd "$TERRAFORM_DIR"

echo "🔄 Initializing Terraform..."
terraform init -upgrade

echo "📝 Planning infrastructure changes..."
terraform plan -out=tfplan

# echo "🏗️ Applying infrastructure changes with retries..."
# MAX_RETRIES=3
# RETRY_DELAY=60 # in seconds
# ATTEMPT=0
# LAST_EXIT_CODE=1

# while [ $ATTEMPT -lt $MAX_RETRIES ]; do
#   ATTEMPT=$((ATTEMPT + 1))
#   echo "Terraform apply attempt #$ATTEMPT of $MAX_RETRIES..."
#   terraform apply -auto-approve tfplan || LAST_EXIT_CODE=$?

#   if [ $LAST_EXIT_CODE -eq 0 ]; then
#     echo "✅ Terraform apply successful."
#     break
#   fi
#   if [ $ATTEMPT -ge $MAX_RETRIES ]; then
#     break
#   fi
#   echo "⚠️ Terraform apply failed. Retrying in $RETRY_DELAY seconds..."
#   sleep $RETRY_DELAY
# done

# if [ $LAST_EXIT_CODE -ne 0 ]; then
#   echo "❌ Terraform apply failed after $MAX_RETRIES attempts. Exiting."
#   exit $LAST_EXIT_CODE
# fi

# 3. --- Kubectl and Helm Configuration ---
echo "🔧 Configuring kubectl contexts..."
TPU_CLUSTER_NAME=$(terraform output -raw tpu_cluster_name)
GPU_CLUSTER_NAME=$(terraform output -raw gpu_cluster_name)
TPU_CLUSTER_LOCATION=$(terraform output -raw tpu_cluster_location)
GPU_CLUSTER_LOCATION=$(terraform output -raw gpu_cluster_location)
PROJECT_ID=$(terraform output -raw project_id)

gcloud container clusters get-credentials "$TPU_CLUSTER_NAME" --zone="$TPU_CLUSTER_LOCATION" --project="$PROJECT_ID"
gcloud container clusters get-credentials "$GPU_CLUSTER_NAME" --zone="$GPU_CLUSTER_LOCATION" --project="$PROJECT_ID"

echo "🤖 Installing NVIDIA GPU Operator on the GPU cluster..."
GPU_CONTEXT="gke_${PROJECT_ID}_${GPU_CLUSTER_LOCATION}_${GPU_CLUSTER_NAME}"
kubectl config use-context "$GPU_CONTEXT"

kubectl create namespace "$HELM_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo update

helm upgrade --install "$HELM_RELEASE_NAME" nvidia/gpu-operator \
    --namespace "$HELM_NAMESPACE" \
    --set driver.enabled=false \
    --set toolkit.enabled=false

echo "⏳ Waiting for the GPU operator to become fully ready..."
# ** THIS IS THE CORRECTED LINE **
# Use the modern label to wait for the main operator pods.
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=gpu-operator \
    -n "$HELM_NAMESPACE" \
    --timeout=5m

# --- Final Summary ---
echo ""
echo "🎉 Infrastructure setup complete!"
echo "-------------------------------------"
echo "TPU Cluster: $TPU_CLUSTER_NAME ($TPU_CLUSTER_LOCATION)"
echo "GPU Cluster: $GPU_CLUSTER_NAME ($GPU_CLUSTER_LOCATION)"
echo "GCS Bucket:  $(terraform output -raw gcs_bucket_name)"
echo "-------------------------------------"
echo ""
echo "Next steps:"
echo "1. Run: ./scripts/run-benchmarks.sh"
echo "2. Monitor: kubectl get pods -A --context <context_name>"

```
