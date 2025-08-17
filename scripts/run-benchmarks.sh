#!/bin/bash

# vLLM Benchmark Runner Script
# This script runs benchmarks on both TPU and GPU clusters

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../configs/benchmark-config.yaml"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

# Parse configuration
PROJECT_ID=$(grep "project_id:" "$CONFIG_FILE" | cut -d'"' -f2)
GCS_BUCKET=$(grep "bucket_name:" "$CONFIG_FILE" | cut -d'"' -f2)
RESULTS_PREFIX=$(grep "results_prefix:" "$CONFIG_FILE" | cut -d'"' -f2)

# Get cluster names from Terraform
cd "$TERRAFORM_DIR"
TPU_CLUSTER_NAME=$(terraform output -raw tpu_cluster_name)
GPU_CLUSTER_NAME=$(terraform output -raw gpu_cluster_name)
TPU_CLUSTER_LOCATION=$(terraform output -raw tpu_cluster_location)
GPU_CLUSTER_LOCATION=$(terraform output -raw gpu_cluster_location)
cd "$SCRIPT_DIR"

TIMESTAMP=$(date +"%Y_%m_%d_%H_%M")
RESULTS_DIR="gs://$GCS_BUCKET/$RESULTS_PREFIX"

echo "Starting vLLM benchmarks..."
echo "Timestamp: $TIMESTAMP"
echo "TPU Cluster: $TPU_CLUSTER_NAME ($TPU_CLUSTER_LOCATION)"
echo "GPU Cluster: $GPU_CLUSTER_NAME ($GPU_CLUSTER_LOCATION)"
echo "Results will be saved to: $RESULTS_DIR"

# Function to run benchmark on a specific cluster
run_benchmark() {
    local cluster_name=$1
    local cluster_location=$2
    local job_type=$3
    local system_type=$4
    
    echo "Running $job_type benchmark on $cluster_name..."
    
    # Get credentials for the cluster
    gcloud container clusters get-credentials "$cluster_name" --zone="$cluster_location"
    
    # Create namespace for this benchmark
    kubectl create namespace "vllm-benchmark-$job_type-$TIMESTAMP" --dry-run=client -o yaml | kubectl apply -f -
    
    # Create ConfigMap with benchmark script
    kubectl create configmap benchmark-script \
        --from-file="$SCRIPT_DIR/auto_tune.sh" \
        -n "vllm-benchmark-$job_type-$TIMESTAMP" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Create Job manifest
    cat > /tmp/benchmark-job-$job_type.yaml << EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: vllm-benchmark-$job_type
  namespace: vllm-benchmark-$job_type-$TIMESTAMP
spec:
  template:
    spec:
      nodeSelector:
        cloud.google.com/gke-nodepool: $job_type-pool
      tolerations:
      - key: cloud.google.com/gke-tpu
        operator: Equal
        value: "true"
        effect: NoSchedule
      - key: nvidia.com/gpu
        operator: Equal
        value: "true"
        effect: NoSchedule
      containers:
      - name: vllm-benchmark
        image: $5
        command: ["/bin/bash"]
        args:
        - -c
        - |
          # Install required packages
          pip install -q datasets
          
          # Copy benchmark script
          cp /config/auto_tune.sh /tmp/auto_tune.sh
          chmod +x /tmp/auto_tune.sh
          
          # Set environment variables
          export MODEL="meta-llama/Llama-3.1-8B-Instruct"
          export SYSTEM="$system_type"
          export INPUT_LEN=4000
          export OUTPUT_LEN=16
          export MAX_MODEL_LEN=4096
          
          # Run benchmark
          cd /tmp
          ./auto_tune.sh
          
          # Upload results to GCS
          gsutil -m cp -r /tmp/auto-benchmark/* gs://$GCS_BUCKET/$RESULTS_PREFIX/$system_type/$TIMESTAMP/
          
        volumeMounts:
        - name: benchmark-script
          mountPath: /config
        resources:
          requests:
            memory: "64Gi"
            cpu: "32"
          limits:
            memory: "64Gi"
            cpu: "32"
      volumes:
      - name: benchmark-script
        configMap:
          name: benchmark-script
      restartPolicy: Never
  backoffLimit: 0
