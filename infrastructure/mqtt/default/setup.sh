#!/bin/bash
# Post-install setup script for MQTT
# This runs after docker-compose.yml and .env are in place
# Working directory is the install path

set -e

# Source the .env file to get variables
if [ -f .env ]; then
    source .env
fi

# Create password file if credentials provided
if [ -n "$MQTT_USER" ] && [ -n "$MQTT_PASSWORD" ]; then
    mkdir -p config
    # Use docker to run mosquitto_passwd
    docker run --rm -v "$(pwd)/config:/config" eclipse-mosquitto:2 \
        mosquitto_passwd -b -c /config/passwd "$MQTT_USER" "$MQTT_PASSWORD"
    # Make readable by mosquitto user (UID 1883 in container)
    chmod 644 config/passwd
    echo "Created MQTT password file for user: $MQTT_USER"
fi
