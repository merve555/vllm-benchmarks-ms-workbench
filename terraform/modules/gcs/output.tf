# GCS Module Outputs

output "bucket_name" {
  description = "Name of the created GCS bucket"
  value       = google_storage_bucket.benchmark_results.name
}

output "bucket_url" {
  description = "URL of the created GCS bucket"
  value       = google_storage_bucket.benchmark_results.url
}

output "bucket_self_link" {
  description = "Self-link of the created GCS bucket"
  value       = google_storage_bucket.benchmark_results.self_link
}