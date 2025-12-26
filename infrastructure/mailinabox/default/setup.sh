#!/bin/bash
# Mail-in-a-Box LXD setup script
# Creates a dedicated LXD container for MIAB

set -e

# Source .env for variables
if [ -f .env ]; then
    source .env
fi

MIAB_HOSTNAME="${MIAB_HOSTNAME:-box.example.com}"
MIAB_EMAIL="${MIAB_EMAIL:-admin@example.com}"
CONTAINER_NAME="${MIAB_CONTAINER_NAME:-mailinabox}"
MIAB_MEMORY="${MIAB_MEMORY:-2GB}"
MIAB_DISK="${MIAB_DISK:-20GB}"

echo "Setting up Mail-in-a-Box in LXD container: $CONTAINER_NAME"
echo "Hostname: $MIAB_HOSTNAME"
echo "Admin email: $MIAB_EMAIL"

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

echo "Creating LXD container..."
lxc launch ubuntu:22.04 "$CONTAINER_NAME" \
    -c limits.memory="$MIAB_MEMORY" \
    -c security.nesting=true

echo "Waiting for container to start..."
sleep 10

# Configure container for Mail-in-a-Box requirements
echo "Configuring container..."
lxc config device add "$CONTAINER_NAME" smtp proxy listen=tcp:0.0.0.0:25 connect=tcp:127.0.0.1:25 || true
lxc config device add "$CONTAINER_NAME" smtps proxy listen=tcp:0.0.0.0:465 connect=tcp:127.0.0.1:465 || true
lxc config device add "$CONTAINER_NAME" submission proxy listen=tcp:0.0.0.0:587 connect=tcp:127.0.0.1:587 || true
lxc config device add "$CONTAINER_NAME" imaps proxy listen=tcp:0.0.0.0:993 connect=tcp:127.0.0.1:993 || true
lxc config device add "$CONTAINER_NAME" https proxy listen=tcp:0.0.0.0:443 connect=tcp:127.0.0.1:443 || true
lxc config device add "$CONTAINER_NAME" http proxy listen=tcp:0.0.0.0:80 connect=tcp:127.0.0.1:80 || true
lxc config device add "$CONTAINER_NAME" dns-tcp proxy listen=tcp:0.0.0.0:53 connect=tcp:127.0.0.1:53 || true
lxc config device add "$CONTAINER_NAME" dns-udp proxy listen=udp:0.0.0.0:53 connect=udp:127.0.0.1:53 || true

# Set hostname inside container
lxc exec "$CONTAINER_NAME" -- hostnamectl set-hostname "$MIAB_HOSTNAME"

# Install Mail-in-a-Box
echo "Installing Mail-in-a-Box inside container..."
lxc exec "$CONTAINER_NAME" -- bash -c "
    export NONINTERACTIVE=1
    export PRIMARY_HOSTNAME=$MIAB_HOSTNAME
    export PUBLIC_IP=\$(curl -4 -s icanhazip.com)
    export PUBLIC_IPV6=\$(curl -6 -s icanhazip.com 2>/dev/null || echo '')
    export SKIP_NETWORK_CHECKS=1

    curl -s https://mailinabox.email/setup.sh | sudo bash
"

# Get container IP
CONTAINER_IP=$(lxc list "$CONTAINER_NAME" -c 4 --format csv | cut -d' ' -f1)

echo ""
echo "=========================================="
echo "Mail-in-a-Box installation complete!"
echo "=========================================="
echo ""
echo "Container: $CONTAINER_NAME"
echo "Container IP: $CONTAINER_IP"
echo ""
echo "Admin panel: https://$MIAB_HOSTNAME/admin"
echo "Webmail: https://$MIAB_HOSTNAME/mail"
echo ""
echo "Required DNS records (point to your server's public IP):"
echo "  A     $MIAB_HOSTNAME -> <public-ip>"
echo "  MX    @ -> $MIAB_HOSTNAME"
echo "  See admin panel for complete DNS setup"
echo ""
echo "To access container:"
echo "  lxc exec $CONTAINER_NAME -- bash"
echo ""
echo "To stop/start:"
echo "  lxc stop $CONTAINER_NAME"
echo "  lxc start $CONTAINER_NAME"
