# ---------- justfile ----------
# Variables ---------------------------------------------------------
PIPELINE      := "rnaseq"
REVISION      := "3.19.0"

HOME_DIR      := env("HOME")
BUNDLE_DIR    := HOME_DIR + "/bundles/nfcore-" + PIPELINE + "_" + REVISION
CACHE_DIR     := BUNDLE_DIR + "/containers"
S3_URI        := "s3://lifebit-user-data-nextflow/nfcore/" + PIPELINE + "/" + REVISION

# Recipes -----------------------------------------------------------
pull:
    mkdir -p {{BUNDLE_DIR}}
    nf-core pipelines download {{PIPELINE}} \
        --revision {{REVISION}} \
        --container-system none \
        --compress none \
        --outdir {{BUNDLE_DIR}} \
        --force

push:
    aws s3 sync {{BUNDLE_DIR}} {{S3_URI}}

pull-offline:
    aws s3 sync {{S3_URI}} {{BUNDLE_DIR}}

load-containers:
    for t in {{CACHE_DIR}}/*.tar; do podman load -i "$$t"; done

run:
    export NXF_OFFLINE=true
    nextflow run {{BUNDLE_DIR}}/workflow \
        -profile docker -r {{REVISION}} \
        --input samplesheet.csv --outdir results \
        -with-trace -with-report -resume
# -------------------------------------------------------------------

