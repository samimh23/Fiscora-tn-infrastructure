#!/usr/bin/env bash
set -euo pipefail

exec vllm serve "${MODEL_PATH:-/models/nuextract3}" \
  --host 0.0.0.0 \
  --port "${PORT:-8080}" \
  --served-model-name numind/NuExtract3 \
  --trust-remote-code \
  --quantization fp8 \
  --limit-mm-per-prompt '{"image": 99, "video": 0}' \
  --chat-template-content-format openai \
  --generation-config vllm \
  --max-model-len 8192 \
  --gpu-memory-utilization 0.95 \
  --max-num-seqs "${MAX_NUM_SEQS:-32}" \
  --speculative-config '{"method": "mtp", "num_speculative_tokens": 4}'

