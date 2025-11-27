# Terraform variables for vLLM benchmark infrastructure

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The default GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The default GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "cluster_name_prefix" {
  description = "Prefix for GKE cluster names"
  type        = string
  default     = "ms-vllm-benchmark"
}

variable "gcs_bucket_name" {
  description = "Name of the GCS bucket for benchmark results"
  type        = string
}

variable "gcs_bucket_location" {
  description = "Location for the GCS bucket"
  type        = string
  default     = "asia-southeast1"
}

# TPU Cluster variables
variable "tpu_cluster_name" {
  description = "Name of the TPU cluster"
  type        = string
  default     = "ms-vllm-benchmark-tpu"
}

variable "tpu_cluster_location" {
  description = "Location for the TPU cluster"
  type        = string
  default     = "asia-northeast1-b"
}

variable "tpu_machine_type" {
  description = "Machine type for TPU nodes"
  type        = string
  default     = "ct6e-standard-1t"
}

variable "tpu_min_node_count" {
  description = "Minimum number of TPU nodes"
  type        = number
  default     = 1
}

variable "tpu_max_node_count" {
  description = "Maximum number of TPU nodes"
  type        = number
  default     = 1
}

variable "tpu_type" {
  description = "TPU type"
  type        = string
  default     = "v6e"
}

variable "tpu_topology" {
  description = "TPU topology"
  type        = string
  default     = "1x1"
}

# GPU Cluster variables
variable "gpu_cluster_name" {
  description = "Name of the GPU cluster"
  type        = string
  default     = "ms-vllm-benchmark-gpu"
}

variable "gpu_cluster_location" {
  description = "Location for the GPU cluster"
  type        = string
  default     = "asia-southeast1-b"
}

variable "gpu_machine_type" {
  description = "Machine type for GPU nodes"
  type        = string
  default     = "a3-highgpu-1g"
}

variable "gpu_min_node_count" {
  description = "Minimum number of GPU nodes"
  type        = number
  default     = 1
}

variable "gpu_max_node_count" {
  description = "Maximum number of GPU nodes"
  type        = number
  default     = 1
}

variable "gpu_type" {
  description = "GPU type"
  type        = string
  default     = "nvidia-h100-80gb"
}

variable "gpu_count" {
  description = "Number of GPUs per node"
  type        = number
  default     = 1
}

variable "gpu_use_spot_instances" {
  description = "Whether to use spot instances for GPU nodes"
  type        = bool
  default     = false
}

variable "huggingface_token" {
  description = "The Hugging Face token for accessing models."
  type        = string
  sensitive   = true # This ensures the token is never shown in Terraform output
}