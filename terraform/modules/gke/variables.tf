# ./modules/gke/variables.tf

variable "project_id" {
  description = "The GCP project ID where the cluster will be created."
  type        = string
}

variable "cluster_name" {
  description = "The name for the GKE cluster."
  type        = string
}

variable "cluster_location" {
  description = "The zone or region for the GKE cluster and its nodes."
  type        = string
}

variable "node_pool_name" {
  description = "The name for the node pool."
  type        = string
}

variable "machine_type" {
  description = "The machine type for the nodes in the node pool."
  type        = string
}

variable "node_count" {
  description = "The initial number of nodes for the node pool."
  type        = number
  default     = 1
}

variable "min_node_count" {
  description = "The minimum number of nodes for autoscaling."
  type        = number
  default     = 0
}

variable "max_node_count" {
  description = "The maximum number of nodes for autoscaling."
  type        = number
  default     = 2
}

variable "disk_size_gb" {
  description = "The disk size in GB for node VMs."
  type        = number
  default     = 100
}

variable "oauth_scopes" {
  description = "The set of OAuth scopes to be made available on all of the node VMs."
  type        = list(string)
}

variable "node_labels" {
  description = "A map of key/value labels to apply to each node."
  type        = map(string)
  default     = {}
}

variable "api_dependencies" {
  description = "A list of API services that must be enabled before the cluster is created."
  type        = any
  default     = []
}

variable "gpu_config" {
  description = "Configuration for a GPU accelerator. Set this to create a GPU node pool."
  type = object({
    type  = string
    count = number
  })
  default = null
}

variable "enable_tpu" {
  description = "Set to true to create a TPU node pool."
  type        = bool
  default     = false
}