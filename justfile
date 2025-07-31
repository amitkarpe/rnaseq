#######################################################################
# Tell `just` to load .env automatically – available in every recipe
#######################################################################
set dotenv-load := true          # ← **key line**
set dotenv-filename := ".env"    # (default, but explicit)

#######################################################################
# All commands rely on vars from .env (PIPELINE, BUNDLE_DIR, …)
# No explicit `source .env` lines are needed.
#######################################################################

# 1. Download pipeline code (no container images)
pull:
    mkdir -p "$BUNDLE_DIR" && \
    nf-core pipelines download "$PIPELINE" \
        --revision "$REVISION" \
        --container-system none \
        --compress none \
        --outdir "$BUNDLE_DIR" --force

# 2. Produce JSON list of processes ↔ containers
inspect:
    nextflow inspect "nf-core/$PIPELINE" \
        -r "$REVISION" \
        -profile test,podman \
        -concretize true \
        -format config \
        --outdir /tmp -c custom.config > "$INSPECT_JSON"

# 3. Sanity-check the JSON format
validate-json:
    ls -lh "$INSPECT_JSON"

# 4. Generate proxy config (calls helper script)
gen-proxy-conf:
    ./gen-proxy-conf.sh

# 5. Mirror entire ~/offline → S3 (online side)
push:
    aws s3 sync "$OFFLINE_DIR" "$S3_ROOT"

# 6. Pull mirror inside air-gapped VPC (offline side)
pull-offline:
    aws s3 sync "$S3_ROOT" "$ROOT_DIR/"

# 7. Run the pipeline fully offline
run:
    export NXF_OFFLINE=true && \
    nextflow run "$BUNDLE_DIR/workflow" \
        -profile podman,test2 \
        -c "$PROXY_CONF" \
        -w /tmp/work-rnaseq \
        -offline -resume \
        -r "$REVISION" \
        --input samplesheet.csv --outdir results

