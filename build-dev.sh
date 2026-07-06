#!/usr/bin/env bash
# Build a model Docker image using local idmodels and iddata sources.
#
# Usage: ./build-dev.sh <model_dir> [tag]
#
#   model_dir  - subdirectory of this repo containing the model (e.g. covid_ar6_pooled)
#   tag        - Docker image tag (default: <model_dir>:dev-local)
#
# Expects idmodels and iddata repos to be siblings of this repo:
#   ../idmodels
#   ../iddata
set -euo pipefail

MODEL_DIR="${1:?Usage: $0 <model_dir> [tag]}"
TAG="${2:-${MODEL_DIR}:dev-local}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

time docker build --progress=plain \
  --build-arg MODEL_DIR="${MODEL_DIR}" \
  --build-context idmodels="${SCRIPT_DIR}/../idmodels" \
  --build-context iddata="${SCRIPT_DIR}/../iddata" \
  --tag="${TAG}" \
  --file="${SCRIPT_DIR}/Dockerfile.dev" \
  "${SCRIPT_DIR}"
