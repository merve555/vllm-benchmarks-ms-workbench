# GCS Bucket Module
# This module creates a GCS bucket for storing benchmark results

resource "google_storage_bucket" "benchmark_results" {
  name          = var.bucket_name
  location      = var.bucket_location
  force_destroy = var.force_destroy
  
  uniform_bucket_level_access = true
  
  versioning {
    enabled = true
  }
  
  lifecycle_rule {
    condition {
      age = var.retention_days
    }
    action {
      type = "Delete"
    }
  }
  
  labels = var.labels
}