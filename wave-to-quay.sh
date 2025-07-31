#!/usr/bin/env bash
# ----------------------------------------------------------------------
# Copy community.wave.seqera.io images → quay.io/trustsg/...
# Does NOT try to create or flip repo visibility.
# ----------------------------------------------------------------------
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 0. pick up QUAY_USER / QUAY_TOKEN / TAG_LATEST from ~/.env
[[ -f "${HOME}/.env" ]] && source "${HOME}/.env"
: "${QUAY_USER:?Need QUAY_USER in env}"
: "${QUAY_TOKEN:?Need QUAY_TOKEN in env}"

CFG="${1:-conf/containers.local.config}"
[[ -f "${CFG}" ]] || { echo "❌ ${CFG} not found"; exit 1; }

SRC_PREFIX='community.wave.seqera.io/library/'
DST_PREFIX='quay.io/trustsg/'

mapfile -t WAVES < <(
  grep -oE "${SRC_PREFIX}[[:alnum:]_./:-]+" "$CFG" | sort -u
)

[[ ${#WAVES[@]} -eq 0 ]] && { echo "✔︎ No Wave images found"; exit 0; }
echo "🛈  ${#WAVES[@]} Wave images to process"

for SRC in "${WAVES[@]}"; do
  REPO_TAG="${SRC#$SRC_PREFIX}"          # e.g. fastp:sha
  DST="${DST_PREFIX}${REPO_TAG}"

  # Skip if tag exists on Quay
  if docker run --rm quay.io/skopeo/stable \
       inspect --creds "${QUAY_USER}:${QUAY_TOKEN}" \
       "docker://${DST}" >/dev/null 2>&1; then
       echo "✅  Tag exists   $DST"
       continue
  fi

  echo "⏩  Copying  $SRC  →  $DST"
  if docker run --rm \
        -v ~/.docker:/root/.docker \
        quay.io/skopeo/stable copy \
          --dest-creds "${QUAY_USER}:${QUAY_TOKEN}" \
          "docker://${SRC}" "docker://${DST}"
  then
      echo "✔︎  Copied  $DST"
      # Optional :latest tag
      if [[ "${TAG_LATEST:-false}" == "true" ]]; then
          LATEST_DST="${DST%%:*}:latest"
          docker run --rm \
            -v ~/.docker:/root/.docker \
            quay.io/skopeo/stable copy \
              --dest-creds "${QUAY_USER}:${QUAY_TOKEN}" \
              "docker://${DST}" "docker://${LATEST_DST}"
      fi
  else
      echo "✗  Copy failed for $DST (repo may need to be created manually)"
  fi
done

echo "🎉  Copy phase complete."

