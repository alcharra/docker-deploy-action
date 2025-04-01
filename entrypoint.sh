#!/bin/bash
set -e

trap 'source ./scripts/cleanup.sh' EXIT

echo "🚀 Starting Docker Deploy Action"

source ./scripts/setup_ssh.sh
source ./scripts/prepare_remote_target.sh
source ./scripts/upload_and_verify_files.sh
source ./scripts/setup_network.sh
source ./scripts/registry_login.sh
source ./scripts/deploy_compose.sh
source ./scripts/deploy_stack.sh
source ./scripts/prune.sh

echo "✅ Deployment complete"