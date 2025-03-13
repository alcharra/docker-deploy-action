#!/bin/bash
set -e

echo "🚀 Starting Docker Deploy Action"

# Create temporary SSH key file
DEPLOY_KEY_PATH=$(mktemp)

echo "$SSH_KEY" > "$DEPLOY_KEY_PATH"
chmod 600 "$DEPLOY_KEY_PATH"

# Ensure project path exists
echo "📂 Checking if project path exists on remote server: $PROJECT_PATH"

ssh -i "$DEPLOY_KEY_PATH" -o StrictHostKeyChecking=no -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" bash -s <<EOF
    if [ ! -d "$PROJECT_PATH" ]; then
        echo '📁 Project path not found - creating it...'
        mkdir -p "$PROJECT_PATH"
        chown "$SSH_USER":"$SSH_USER" "$PROJECT_PATH"
        chmod 750 "$PROJECT_PATH"

        # Verify that it exists after creation
        if [ ! -d "$PROJECT_PATH" ]; then
            echo '❌ Failed to create project path!'
            exit 1
        fi

        echo '✅ Project path created and verified.'
    else
        echo '✅ Project path already exists.'
    fi
EOF

# Verify the deploy file exists
if [ ! -f "$DEPLOY_FILE" ]; then
    echo "❌ Required file $DEPLOY_FILE not found"
    exit 1
fi

# Prepare list of files to upload
FILES_TO_UPLOAD=("$DEPLOY_FILE")

# Process extra files but only if EXTRA_FILES is set
if [[ -n "$EXTRA_FILES" ]]; then
    IFS=',' read -ra EXTRA_FILES_LIST <<< "$EXTRA_FILES"

    for file in "${EXTRA_FILES_LIST[@]}"; do
        if [ ! -f "$file" ]; then
            echo "❌ Extra file $file not found"
            exit 1
        fi
        FILES_TO_UPLOAD+=("$file")
    done
fi

# Convert array to string for SSH
FILES_TO_UPLOAD_STR=$(printf "%s " "${FILES_TO_UPLOAD[@]}")

# Upload all files in a single scp command
echo "📂 Uploading files to $SSH_USER@$SSH_HOST:$PROJECT_PATH/"
scp -i "$DEPLOY_KEY_PATH" -o StrictHostKeyChecking=no -P "$SSH_PORT" "${FILES_TO_UPLOAD[@]}" "$SSH_USER@$SSH_HOST:$PROJECT_PATH/"

# Connect to remote server to deploy
echo "🔗 Connecting to $SSH_USER@$SSH_HOST to deploy..."
ssh -i "$DEPLOY_KEY_PATH" -o StrictHostKeyChecking=no -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" bash -s <<EOF
    set -e

    echo "✅ Connected to $SSH_HOST"

    # Verify all uploaded files exist
    for file in $FILES_TO_UPLOAD_STR; do
        filename=$(basename "$file")
        if ! ls "$PROJECT_PATH/$filename" >/dev/null 2>&1; then
            echo "❌ Missing file after upload: $PROJECT_PATH/$filename"
            exit 1
        fi
    done

    echo "✅ All files verified on server"

    # Create network if needed
    if [ -n "$DOCKER_NETWORK" ]; then
        echo "🌐 Ensuring network $DOCKER_NETWORK exists"

        if ! docker network inspect "$DOCKER_NETWORK" > /dev/null 2>&1; then
            echo "🔧 Creating $DOCKER_NETWORK network with driver $DOCKER_NETWORK_DRIVER"

            if [ "$MODE" == "stack" ] && [ "$DOCKER_NETWORK_DRIVER" == "overlay" ]; then
                # Use --scope swarm only for overlay networks in Swarm mode
                docker network create \
                    --driver "$DOCKER_NETWORK_DRIVER" \
                    --scope swarm \
                    "$DOCKER_NETWORK"
            else
                docker network create \
                    --driver "$DOCKER_NETWORK_DRIVER" \
                    "$DOCKER_NETWORK"
            fi

            # Verify network creation
            if docker network inspect "$DOCKER_NETWORK" > /dev/null 2>&1; then
                echo "✅ Network $DOCKER_NETWORK successfully created"
            else
                echo "❌ Network creation failed for $DOCKER_NETWORK!"
                exit 1
            fi
        else
            echo "✅ Network $DOCKER_NETWORK already exists"
        fi
    fi

    echo "📦 Changing directory to $PROJECT_PATH"
    cd "$PROJECT_PATH" || { echo "❌ Failed to change directory"; exit 1; }

    # Optional Registry Login
    if [ -n "$REGISTRY_HOST" ] && [ -n "$REGISTRY_USER" ] && [ -n "$REGISTRY_PASS" ]; then
        echo "🔑 Logging into container registry: $REGISTRY_HOST"
        echo "$REGISTRY_PASS" | docker login "$REGISTRY_HOST" -u "$REGISTRY_USER" --password-stdin
    else
        echo "⏭️ Skipping container registry login - credentials not provided"
    fi

    # Deploy stack or compose services
    if [ "$MODE" == "stack" ]; then
        echo "⚓ Deploying stack $STACK_NAME using Docker Swarm"
        docker stack deploy -c "$DEPLOY_FILE" "$STACK_NAME" --with-registry-auth --detach=false

        echo "✅ Verifying services in stack $STACK_NAME"
        docker service ls --filter "label=com.docker.stack.namespace=$STACK_NAME"
        
        # Verify stack services are running
        if ! docker service ls --filter "label=com.docker.stack.namespace=$STACK_NAME" | grep -v REPLICAS | grep -q " 0/"; then
            echo "✅ All services in stack $STACK_NAME are running correctly"
        else
            echo "❌ One or more services failed to start in stack $STACK_NAME!"
            docker service ls --filter "label=com.docker.stack.namespace=$STACK_NAME"
            exit 1
        fi
    else
        echo "🐳 Deploying using Docker Compose"

        # Detect correct docker-compose command
        DOCKER_COMPOSE_CMD=$(command -v docker-compose || command -v docker compose)

        $DOCKER_COMPOSE_CMD pull && 
        $DOCKER_COMPOSE_CMD down && 
        $DOCKER_COMPOSE_CMD up -d

        echo "✅ Verifying Compose services"

        # Verify all compose services are running
        if $DOCKER_COMPOSE_CMD ps | grep -E "Exit|Restarting|Dead"; then
            echo "❌ One or more services failed to start!"
            docker-compose ps
            exit 1
        else
            echo "✅ All services are running"
            docker-compose ps
        fi
    fi

    # Run optional docker prune
    case "$DOCKER_PRUNE" in
        system) echo "🧹 Running full system prune"; docker system prune -f ;;
        volumes) echo "📦 Running volume prune"; docker volume prune -f ;;
        networks) echo "🌐 Running network prune"; docker network prune -f ;;
        images) echo "🖼️ Running image prune"; docker image prune -f ;;
        containers) echo "📦 Running container prune"; docker container prune -f ;;
        none|"") echo "⏭️ Skipping docker prune" ;;
        *) echo "❌ Invalid prune type: $DOCKER_PRUNE"; exit 1 ;;
    esac
EOF

# Cleanup SSH key
rm -f "$DEPLOY_KEY_PATH"

echo "✅ Deployment complete"