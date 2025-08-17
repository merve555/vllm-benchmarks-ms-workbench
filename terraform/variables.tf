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

variable "tpu_zone" {
  description = "Zone for TPU cluster"
  type        = string
  default     = "asia-northeast1-b"
}

variable "gpu_zone" {
  description = "Zone for GPU cluster"
  type        = string
  default     = "asia-southeast1-b"
}

variable "huggingface_token" {
  description = "The Hugging Face token for accessing models."
  type        = string
  sensitive   = true # This ensures the token is never shown in Terraform output
}