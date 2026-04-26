#!/bin/bash
# install-sandbox.sh - One-time setup for Claude Sandbox
#
# This script:
# 1. Creates ~/.claude-sandbox-env template (if not exists)
# 2. Appends sandbox functions to ~/.zshrc (idempotent)
# 3. Pulls latest Docker image

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Claude Sandbox Installation ==="
echo ""

# =============================================================================
# Step 1: Create ~/.claude-sandbox-env if it doesn't exist
# =============================================================================
ENV_FILE="$HOME/.claude-sandbox-env"
if [[ -f "$ENV_FILE" ]]; then
    echo "[1/3] Environment file already exists: $ENV_FILE"
else
    echo "[1/3] Creating environment file: $ENV_FILE"
    cp "$REPO_DIR/config/claude-sandbox-env.template" "$ENV_FILE"
    chmod 600 "$ENV_FILE"
    echo "      -> Edit this file to add your MCP API keys"
fi

# =============================================================================
# Step 2: Add sandbox functions to ~/.zshrc (idempotent)
# =============================================================================
ZSHRC="$HOME/.zshrc"
MARKER="# === Claude Sandbox Functions ==="

if grep -q "$MARKER" "$ZSHRC" 2>/dev/null; then
    echo "[2/3] Sandbox functions already in ~/.zshrc"
else
    echo "[2/3] Adding sandbox functions to ~/.zshrc"
    cat >> "$ZSHRC" << 'SANDBOX_FUNCTIONS'

# === Claude Sandbox Functions ===
# Isolated development environment for Claude Code
# https://github.com/eovidiu/claude-sandbox

sandbox() {
    local env_file="$HOME/.claude-sandbox-env"

    # Build environment variable arguments
    local env_args=()

    # Forward the primary Claude API key from the host environment when present.
    [[ -n "${ANTHROPIC_API_KEY:-}" ]] && env_args+=("-e" "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY")

    # Source MCP API keys from env file
    if [[ -f "$env_file" ]]; then
        while IFS='=' read -r key value; do
            [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
            value="${value%\"}"
            value="${value#\"}"
            [[ -n "$value" ]] && env_args+=("-e" "$key=$value")
        done < <(grep -v '^#' "$env_file" | grep -v '^$')
    fi

    # Git configuration - inherit from host
    local git_name=$(git config --global user.name 2>/dev/null)
    local git_email=$(git config --global user.email 2>/dev/null)
    [[ -n "$git_name" ]] && env_args+=("-e" "GIT_USER_NAME=$git_name")
    [[ -n "$git_email" ]] && env_args+=("-e" "GIT_USER_EMAIL=$git_email")

    docker run -it --rm \
        --network bridge \
        -v "$PWD:/workspace:rw" \
        "${env_args[@]}" \
        ghcr.io/eovidiu/claude-sandbox:latest \
        /bin/bash -c '/usr/local/bin/setup-mcp.sh && claude --dangerously-skip-permissions'
}

# === End Claude Sandbox Functions ===
SANDBOX_FUNCTIONS
    echo "      -> Function added: sandbox"
fi

# =============================================================================
# Step 3: Pull latest Docker image
# =============================================================================
echo "[3/3] Pulling latest Docker image..."
docker pull ghcr.io/eovidiu/claude-sandbox:latest

# =============================================================================
# Done!
# =============================================================================
echo ""
echo "=== Installation Complete ==="
echo ""
echo "Next steps:"
echo "  1. Edit ~/.claude-sandbox-env to add your MCP API keys"
echo "  2. Run 'source ~/.zshrc' to load the sandbox functions"
echo "  3. cd into any project and run 'sandbox'"
echo ""
echo "Commands:"
echo "  sandbox         - Start Claude Code in isolated container"
echo ""
