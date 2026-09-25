FROM vllm/vllm-openai:nightly

ARG MODEL_ID=numind/NuExtract3
ARG MODEL_REVISION=c99dc8f5641b866aa0192b6ea78f84bf9f3535f1

LABEL org.opencontainers.image.title="Fiscora NuExtract3 financial-document inference"
LABEL org.opencontainers.image.source="https://huggingface.co/numind/NuExtract3"
LABEL org.opencontainers.image.licenses="Apache-2.0"

# Embed an immutable model snapshot so a scale-from-zero instance never needs
# Hugging Face network access at runtime.
RUN python3 -c "from huggingface_hub import snapshot_download; snapshot_download(repo_id='${MODEL_ID}', revision='${MODEL_REVISION}', local_dir='/models/nuextract3')"

COPY start.sh /opt/fiscora/start.sh
RUN chmod 0555 /opt/fiscora/start.sh

ENV MODEL_PATH=/models/nuextract3 \
    MAX_NUM_SEQS=2 \
    PORT=8080 \
    OMP_NUM_THREADS=1 \
    HF_HUB_OFFLINE=1 \
    TRANSFORMERS_OFFLINE=1

EXPOSE 8080
ENTRYPOINT ["/opt/fiscora/start.sh"]
