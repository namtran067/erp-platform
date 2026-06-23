#!/usr/bin/env bash
# ============================================================================
# Build the custom production image the OFFICIAL way: using frappe_docker's
# multi-stage Containerfile (images/custom/Containerfile) with our prod/apps.json
# passed in as a build secret.
#
# Why this way (instead of a hand-written Dockerfile):
#   frappe_docker's Containerfile COPYs files from resources/ (nginx templates,
#   entrypoints, security headers, ...), so the build context MUST be a
#   frappe_docker checkout. We clone it into prod/frappe_docker/ (gitignored) on
#   demand and reuse its build logic — no duplication, easy upstream updates.
#
# Output image: ${IMAGE}:${TAG}  (default my-erpnext:v16-custom)
#
# NOTE: --secret requires BuildKit (DOCKER_BUILDKIT=1, set below). The host's
# `docker buildx` plugin is broken, but the classic builder's BuildKit mode is
# enough for --secret.
# ============================================================================
set -euo pipefail

IMAGE="${IMAGE:-my-erpnext}"
TAG="${TAG:-v16-custom}"
# Match the dev submodules: frappe comes from your fork on version-16.
FRAPPE_REPO="${FRAPPE_REPO:-https://github.com/namtran067/frappe.git}"
FRAPPE_BRANCH="${FRAPPE_BRANCH:-version-16}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROD_DIR="$ROOT/prod"
FD_DIR="$PROD_DIR/frappe_docker"
APPS_JSON="$PROD_DIR/apps.json"

if [ ! -f "$APPS_JSON" ]; then
  echo "ERROR: $APPS_JSON not found. Create it first (see prod/apps.json)." >&2
  exit 1
fi

echo "==> Ensuring frappe_docker is present at ${FD_DIR} ..."
if [ -d "$FD_DIR/.git" ]; then
  git -C "$FD_DIR" pull --ff-only
else
  rm -rf "$FD_DIR"
  git clone --depth 1 https://github.com/frappe/frappe_docker.git "$FD_DIR"
fi

echo "==> Building image ${IMAGE}:${TAG}  (frappe=${FRAPPE_REPO}@${FRAPPE_BRANCH}) ..."
cd "$FD_DIR"
DOCKER_BUILDKIT=1 docker build \
  -f images/custom/Containerfile \
  --secret id=apps_json,src="$APPS_JSON" \
  --build-arg FRAPPE_PATH="$FRAPPE_REPO" \
  --build-arg FRAPPE_BRANCH="$FRAPPE_BRANCH" \
  -t "${IMAGE}:${TAG}" \
  .

cat <<EOF

==> DONE. Image: ${IMAGE}:${TAG}

  Deploy with:
    make prod-up
  (prod/.env sets CUSTOM_IMAGE=${IMAGE} CUSTOM_TAG=${TAG})
EOF
