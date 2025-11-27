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

# Configure the Google Cloud provider
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "container.googleapis.com",
    "tpu.googleapis.com",
    "compute.googleapis.com",
    "storage.googleapis.com"
  ])
  
  service = each.value
  disable_dependent_services = false
  disable_on_destroy = false
}

# Create Cloud Router for NAT
resource "google_compute_router" "gke_router" {
  name    = "gke-router"
  region  = var.region
  network = "default"
  
  depends_on = [google_project_service.required_apis]
}

# Create Cloud NAT for internet access
resource "google_compute_router_nat" "gke_nat" {
  name                               = "gke-nat"
  router                            = google_compute_router.gke_router.name
  region                            = google_compute_router.gke_router.region
  nat_ip_allocate_option            = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Create GCS bucket for benchmark results
resource "google_storage_bucket" "benchmark_results" {
  name          = var.gcs_bucket_name
  location      = var.gcs_bucket_location
  force_destroy = true
  
  uniform_bucket_level_access = true
  
  versioning {
    enabled = true
  }
  
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }
  
  labels = {
    purpose = "vllm-benchmark"
    managed = "terraform"
  }
  
  depends_on = [google_project_service.required_apis]
}

# Create TPU cluster
module "tpu_cluster" {
  source = "./modules/gke"

  project_id       = var.project_id
  cluster_name     = var.tpu_cluster_name
  cluster_location = var.tpu_cluster_location

  # TPU Node Pool Configuration
  enable_tpu     = true
  node_pool_name = "tpu-pool"
  machine_type   = var.tpu_machine_type
  min_node_count = var.tpu_min_node_count
  max_node_count = var.tpu_max_node_count
  node_labels    = { "cloud.google.com/gke-tpu" = "true" }
  oauth_scopes = [
    "https://www.googleapis.com/auth/devstorage.read_only",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring",
    "https://www.googleapis.com/auth/compute"
  ]

  api_dependencies = values(google_project_service.required_apis)
}

# Create GPU cluster
module "gpu_cluster" {
  source = "./modules/gke"

  project_id       = var.project_id
  cluster_name     = var.gpu_cluster_name
  cluster_location = var.gpu_cluster_location

  # GPU Node Pool Configuration
  node_pool_name = "gpu-pool"
  machine_type   = var.gpu_machine_type
  min_node_count = var.gpu_min_node_count
  max_node_count = var.gpu_max_node_count
  gpu_config = {
    type  = var.gpu_type
    count = var.gpu_count
  }
  use_spot_instances = var.gpu_use_spot_instances
  node_labels = { "nvidia.com/gpu" = "true" }
  oauth_scopes = [
    "https://www.googleapis.com/auth/devstorage.read_only",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring",
    "https://www.googleapis.com/auth/compute"
  ]

  api_dependencies = values(google_project_service.required_apis)
}