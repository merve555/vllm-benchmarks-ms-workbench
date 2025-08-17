# terraform.tfvars - update with your values

project_id = "diesel-patrol-382622"
region     = "us-central1"

# GCS bucket configuration
gcs_bucket_name = "ms-vllm-benchmark-results-20250804"  # TODO: automate this with a random string to get unique ID

# Cluster configuration
cluster_name_prefix = "ms-vllm-benchmark"

# Zone configuration (these are the only zones where TPU v6e and H100 are available)
tpu_zone = "asia-northeast1-b"  # TPU v6e available here
gpu_zone = "asia-southeast1-b"  # H100 GPU available here

huggingface_token = "your-hf-token"    # TODO: delete later"