#!/bin/bash
# ERPNext Site Creation Script
# Run this after docker compose up -d

set -e

# Source .env for variables
if [ -f .env ]; then
    source .env
fi

SITE_DOMAIN="${SITE_DOMAIN:-erp.example.com}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:-changeme}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"

echo "=============================================="
echo "ERPNext Site Setup"
echo "=============================================="
echo "Site: $SITE_DOMAIN"
echo "=============================================="

# Wait for services to be ready
echo "[1/4] Waiting for services to be ready..."
sleep 10

# Check if backend is running
if ! docker ps | grep -q erpnext-backend; then
    echo "ERROR: ERPNext backend is not running."
    echo "Run 'docker compose up -d' first."
    exit 1
fi

# Wait for configurator to complete
echo "[2/4] Waiting for configurator..."
TIMEOUT=120
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    STATUS=$(docker inspect erpnext-configurator --format='{{.State.Status}}' 2>/dev/null || echo "not found")
    if [ "$STATUS" = "exited" ]; then
        EXIT_CODE=$(docker inspect erpnext-configurator --format='{{.State.ExitCode}}' 2>/dev/null || echo "1")
        if [ "$EXIT_CODE" = "0" ]; then
            echo "Configurator completed successfully."
            break
        else
            echo "ERROR: Configurator failed with exit code $EXIT_CODE"
            docker logs erpnext-configurator
            exit 1
        fi
    fi
    sleep 5
    ELAPSED=$((ELAPSED + 5))
    echo "  Waiting... ($ELAPSED s)"
done

# Check if site already exists
echo "[3/4] Checking for existing site..."
SITE_EXISTS=$(docker exec erpnext-backend bench --site $SITE_DOMAIN list-apps 2>/dev/null && echo "yes" || echo "no")

if [ "$SITE_EXISTS" = "yes" ]; then
    echo "Site $SITE_DOMAIN already exists."
    echo "To recreate, run: docker exec erpnext-backend bench drop-site $SITE_DOMAIN --force"
    exit 0
fi

# Create new site
echo "[4/4] Creating ERPNext site (this takes 2-5 minutes)..."
docker exec -e SITE_DOMAIN="$SITE_DOMAIN" erpnext-backend bench new-site "$SITE_DOMAIN" \
    --mariadb-root-password "$DB_ROOT_PASSWORD" \
    --admin-password "$ADMIN_PASSWORD" \
    --install-app erpnext

# Set as default site
docker exec erpnext-backend bench use "$SITE_DOMAIN"

echo ""
echo "=============================================="
echo "ERPNext Installation Complete!"
echo "=============================================="
echo ""
echo "Site: https://$SITE_DOMAIN"
echo "Username: Administrator"
echo "Password: $ADMIN_PASSWORD"
echo ""
echo "Note: If using Traefik, ensure DNS points to this server"
echo "      and wait for SSL certificate provisioning."
echo "=============================================="
