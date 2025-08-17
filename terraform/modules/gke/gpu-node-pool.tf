# ./modules/gke/gpu-node-pool.tf

# This resource creates a GPU node pool, but only if a 'gpu_config' object is provided.
resource "google_container_node_pool" "gpu_node_pool" {
  count      = var.gpu_config != null ? 1 : 0
  name       = var.node_pool_name
  cluster    = google_container_cluster.cluster.name
  location   = google_container_cluster.cluster.location
  node_count = var.node_count

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  node_config {
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    labels       = var.node_labels
    oauth_scopes = var.oauth_scopes

    spot = false # set to true for Spot VMs  

    # Statically assign the GPU configuration
    guest_accelerator {
      type  = var.gpu_config.type
      count = var.gpu_config.count
    }

    # Add taint to ensure only GPU-specific workloads are scheduled
    taint {
      key    = "nvidia.com/gpu"
      value  = "true"
      effect = "NO_SCHEDULE"
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  timeouts {
    create = "30m"
    update = "30m"
  }
}
