# GKE Module Outputs

output "cluster_name" {
  description = "Name of the created GKE cluster"
  value       = google_container_cluster.cluster.name
}

output "cluster_location" {
  description = "Location of the created GKE cluster"
  value       = google_container_cluster.cluster.location
}

output "cluster_endpoint" {
  description = "Endpoint of the created GKE cluster"
  value       = google_container_cluster.cluster.endpoint
}

output "cluster_master_version" {
  description = "Master version of the created GKE cluster"
  value       = google_container_cluster.cluster.master_version
}

output "node_pool_name" {
  description = "Name of the created node pool"
  value       = try(google_container_node_pool.tpu_node_pool[0].name, google_container_node_pool.gpu_node_pool[0].name, null)
}

output "node_pool_instance_group_urls" {
  description = "List of instance group URLs for the node pool"
  value       = try(google_container_node_pool.tpu_node_pool[0].instance_group_urls, google_container_node_pool.gpu_node_pool[0].instance_group_urls, [])
}
