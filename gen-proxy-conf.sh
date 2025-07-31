#!/usr/bin/env bash
# ----------------------------------------------------------------------
# Build a Nextflow config that:
#   * leaves already-proxied images untouched
#   * rewrites Wave images
#       community.wave.seqera.io/library/<img>:<tag>
#     → nexus-docker-quay.ship.gov.sg/trustsg/<img>:<tag>
# ----------------------------------------------------------------------
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# Load minimal vars
source "${SCRIPT_DIR}/.env"

OFFLINE_DIR="${HOME}/offline"
BUNDLE_DIR="${OFFLINE_DIR}/${PIPELINE}/${REVISION}"
INSPECT_JSON="${BUNDLE_DIR}/processes.json"
PROXY_CONF="${BUNDLE_DIR}/process_with_nexus_proxy.conf"

[[ -f "${INSPECT_JSON}" ]] || { echo "❌ ${INSPECT_JSON} not found"; exit 1; }

mkdir -p "$(dirname "${PROXY_CONF}")"

{
  echo 'process {'
  jq -r \
    --arg proxy "${REGISTRY_PROXY}" \
    '.processes[] | 
      .container as $raw |
      ( if $raw | startswith("community.wave.seqera.io/library/") then
            $raw
            | sub("^community\\.wave\\.seqera\\.io/library/"; ($proxy + "/trustsg/"))
        elif $raw | startswith($proxy) then
            # already rewritten by podman.registry – keep as is
            $raw
        else
            # replace leading registry domain with proxy
            $raw | sub("^[^/]+/"; ($proxy + "/"))
        end ) as $final |
      "    withName: \"" + .name + "\" {\\n" +
      "        container = \"" + $final + "\"\\n" +
      "    }"' \
    "${INSPECT_JSON}"
  echo '}'
} > "${PROXY_CONF}"

echo "✔︎ Wrote ${PROXY_CONF}"

