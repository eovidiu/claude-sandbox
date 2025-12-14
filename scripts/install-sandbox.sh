#!/bin/bash
# install-sandbox.sh - One-time setup for Claude Sandbox
#
# This script:
# 1. Creates ~/.claude-sandbox-env template (if not exists)
# 2. Appends sandbox functions to ~/.zshrc (idempotent)
# 3. Verifies SSH keys exist
# 4. Pulls latest Docker image

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
    echo "[1/4] Environment file already exists: $ENV_FILE"
else
    echo "[1/4] Creating environment file: $ENV_FILE"
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
    echo "[2/4] Sandbox functions already in ~/.zshrc"
else
    echo "[2/4] Adding sandbox functions to ~/.zshrc"
    cat >> "$ZSHRC" << 'SANDBOX_FUNCTIONS'

# === Claude Sandbox Functions ===
# Isolated development environment for Claude Code
# https://github.com/eovidiu/claude-sandbox

sandbox() {
    local project_name=$(basename "$(pwd)" | tr '.' '-')
    local container="sandbox-${project_name}"
    local env_file="$HOME/.claude-sandbox-env"

    # Handle --reset flag
    if [[ "$1" == "--reset" ]]; then
        echo "Resetting sandbox for ${project_name}..."
        docker rm -f "$container" 2>/dev/null
        shift
    fi

    # Show container status
    local status=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null || echo "not created")
    echo "Sandbox status: $status"

    # Build environment variable arguments
    local env_args=()

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

    # Create container if doesn't exist
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        echo "Creating sandbox for ${project_name}..."
        docker run -d --name "$container" \
            -v "$(pwd):/workspace:rw" \
            -v "$HOME/.ssh:/home/dev/.ssh:ro" \
            -v "$HOME/.gitconfig:/home/dev/.gitconfig:ro" \
            -p 3000:3000 -p 8000:8000 \
            "${env_args[@]}" \
            ghcr.io/eovidiu/claude-sandbox:latest \
            tail -f /dev/null
    fi

    docker start "$container" 2>/dev/null

    # Generate MCP config and launch Claude (env vars passed via exec)
    docker exec -it -w /workspace "${env_args[@]}" \
        "$container" /bin/bash -c '/usr/local/bin/setup-mcp.sh && claude --dangerously-skip-permissions'
}

sandbox-rm() {
    local container="sandbox-${1:-$(basename "$(pwd)" | tr '.' '-')}"
    docker rm -f "$container" 2>/dev/null && echo "Removed $container" || echo "Container $container not found"
}

sandbox-ls() {
    docker ps -a --filter "name=sandbox-" --format "table {{.Names}}\t{{.Status}}\t{{.Size}}"
}

sandbox-shell() {
    local project_name=$(basename "$(pwd)" | tr '.' '-')
    local container="sandbox-${project_name}"
    docker exec -it -w /workspace "$container" /bin/bash
}
# === End Claude Sandbox Functions ===
SANDBOX_FUNCTIONS
    echo "      -> Functions added: sandbox, sandbox-rm, sandbox-ls, sandbox-shell"
fi

# =============================================================================
# Step 3: Verify SSH keys exist
# =============================================================================
echo "[3/4] Checking SSH keys..."
if [[ -f "$HOME/.ssh/id_ed25519" ]] || [[ -f "$HOME/.ssh/id_rsa" ]]; then
    echo "      -> SSH keys found"
else
    echo "      -> WARNING: No SSH keys found in ~/.ssh/"
    echo "         Git push/pull may not work. Generate keys with:"
    echo "         ssh-keygen -t ed25519 -C \"your@email.com\""
fi

# =============================================================================
# Step 4: Pull latest Docker image
# =============================================================================
echo "[4/4] Pulling latest Docker image..."
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
echo "  sandbox --reset - Reset container (fresh start)"
echo "  sandbox-ls      - List all sandbox containers"
echo "  sandbox-rm      - Remove current project's sandbox"
echo "  sandbox-shell   - Open bash shell in sandbox"
echo ""
