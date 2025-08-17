# ./modules/gke/tpu-node-pool.tf

# This resource creates a TPU node pool, but only if 'enable_tpu' is set to true.
resource "google_container_node_pool" "tpu_node_pool" {
  count      = var.enable_tpu ? 1 : 0
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

    # Add taint for TPU workloads
    taint {
      key    = "cloud.google.com/gke-tpu"
      value  = "true"
      effect = "NO_SCHEDULE"
    }

    # Required for modern TPU VMs
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}