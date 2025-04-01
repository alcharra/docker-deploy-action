#!/bin/bash
set -e

if [[ -z "$DOCKER_NETWORK" ]]; then
    echo "🌐 No Docker network specified — skipping network setup"
    return 0
fi

echo "🌐 Setting up Docker network: $DOCKER_NETWORK on remote host"

ssh -i "$DEPLOY_KEY_PATH" \
    -o ConnectTimeout="${TIMEOUT:-10}" \
    -o ServerAliveInterval=15 \
    -o ServerAliveCountMax=2 \
    -o UserKnownHostsFile="$KNOWN_HOSTS_PATH" \
    -p "$SSH_PORT" \
    "$SSH_USER@$SSH_HOST" bash -s <<EOF
    set -e

    # Check if Docker is installed
    if ! command -v docker &>/dev/null; then
        echo "❌ Docker is not installed or not in PATH. Please install Docker first."
        exit 1
    fi

    # Ensure driver is specified
    if [ -z "$DOCKER_NETWORK_DRIVER" ]; then
        echo "❌ DOCKER_NETWORK_DRIVER is not set!"
        exit 1
    fi

    # Check if network already exists
    if docker network inspect "$DOCKER_NETWORK" > /dev/null 2>&1; then
        echo "✅ Network '$DOCKER_NETWORK' already exists. Checking driver..."

        EXISTING_DRIVER=\$(docker network inspect --format '{{ .Driver }}' "$DOCKER_NETWORK")
        if [ "\$EXISTING_DRIVER" != "$DOCKER_NETWORK_DRIVER" ]; then
            echo "⚠️ Network '$DOCKER_NETWORK' exists but uses driver '\$EXISTING_DRIVER' instead of '$DOCKER_NETWORK_DRIVER'"
            echo "🚨 Consider deleting and recreating the network manually if this is incorrect."
        else
            echo "✅ Network driver matches expected: $DOCKER_NETWORK_DRIVER"
        fi
    else
        echo "🔧 Creating Docker network '$DOCKER_NETWORK' with driver '$DOCKER_NETWORK_DRIVER'"

        CREATE_FLAGS="--driver $DOCKER_NETWORK_DRIVER"

        if [ "$DOCKER_NETWORK_DRIVER" == "overlay" ] && [ "$MODE" == "stack" ]; then
            if ! docker info | grep -q "Swarm: active"; then
                echo "⚠️ Warning: Swarm mode is not active. Overlay networks may not function as expected for stacks."
            fi
            CREATE_FLAGS="\$CREATE_FLAGS --scope swarm"
        fi

        if [ "$DOCKER_NETWORK_DRIVER" == "overlay" ] && [ "$DOCKER_NETWORK_ATTACHABLE" == "true" ]; then
            CREATE_FLAGS="\$CREATE_FLAGS --attachable"
        fi

        docker network create \$CREATE_FLAGS "$DOCKER_NETWORK"

        # Verify it was created
        if docker network inspect "$DOCKER_NETWORK" > /dev/null 2>&1; then
            echo "✅ Docker network '$DOCKER_NETWORK' created successfully"
        else
            echo "❌ Failed to create Docker network '$DOCKER_NETWORK'"
            exit 1
        fi
    fi
EOF
