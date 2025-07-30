# ---------------------- USER-EDITABLE VARIABLES ----------------------
PIPELINE        := "rnaseq"
REVISION        := "3_19_0"                       # tag or commit
REGISTRY_PROXY  := "nexus-docker-quay.ship.gov.sg"

HOME_DIR        := env("HOME")
ROOT_DIR        := HOME_DIR + "/offline"          # top-level mirror
BUNDLE_DIR      := ROOT_DIR + "/" + PIPELINE + "/" + REVISION
INSPECT_JSON    := BUNDLE_DIR + "/processes.json"
PROXY_CONF      := BUNDLE_DIR + "/process_with_nexus_proxy.conf"

S3_ROOT         := "s3://lifebit-user-data-nextflow/offline/"  # full mirror
# --------------------------------------------------------------------


# 1️⃣ Download pipeline code + configs (no containers) ─────────────────
#    Uses new CLI: `nf-core pipelines download …` (≥ v3.3). :contentReference[oaicite:0]{index=0}
pull:
    mkdir -p {{BUNDLE_DIR}}
    nf-core pipelines download {{PIPELINE}} \
        --revision {{REVISION}} \
        --container-system none \
        --compress none \
        --outdir {{BUNDLE_DIR}} --force


# 2️⃣ Create JSON list of all processes ↔ images (fast, no run needed) ─
#    Docs: nextflow inspect -format json. :contentReference[oaicite:1]{index=1}
inspect:
    nextflow inspect "nf-core/{{PIPELINE}}" \
        -r "{{REVISION}}" \
        -profile test,docker \
        -concretize true \
        -format json \
        --outdir /tmp > {{INSPECT_JSON}}


# 3️⃣ Quick sanity-check for the JSON structure with jq ───────────────
validate-json:
    jq -e '.processes[0].name and .processes[0].container' {{INSPECT_JSON}}


# 4️⃣ Build proxy-aware Nextflow config (adds Nexus prefix) ───────────
gen-proxy-conf:
    printf 'process {\n' > {{PROXY_CONF}}
    jq -r --arg proxy {{REGISTRY_PROXY}} \
        '.processes[] |
         "    withName: \"" + .name + "\" {\\n" +
         "        container = '\''" + $proxy + "/" + ( .container | sub("^[^/]+/";"") ) + "'\''\\n" +
         "    }"' \
        {{INSPECT_JSON}} >> {{PROXY_CONF}}
    echo '}' >> {{PROXY_CONF}}


# 5️⃣ Sync *everything* under ~/offline → S3 (online box) ──────────────
push:
    aws s3 sync {{ROOT_DIR}}/ {{S3_ROOT}}


# 6️⃣ Pull the mirror down inside the air-gapped VPC ───────────────────
pull-offline:
    aws s3 sync {{S3_ROOT}} {{ROOT_DIR}}/


# 7️⃣ Run the pipeline 100 % offline with Podman images ───────────────
run:
    export NXF_OFFLINE=true
    nextflow run {{BUNDLE_DIR}}/workflow \
        -profile podman,test2 \
        -c {{PROXY_CONF}} \
        -w /tmp/work-rnaseq \
        -offline -resume \
        -r {{REVISION}} \
        --input samplesheet.csv --outdir results

