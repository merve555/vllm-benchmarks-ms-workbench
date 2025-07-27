FROM python:3.10-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    bc \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /workspace

# Clone vLLM repository
RUN git clone https://github.com/vllm-project/vllm.git /workspace/vllm

# Install vLLM with TPU support
RUN cd /workspace/vllm && \
    pip install --upgrade pip && \
    pip install -e .[tpu]

# Install additional dependencies
RUN pip install datasets torch_xla

# Create directories for results
RUN mkdir -p /shared/autotune-results

# Copy the autotune script
COPY scripts/auto_tune_gke_tpu.sh /workspace/auto_tune_gke_tpu.sh
RUN chmod +x /workspace/auto_tune_gke_tpu.sh

# Set environment variables for TPU
ENV XLA_USE_BF16=1
ENV TPU_NUM_DEVICES=1
ENV TPU_CHIPS_PER_HOST=1

# Default command
CMD ["/workspace/auto_tune_gke_tpu.sh"]