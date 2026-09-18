#!/usr/bin/env bash
set -euo pipefail

exec vllm serve "${MODEL_PATH:-/models/qwen3-5-4b}" \
  --host 0.0.0.0 \
  --port "${PORT:-8080}" \
  --served-model-name Qwen/Qwen3.5-4B \
  --reasoning-parser qwen3 \
  --default-chat-template-kwargs '{"enable_thinking": false}' \
  --dtype bfloat16 \
  --limit-mm-per-prompt '{"image": 1, "video": 0}' \
  --generation-config vllm \
  --max-model-len 16384 \
  --gpu-memory-utilization 0.92 \
  --max-num-seqs "${MAX_NUM_SEQS:-4}" \
  --mm-processor-cache-gb 0
