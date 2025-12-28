#!/bin/bash
# Mail-in-a-Box LXD setup script
# Creates a dedicated LXD container for MIAB with Traefik integration
# Handles all initialization automatically for out-of-box installation

set -e

# Source .env for variables
if [ -f .env ]; then
    source .env
fi

MIAB_HOSTNAME="${MIAB_HOSTNAME:-box.example.com}"
MIAB_EMAIL="${MIAB_EMAIL:-admin@example.com}"
CONTAINER_NAME="${MIAB_CONTAINER_NAME:-mailinabox}"
MIAB_MEMORY="${MIAB_MEMORY:-2GB}"
MIAB_STATIC_IP="${MIAB_STATIC_IP:-10.100.100.10}"
MIAB_NETWORK="${MIAB_NETWORK:-miabbr0}"
MIAB_NETWORK_SUBNET="${MIAB_NETWORK_SUBNET:-10.100.100.0/24}"
MIAB_NETWORK_GATEWAY="${MIAB_NETWORK_GATEWAY:-10.100.100.1}"
TRAEFIK_CONFIG_DIR="${TRAEFIK_CONFIG_DIR:-/opt/infra-services/infrastructure/traefik/default/config}"
INSTALL_LOG="/tmp/miab-install-${CONTAINER_NAME}.log"

echo "=============================================="
echo "Mail-in-a-Box LXD Setup"
echo "=============================================="
echo "Container: $CONTAINER_NAME"
echo "Hostname: $MIAB_HOSTNAME"
echo "Admin email: $MIAB_EMAIL"
echo "Static IP: $MIAB_STATIC_IP"
echo "Install log: $INSTALL_LOG"
echo "=============================================="

# Step 1: Install LXD if not available
echo "[1/9] Checking LXD installation..."
if ! command -v lxc &> /dev/null; then
    echo "Installing LXD..."
    sudo snap install lxd
    sudo usermod -aG lxd $USER
    echo "LXD installed. You may need to log out and back in for group changes."
fi

# Step 2: Initialize LXD with storage pool
echo "[2/9] Initializing LXD..."
if ! sudo lxc storage list 2>/dev/null | grep -q "default"; then
    echo "Creating LXD storage pool..."
    sudo lxd init --auto
fi

# Step 3: Check if container already exists
if sudo lxc info "$CONTAINER_NAME" &> /dev/null; then
    echo "Container $CONTAINER_NAME already exists."
    echo "To recreate, run: sudo lxc delete $CONTAINER_NAME --force"
    exit 1
fi

# Step 4: Create dedicated network for MIAB
echo "[3/9] Setting up LXD network ($MIAB_NETWORK)..."
if ! sudo lxc network show "$MIAB_NETWORK" &> /dev/null; then
    sudo lxc network create "$MIAB_NETWORK" \
        ipv4.address="${MIAB_NETWORK_GATEWAY}/24" \
        ipv4.nat=true \
        ipv6.address=none
fi

# Step 5: Add iptables FORWARD rules for LXD network
echo "[4/9] Configuring iptables for LXD network..."
# Check if rules already exist
if ! sudo iptables -C FORWARD -i "$MIAB_NETWORK" -j ACCEPT 2>/dev/null; then
    sudo iptables -I FORWARD -i "$MIAB_NETWORK" -j ACCEPT
fi
if ! sudo iptables -C FORWARD -o "$MIAB_NETWORK" -j ACCEPT 2>/dev/null; then
    sudo iptables -I FORWARD -o "$MIAB_NETWORK" -j ACCEPT
fi

# Save iptables rules if iptables-persistent is available
if [ -d /etc/iptables ]; then
    sudo iptables-save | sudo tee /etc/iptables/rules.v4 > /dev/null
    echo "iptables rules saved"
fi

# Step 6: Create LXD container with static IP
echo "[5/9] Creating LXD container..."
sudo lxc launch ubuntu:22.04 "$CONTAINER_NAME" \
    -c limits.memory="$MIAB_MEMORY" \
    -c security.nesting=true

echo "Waiting for container to initialize..."
sleep 5

# Attach to our network with static IP
sudo lxc config device remove "$CONTAINER_NAME" eth0 2>/dev/null || true
sudo lxc config device add "$CONTAINER_NAME" eth0 nic \
    network="$MIAB_NETWORK" \
    ipv4.address="$MIAB_STATIC_IP"

# Restart to apply network config
sudo lxc restart "$CONTAINER_NAME"
echo "Waiting for container to restart..."
sleep 10

# Verify IP assignment
ACTUAL_IP=$(sudo lxc list "$CONTAINER_NAME" -c 4 --format csv | cut -d' ' -f1)
echo "Container IP: $ACTUAL_IP"

# Create .lxd marker file for infra-cli to detect LXD-based stack
echo "$CONTAINER_NAME" > .lxd
echo "Created .lxd marker file"

# Step 7: Configure port proxies for mail ports (Traefik handles 80/443)
echo "[6/9] Configuring mail port proxies..."
sudo lxc config device add "$CONTAINER_NAME" smtp proxy \
    listen=tcp:0.0.0.0:25 connect=tcp:${MIAB_STATIC_IP}:25 2>/dev/null || true
sudo lxc config device add "$CONTAINER_NAME" smtps proxy \
    listen=tcp:0.0.0.0:465 connect=tcp:${MIAB_STATIC_IP}:465 2>/dev/null || true
sudo lxc config device add "$CONTAINER_NAME" submission proxy \
    listen=tcp:0.0.0.0:587 connect=tcp:${MIAB_STATIC_IP}:587 2>/dev/null || true
sudo lxc config device add "$CONTAINER_NAME" imaps proxy \
    listen=tcp:0.0.0.0:993 connect=tcp:${MIAB_STATIC_IP}:993 2>/dev/null || true

# Step 8: Install Mail-in-a-Box inside container
echo "[7/9] Installing Mail-in-a-Box (this takes 10-15 minutes)..."
echo "Progress: $INSTALL_LOG"

# Create fstab (MIAB checks for it)
sudo lxc exec "$CONTAINER_NAME" -- touch /etc/fstab

# Set hostname
sudo lxc exec "$CONTAINER_NAME" -- hostnamectl set-hostname "$MIAB_HOSTNAME"

# Get public IP
PUBLIC_IP=$(curl -4 -s icanhazip.com)

# Create install script inside container
sudo lxc exec "$CONTAINER_NAME" -- bash -c "cat > /root/install-miab.sh << 'INSTALLSCRIPT'
#!/bin/bash
set -e

export NONINTERACTIVE=1
export PRIMARY_HOSTNAME=$MIAB_HOSTNAME
export EMAIL_ADDR=$MIAB_EMAIL
export PUBLIC_IP=$PUBLIC_IP
export PUBLIC_IPV6=\"\"
export SKIP_NETWORK_CHECKS=1

echo \"Starting Mail-in-a-Box installation...\"
echo \"Hostname: \$PRIMARY_HOSTNAME\"
echo \"Public IP: \$PUBLIC_IP\"

# Download and run MIAB setup
cd /root
curl -s https://mailinabox.email/setup.sh -o setup.sh
chmod +x setup.sh
bash setup.sh

echo \"MIAB installation completed!\"
INSTALLSCRIPT
chmod +x /root/install-miab.sh"

# Run installation in background
sudo lxc exec "$CONTAINER_NAME" -- bash -c "nohup /root/install-miab.sh > /var/log/miab-install.log 2>&1 &"

echo "Installation started in background..."
echo "Monitoring progress..."

# Wait for installation with progress updates
TIMEOUT=900  # 15 minutes
ELAPSED=0
INTERVAL=30

while [ $ELAPSED -lt $TIMEOUT ]; do
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))

    # Check if install script is still running
    if ! sudo lxc exec "$CONTAINER_NAME" -- pgrep -f "install-miab.sh" > /dev/null 2>&1; then
        echo "Installation script finished."
        break
    fi

    # Show last line of progress
    LAST_LINE=$(sudo lxc exec "$CONTAINER_NAME" -- tail -1 /var/log/miab-install.log 2>/dev/null || echo "...")
    echo "[$ELAPSED s] $LAST_LINE"
done

# Copy install log to host
sudo lxc exec "$CONTAINER_NAME" -- cat /var/log/miab-install.log > "$INSTALL_LOG" 2>/dev/null || true

# Check if installation succeeded
if sudo lxc exec "$CONTAINER_NAME" -- test -f /root/mailinabox/tools/web_update; then
    echo "MIAB files installed successfully."
else
    echo "ERROR: MIAB installation may have failed. Check $INSTALL_LOG"
    exit 1
fi

# Step 9: Start services and configure web
echo "[8/9] Starting services..."

# Create startup script for MIAB services (runs on container boot)
sudo lxc exec "$CONTAINER_NAME" -- bash -c 'cat > /usr/local/bin/miab-start.sh << "STARTSCRIPT"
#!/bin/bash
# MIAB startup script - runs on container boot
# Needed because systemd does not work properly in LXD

sleep 5  # Wait for network

# Start management daemon if not running
if ! pgrep -f "gunicorn.*wsgi:app" > /dev/null; then
    source /usr/local/lib/mailinabox/env/bin/activate
    mkdir -p /var/lib/mailinabox
    if [ ! -f /var/lib/mailinabox/api.key ]; then
        tr -cd "[:xdigit:]" < /dev/urandom | head -c 32 > /var/lib/mailinabox/api.key
        chmod 640 /var/lib/mailinabox/api.key
    fi
    export PYTHONPATH=/root/mailinabox/management
    cd /root/mailinabox/management
    nohup gunicorn -b localhost:10222 -w 1 --timeout 630 wsgi:app >> /var/log/mailinabox-daemon.log 2>&1 &
fi

# Ensure nginx is running
service nginx start 2>/dev/null || true

# Ensure postfix is running
service postfix start 2>/dev/null || true

# Ensure dovecot is running
service dovecot start 2>/dev/null || true
STARTSCRIPT
chmod +x /usr/local/bin/miab-start.sh'

# Add to cron @reboot for persistence across container restarts
sudo lxc exec "$CONTAINER_NAME" -- bash -c '
(crontab -l 2>/dev/null | grep -v miab-start; echo "@reboot /usr/local/bin/miab-start.sh") | crontab -
'

# Run the startup script now
sudo lxc exec "$CONTAINER_NAME" -- /usr/local/bin/miab-start.sh

sleep 5

# Run web_update to configure nginx
echo "Configuring web server..."
sudo lxc exec "$CONTAINER_NAME" -- bash -c 'cd /root/mailinabox && tools/web_update' || true

# Verify services are running
echo "Verifying services..."
NGINX_OK=$(sudo lxc exec "$CONTAINER_NAME" -- ss -tlnp | grep -c ":443" || echo "0")
POSTFIX_OK=$(sudo lxc exec "$CONTAINER_NAME" -- ss -tlnp | grep -c ":25" || echo "0")
DOVECOT_OK=$(sudo lxc exec "$CONTAINER_NAME" -- ss -tlnp | grep -c ":993" || echo "0")

if [ "$NGINX_OK" -gt 0 ] && [ "$POSTFIX_OK" -gt 0 ] && [ "$DOVECOT_OK" -gt 0 ]; then
    echo "All services running!"
else
    echo "WARNING: Some services may not be running. Check manually."
fi

# Step 10: Create Traefik config
echo "[9/9] Creating Traefik configuration..."
if [ -d "$TRAEFIK_CONFIG_DIR" ]; then
    sudo tee "$TRAEFIK_CONFIG_DIR/mailinabox.yml" > /dev/null << TRAEFIKEOF
# Mail-in-a-Box Traefik routing
# Auto-generated by MIAB setup script

http:
  routers:
    mailinabox:
      rule: "Host(\`${MIAB_HOSTNAME}\`)"
      entryPoints:
        - websecure
      service: mailinabox
      tls:
        certResolver: letsencrypt

  services:
    mailinabox:
      loadBalancer:
        servers:
          - url: "https://mailinabox"
        serversTransport: miab-transport

  serversTransports:
    miab-transport:
      insecureSkipVerify: true
TRAEFIKEOF
    sudo chown root:root "$TRAEFIK_CONFIG_DIR/mailinabox.yml"
    sudo chmod 644 "$TRAEFIK_CONFIG_DIR/mailinabox.yml"
    echo "Traefik config created: $TRAEFIK_CONFIG_DIR/mailinabox.yml"
else
    echo "WARNING: Traefik config directory not found at $TRAEFIK_CONFIG_DIR"
    echo "You'll need to manually configure Traefik to route to $MIAB_STATIC_IP"
fi

# Final summary
echo ""
echo "=============================================="
echo "Mail-in-a-Box Installation Complete!"
echo "=============================================="
echo ""
echo "Container: $CONTAINER_NAME"
echo "Container IP: $MIAB_STATIC_IP"
echo "Public IP: $PUBLIC_IP"
echo ""
echo "Access (via Traefik):"
echo "  Admin panel: https://$MIAB_HOSTNAME/admin"
echo "  Webmail: https://$MIAB_HOSTNAME/mail"
echo ""
echo "Required DNS records (point to $PUBLIC_IP):"
echo "  A     $MIAB_HOSTNAME -> $PUBLIC_IP"
echo "  MX    @ -> $MIAB_HOSTNAME"
echo "  (See admin panel for SPF, DKIM, DMARC records)"
echo ""
echo "Mail ports proxied to host:"
echo "  25   - SMTP"
echo "  465  - SMTPS"
echo "  587  - Submission"
echo "  993  - IMAPS"
echo ""
echo "Container management:"
echo "  sudo lxc exec $CONTAINER_NAME -- bash    # Shell access"
echo "  sudo lxc stop $CONTAINER_NAME            # Stop"
echo "  sudo lxc start $CONTAINER_NAME           # Start"
echo "  sudo lxc delete $CONTAINER_NAME --force  # Remove"
echo ""
echo "To create admin user, run:"
echo "  sudo lxc exec $CONTAINER_NAME -- mailinabox"
echo ""
echo "Install log: $INSTALL_LOG"
echo "=============================================="
