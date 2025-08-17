# ./main.tf

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.17.0"
    }
  }
}

# Configure the Google Provider
provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs for GKE, TPUs, and GCS
resource "google_project_service" "required_apis" {
  for_each = toset([
    "container.googleapis.com",
    "tpu.googleapis.com",
    "compute.googleapis.com",
    "storage.googleapis.com"
  ])

  project                    = var.project_id
  service                    = each.value
  disable_dependent_services = true
  disable_on_destroy         = false
}

# Create GCS bucket for storing benchmark results
module "gcs_bucket" {
  source          = "./modules/gcs"
  bucket_name     = var.gcs_bucket_name
  bucket_location = var.gcs_bucket_location
  force_destroy   = true
  retention_days  = 30
  labels = {
    purpose = "vllm-benchmark"
    managed = "terraform"
  }
}

# Create a dedicated GKE cluster for TPU workloads
module "tpu_cluster" {
  source = "./modules/gke"

  project_id       = var.project_id
  cluster_name     = "${var.cluster_name_prefix}-tpu"
  cluster_location = var.tpu_zone

  # TPU Node Pool Configuration
  enable_tpu     = true
  node_pool_name = "tpu-pool"
  machine_type   = "ct6e-standard-4t" # TODO adjust here
  node_labels    = { "cloud.google.com/gke-tpu" = "true" }
  oauth_scopes = [
    "https://www.googleapis.com/auth/devstorage.read_only",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring",
    "https://www.googleapis.com/auth/compute"
  ]

  api_dependencies = values(google_project_service.required_apis)
}

# Create a dedicated GKE cluster for GPU workloads
module "gpu_cluster" {
  source = "./modules/gke"

  project_id       = var.project_id
  cluster_name     = "${var.cluster_name_prefix}-gpu"
  cluster_location = var.gpu_zone

  # GPU Node Pool Configuration
  node_pool_name = "gpu-pool"
  machine_type   = "a3-highgpu-8g" # TODO: adjust
  gpu_config = {
    type  = "nvidia-h100-80gb"
    count = 8
  }
  node_labels = { "nvidia.com/gpu" = "true" }
  oauth_scopes = [
    "https://www.googleapis.com/auth/devstorage.read_only",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring",
    "https://www.googleapis.com/auth/compute"
  ]

  api_dependencies = values(google_project_service.required_apis)
}