#!/bin/bash

# vLLM Benchmark Infrastructure Setup Script
# This script sets up GKE clusters and a GCS bucket using Terraform,
# then configures the clusters for GPU workloads.

set -e

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

echo "Starting vLLM benchmark infrastructure setup..."

# 1. --- Prerequisite Checks ---
echo "🔎 Checking for required tools: terraform, gcloud..."
if ! command -v terraform &> /dev/null || ! command -v gcloud &> /dev/null; then
    echo "❌ Error: One or more required tools (terraform, gcloud) are not installed."
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

echo "Planning infrastructure changes..."
terraform plan -out=tfplan

echo "🏗️ Applying infrastructure changes..."
echo "Note: GKE cluster creation can take 15-20 minutes. Please be patient."

# Function to check if Terraform is still running
check_terraform_running() {
    if pgrep -f "terraform apply" > /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to check for specific retryable errors
is_retryable_error() {
    local exit_code=$1
    local error_output=$2
    
    # Common retryable errors for GCP/GKE
    local retryable_patterns=(
        "quota exceeded"
        "resource not ready"
        "operation in progress"
        "temporary error"
        "rate limit exceeded"
        "backend error"
        "timeout"
        "connection reset"
    )
    
    for pattern in "${retryable_patterns[@]}"; do
        if echo "$error_output" | grep -i "$pattern" > /dev/null; then
            return 0
        fi
    done
    
    return 1
}

# Run terraform apply with better error handling
echo "Starting Terraform apply..."
echo "⏳ This may take 15-20 minutes for GKE cluster creation..."

# Run terraform apply and capture output
APPLY_OUTPUT=$(terraform apply -auto-approve tfplan 2>&1)
APPLY_EXIT_CODE=$?

if [ $APPLY_EXIT_CODE -eq 0 ]; then
    echo "Terraform apply completed successfully!"
else
    echo "❌ Terraform apply failed with exit code: $APPLY_EXIT_CODE"
    echo "Error output:"
    echo "$APPLY_OUTPUT"
    
    # Check if it's a retryable error
    if is_retryable_error "$APPLY_EXIT_CODE" "$APPLY_OUTPUT"; then
        echo "🔄 Detected retryable error. Retrying once after 5 minutes..."
        sleep 300  # Wait 5 minutes
        echo "🔄 Retrying Terraform apply..."
        terraform apply -auto-approve tfplan
        if [ $? -eq 0 ]; then
            echo "Terraform apply succeeded on retry!"
        else
            echo "❌ Terraform apply failed on retry. Please check the error and run manually."
            exit 1
        fi
    else
        echo "❌ Non-retryable error detected. Please fix the issue and run manually."
        exit 1
    fi
fi

# 3. --- Verify Cloud NAT Configuration ---
echo "Verifying Cloud NAT configuration..."
PROJECT_ID=$(terraform output -raw project_id)
REGION=$(terraform output -raw cloud_router_region)

echo "Checking Cloud Router..."
gcloud compute routers describe gke-router --region=$REGION --project=$PROJECT_ID

echo "Checking Cloud NAT..."
gcloud compute routers nats describe gke-nat --router=gke-router --region=$REGION --project=$PROJECT_ID

# 4. --- Kubectl Configuration ---
echo "Configuring kubectl contexts..."

TPU_CLUSTER_NAME=$(terraform output -raw tpu_cluster_name)
GPU_CLUSTER_NAME=$(terraform output -raw gpu_cluster_name)
TPU_CLUSTER_LOCATION=$(terraform output -raw tpu_cluster_location)
GPU_CLUSTER_LOCATION=$(terraform output -raw gpu_cluster_location)
PROJECT_ID=$(terraform output -raw project_id)

gcloud container clusters get-credentials "$TPU_CLUSTER_NAME" --zone="$TPU_CLUSTER_LOCATION" --project="$PROJECT_ID"
gcloud container clusters get-credentials "$GPU_CLUSTER_NAME" --zone="$GPU_CLUSTER_LOCATION" --project="$PROJECT_ID"

echo "🤖 GKE will automatically install NVIDIA drivers for GPU nodes..."
echo "⏳ No additional GPU operator installation needed."
echo "🌐 Cloud NAT is configured for internet connectivity..."

# --- Final Summary ---
echo ""
echo "🎉 Infrastructure setup complete!"
echo "-------------------------------------"
echo "TPU Cluster: $TPU_CLUSTER_NAME ($TPU_CLUSTER_LOCATION)"
echo "GPU Cluster: $GPU_CLUSTER_NAME ($GPU_CLUSTER_LOCATION)"
echo "GCS Bucket:  $(terraform output -raw gcs_bucket_name)"
echo "Cloud Router: $(terraform output -raw cloud_router_name)"
echo "Cloud NAT: $(terraform output -raw cloud_nat_name)"
echo "-------------------------------------"
echo ""
echo "Next steps:"
echo "1. Run: ./scripts/run-benchmarks.sh"
echo "2. Monitor: kubectl get pods -A --context <context_name>"
echo ""
echo "Network connectivity should now work properly for package installation!"
