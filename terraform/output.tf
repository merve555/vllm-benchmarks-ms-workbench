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

# Cloud Router outputs
output "cloud_router_name" {
  description = "Name of the Cloud Router"
  value       = google_compute_router.gke_router.name
}

output "cloud_router_region" {
  description = "Region of the Cloud Router"
  value       = google_compute_router.gke_router.region
}

# Cloud NAT outputs
output "cloud_nat_name" {
  description = "Name of the Cloud NAT"
  value       = google_compute_router_nat.gke_nat.name
}

output "cloud_nat_region" {
  description = "Region of the Cloud NAT"
  value       = google_compute_router_nat.gke_nat.region
}