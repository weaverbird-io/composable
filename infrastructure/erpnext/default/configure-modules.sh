#!/bin/bash
# Configure ERPNext modules after installation
# Run this after setup.sh to install and configure HRMS and Helpdesk

set -e

# Source .env for variables
if [ -f .env ]; then
    source .env
fi

SITE_DOMAIN="${SITE_DOMAIN:-erp.example.com}"

echo "=============================================="
echo "ERPNext Module Configuration"
echo "=============================================="
echo "Site: $SITE_DOMAIN"
echo "=============================================="

# Check if site exists
echo "[1/5] Checking site..."
if ! docker exec erpnext-backend bench --site "$SITE_DOMAIN" list-apps &>/dev/null; then
    echo "ERROR: Site $SITE_DOMAIN not found. Run setup.sh first."
    exit 1
fi

# List currently installed apps
echo "Currently installed apps:"
docker exec erpnext-backend bench --site "$SITE_DOMAIN" list-apps

# Install HRMS
echo ""
echo "[2/5] Installing HRMS (Human Resources)..."
if docker exec erpnext-backend bench --site "$SITE_DOMAIN" list-apps | grep -q "hrms"; then
    echo "HRMS already installed"
else
    docker exec erpnext-backend bench --site "$SITE_DOMAIN" install-app hrms || {
        echo "WARNING: HRMS installation failed. Make sure you built the custom image with HRMS."
        echo "Run: ./build.sh"
    }
fi

# Install Helpdesk
echo ""
echo "[3/5] Installing Helpdesk..."
if docker exec erpnext-backend bench --site "$SITE_DOMAIN" list-apps | grep -q "helpdesk"; then
    echo "Helpdesk already installed"
else
    docker exec erpnext-backend bench --site "$SITE_DOMAIN" install-app helpdesk || {
        echo "WARNING: Helpdesk installation failed. Make sure you built the custom image with Helpdesk."
        echo "Run: ./build.sh"
    }
fi

# Clear cache
echo ""
echo "[4/5] Clearing cache..."
docker exec erpnext-backend bench --site "$SITE_DOMAIN" clear-cache

# Migrate
echo ""
echo "[5/5] Running migrations..."
docker exec erpnext-backend bench --site "$SITE_DOMAIN" migrate

echo ""
echo "=============================================="
echo "Module Configuration Complete!"
echo "=============================================="
echo ""
echo "Installed apps:"
docker exec erpnext-backend bench --site "$SITE_DOMAIN" list-apps
echo ""
echo "Access your ERPNext at: https://$SITE_DOMAIN"
echo ""
echo "Setup guides:"
echo "  HR Module: Setup > HR Settings"
echo "  Helpdesk: Setup > Support Settings"
echo "  Inventory: Stock > Stock Settings"
echo ""
echo "Stock/Inventory is built into ERPNext core."
echo "=============================================="
