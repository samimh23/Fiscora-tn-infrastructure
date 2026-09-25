FROM vllm/vllm-openai:nightly

ARG MODEL_ID=numind/NuExtract-2.0-8B
ARG MODEL_REVISION=a470f0b5dd0b42fa7182cdbe7c6113a232f671e4

LABEL org.opencontainers.image.title="Fiscora NuExtract 2.0 financial-document inference"
LABEL org.opencontainers.image.source="https://huggingface.co/numind/NuExtract-2.0-8B"
LABEL org.opencontainers.image.licenses="MIT"

# Embed an immutable model snapshot so a scale-from-zero instance never needs
# Hugging Face network access at runtime.
RUN python3 -c "from huggingface_hub import snapshot_download; snapshot_download(repo_id='${MODEL_ID}', revision='${MODEL_REVISION}', local_dir='/models/nuextract-2-8b')"

COPY start.sh /opt/fiscora/start.sh
RUN chmod 0555 /opt/fiscora/start.sh

ENV MODEL_PATH=/models/nuextract-2-8b \
    MAX_NUM_SEQS=2 \
    PORT=8080 \
    OMP_NUM_THREADS=1 \
    HF_HUB_OFFLINE=1 \
    TRANSFORMERS_OFFLINE=1

EXPOSE 8080
ENTRYPOINT ["/opt/fiscora/start.sh"]

