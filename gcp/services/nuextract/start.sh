#!/usr/bin/env bash
set -euo pipefail

exec vllm serve "${MODEL_PATH:-/models/nuextract3}" \
  --host 0.0.0.0 \
  --port "${PORT:-8080}" \
  --served-model-name numind/NuExtract3 \
  --trust-remote-code \
  --chat-template-content-format openai \
  --dtype bfloat16 \
  --limit-mm-per-prompt '{"image": 6, "video": 0}' \
  --generation-config vllm \
  --max-model-len 16384 \
  --gpu-memory-utilization 0.92 \
  --max-num-seqs "${MAX_NUM_SEQS:-2}" \
  --speculative-config '{"method": "qwen3_next_mtp", "num_speculative_tokens": 2}' \
  --mm-processor-cache-gb 0
