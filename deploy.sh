#!/usr/bin/env bash
# deploy.sh — build, push, and update AWS task definitions for operational models.
#
# Usage:
#   ./deploy.sh [--dry-run] [model_dir ...]
#
# Environment variables:
#   AWS credentials       — honoured automatically: AWS_PROFILE, or
#                           AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY + AWS_DEFAULT_REGION
#
# Examples:
#   ./deploy.sh                          # deploy all five models
#   ./deploy.sh flu_ar2 flu_flusion      # deploy only those two
#   ./deploy.sh --dry-run                # preview all five without writing anything

set -euo pipefail

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
readonly DOCKER_ORG="reichlab"
readonly AWS_REGION="us-east-1"
readonly ALL_MODELS=(covid_ar6_pooled covid_gbqr flu_ar2 flu_flusion flu_trends_ensemble temp)

# Map model_dir  →  ECS task-definition family name
task_def_name() {
  local model="$1"
  # Replace underscores with hyphens and append -model
  echo "${model//_/-}-model"
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
DRY_RUN=false
MODELS=()

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --*)       echo "Unknown flag: $arg" >&2; exit 1 ;;
    *)         MODELS+=("$arg") ;;
  esac
done

if [[ ${#MODELS[@]} -eq 0 ]]; then
  MODELS=("${ALL_MODELS[@]}")
fi

for model in "${MODELS[@]}"; do
  valid=false
  for m in "${ALL_MODELS[@]}"; do
    [[ "${model}" == "${m}" ]] && valid=true && break
  done
  if ! $valid; then
    echo "Unknown model: ${model}. Valid models: ${ALL_MODELS[*]}" >&2
    exit 1
  fi
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log() { echo "[deploy] $*"; }

# run CMD [ARGS…]
# In dry-run mode: print the command but skip it.
# In live mode:    run it.
run() {
  if $DRY_RUN; then
    echo "  [dry-run] $(printf '%q ' "$@")"
  else
    "$@"
  fi
}

# ---------------------------------------------------------------------------
# Step 0: docker login (always, even in dry-run — read-only auth is fine)
# ---------------------------------------------------------------------------
log "Logging in to Docker Hub …"
docker login

# ---------------------------------------------------------------------------
# Step 1: Compute new image tags (fetch current tags from Docker Hub API)
# ---------------------------------------------------------------------------
log "Computing new image tags …"

declare -A NEW_TAG   # model → new version string (e.g. "1.6")

for model in "${MODELS[@]}"; do
  # Docker Hub API returns tags sorted by last_updated desc for public repos.
  # We grab all numeric tags, sort them, and take the highest.
  current_version=$(
    curl -fsSL \
      "https://hub.docker.com/v2/repositories/${DOCKER_ORG}/${model}/tags/?ordering=last_updated&page_size=25" \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
tags = [r['name'] for r in data.get('results', [])]
# Keep only tags matching major.minor pattern
import re
numeric = [t for t in tags if re.fullmatch(r'[0-9]+\.[0-9]+', t)]
if not numeric:
    raise SystemExit('No numeric tags found for ${model}')
# Sort by (major, minor) numerically
numeric.sort(key=lambda t: tuple(int(x) for x in t.split('.')))
print(numeric[-1])
"
  )

  # Increment the minor (point) version
  major="${current_version%%.*}"
  minor="${current_version##*.}"
  new_minor=$(( minor + 1 ))
  NEW_TAG[$model]="${major}.${new_minor}"

  log "  ${model}: ${current_version} → ${NEW_TAG[$model]}"
done

if $DRY_RUN; then
  log ""
  log "=== DRY-RUN MODE: the following commands would be executed ==="
  log ""
fi


# ---------------------------------------------------------------------------
# Steps 2 & 3: Build then push each image
# ---------------------------------------------------------------------------
for model in "${MODELS[@]}"; do
  full_tag="${DOCKER_ORG}/${model}:${NEW_TAG[$model]}"

  log "--- Building ${full_tag} ---"
  run docker build --progress=plain \
    --build-arg "MODEL_DIR=${model}" \
    --platform=linux/amd64 \
    --tag="${full_tag}" \
    --file=Dockerfile \
    .

  log "--- Pushing ${full_tag} ---"
  run docker push "${full_tag}"
done

# ---------------------------------------------------------------------------
# Step 4: Update AWS ECS task definitions
# ---------------------------------------------------------------------------
for model in "${MODELS[@]}"; do
  full_tag="${DOCKER_ORG}/${model}:${NEW_TAG[$model]}"
  family="$(task_def_name "${model}")"

  log "--- Updating ECS task definition: ${family} ---"

  # Fetch current task definition and strip read-only fields AWS won't accept.
  # Note: this runs even in dry-run mode (read-only), so AWS credentials are required.
  new_def=$(
    aws ecs describe-task-definition \
      --region "${AWS_REGION}" \
      --task-definition "${family}" \
      --query taskDefinition \
      --output json \
    | python3 -c "
import sys, json
td = json.load(sys.stdin)
# Remove fields that are not accepted by register-task-definition
for field in ('taskDefinitionArn','revision','status','requiresAttributes',
              'compatibilities','registeredAt','registeredBy'):
    td.pop(field, None)
# Update the image in the first container definition
td['containerDefinitions'][0]['image'] = \"${full_tag}\"
print(json.dumps(td))
"
  )

  if $DRY_RUN; then
    echo "  [dry-run] aws ecs register-task-definition --region ${AWS_REGION} --cli-input-json '${new_def}'"
  else
    new_revision=$(
      aws ecs register-task-definition \
        --region "${AWS_REGION}" \
        --cli-input-json "${new_def}" \
        --query 'taskDefinition.{family:family,revision:revision}' \
        --output text \
      | awk '{print $1 ":" $2}'
    )
    log "  Registered new revision: ${new_revision}"
  fi
done

log ""
log "Deployment complete for: ${MODELS[*]}"
