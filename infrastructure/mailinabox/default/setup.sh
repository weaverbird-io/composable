#!/bin/bash
# Mail-in-a-Box LXD setup script
# Creates a dedicated LXD container for MIAB with Traefik integration

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
TRAEFIK_CONFIG_DIR="${TRAEFIK_CONFIG_DIR:-/opt/infra-services/infrastructure/traefik/default/config}"

echo "Setting up Mail-in-a-Box in LXD container: $CONTAINER_NAME"
echo "Hostname: $MIAB_HOSTNAME"
echo "Admin email: $MIAB_EMAIL"
echo "Static IP: $MIAB_STATIC_IP"

# Check if LXD is available
if ! command -v lxc &> /dev/null; then
    echo "LXD is not installed. Installing..."
    sudo snap install lxd
    sudo lxd init --auto
    sudo usermod -aG lxd $USER
    echo "Please log out and back in, then run this script again."
    exit 1
fi

# Check if container already exists
if lxc info "$CONTAINER_NAME" &> /dev/null; then
    echo "Container $CONTAINER_NAME already exists."
    echo "To recreate, run: lxc delete $CONTAINER_NAME --force"
    exit 1
fi

# Create a dedicated network for MIAB with static IP support
echo "Setting up LXD network..."
if ! lxc network show miabbr0 &> /dev/null; then
    lxc network create miabbr0 ipv4.address=10.100.100.1/24 ipv4.nat=true ipv6.address=none
fi

echo "Creating LXD container..."
lxc launch ubuntu:22.04 "$CONTAINER_NAME" \
    -c limits.memory="$MIAB_MEMORY" \
    -c security.nesting=true \
    -n miabbr0

# Assign static IP to container
echo "Assigning static IP $MIAB_STATIC_IP..."
lxc config device override "$CONTAINER_NAME" eth0 ipv4.address="$MIAB_STATIC_IP"

echo "Waiting for container to start..."
sleep 10

# Restart to apply static IP
lxc restart "$CONTAINER_NAME"
sleep 5

# Configure port proxies for MAIL PORTS ONLY (Traefik handles HTTP/HTTPS)
echo "Configuring mail port proxies..."
lxc config device add "$CONTAINER_NAME" smtp proxy listen=tcp:0.0.0.0:25 connect=tcp:${MIAB_STATIC_IP}:25 || true
lxc config device add "$CONTAINER_NAME" smtps proxy listen=tcp:0.0.0.0:465 connect=tcp:${MIAB_STATIC_IP}:465 || true
lxc config device add "$CONTAINER_NAME" submission proxy listen=tcp:0.0.0.0:587 connect=tcp:${MIAB_STATIC_IP}:587 || true
lxc config device add "$CONTAINER_NAME" imaps proxy listen=tcp:0.0.0.0:993 connect=tcp:${MIAB_STATIC_IP}:993 || true

# DNS ports - only if you want MIAB to handle DNS (optional, usually external DNS is used)
# lxc config device add "$CONTAINER_NAME" dns-tcp proxy listen=tcp:0.0.0.0:53 connect=tcp:${MIAB_STATIC_IP}:53 || true
# lxc config device add "$CONTAINER_NAME" dns-udp proxy listen=udp:0.0.0.0:53 connect=udp:${MIAB_STATIC_IP}:53 || true

# Set hostname inside container
lxc exec "$CONTAINER_NAME" -- hostnamectl set-hostname "$MIAB_HOSTNAME"

# Install Mail-in-a-Box
echo "Installing Mail-in-a-Box inside container (this takes 10-15 minutes)..."
lxc exec "$CONTAINER_NAME" -- bash -c "
    export NONINTERACTIVE=1
    export PRIMARY_HOSTNAME=$MIAB_HOSTNAME
    export PUBLIC_IP=\$(curl -4 -s icanhazip.com)
    export PUBLIC_IPV6=\$(curl -6 -s icanhazip.com 2>/dev/null || echo '')
    export SKIP_NETWORK_CHECKS=1

    curl -s https://mailinabox.email/setup.sh | sudo bash
"

# Create Traefik dynamic config for MIAB routing
echo "Creating Traefik configuration..."
if [ -d "$TRAEFIK_CONFIG_DIR" ]; then
    cat > /tmp/miab-traefik.yml << TRAEFIK_EOF
# Mail-in-a-Box Traefik routing
# Routes web traffic to LXD container, Traefik handles TLS termination

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
      insecureSkipVerify: true  # MIAB has self-signed cert internally
TRAEFIK_EOF
    sudo mv /tmp/miab-traefik.yml "$TRAEFIK_CONFIG_DIR/mailinabox.yml"
    sudo chown root:root "$TRAEFIK_CONFIG_DIR/mailinabox.yml"
    sudo chmod 644 "$TRAEFIK_CONFIG_DIR/mailinabox.yml"
    echo "Traefik config created at $TRAEFIK_CONFIG_DIR/mailinabox.yml"
else
    echo "WARNING: Traefik config directory not found at $TRAEFIK_CONFIG_DIR"
    echo "You'll need to manually configure Traefik to route to $MIAB_STATIC_IP"
fi

# Get public IP for DNS instructions
PUBLIC_IP=$(curl -4 -s icanhazip.com)

echo ""
echo "=========================================="
echo "Mail-in-a-Box installation complete!"
echo "=========================================="
echo ""
echo "Container: $CONTAINER_NAME"
echo "Container IP: $MIAB_STATIC_IP (static)"
echo "Public IP: $PUBLIC_IP"
echo ""
echo "Access (via Traefik):"
echo "  Admin panel: https://$MIAB_HOSTNAME/admin"
echo "  Webmail: https://$MIAB_HOSTNAME/mail"
echo ""
echo "Required DNS records:"
echo "  A     $MIAB_HOSTNAME -> $PUBLIC_IP"
echo "  MX    @ -> $MIAB_HOSTNAME"
echo "  See admin panel for complete DNS setup (SPF, DKIM, DMARC)"
echo ""
echo "Mail ports exposed on host:"
echo "  25   - SMTP"
echo "  465  - SMTPS"
echo "  587  - Submission"
echo "  993  - IMAPS"
echo ""
echo "Container management:"
echo "  lxc exec $CONTAINER_NAME -- bash    # Shell access"
echo "  lxc stop $CONTAINER_NAME            # Stop"
echo "  lxc start $CONTAINER_NAME           # Start"
echo "  lxc delete $CONTAINER_NAME --force  # Remove"
echo ""
echo "Traefik will automatically pick up the config and route traffic."
