# ./modules/gke/cluster.tf

resource "google_container_cluster" "cluster" {
  name     = var.cluster_name
  location = var.cluster_location

  # We create dedicated node pools, so we remove the default one.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Basic network and security settings
  network_policy {
    enabled = true
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  ip_allocation_policy {} # Use GKE default IP aliasing

  release_channel {
    channel = "STABLE"
  }

  deletion_protection = false

  # This depends_on ensures that the necessary APIs are enabled before the cluster is created.
  depends_on = [var.api_dependencies]
}