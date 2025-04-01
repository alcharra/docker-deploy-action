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

    # Detect Compose version
    if docker compose version >/dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
    elif docker-compose version >/dev/null 2>&1; then
        COMPOSE_CMD="docker-compose"
    else
        echo "❌ Docker Compose is not installed on the remote server"
        exit 1
    fi

    cd "$PROJECT_PATH"

    # Optionally pull images
    if [ "$COMPOSE_PULL" == "true" ]; then
        echo "📥 Pulling updated images..."
        \$COMPOSE_CMD pull || {
            echo "❌ Failed to pull images"
            exit 1
        }
    else
        echo "⏭️ Skipping image pull"
    fi

    # Restart services
    echo "🔄 Recreating services..."
    \$COMPOSE_CMD down
    \$COMPOSE_CMD up -d

    # Verify services
    echo "🔍 Verifying services..."

    if \$COMPOSE_CMD ps | grep -E "Exit|Restarting|Dead" >/dev/null; then
        echo "❌ One or more services failed to start"
        \$COMPOSE_CMD ps

        # Rollback if enabled
        if [ "$ENABLE_ROLLBACK" == "true" ]; then
            echo "🔄 Attempting rollback..."

            if [ -f "$PROJECT_PATH/${DEPLOY_FILE}.backup" ]; then
                echo "♻️ Restoring backup deployment file"
                mv "$PROJECT_PATH/${DEPLOY_FILE}.backup" "$PROJECT_PATH/$DEPLOY_FILE"

                echo "♻️ Re-deploying previous version"
                \$COMPOSE_CMD down
                \$COMPOSE_CMD up -d

                echo "✅ Rollback successful"

                # Clean up backup file
                rm -f "$PROJECT_PATH/${DEPLOY_FILE}.backup"
            else
                echo "⚠️ No backup file found, rollback skipped"
            fi
        fi

        exit 1
    else
        echo "✅ All services are running"
    fi
EOF
