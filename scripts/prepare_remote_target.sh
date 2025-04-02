#!/bin/bash
set -e

echo "📁 Checking and preparing project path on remote server"

ssh -i "$DEPLOY_KEY_PATH" \
    -o ConnectTimeout="${TIMEOUT:-10}" \
    -o ServerAliveInterval=15 \
    -o ServerAliveCountMax=2 \
    -o UserKnownHostsFile="$KNOWN_HOSTS_PATH" \
    -p "$SSH_PORT" \
    "$SSH_USER@$SSH_HOST" bash -s <<EOF
    
    set -e

    # Create project path if it doesn't exist
    if [ ! -d "$PROJECT_PATH" ]; then
        echo "📁 Project path not found - creating it..."
        mkdir -p "$PROJECT_PATH"
        chown "$SSH_USER":"$SSH_USER" "$PROJECT_PATH"
        chmod 750 "$PROJECT_PATH"

        if [ ! -d "$PROJECT_PATH" ]; then
            echo "❌ Failed to create project path!"
            exit 1
        fi

        echo "✅ Project path created and verified."
    else
        echo "✅ Project path already exists."
    fi

    # Backup existing deploy file if applicable
    if [ "$ENABLE_ROLLBACK" == "true" ] && [ "$MODE" == "compose" ]; then
        echo "🔄 Creating a backup of the current deployment file (if exists)"
        
        if ls "$PROJECT_PATH/$DEPLOY_FILE" >/dev/null 2>&1; then
            cp "$PROJECT_PATH/$DEPLOY_FILE" "$PROJECT_PATH/${DEPLOY_FILE}.backup"

            if ls "$PROJECT_PATH/${DEPLOY_FILE}.backup" >/dev/null 2>&1; then
                echo "✅ Backup created: ${DEPLOY_FILE}.backup"
            else
                echo "❌ Backup creation failed!"
                exit 1
            fi
        else
            echo "⚠️ No existing deployment file found, skipping backup."
        fi
    fi
EOF
