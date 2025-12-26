#!/bin/bash
# Mailcow setup script
# This clones mailcow-dockerized and generates the configuration

set -e

# Source .env for variables
if [ -f .env ]; then
    source .env
fi

MAILCOW_HOSTNAME="${MAILCOW_HOSTNAME:-mail.example.com}"
MAILCOW_TZ="${MAILCOW_TZ:-UTC}"

echo "Setting up Mailcow for: $MAILCOW_HOSTNAME"

# Clone mailcow-dockerized if not exists
if [ ! -d "mailcow-dockerized" ]; then
    echo "Cloning mailcow-dockerized..."
    git clone https://github.com/mailcow/mailcow-dockerized.git
fi

cd mailcow-dockerized

# Generate config non-interactively
echo "Generating mailcow configuration..."
cat > mailcow.conf << EOF
# Mailcow configuration
MAILCOW_HOSTNAME=${MAILCOW_HOSTNAME}
MAILCOW_TZ=${MAILCOW_TZ}

# Database
DBNAME=mailcow
DBUSER=mailcow
DBPASS=$(openssl rand -hex 16)
DBROOT=$(openssl rand -hex 16)

# Redis
REDISPASS=$(openssl rand -hex 16)

# API
API_KEY=$(openssl rand -hex 32)
API_KEY_READ_ONLY=$(openssl rand -hex 32)
API_ALLOW_FROM=127.0.0.1,::1

# Ports - use non-standard to work behind traefik
HTTP_PORT=8080
HTTP_BIND=0.0.0.0
HTTPS_PORT=8443
HTTPS_BIND=0.0.0.0

# SMTP ports
SMTP_PORT=25
SMTPS_PORT=465
SUBMISSION_PORT=587

# IMAP/POP ports
IMAP_PORT=143
IMAPS_PORT=993
POP_PORT=110
POPS_PORT=995

# Sieve
SIEVE_PORT=4190

# Skip Let's Encrypt (traefik handles SSL)
SKIP_LETS_ENCRYPT=y
SKIP_CLAMD=n
SKIP_SOGO=n

# Compose project name
COMPOSE_PROJECT_NAME=mailcow
EOF

echo "Mailcow configuration generated!"
echo ""
echo "Required DNS records for $MAILCOW_HOSTNAME:"
echo "  MX     @ -> $MAILCOW_HOSTNAME (priority 10)"
echo "  A      mail -> <server-ip>"
echo "  TXT    @ -> v=spf1 mx ~all"
echo "  TXT    _dmarc -> v=DMARC1; p=quarantine"
echo "  TXT    dkim._domainkey -> (get from mailcow UI after setup)"
echo ""
echo "To start mailcow:"
echo "  cd mailcow-dockerized && docker compose up -d"
