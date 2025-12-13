#!/bin/bash
# Entrypoint script for isolated development environment
# This script initializes the container and handles runtime configuration

set -euo pipefail

# Source nvm to make node/npm/claude available
# NVM is installed in the dev user's home directory
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Ensure npm global binaries (including claude) are in PATH
# nvm.sh already adds the bin directory, but we ensure it's accessible
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version | sed 's/v//')
    export PATH="$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH"
fi

# Display environment information
echo "=== Isolated Development Environment ==="
echo "User: $(whoami)"
echo "Node version: $(node --version 2>/dev/null || echo 'not found')"
echo "npm version: $(npm --version 2>/dev/null || echo 'not found')"
echo "yarn version: $(yarn --version 2>/dev/null || echo 'not found')"
echo "Python version: $(python --version 2>/dev/null || echo 'not found')"
echo "pip version: $(pip --version 2>/dev/null || echo 'not found')"
echo "Claude Code version: $(claude --version 2>/dev/null || echo 'not found')"
echo "Working directory: $(pwd)"
echo "========================================"

# If running interactively with TTY and no specific command, auto-launch Claude Code
if [ -t 0 ] && [ "$#" -eq 1 ] && [ "$1" = "/bin/bash" ]; then
    exec claude --dangerously-skip-permissions
fi

# Execute the command passed to the container
exec "$@"
