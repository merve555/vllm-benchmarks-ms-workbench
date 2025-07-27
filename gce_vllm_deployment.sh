#!/bin/bash

# vLLM Auto-Tune Deployment on Google Cloud Engine
# This script deploys and runs the vLLM auto-tune benchmark on GCE with GPU/TPU support

set -e

# Configuration - Modify these variables as needed
PROJECT_ID="your-project-id"  # Replace with your GCP project ID
ZONE="us-central1-a"          # GCE zone
MACHINE_TYPE="n1-standard-4"  # Base machine type (will be modified for GPU/TPU)
GPU_TYPE="nvidia-tesla-v100"  # GPU type: nvidia-tesla-v100, nvidia-tesla-t4, nvidia-tesla-a100
GPU_COUNT=1                   # Number of GPUs
TPU_TYPE="v3-8"              # TPU type: v2-8, v3-8, v4-8, etc.
INSTANCE_NAME="vllm-auto-tune"
DISK_SIZE="100GB"
DOCKER_IMAGE="vllm/vllm-openai:latest"  # vLLM Docker image

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== vLLM Auto-Tune GCE Deployment Script ===${NC}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command_exists gcloud; then
    echo -e "${RED}Error: gcloud CLI is not installed. Please install it first.${NC}"
    echo "Visit: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

if ! command_exists docker; then
    echo -e "${RED}Error: Docker is not installed. Please install it first.${NC}"
    exit 1
fi

# Authenticate with Google Cloud
echo -e "${YELLOW}Authenticating with Google Cloud...${NC}"
gcloud auth login --no-launch-browser

# Set the project
echo -e "${YELLOW}Setting project to $PROJECT_ID...${NC}"
gcloud config set project $PROJECT_ID

# Enable required APIs
echo -e "${YELLOW}Enabling required APIs...${NC}"
gcloud services enable compute.googleapis.com
gcloud services enable tpu.googleapis.com

# Function to create GPU instance
create_gpu_instance() {
    echo -e "${YELLOW}Creating GPU instance...${NC}"
    
    # Create instance with GPU
    gcloud compute instances create $INSTANCE_NAME \
        --zone=$ZONE \
        --machine-type=$MACHINE_TYPE \
        --maintenance-policy=TERMINATE \
        --accelerator="type=$GPU_TYPE,count=$GPU_COUNT" \
        --boot-disk-size=$DISK_SIZE \
        --image-family=debian-11 \
        --image-project=debian-cloud \
        --metadata=startup-script="#!/bin/bash
# Install Docker
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \"deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \$(lsb_release -cs) stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
usermod -aG docker \$USER

# Install NVIDIA Docker runtime
distribution=\$(. /etc/os-release;echo \$ID\$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/\$distribution/nvidia-docker.list | tee /etc/apt/sources.list.d/nvidia-docker.list
apt-get update
apt-get install -y nvidia-docker2
systemctl restart docker

# Install additional tools
apt-get install -y git curl wget tmux

# Clone vLLM repository
git clone https://github.com/vllm-project/vllm.git /home/vllm
chown -R \$USER:\$USER /home/vllm"
}

# Function to create TPU instance
create_tpu_instance() {
    echo -e "${YELLOW}Creating TPU instance...${NC}"
    
    # Create TPU
    gcloud compute tpus create $INSTANCE_NAME \
        --zone=$ZONE \
        --version=tpu-vm-base \
        --accelerator-type=$TPU_TYPE
    
    # Create TPU VM
    gcloud compute tpus tpu-vm create $INSTANCE_NAME \
        --zone=$ZONE \
        --accelerator-type=$TPU_TYPE \
        --version=tpu-vm-base \
        --metadata=startup-script="#!/bin/bash
# Install Docker
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \"deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \$(lsb_release -cs) stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
usermod -aG docker \$USER

# Install additional tools
apt-get install -y git curl wget tmux

# Clone vLLM repository
git clone https://github.com/vllm-project/vllm.git /home/vllm
chown -R \$USER:\$USER /home/vllm"
}

# Function to create auto-tune script
create_auto_tune_script() {
    cat > auto_tune_config.sh << 'EOF'
#!/bin/bash

# vLLM Auto-Tune Configuration
# Modify these variables according to your needs

TAG=$(date +"%Y_%m_%d_%H_%M")
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
BASE="$SCRIPT_DIR"
MODEL="meta-llama/Llama-3.1-8B-Instruct"  # Change to your model
SYSTEM="GPU"  # Change to "TPU" if using TPU
TP=1
DOWNLOAD_DIR=""
INPUT_LEN=4000
OUTPUT_LEN=16
MAX_MODEL_LEN=4096
MIN_CACHE_HIT_PCT=0
MAX_LATENCY_ALLOWED_MS=100000000000  # Very large number to ignore latency
NUM_SEQS_LIST="128 256"
NUM_BATCHED_TOKENS_LIST="512 1024 2048 4096"

LOG_FOLDER="$BASE/auto-benchmark/$TAG"
RESULT="$LOG_FOLDER/result.txt"
PROFILE_PATH="$LOG_FOLDER/profile"

echo "result file: $RESULT"
echo "model: $MODEL"

rm -rf $LOG_FOLDER
rm -rf $PROFILE_PATH
mkdir -p $LOG_FOLDER
mkdir -p $PROFILE_PATH

cd "$BASE/vllm"

pip install -q datasets

current_hash=$(git rev-parse HEAD)
echo "hash:$current_hash" >> "$RESULT"
echo "current_hash: $current_hash"

TOTAL_LEN=$((INPUT_LEN + OUTPUT_LEN))
RED='\033[0;31m'
if (( TOTAL_LEN > MAX_MODEL_LEN )); then
    echo -e "${RED}FAILED: INPUT_LEN($INPUT_LEN) + OUTPUT_LEN($OUTPUT_LEN) = $TOTAL_LEN, which is > MAX_MODEL_LEN = $MAX_MODEL_LEN.\033[0m" >&2
    exit 1
fi

best_throughput=0
best_max_num_seqs=0
best_num_batched_tokens=0
best_goodput=0

start_server() {
    local gpu_memory_utilization=$1
    local max_num_seqs=$2
    local max_num_batched_tokens=$3
    local vllm_log=$4
    local profile_dir=$5

    pkill -f vllm

    VLLM_USE_V1=1 VLLM_SERVER_DEV_MODE=1 VLLM_TORCH_PROFILER_DIR=$profile_dir vllm serve $MODEL \
        --disable-log-requests \
        --port 8004 \
        --gpu-memory-utilization $gpu_memory_utilization \
        --max-num-seqs $max_num_seqs \
        --max-num-batched-tokens $max_num_batched_tokens \
        --tensor-parallel-size $TP \
        --enable-prefix-caching \
        --load-format dummy \
        --download-dir "$DOWNLOAD_DIR" \
        --max-model-len $MAX_MODEL_LEN > "$vllm_log" 2>&1 &

    # wait for 10 minutes...
    server_started=0
    for i in {1..60}; do
        RESPONSE=$(curl -s -X GET "http://0.0.0.0:8004/health" -w "%{http_code}" -o /dev/stdout)
        STATUS_CODE=$(echo "$RESPONSE" | tail -n 1)
        if [[ "$STATUS_CODE" -eq 200 ]]; then
            server_started=1
            break
        else
            sleep 10
        fi
    done
    if (( ! server_started )); then
        echo "server did not start within 10 minutes. Please check server log at $vllm_log".
        return 1
    else
        return 0
    fi
}

update_best_profile() {
    local profile_dir=$1
    local profile_index=$2
    sorted_paths=($(find "$profile_dir" -maxdepth 1 -not -path "$profile_dir" | sort))
    selected_profile_file=
    if [[ "$SYSTEM" == "TPU" ]]; then
        selected_profile_file="${sorted_paths[$profile_index]}/*.xplane.pb"
    fi
    if [[ "$SYSTEM" == "GPU" ]]; then
        selected_profile_file="${sorted_paths[$profile_index]}"
    fi
    rm -f $PROFILE_PATH/*
    cp $selected_profile_file $PROFILE_PATH
}

run_benchmark() {
    local max_num_seqs=$1
    local max_num_batched_tokens=$2
    local gpu_memory_utilization=$3
    echo "max_num_seq: $max_num_seqs, max_num_batched_tokens: $max_num_batched_tokens"
    local vllm_log="$LOG_FOLDER/vllm_log_${max_num_seqs}_${max_num_batched_tokens}.txt"
    local profile_dir="$LOG_FOLDER/profile_${max_num_seqs}_${max_num_batched_tokens}"
    echo "vllm_log: $vllm_log"
    echo
    rm -f $vllm_log
    mkdir -p $profile_dir
    pkill -f vllm
    local profile_index=0

    echo "starting server..."
    start_server $gpu_memory_utilization $max_num_seqs $max_num_batched_tokens $vllm_log $profile_dir
    result=$?
    if [[ "$result" -eq 1 ]]; then
        echo "server failed to start. gpu_memory_utilization:$gpu_memory_utilization, max_num_seqs:$max_num_seqs, max_num_batched_tokens: $max_num_batched_tokens"
    else
        echo "server started."
    fi
    echo

    echo "run benchmark test..."
    meet_latency_requirement=0
    # get a basic qps by using request-rate inf
    bm_log="$LOG_FOLDER/bm_log_${max_num_seqs}_${max_num_batched_tokens}_requestrate_inf.txt"
    prefix_len=$(( INPUT_LEN * MIN_CACHE_HIT_PCT / 100 ))
    adjusted_input_len=$(( INPUT_LEN - prefix_len ))
    vllm bench serve \
        --backend vllm \
        --model $MODEL  \
        --dataset-name random \
        --random-input-len $adjusted_input_len \
        --random-output-len $OUTPUT_LEN \
        --ignore-eos \
        --disable-tqdm \
        --request-rate inf \
        --percentile-metrics ttft,tpot,itl,e2el \
        --goodput e2el:$MAX_LATENCY_ALLOWED_MS \
        --num-prompts 1000 \
        --random-prefix-len $prefix_len \
        --port 8004 \
        --profile &> "$bm_log"
    throughput=$(grep "Request throughput (req/s):" "$bm_log" | sed 's/[^0-9.]//g')
    e2el=$(grep "P99 E2EL (ms):" "$bm_log" | awk '{print $NF}')
    goodput=$(grep "Request goodput (req/s):" "$bm_log" | sed 's/[^0-9.]//g')

    if (( $(echo "$e2el <= $MAX_LATENCY_ALLOWED_MS" | bc -l) )); then
        meet_latency_requirement=1
        request_rate=inf
    fi

    if (( ! meet_latency_requirement )); then
    # start from request-rate as int(throughput) + 1
        request_rate=$((${throughput%.*} + 1))
        while ((request_rate > 0)); do
            profile_index=$((profile_index+1))
            # clear prefix cache
            curl -X POST http://0.0.0.0:8004/reset_prefix_cache
            sleep 5
            bm_log="$LOG_FOLDER/bm_log_${max_num_seqs}_${max_num_batched_tokens}_requestrate_${request_rate}.txt"
            vllm bench serve \
                --backend vllm \
                --model $MODEL  \
                --dataset-name random \
                --random-input-len $adjusted_input_len \
                --random-output-len $OUTPUT_LEN \
                --ignore-eos \
                --disable-tqdm \
                --request-rate $request_rate \
                --percentile-metrics ttft,tpot,itl,e2el \
                --goodput e2el:$MAX_LATENCY_ALLOWED_MS \
                --num-prompts 100 \
                --random-prefix-len $prefix_len \
                --port 8004 &> "$bm_log"
            throughput=$(grep "Request throughput (req/s):" "$bm_log" | sed 's/[^0-9.]//g')
            e2el=$(grep "P99 E2EL (ms):" "$bm_log" | awk '{print $NF}')
            goodput=$(grep "Request goodput (req/s):" "$bm_log" | sed 's/[^0-9.]//g')
            if (( $(echo "$e2el <= $MAX_LATENCY_ALLOWED_MS" | bc -l) )); then
                meet_latency_requirement=1
                break
            fi
            request_rate=$((request_rate-1))
        done
    fi
    # write the results and update the best result.
    if ((meet_latency_requirement)); then
        echo "max_num_seqs: $max_num_seqs, max_num_batched_tokens: $max_num_batched_tokens, request_rate: $request_rate, e2el: $e2el, throughput: $throughput, goodput: $goodput"
        echo "max_num_seqs: $max_num_seqs, max_num_batched_tokens: $max_num_batched_tokens, request_rate: $request_rate, e2el: $e2el, throughput: $throughput, goodput: $goodput" >> "$RESULT"
        if (( $(echo "$throughput > $best_throughput" | bc -l) )); then
            best_throughput=$throughput
            best_max_num_seqs=$max_num_seqs
            best_num_batched_tokens=$max_num_batched_tokens
            best_goodput=$goodput
            if [[ "$SYSTEM" == "TPU" ]]; then
                update_best_profile "$profile_dir/plugins/profile" $profile_index
            fi
            if [[ "$SYSTEM" == "GPU" ]]; then
                update_best_profile "$profile_dir" $profile_index
            fi
        fi
    else
        echo "max_num_seqs: $max_num_seqs, max_num_batched_tokens: $max_num_batched_tokens does not meet latency requirement ${MAX_LATENCY_ALLOWED_MS}"
        echo "max_num_seqs: $max_num_seqs, max_num_batched_tokens: $max_num_batched_tokens does not meet latency requirement ${MAX_LATENCY_ALLOWED_MS}" >> "$RESULT"
    fi

    echo "best_max_num_seqs: $best_max_num_seqs, best_num_batched_tokens: $best_num_batched_tokens, best_throughput: $best_throughput"

    pkill vllm
    sleep 10
    printf '=%.0s' $(seq 1 20)
    return 0
}

read -r -a num_seqs_list <<< "$NUM_SEQS_LIST"
read -r -a num_batched_tokens_list <<< "$NUM_BATCHED_TOKENS_LIST"

# first find out the max gpu-memory-utilization without HBM OOM.
gpu_memory_utilization=0.98
find_gpu_memory_utilization=0
while (( $(echo "$gpu_memory_utilization >= 0.9" | bc -l) )); do
    start_server $gpu_memory_utilization "${num_seqs_list[-1]}" "${num_batched_tokens_list[-1]}" "$LOG_FOLDER/vllm_log_gpu_memory_utilization_$gpu_memory_utilization.log"
    result=$?
    if [[ "$result" -eq 0 ]]; then
        find_gpu_memory_utilization=1
        break
    else
        gpu_memory_utilization=$(echo "$gpu_memory_utilization - 0.01" | bc)
    fi
done

if [[ "$find_gpu_memory_utilization" -eq 1 ]]; then
    echo "Using gpu_memory_utilization=$gpu_memory_utilization to serve model."
else
    echo "Cannot find a proper gpu_memory_utilization over 0.9 to serve the model, please check logs in $LOG_FOLDER."
    exit 1
fi

for num_seqs in "${num_seqs_list[@]}"; do
    for num_batched_tokens in "${num_batched_tokens_list[@]}"; do
        run_benchmark $num_seqs $num_batched_tokens $gpu_memory_utilization
    done
done
echo "finish permutations"
echo "best_max_num_seqs: $best_max_num_seqs, best_num_batched_tokens: $best_num_batched_tokens, best_throughput: $best_throughput, profile saved in: $PROFILE_PATH"
echo "best_max_num_seqs: $best_max_num_seqs, best_num_batched_tokens: $best_num_batched_tokens, best_throughput: $best_throughput, profile saved in: $PROFILE_PATH" >> "$RESULT"
EOF

    chmod +x auto_tune_config.sh
}

# Function to create Docker run script
create_docker_run_script() {
    cat > run_vllm_docker.sh << 'EOF'
#!/bin/bash

# Run vLLM in Docker container
echo "Starting vLLM Docker container..."

# For GPU
if [[ "$SYSTEM" == "GPU" ]]; then
    docker run --gpus all -it --rm \
        -v $(pwd):/workspace \
        -p 8004:8004 \
        $DOCKER_IMAGE \
        bash -c "
        cd /workspace
        git clone https://github.com/vllm-project/vllm.git
        cd vllm
        pip install -e .
        cd /workspace
        bash auto_tune_config.sh
        "
fi

# For TPU
if [[ "$SYSTEM" == "TPU" ]]; then
    docker run -it --rm \
        -v $(pwd):/workspace \
        -p 8004:8004 \
        $DOCKER_IMAGE \
        bash -c "
        cd /workspace
        git clone https://github.com/vllm-project/vllm.git
        cd vllm
        pip install -e .
        cd /workspace
        bash auto_tune_config.sh
        "
fi
EOF

    chmod +x run_vllm_docker.sh
}

# Main deployment logic
echo -e "${YELLOW}Choose deployment type:${NC}"
echo "1. GPU deployment"
echo "2. TPU deployment"
read -p "Enter your choice (1 or 2): " choice

case $choice in
    1)
        echo -e "${GREEN}Deploying with GPU support...${NC}"
        create_gpu_instance
        ;;
    2)
        echo -e "${GREEN}Deploying with TPU support...${NC}"
        create_tpu_instance
        ;;
    *)
        echo -e "${RED}Invalid choice. Exiting.${NC}"
        exit 1
        ;;
esac

# Wait for instance to be ready
echo -e "${YELLOW}Waiting for instance to be ready...${NC}"
sleep 60

# SSH into the instance and set up the environment
echo -e "${YELLOW}Setting up the environment on the instance...${NC}"

if [[ "$choice" == "1" ]]; then
    # For GPU instance
    gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="
        cd /home
        git clone https://github.com/vllm-project/vllm.git
        cd vllm
        pip install -e .
        cd /home
        wget https://raw.githubusercontent.com/vllm-project/vllm/main/benchmarks/auto_tune/auto_tune.sh
        chmod +x auto_tune.sh
        echo 'Setup complete!'
    "
else
    # For TPU instance
    gcloud compute tpus tpu-vm ssh $INSTANCE_NAME --zone=$ZONE --command="
        cd /home
        git clone https://github.com/vllm-project/vllm.git
        cd vllm
        pip install -e .
        cd /home
        wget https://raw.githubusercontent.com/vllm-project/vllm/main/benchmarks/auto_tune/auto_tune.sh
        chmod +x auto_tune.sh
        echo 'Setup complete!'
    "
fi

echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "1. SSH into the instance:"
if [[ "$choice" == "1" ]]; then
    echo "   gcloud compute ssh $INSTANCE_NAME --zone=$ZONE"
else
    echo "   gcloud compute tpus tpu-vm ssh $INSTANCE_NAME --zone=$ZONE"
fi
echo ""
echo "2. Navigate to the vLLM directory:"
echo "   cd /home/vllm"
echo ""
echo "3. Run the auto-tune script:"
echo "   bash auto_tune.sh"
echo ""
echo "4. Monitor the results in the auto-benchmark directory"
echo ""
echo "5. When done, delete the instance:"
if [[ "$choice" == "1" ]]; then
    echo "   gcloud compute instances delete $INSTANCE_NAME --zone=$ZONE"
else
    echo "   gcloud compute tpus delete $INSTANCE_NAME --zone=$ZONE"
    echo "   gcloud compute tpus tpu-vm delete $INSTANCE_NAME --zone=$ZONE"
fi