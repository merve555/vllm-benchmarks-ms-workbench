#!/bin/bash

# vLLM Benchmark Runner Script
# This script runs benchmarks on both TPU and GPU clusters in parallel

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../configs/benchmark-config.yaml"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"
K8S_DIR="$SCRIPT_DIR/../k8s"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command_exists kubectl; then
        missing_tools+=("kubectl")
    fi
    
    if ! command_exists gcloud; then
        missing_tools+=("gcloud")
    fi
    
    if ! command_exists terraform; then
        missing_tools+=("terraform")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        exit 1
    fi
    
    print_success "All prerequisites are available"
}

# Get cluster information from Terraform
get_cluster_info() {
    print_status "Getting cluster information from Terraform..."
    
    cd "$TERRAFORM_DIR"
    
    # Check if terraform has been applied
    if ! terraform output -json >/dev/null 2>&1; then
        print_error "Terraform outputs not available. Please run setup-infrastructure.sh first."
        exit 1
    fi
    
    TPU_CLUSTER_NAME=$(terraform output -raw tpu_cluster_name 2>/dev/null || echo "")
    GPU_CLUSTER_NAME=$(terraform output -raw gpu_cluster_name 2>/dev/null || echo "")
    TPU_CLUSTER_LOCATION=$(terraform output -raw tpu_cluster_location 2>/dev/null || echo "")
    GPU_CLUSTER_LOCATION=$(terraform output -raw gpu_cluster_location 2>/dev/null || echo "")
    PROJECT_ID=$(terraform output -raw project_id 2>/dev/null || echo "")
    GCS_BUCKET=$(terraform output -raw gcs_bucket_name 2>/dev/null || echo "")
    
    cd "$SCRIPT_DIR"
    
    if [ -z "$TPU_CLUSTER_NAME" ] || [ -z "$GPU_CLUSTER_NAME" ]; then
        print_error "Could not retrieve cluster information from Terraform"
        exit 1
    fi
    
    print_success "Retrieved cluster information"
    print_status "TPU Cluster: $TPU_CLUSTER_NAME ($TPU_CLUSTER_LOCATION)"
    print_status "GPU Cluster: $GPU_CLUSTER_NAME ($GPU_CLUSTER_LOCATION)"
    print_status "GCS Bucket: $GCS_BUCKET"
}

# Configure kubectl contexts
configure_kubectl() {
    print_status "Configuring kubectl contexts..."
    
    # Get credentials for both clusters
    gcloud container clusters get-credentials "$TPU_CLUSTER_NAME" \
        --zone="$TPU_CLUSTER_LOCATION" \
        --project="$PROJECT_ID"
    
    gcloud container clusters get-credentials "$GPU_CLUSTER_NAME" \
        --zone="$GPU_CLUSTER_LOCATION" \
        --project="$PROJECT_ID"
    
    print_success "Kubectl contexts configured"
}

# Function to run benchmark on a specific cluster (non-blocking)
start_benchmark_on_cluster() {
    local cluster_type=$1
    local cluster_name=$2
    local cluster_location=$3
    local job_file=$4
    
    print_status "Starting benchmark on $cluster_type cluster ($cluster_name)..."
    
    # Set kubectl context
    local context="gke_${PROJECT_ID}_${cluster_location}_${cluster_name}"
    kubectl config use-context "$context"
    
    # Create ConfigMap with environment variables in default namespace
    kubectl create configmap benchmark-config \
        --from-literal=GCS_BUCKET="$GCS_BUCKET" \
        --from-literal=MODEL="meta-llama/Llama-3.1-8B-Instruct" \
        --from-literal=SYSTEM="$cluster_type" \
        --from-literal=INPUT_LEN="4000" \
        --from-literal=OUTPUT_LEN="16" \
        --from-literal=MAX_MODEL_LEN="4096" \
        --from-literal=TP="1" \
        --from-literal=TENSOR_PARALLEL_SIZE="1" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Create ConfigMap with the benchmark script in default namespace
    # Use vllm_auto_tune.sh which is based on the official vLLM auto_tune.sh
    kubectl create configmap benchmark-script \
        --from-file=auto_tune_benchmark.sh="$SCRIPT_DIR/vllm_auto_tune.sh" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Delete existing job if it exists (to avoid immutable field errors)
    local job_name="vllm-${cluster_type,,}-benchmark"
    kubectl delete job "$job_name" --ignore-not-found=true
    
    # Apply the job to default namespace
    kubectl apply -f "$job_file"
    
    print_success "Started $cluster_type benchmark job: $job_name"
}

# Function to monitor a benchmark job
monitor_benchmark_job() {
    local cluster_type=$1
    local cluster_name=$2
    local cluster_location=$3
    
    local context="gke_${PROJECT_ID}_${cluster_location}_${cluster_name}"
    local job_name="vllm-${cluster_type,,}-benchmark"
    
    print_status "Monitoring $cluster_type benchmark job..."
    
    # Wait for job to complete
    kubectl wait --for=condition=complete job/"$job_name" \
        --context="$context" \
        --timeout=2h
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        print_success "$cluster_type benchmark completed successfully"
        
        # Get job logs
        local timestamp=$(date +"%Y_%m_%d_%H_%M")
        local log_file="$SCRIPT_DIR/../logs/${cluster_type,,}-benchmark-${timestamp}.log"
        mkdir -p "$(dirname "$log_file")"
        kubectl logs job/"$job_name" --context="$context" > "$log_file"
        print_status "$cluster_type logs saved to: $log_file"
        return 0
    else
        print_error "$cluster_type benchmark failed"
        kubectl logs job/"$job_name" --context="$context" || true
        return 1
    fi
}

# Main execution
main() {
    print_status "Starting vLLM benchmark execution (parallel mode)..."
    
    # Check prerequisites
    check_prerequisites
    
    # Get cluster information
    get_cluster_info
    
    # Configure kubectl
    configure_kubectl
    
    # Start both benchmarks in parallel
    print_status "Starting benchmarks in parallel..."
    
    # Start TPU benchmark
    start_benchmark_on_cluster "TPU" "$TPU_CLUSTER_NAME" "$TPU_CLUSTER_LOCATION" "$K8S_DIR/job-tpu.yaml"
    
    # Start GPU benchmark
    start_benchmark_on_cluster "GPU" "$GPU_CLUSTER_NAME" "$GPU_CLUSTER_LOCATION" "$K8S_DIR/job-gpu.yaml"
    
    print_status "Both benchmark jobs started. Monitoring progress..."
    
    # Monitor both jobs in parallel using background processes
    local failed_clusters=()
    
    # Start monitoring TPU job in background
    monitor_benchmark_job "TPU" "$TPU_CLUSTER_NAME" "$TPU_CLUSTER_LOCATION" &
    local tpu_pid=$!
    
    # Start monitoring GPU job in background
    monitor_benchmark_job "GPU" "$GPU_CLUSTER_NAME" "$GPU_CLUSTER_LOCATION" &
    local gpu_pid=$!
    
    # Wait for both monitoring processes to complete
    wait $tpu_pid
    local tpu_exit_code=$?
    
    wait $gpu_pid
    local gpu_exit_code=$?
    
    # Check results
    if [ $tpu_exit_code -ne 0 ]; then
        failed_clusters+=("TPU")
    fi
    
    if [ $gpu_exit_code -ne 0 ]; then
        failed_clusters+=("GPU")
    fi
    
    # Summary
    echo ""
    print_status "Benchmark execution summary:"
    echo "====================================="
    
    if [ ${#failed_clusters[@]} -eq 0 ]; then
        print_success "All benchmarks completed successfully!"
        print_status "Results are available in GCS bucket: $GCS_BUCKET"
    else
        print_warning "Some benchmarks failed: ${failed_clusters[*]}"
        print_status "Successful benchmark results are still available in GCS bucket: $GCS_BUCKET"
        
        # Exit with error code if any benchmark failed
        exit 1
    fi
}

# Run main function
main "$@"
