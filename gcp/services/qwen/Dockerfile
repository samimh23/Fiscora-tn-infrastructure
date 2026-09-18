FROM vllm/vllm-openai:nightly

ARG MODEL_ID=Qwen/Qwen3.5-4B
ARG MODEL_REVISION=851bf6e

LABEL org.opencontainers.image.title="Fiscora Qwen3.5 financial-document inference"
LABEL org.opencontainers.image.source="https://huggingface.co/Qwen/Qwen3.5-4B"
LABEL org.opencontainers.image.licenses="Apache-2.0"

# Embed the immutable public model in the image. Cloud Run can therefore start
# from zero without downloading model weights from Hugging Face at runtime.
RUN python3 -c "from huggingface_hub import snapshot_download; snapshot_download(repo_id='${MODEL_ID}', revision='${MODEL_REVISION}', local_dir='/models/qwen3-5-4b')"

COPY start.sh /opt/fiscora/start.sh
RUN chmod 0555 /opt/fiscora/start.sh

ENV MODEL_PATH=/models/qwen3-5-4b \
    MAX_NUM_SEQS=4 \
    PORT=8080 \
    OMP_NUM_THREADS=1 \
    HF_HUB_OFFLINE=1 \
    TRANSFORMERS_OFFLINE=1

EXPOSE 8080
ENTRYPOINT ["/opt/fiscora/start.sh"]
