# GCS Module Variables

variable "bucket_name" {
  description = "Name of the GCS bucket"
  type        = string
}

variable "bucket_location" {
  description = "Location for the GCS bucket"
  type        = string
  default     = "asia-southeast1"
}

variable "force_destroy" {
  description = "Whether to force destroy the bucket"
  type        = bool
  default     = true
}

variable "retention_days" {
  description = "Number of days to retain objects"
  type        = number
  default     = 30
}

variable "labels" {
  description = "Labels to apply to the bucket"
  type        = map(string)
  default     = {}
}