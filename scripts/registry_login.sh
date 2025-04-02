#!/bin/bash
set -e

echo "🔐 Checking for container registry credentials..."

ssh -i "$DEPLOY_KEY_PATH" \
    -o ConnectTimeout="${TIMEOUT:-10}" \
    -o ServerAliveInterval=15 \
    -o ServerAliveCountMax=2 \
    -o UserKnownHostsFile="$KNOWN_HOSTS_PATH" \
    -p "$SSH_PORT" \
    "$SSH_USER@$SSH_HOST" bash -s <<EOF
    set -e

    if [ -n "$REGISTRY_HOST" ] && [ -n "$REGISTRY_USER" ] && [ -n "$REGISTRY_PASS" ]; then
        echo "🔑 Logging into container registry: $REGISTRY_HOST"
        echo "$REGISTRY_PASS" | docker login "$REGISTRY_HOST" -u "$REGISTRY_USER" --password-stdin
    else
        echo "⏭️ Skipping container registry login - credentials not provided"
    fi
EOF