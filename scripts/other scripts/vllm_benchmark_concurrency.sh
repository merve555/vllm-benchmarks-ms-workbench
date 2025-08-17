#!/bin/bash

TAG=$(date +"%Y_%m_%d_%H_%M")
BASE="/home/mervesayan"

# Pulling GPTQ Quantized model (offline) from GCS and Local Model Paths
GCS_MODEL_PATH="gs://ms-qwen25-coder-14b-gptq-8bit-quantized/Qwen2.5-Coder-14B-GPTQ-8bit"
LOCAL_MODEL_PATH="$BASE/quantized_model_gptq"

# Point the main MODEL variable to the intended LOCAL path
MODEL="$LOCAL_MODEL_PATH"

TP=1
DOWNLOAD_DIR="/model-weights"
INPUT_LEN=512
OUTPUT_LEN=32
MIN_CACHE_HIT_PCT=0
MAX_LATENCY_ALLOWED_MS=100000000000

# Define the concurrency levels to test
CONCURRENCY_LIST="1 10 25 50 100"

# Use fixed server parameters for this test - in this case: optimal conifgs for max throughput
MAX_NUM_SEQS=256
MAX_NUM_BATCHED_TOKENS=4096
GPU_MEMORY_UTILIZATION=0.95


LOG_FOLDER="$BASE/auto-benchmark/$TAG-concurrency"
RESULT="$LOG_FOLDER/result.txt"

echo "result file: $RESULT"
echo "model: $MODEL"

rm -rf $LOG_FOLDER
mkdir -p $LOG_FOLDER

# Step to download the model from GCS
echo "--- Downloading quantized model from GCS to local disk ---"
# Remove any old version first for a clean slate
rm -rf "$LOCAL_MODEL_PATH"
# Create the destination directory before copying into it.
mkdir -p "$LOCAL_MODEL_PATH"
# Use gsutil to copy the contents of the GCS folder
gsutil -m cp -r "$GCS_MODEL_PATH"/* "$LOCAL_MODEL_PATH"
echo "--- Download complete ---"

cd "$BASE/vllm"

pip install -q datasets

current_hash=$(git rev-parse HEAD)
echo "hash:$current_hash" >> "$RESULT"
echo "current_hash: $current_hash"
echo "Fixed Server Config: max_num_seqs=${MAX_NUM_SEQS}, max_num_batched_tokens=${MAX_NUM_BATCHED_TOKENS}" >> "$RESULT"


start_server() {
    local vllm_log=$1
    
    pkill -f vllm

    VLLM_USE_V1=1 VLLM_SERVER_DEV_MODE=1 vllm serve $MODEL \
        --quantization gptq \
        --disable-log-requests \
        --port 8004 \
        --gpu-memory-utilization $GPU_MEMORY_UTILIZATION \
        --max-num-seqs $MAX_NUM_SEQS \
        --max-num-batched-tokens $MAX_NUM_BATCHED_TOKENS \
        --tensor-parallel-size $TP \
        --no-enable-prefix-caching \
        --download-dir "$DOWNLOAD_DIR" \
        --max-model-len $(( INPUT_LEN+OUTPUT_LEN )) > "$vllm_log" 2>&1 &

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


# Benchmark function
run_benchmark_for_concurrency() {
    local num_clients=$1
    local gpu_memory_utilization=$2

    echo ""
    echo "---------------------------------------------------------"
    echo "--- Running benchmark for $num_clients concurrent clients ---"
    echo "---------------------------------------------------------"

    bm_log="$LOG_FOLDER/bm_log_clients_${num_clients}.txt"
    prefix_len=$(( INPUT_LEN * MIN_CACHE_HIT_PCT / 100 ))    
    python benchmarks/benchmark_serving.py \
        --backend vllm \
        --model "$MODEL" \
        --dataset-name random \
        --random-input-len "$INPUT_LEN" \
        --random-output-len "$OUTPUT_LEN" \
        --ignore-eos \
        --disable-tqdm \
        --request-rate inf \
        --max-concurrency "$concurrency" \
        --percentile-metrics ttft,tpot,itl,e2el \
        --metric-percentiles 50,95,99 \
        --goodput e2el:$MAX_LATENCY_ALLOWED_MS \
        --num-prompts 1000 \
        --random-prefix-len "$prefix_len" \
        --port 8004 &> "$bm_log"

    echo "--- Results for $num_clients Client(s) ---" | tee -a "$RESULT"
    grep "Request throughput" "$bm_log" | tee -a "$RESULT"
    grep "Output token throughput" "$bm_log" | tee -a "$RESULT"
    grep "Mean E2EL" "$bm_log" | tee -a "$RESULT"
    echo "" >> "$RESULT"
}

# Main logic loops over concurrency levels

# Start the server once with fixed settings
vllm_log="$LOG_FOLDER/vllm_server_log.txt"
echo "Starting server with fixed parameters for concurrency test..."
start_server "$vllm_log"
result=$?
if [[ "$result" -eq 1 ]]; then
    echo "Server failed to start, cannot run benchmark. Check log: $vllm_log"
    exit 1
else
    echo "Server started successfully."
fi

# Loop through the list of concurrency levels to test
read -r -a concurrency_list_array <<< "$CONCURRENCY_LIST"
for concurrency in "${concurrency_list_array[@]}"; do
    run_benchmark_for_concurrency "$concurrency" "$GPU_MEMORY_UTILIZATION"
done


pkill -f vllm
echo "Concurrency benchmark finished."
echo "Full results are in: $RESULT"
