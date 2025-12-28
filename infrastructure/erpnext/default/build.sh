#!/bin/bash
# Build custom ERPNext image with HRMS and Helpdesk
# Run this once to create the custom image

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="${ERPNEXT_IMAGE:-erpnext-custom}"
IMAGE_TAG="${ERPNEXT_TAG:-v15}"
FRAPPE_VERSION="${FRAPPE_VERSION:-version-15}"

echo "=============================================="
echo "Building Custom ERPNext Image"
echo "=============================================="
echo "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
echo "Apps: ERPNext, HRMS, Helpdesk"
echo "=============================================="

# Check if apps.json exists
if [ ! -f "$SCRIPT_DIR/apps.json" ]; then
    echo "ERROR: apps.json not found"
    exit 1
fi

# Validate apps.json
echo "[1/4] Validating apps.json..."
if command -v jq &> /dev/null; then
    jq empty "$SCRIPT_DIR/apps.json" || { echo "Invalid JSON"; exit 1; }
fi

# Clone frappe_docker if not present
echo "[2/4] Setting up frappe_docker..."
FRAPPE_DOCKER_DIR="/tmp/frappe_docker"
if [ ! -d "$FRAPPE_DOCKER_DIR" ]; then
    git clone --depth 1 https://github.com/frappe/frappe_docker.git "$FRAPPE_DOCKER_DIR"
else
    cd "$FRAPPE_DOCKER_DIR" && git pull
fi

# Copy apps.json
cp "$SCRIPT_DIR/apps.json" "$FRAPPE_DOCKER_DIR/apps.json"

# Encode apps.json for build arg
echo "[3/4] Preparing build..."
export APPS_JSON_BASE64=$(base64 -w 0 "$FRAPPE_DOCKER_DIR/apps.json")

# Build custom image
echo "[4/4] Building image (this takes 10-20 minutes)..."
cd "$FRAPPE_DOCKER_DIR"

docker build \
    --build-arg=FRAPPE_PATH=https://github.com/frappe/frappe \
    --build-arg=FRAPPE_BRANCH=$FRAPPE_VERSION \
    --build-arg=PYTHON_VERSION=3.11.6 \
    --build-arg=NODE_VERSION=18.18.2 \
    --build-arg=APPS_JSON_BASE64=$APPS_JSON_BASE64 \
    --tag=${IMAGE_NAME}:${IMAGE_TAG} \
    --file=images/custom/Containerfile .

echo ""
echo "=============================================="
echo "Build Complete!"
echo "=============================================="
echo "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""
echo "To use this image, update your .env:"
echo "  ERPNEXT_IMAGE=${IMAGE_NAME}"
echo "  ERPNEXT_TAG=${IMAGE_TAG}"
echo ""
echo "Then restart ERPNext:"
echo "  docker compose down"
echo "  docker compose up -d"
echo ""
echo "After restart, install apps on your site:"
echo "  docker exec erpnext-backend bench --site \$SITE_DOMAIN install-app hrms"
echo "  docker exec erpnext-backend bench --site \$SITE_DOMAIN install-app helpdesk"
echo "=============================================="
