#!/bin/bash
# Entrypoint script for isolated development environment
# This script initializes the container and handles runtime configuration

set -euo pipefail

# Source nvm to make node/npm/claude available
export NVM_DIR="/root/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Ensure npm global binaries (including claude) are in PATH
# nvm.sh already adds the bin directory, but we ensure it's accessible
NODE_VERSION=$(node --version | sed 's/v//')
export PATH="$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH"

# Display environment information
echo "=== Isolated Development Environment ==="
echo "Node version: $(node --version)"
echo "npm version: $(npm --version)"
echo "yarn version: $(yarn --version)"
echo "Python version: $(python --version)"
echo "pip version: $(pip --version)"
echo "Working directory: $(pwd)"
echo "========================================"

# Execute the command passed to the container
exec "$@"
