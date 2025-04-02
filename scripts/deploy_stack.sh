#!/bin/bash
set -e

if [[ "$MODE" != "stack" ]]; then
    return 0
fi

echo "🐳 Deploying stack using Docker Swarm"

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
        echo "❌ Docker is not installed on the server"
        exit 1
    fi

    # Ensure Swarm mode is active
    if ! docker info | grep -q "Swarm: active"; then
        echo "❌ Docker Swarm mode is not active. Run 'docker swarm init' to enable it."
        exit 1
    fi

    # Change to project directory
    cd "$PROJECT_PATH"

    echo "⚓ Deploying stack: $STACK_NAME using file: \$STACK_FILE_NAME"
    STACK_FILE_NAME=\$(basename "$DEPLOY_FILE")

    docker stack deploy -c "\$STACK_FILE_NAME" "$STACK_NAME" --with-registry-auth --detach=false

    echo "🔍 Verifying services in stack: $STACK_NAME"

    if ! docker service ls --filter "label=com.docker.stack.namespace=$STACK_NAME" | grep -v REPLICAS | grep -q " 0/"; then
        echo "✅ All services in stack '$STACK_NAME' are running"
    else
        echo "❌ One or more services failed to start in stack '$STACK_NAME'"
        docker service ls --filter "label=com.docker.stack.namespace=$STACK_NAME"

        if [ "$ENABLE_ROLLBACK" == "true" ]; then
            echo "🔄 Attempting rollback for failed services..."
            for service in \$(docker service ls --filter "label=com.docker.stack.namespace=$STACK_NAME" --format "{{.Name}}"); do
                echo "🔄 Rolling back service: \$service"
                docker service update --rollback "\$service" || echo "⚠️ Rollback failed for: \$service"
            done
        fi

        exit 1
    fi
EOF
