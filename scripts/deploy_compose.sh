#!/bin/bash
set -e

if [[ "$MODE" != "compose" ]]; then
    return 0
fi

ssh -i "$DEPLOY_KEY_PATH" \
    -o ConnectTimeout="${TIMEOUT:-10}" \
    -o ServerAliveInterval=15 \
    -o ServerAliveCountMax=2 \
    -o UserKnownHostsFile="$KNOWN_HOSTS_PATH" \
    -p "$SSH_PORT" \
    "$SSH_USER@$SSH_HOST" bash -s <<EOF
    set -e

    cd "$PROJECT_PATH"

    # Detect Docker Compose command
    if docker compose version >/dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
    elif docker-compose version >/dev/null 2>&1; then
        COMPOSE_CMD="docker-compose"
    else
        echo "❌ Docker Compose is not installed"
        exit 1
    fi

    # Pull images if requested
    if [[ "$COMPOSE_PULL" == "true" ]]; then
        echo "📥 Pulling updated images"
        \$COMPOSE_CMD pull || {
            echo "❌ Failed to pull images"
            exit 1
        }
    else
        echo "⏭️ Skipping image pull"
    fi

    # Build up the flags
    UP_FLAGS="-d"

    if [[ "$COMPOSE_BUILD" == "true" ]]; then
        UP_FLAGS="\$UP_FLAGS --build"
    fi

    if [[ "$COMPOSE_NO_DEPS" == "true" ]]; then
        UP_FLAGS="\$UP_FLAGS --no-deps"
    fi

    # Restart services
    if [[ -n "$COMPOSE_TARGET_SERVICES" ]]; then
        IFS=',' read -ra SERVICES <<< "$COMPOSE_TARGET_SERVICES"
        echo "🔁 Restarting selected services: \${SERVICES[*]}"
        for service in "\${SERVICES[@]}"; do
            \$COMPOSE_CMD up \$UP_FLAGS "\$service"
        done
    else
        echo "🔁 Restarting all services"
        \$COMPOSE_CMD down
        \$COMPOSE_CMD up \$UP_FLAGS
    fi

    # Verify services
    echo "🔍 Verifying services..."

    COMPOSE_FILE_NAME=\$(basename "$DEPLOY_FILE") 

    if \$COMPOSE_CMD ps | grep -E "Exit|Restarting|Dead" >/dev/null; then
        echo "❌ One or more services failed to start"
        \$COMPOSE_CMD ps

        # Rollback if enabled
        if [[ "$ENABLE_ROLLBACK" == "true" ]]; then
            echo "🔄 Attempting rollback..."

            if [[ -f "\$COMPOSE_FILE_NAME.backup" ]]; then
                echo "♻️ Restoring backup deployment file"
                mv "\$COMPOSE_FILE_NAME.backup" "\$COMPOSE_FILE_NAME"

                echo "♻️ Re-deploying previous version"
                \$COMPOSE_CMD down
                \$COMPOSE_CMD up -d

                echo "✅ Rollback successful"
            else
                echo "⚠️ No backup file found, rollback skipped"
            fi
        fi

        exit 1
    else
        echo "✅ All services are running"
    fi

    # Clean up backup file
    rm -f "\$COMPOSE_FILE_NAME.backup"
EOF