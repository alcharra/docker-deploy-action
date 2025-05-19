#!/bin/bash
set -e

echo "🔐 Setting up SSH connection"

SSH_PORT="${SSH_PORT:-22}"

export DEPLOY_KEY_PATH=$(mktemp)
echo "$SSH_KEY" > "$DEPLOY_KEY_PATH"
chmod 600 "$DEPLOY_KEY_PATH"

if [ -n "$SSH_KEY_PASSPHRASE" ]; then
    echo "🔑 Using passphrase to add key to ssh-agent"
    eval "$(ssh-agent -s)"

    ASKPASS_SCRIPT=$(mktemp)
    echo -e "#!/bin/sh\necho \"$SSH_KEY_PASSPHRASE\"" > "$ASKPASS_SCRIPT"
    chmod +x "$ASKPASS_SCRIPT"

    SSH_ASKPASS="$ASKPASS_SCRIPT" setsid ssh-add "$DEPLOY_KEY_PATH" < /dev/null

    rm -f "$ASKPASS_SCRIPT"
fi

export KNOWN_HOSTS_PATH=$(mktemp)

if [ -n "$SSH_KNOWN_HOSTS" ]; then
    echo "🧾 Using provided known_hosts data"
    echo "$SSH_KNOWN_HOSTS" > "$KNOWN_HOSTS_PATH"
elif [ -n "$FINGERPRINT" ]; then
    echo "🧾 Using provided SSH fingerprint"
    echo "$FINGERPRINT" > "$KNOWN_HOSTS_PATH"
else
    echo "⚠️ No SSH_KNOWN_HOSTS or FINGERPRINT provided"
    echo "🔍 Fetching host key using ssh-keyscan (not verified)"
    ssh-keyscan -p "$SSH_PORT" "$SSH_HOST" > "$KNOWN_HOSTS_PATH" 2>/dev/null

    echo "⚠️ Using unverified SSH host key for $SSH_HOST"
    echo "To avoid this warning, set FINGERPRINT or SSH_KNOWN_HOSTS"
fi

echo "✅ SSH setup complete"