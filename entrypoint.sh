#!/bin/bash
set -e

echo "🚀 Starting Docker Deploy Action"

# Create temporary SSH key file
DEPLOY_KEY_PATH=$(mktemp)

echo "$SSH_KEY" > "$DEPLOY_KEY_PATH"
chmod 600 "$DEPLOY_KEY_PATH"

# Ensure project path exists and backup the deploy file if rollback is enabled
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

    # Only create a backup if running in Compose mode and rollback is enabled
    if [ "$ENABLE_ROLLBACK" == "true" ] && [ "$MODE" == "compose" ]; then
        echo "🔄 Creating a backup of the current deployment file (if exists)"
        
        # Check if the deployment file exists
        if ls "$PROJECT_PATH/$DEPLOY_FILE" >/dev/null 2>&1; then
            cp "$PROJECT_PATH/$DEPLOY_FILE" "$PROJECT_PATH/${DEPLOY_FILE}.backup"
            
            # Verify the backup exists
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

    # Check if Docker is installed
    if ! command -v docker &>/dev/null; then
        echo "❌ Docker is not installed or not in PATH. Please install Docker first."
        exit 1
    fi

    # Create network if needed
    if [ -n "$DOCKER_NETWORK" ]; then
        echo "🌐 Ensuring network $DOCKER_NETWORK exists"

        # Ensure DOCKER_NETWORK_DRIVER is set
        if [ -z "$DOCKER_NETWORK_DRIVER" ]; then
            echo "❌ DOCKER_NETWORK_DRIVER is not set!"
            exit 1
        fi

        # Check if network already exists
        if docker network inspect "$DOCKER_NETWORK" > /dev/null 2>&1; then
            echo "✅ Network $DOCKER_NETWORK exists. Checking driver..."
            
            # Fetch the driver
            EXISTING_DRIVER=\$(docker network inspect --format '{{ .Driver }}' "$DOCKER_NETWORK")

            if [ "\$EXISTING_DRIVER" != "$DOCKER_NETWORK_DRIVER" ]; then
                echo "⚠️ Network $DOCKER_NETWORK exists but uses driver '\$EXISTING_DRIVER' instead of '$DOCKER_NETWORK_DRIVER'"
                echo "🚨 Consider deleting and recreating the network manually."
            else
                echo "✅ Network driver matches expected: $DOCKER_NETWORK_DRIVER"
            fi
        else
            echo "🔧 Creating $DOCKER_NETWORK network with driver $DOCKER_NETWORK_DRIVER"

            # Ensure Swarm mode is active if using an overlay network
            if [ "$DOCKER_NETWORK_DRIVER" == "overlay" ] && [ "$MODE" == "stack" ] && ! docker info | grep -q "Swarm: active"; then
                echo "⚠️ Warning: Swarm mode is not active. Overlay networks require Swarm mode for multi-node communication."
                echo "ℹ️ Without Swarm mode, the overlay network will function as a single-node bridge."
            fi

            # Create the Docker network
            docker network create \
                --driver "$DOCKER_NETWORK_DRIVER" \
                $( [ "$DOCKER_NETWORK_DRIVER" == "overlay" ] && [ "$MODE" == "stack" ] && echo "--scope swarm" ) \
                $( [ "$DOCKER_NETWORK_DRIVER" == "overlay" ] && [ "$MODE" == "stack" ] && [ "$DOCKER_NETWORK_ATTACHABLE" == "true" ] && echo "--attachable" ) \
                "$DOCKER_NETWORK"

            # Verify network creation
            if docker network inspect "$DOCKER_NETWORK" > /dev/null 2>&1; then
                echo "✅ Network $DOCKER_NETWORK successfully created"
            else
                echo "❌ Network creation failed for $DOCKER_NETWORK!"
                exit 1
            fi
        fi
    fi

    echo "📦 Changing directory to $PROJECT_PATH"
    if ! cd "$PROJECT_PATH"; then
        echo "❌ Failed to change directory to $PROJECT_PATH"
        exit 1
    fi

    # Optional Registry Login
    if [ -n "$REGISTRY_HOST" ] && [ -n "$REGISTRY_USER" ] && [ -n "$REGISTRY_PASS" ]; then
        echo "🔑 Logging into container registry: $REGISTRY_HOST"
        echo "$REGISTRY_PASS" | docker login "$REGISTRY_HOST" -u "$REGISTRY_USER" --password-stdin
    else
        echo "⏭️ Skipping container registry login - credentials not provided"
    fi

    # Deploy stack or compose services
    if [ "$MODE" == "stack" ]; then

        # Check if Docker Swarm mode is enabled
        if ! docker info | grep -q "Swarm: active"; then
            echo "❌ Docker Swarm mode is not active. Please initialise Swarm using 'docker swarm init'."
            exit 1
        fi

        echo "⚓ Deploying stack $STACK_NAME using Docker Swarm"
        docker stack deploy -c "$DEPLOY_FILE" "$STACK_NAME" --with-registry-auth --detach=false

        # Verify stack services are running
        echo "✅ Verifying services in stack $STACK_NAME"

        if ! docker service ls --filter "label=com.docker.stack.namespace=$STACK_NAME" | grep -v REPLICAS | grep -q " 0/"; then
            echo "✅ All services in stack $STACK_NAME are running correctly"
        else
            echo "❌ One or more services failed to start in stack $STACK_NAME!"
            docker service ls --filter "label=com.docker.stack.namespace=$STACK_NAME"
            
            # Run optional rollback logic
            if [ "$ENABLE_ROLLBACK" == "true" ]; then
                echo "🔄 Attempting rollback for failed services..."
                for service in $(docker service ls --filter "label=com.docker.stack.namespace=$STACK_NAME" --format "{{.Name}}"); do
                    echo "🔄 Rolling back service: $service"
                    docker service update --rollback "$service"
                done
            fi

            exit 1
        fi
    else
        echo "🐳 Deploying using Docker Compose"

        # Support both legacy (docker-compose v1) and modern (docker compose v2)
        if docker compose version >/dev/null 2>&1; then
            DOCKER_COMPOSE_CMD="docker compose"
        elif docker-compose version >/dev/null 2>&1; then
            DOCKER_COMPOSE_CMD="docker-compose"
        else
            echo "❌ Docker Compose not found! Please install it first."
            exit 1
        fi

        # Run deployment
        \$DOCKER_COMPOSE_CMD pull && 
        \$DOCKER_COMPOSE_CMD down && 
        \$DOCKER_COMPOSE_CMD up -d

        # Verify all compose services are running
        echo "✅ Verifying Compose services"

        if \$DOCKER_COMPOSE_CMD ps | grep -E "Exit|Restarting|Dead"; then
            echo "❌ One or more services failed to start!"
            \$DOCKER_COMPOSE_CMD ps

            # Run optional rollback logic
            if [ "$ENABLE_ROLLBACK" == "true" ]; then
                echo "🔄 Attempting rollback..."
                
                if ls "$PROJECT_PATH/${DEPLOY_FILE}.backup" >/dev/null 2>&1; then
                    echo "🔄 Restoring backup file..."
                    mv "$PROJECT_PATH/${DEPLOY_FILE}.backup" "$PROJECT_PATH/$DEPLOY_FILE"

                    echo "♻️ Re-deploying previous version..."
                    \$DOCKER_COMPOSE_CMD pull && 
                    \$DOCKER_COMPOSE_CMD down && 
                    \$DOCKER_COMPOSE_CMD up -d

                    echo "✅ Rollback successful: Previous deployment file restored."
                else
                    echo "⚠️ No backup found! Rollback not possible."
                fi
            fi
            exit 1
        else
            echo "✅ All services are running"
        fi
        # Cleanup backup file after a successful deployment
        if [ "$ENABLE_ROLLBACK" == "true" ]; then
            if ls "$PROJECT_PATH/${DEPLOY_FILE}.backup" >/dev/null 2>&1; then
                rm -f "$PROJECT_PATH/${DEPLOY_FILE}.backup"
                echo "🧹 Removed backup file after successful deployment."
            fi
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
echo "🧹 Cleaning up SSH key..."
rm -f "$DEPLOY_KEY_PATH"

echo "✅ Deployment complete"