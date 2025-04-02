#!/bin/bash
set -e

echo "🧹 Checking if Docker prune should run..."

ssh -i "$DEPLOY_KEY_PATH" \
    -o ConnectTimeout="${TIMEOUT:-10}" \
    -o ServerAliveInterval=15 \
    -o ServerAliveCountMax=2 \
    -o UserKnownHostsFile="$KNOWN_HOSTS_PATH" \
    -p "$SSH_PORT" \
    "$SSH_USER@$SSH_HOST" bash -s <<EOF
    set -e

    case "$DOCKER_PRUNE" in
        system)
            echo "🧹 Running full system prune"
            docker system prune -f
            ;;
        volumes)
            echo "📦 Running volume prune"
            docker volume prune -f
            ;;
        networks)
            echo "🌐 Running network prune"
            docker network prune -f
            ;;
        images)
            echo "🖼️ Running image prune"
            docker image prune -f
            ;;
        containers)
            echo "📦 Running container prune"
            docker container prune -f
            ;;
        none|"")
            echo "⏭️ Skipping Docker prune"
            ;;
        *)
            echo "❌ Invalid prune type: $DOCKER_PRUNE"
            exit 1
            ;;
    esac
EOF