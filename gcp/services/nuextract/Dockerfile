FROM vllm/vllm-openai:v0.22.1

ARG MODEL_ID=numind/NuExtract3
ARG MODEL_REVISION=main

LABEL org.opencontainers.image.title="Fiscora NuExtract3 inference"
LABEL org.opencontainers.image.source="https://github.com/numindai/nuextract"
LABEL org.opencontainers.image.licenses="Apache-2.0"

# Embed the public model to avoid a multi-gigabyte Hugging Face download on
# every scale-from-zero cold start. Pin MODEL_REVISION to a commit during build.
RUN python3 -c "from huggingface_hub import snapshot_download; snapshot_download(repo_id='${MODEL_ID}', revision='${MODEL_REVISION}', local_dir='/models/nuextract3')"

COPY start.sh /opt/fiscora/start.sh
RUN chmod 0555 /opt/fiscora/start.sh

ENV MODEL_PATH=/models/nuextract3 \
    MAX_NUM_SEQS=32 \
    PORT=8080 \
    HF_HUB_OFFLINE=1 \
    TRANSFORMERS_OFFLINE=1

EXPOSE 8080
ENTRYPOINT ["/opt/fiscora/start.sh"]
