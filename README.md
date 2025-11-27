# vLLM Benchmarks for TPU & GPU

This repository provides infrastructure and automation for running vLLM benchmarks on Google Kubernetes Engine (GKE) with both TPU and GPU nodes. It supports setting up a new GKE cluster or using an existing one.

## Overview

The repository uses the [vLLM auto-tune script](https://github.com/vllm-project/vllm/tree/main/benchmarks/auto_tune) to automatically find optimal server parameters (max_num_seqs and max_num_batched_tokens) that maximize throughput while meeting latency requirements.

## Prerequisites

- Google Cloud SDK installed and configured
- Terraform (version >= 1.0) installed
- kubectl installed
- Hugging Face token for accessing models
- GCP project with appropriate permissions

## Usage

### Option 1: Setup New GKE Cluster

1. Configure Terraform variables:
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your project details.

2. Deploy infrastructure:
```bash
./scripts/setup-infrastructure.sh
```

3. Setup Kubernetes resources:
```bash
./scripts/setup-k8s.sh
```

4. Update Hugging Face token:
```bash
echo -n "your-actual-token" | base64
kubectl patch secret huggingface-token -p='{"data":{"token":"<base64-encoded-token>"}}'
```

### Option 2: Use Existing GKE Cluster

1. Get cluster credentials:
```bash
gcloud container clusters get-credentials <cluster-name> --region=<region> --project=<project-id>
```

2. Create ConfigMap and secrets:
```bash
./scripts/setup-k8s.sh
```

3. Update Hugging Face token (same as above)

## Running Benchmarks

### GPU Benchmarks

Edit `k8s/job-gpu.yaml` to configure:
- Model name
- Input/output lengths
- Max model length
- Max latency
- Prefix caching 

Apply the job:
```bash
kubectl apply -f k8s/job-gpu.yaml
```

Monitor:
```bash
kubectl logs -f job/vllm-gpu-benchmark
```

### TPU Benchmarks

Edit `k8s/job-tpu.yaml` for standard runs, or use `k8s/job-tpu-from-source.yaml` to build vLLM from source.

Apply the job:
```bash
kubectl apply -f k8s/job-tpu.yaml
```

Monitor:
```bash
kubectl logs -f job/vllm-tpu-benchmark
```

## Configuration

Benchmark parameters are configured via environment variables in the Kubernetes job YAML files:

- `MODEL`: Model identifier (e.g., meta-llama/Llama-3.2-1B)
- `INPUT_LEN`: Input token length
- `OUTPUT_LEN`: Output token length
- `MAX_MODEL_LEN`: Maximum model context length
- `MAX_LATENCY_ALLOWED_MS`: Maximum allowed end-to-end latency (optional)
- `NUM_SEQS_LIST`: Space-separated list of max_num_seqs values to test
- `NUM_BATCHED_TOKENS_LIST`: Space-separated list of max_num_batched_tokens values to test
- `GCS_BUCKET`: GCS bucket name for results
- `RESULTS_PREFIX`: Prefix for results path in GCS

## Results

Benchmark results are automatically uploaded to GCS with the following structure:
```
gs://<bucket>/<results-prefix>/<SYSTEM>/<TIMESTAMP>/
├── result.txt
├── benchmark_summary.txt
├── bm_log_*.txt
├── vllm_log_*.txt
└── profile/
```

## Repository Structure

```
├── terraform/              # Infrastructure as Code
│   ├── main.tf
│   ├── variables.tf
│   ├── terraform.tfvars.example
│   └── modules/
│       ├── gcs/           # GCS bucket module
│       └── gke/           # GKE cluster module
├── k8s/                    # Kubernetes manifests
│   ├── job-gpu.yaml       # GPU benchmark job
│   ├── job-tpu.yaml       # TPU benchmark job
│   ├── job-tpu-from-source.yaml  # TPU job with source build
│   └── huggingface-secret.yaml   # Secret template
├── scripts/                # Automation scripts
│   ├── setup-infrastructure.sh
│   ├── setup-k8s.sh
│   └── vllm_auto_tune.sh  # Benchmark script (from vLLM repo)
└── configs/                # Configuration files
    └── benchmark-config.yaml
```

## Cleanup

To remove all resources created by Terraform:

```bash
./scripts/cleanup.sh
```

## Troubleshooting

- **Cluster not accessible**: Verify credentials with `gcloud container clusters get-credentials`
- **Model download fails**: Check Hugging Face token is correct and has access to the model
- **Pod scheduling issues**: Verify node pools exist and have available capacity
- **GCS upload fails**: Ensure Workload Identity is configured or service account has storage permissions
