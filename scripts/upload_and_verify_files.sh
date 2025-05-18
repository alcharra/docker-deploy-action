#!/bin/bash
set -e

echo "📦 Preparing deployment files"

DEPLOY_FILE="$(realpath "$DEPLOY_FILE")"

# Ensure DEPLOY_FILE exists
if [ ! -f "$DEPLOY_FILE" ]; then
    echo "❌ Required file '$DEPLOY_FILE' not found"
    exit 1
fi

# Build list of files to upload
FILES_TO_UPLOAD=("$DEPLOY_FILE")

# Handle extra files
if [[ -n "$EXTRA_FILES" ]]; then
    IFS=',' read -ra EXTRA_FILES_LIST <<< "$EXTRA_FILES"
    for file in "${EXTRA_FILES_LIST[@]}"; do
        abs_file="$(realpath "$file")"
        if [ ! -f "$abs_file" ]; then
            echo "❌ Extra file '$file' not found"
            exit 1
        fi
        FILES_TO_UPLOAD+=("$abs_file")
    done
fi

# Export INPUT_ENV_VARS to .env file and upload if provided
if [[ -n "${ENV_VARS}" ]]; then
    echo "🌿 Creating .env file with environment variables..."
    echo "${ENV_VARS}" > .env
    FILES_TO_UPLOAD+=("$(realpath .env)")
fi

# Upload files to remote server
echo "📤 Uploading files to $SSH_USER@$SSH_HOST:$PROJECT_PATH/"
scp -i "$DEPLOY_KEY_PATH" \
    -o ConnectTimeout="${TIMEOUT:-10}" \
    -o UserKnownHostsFile="$KNOWN_HOSTS_PATH" \
    -P "$SSH_PORT" \
    "${FILES_TO_UPLOAD[@]}" \
    "$SSH_USER@$SSH_HOST:$PROJECT_PATH/"

# Export file list as a space-separated string of filenames
export FILES_TO_UPLOAD_STR=$(for f in "${FILES_TO_UPLOAD[@]}"; do basename "$f"; done | tr '\n' ' ')

echo "🔗 Verifying uploaded files on remote server..."

ssh -i "$DEPLOY_KEY_PATH" \
    -o ConnectTimeout="${TIMEOUT:-10}" \
    -o ServerAliveInterval=15 \
    -o ServerAliveCountMax=2 \
    -o UserKnownHostsFile="$KNOWN_HOSTS_PATH" \
    -p "$SSH_PORT" \
    "$SSH_USER@$SSH_HOST" bash -s <<EOF
    set -e

    for file in $FILES_TO_UPLOAD_STR; do
        if [ ! -f "$PROJECT_PATH/\$file" ]; then
            echo "❌ File not found on server: $PROJECT_PATH/\$file"
            exit 1
        fi
    done
    
    echo "✅ All files successfully uploaded and verified on remote server"
EOF
