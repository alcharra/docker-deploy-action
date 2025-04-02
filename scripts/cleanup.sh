#!/bin/bash
set -e

echo "🧹 Cleaning up temporary files"

# Remove SSH private key
if [[ -n "$DEPLOY_KEY_PATH" && -f "$DEPLOY_KEY_PATH" ]]; then
    rm -f "$DEPLOY_KEY_PATH"
    echo "🗑️ Removed temporary SSH key"
fi

# Remove known_hosts file
if [[ -n "$KNOWN_HOSTS_PATH" && -f "$KNOWN_HOSTS_PATH" ]]; then
    rm -f "$KNOWN_HOSTS_PATH"
    echo "🗑️ Removed temporary known_hosts file"
fi

# Remove .env file
if [[ -f ".env" ]]; then
    rm -f .env
    echo "🗑️ Removed temporary .env file"
fi

# Kill ssh-agent if running
if [[ -n "$SSH_AGENT_PID" ]]; then
    kill "$SSH_AGENT_PID" >/dev/null 2>&1 || true
    echo "🛑 ssh-agent stopped"
fi

echo "✅ Cleanup complete"