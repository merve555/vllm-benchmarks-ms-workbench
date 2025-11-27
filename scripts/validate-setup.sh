#!/bin/bash

# Validation Script for vLLM Benchmark Setup
# This script validates that all components are properly configured

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "Validating vLLM benchmark setup..."

# Check prerequisites
print_status "Checking prerequisites..."

MISSING_TOOLS=()

if ! command -v gcloud &> /dev/null; then
    MISSING_TOOLS+=("gcloud")
fi

if ! command -v kubectl &> /dev/null; then
    MISSING_TOOLS+=("kubectl")
fi

if ! command -v terraform &> /dev/null; then
    MISSING_TOOLS+=("terraform")
fi

if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    print_error "Missing tools: ${MISSING_TOOLS[*]}"
    exit 1
fi

print_success "All prerequisites are available"

# Check Terraform configuration
print_status "Checking Terraform configuration..."

if [ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
    print_error "terraform.tfvars not found. Please create it from terraform.tfvars.example"
    exit 1
fi

print_success "Terraform configuration found"

# Check if infrastructure is deployed
print_status "Checking infrastructure deployment..."

cd "$TERRAFORM_DIR"

if ! terraform output -json >/dev/null 2>&1; then
    print_warning "Terraform outputs not available. Infrastructure may not be deployed."
    print_status "Run: ./scripts/setup-infrastructure.sh"
    exit 1
fi

# Get cluster information
TPU_CLUSTER_NAME=$(terraform output -raw tpu_cluster_name 2>/dev/null || echo "")
GPU_CLUSTER_NAME=$(terraform output -raw gpu_cluster_name 2>/dev/null || echo "")
GCS_BUCKET=$(terraform output -raw gcs_bucket_name 2>/dev/null || echo "")

if [ -z "$TPU_CLUSTER_NAME" ] || [ -z "$GPU_CLUSTER_NAME" ]; then
    print_error "Could not retrieve cluster information from Terraform"
    exit 1
fi

print_success "Infrastructure is deployed"
print_status "TPU Cluster: $TPU_CLUSTER_NAME"
print_status "GPU Cluster: $GPU_CLUSTER_NAME"
print_status "GCS Bucket: $GCS_BUCKET"

# Check kubectl contexts
print_status "Checking kubectl contexts..."

TPU_CONTEXT="gke_$(terraform output -raw project_id)_$(terraform output -raw tpu_cluster_location)_$TPU_CLUSTER_NAME"
GPU_CONTEXT="gke_$(terraform output -raw project_id)_$(terraform output -raw gpu_cluster_location)_$GPU_CLUSTER_NAME"

if ! kubectl config get-contexts "$TPU_CONTEXT" >/dev/null 2>&1; then
    print_warning "TPU cluster context not found. Run: gcloud container clusters get-credentials"
fi

if ! kubectl config get-contexts "$GPU_CONTEXT" >/dev/null 2>&1; then
    print_warning "GPU cluster context not found. Run: gcloud container clusters get-credentials"
fi

# Check Kubernetes resources
print_status "Checking Kubernetes resources..."

if kubectl get secret huggingface-token >/dev/null 2>&1; then
    print_success "Hugging Face secret exists"
else
    print_warning "Hugging Face secret not found. Run: ./scripts/setup-k8s.sh"
fi

if kubectl get configmap benchmark-script >/dev/null 2>&1; then
    print_success "Benchmark script ConfigMap exists"
else
    print_warning "Benchmark script ConfigMap not found. Run: ./scripts/setup-k8s.sh"
fi

# Check GCS bucket
print_status "Checking GCS bucket..."

if gsutil ls "gs://$GCS_BUCKET" >/dev/null 2>&1; then
    print_success "GCS bucket exists and is accessible"
else
    print_warning "GCS bucket not accessible. Check permissions."
fi

cd "$SCRIPT_DIR"

echo ""
print_success "Validation completed!"
echo ""
echo "Next steps:"
echo "1. Update Hugging Face token: kubectl patch secret huggingface-token"
echo "2. Run benchmarks: ./scripts/run-benchmarks.sh"
