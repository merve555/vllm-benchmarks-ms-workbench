# Terraform outputs for vLLM benchmark infrastructure

output "tpu_cluster_name" {
  description = "Name of the TPU GKE cluster"
  value       = module.tpu_cluster.cluster_name
}

output "tpu_cluster_location" {
  description = "Location of the TPU GKE cluster"
  value       = module.tpu_cluster.cluster_location
}

output "gpu_cluster_name" {
  description = "Name of the GPU GKE cluster"
  value       = module.gpu_cluster.cluster_name
}

output "gpu_cluster_location" {
  description = "Location of the GPU GKE cluster"
  value       = module.gpu_cluster.cluster_location
}

output "gcs_bucket_name" {
  description = "Name of the GCS bucket for benchmark results"
  value       = module.gcs_bucket.bucket_name
}

output "gcs_bucket_url" {
  description = "URL of the GCS bucket for benchmark results"
  value       = module.gcs_bucket.bucket_url
}

output "tpu_cluster_endpoint" {
  description = "Endpoint of the TPU GKE cluster"
  value       = module.tpu_cluster.cluster_endpoint
}

output "gpu_cluster_endpoint" {
  description = "Endpoint of the GPU GKE cluster"
  value       = module.gpu_cluster.cluster_endpoint
}

output "project_id" {
  description = "The GCP project ID"
  value       = var.project_id
}