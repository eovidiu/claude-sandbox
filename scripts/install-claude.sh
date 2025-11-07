#!/bin/bash
# install-claude.sh - Install Claude Code CLI
# Part of User Story 2: Run Claude Code Inside Environment

set -euo pipefail

# Script version
VERSION="2.0.0"

# Default values
VERIFY=false

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Exit codes
EXIT_SUCCESS=0
EXIT_DOWNLOAD_FAILED=1
EXIT_INSTALL_FAILED=2
EXIT_VERIFY_FAILED=3

#######################################
# Log message with optional color
#######################################
log() {
    local message="$1"
    local color="${2:-$NC}"
    echo -e "${color}${message}${NC}"
}

#######################################
# Log error and exit
#######################################
error_exit() {
    local message="$1"
    local exit_code="${2:-$EXIT_DOWNLOAD_FAILED}"
    log "ERROR: $message" "$RED" >&2
    exit "$exit_code"
}

#######################################
# Print usage information
#######################################
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install Claude Code CLI via npm in the container.

OPTIONS:
    --verify            Verify installation after completing
    --help              Display this help message
    --version           Display version information

EXIT CODES:
    0   Success
    1   npm install failed
    2   Node.js not available
    3   Verification failed

EXAMPLES:
    # Basic installation
    $(basename "$0")

    # Install and verify
    $(basename "$0") --verify

NOTE:
    This script installs Claude Code globally via npm:
    npm install -g @anthropic-ai/claude-code

EOF
}

#######################################
# Print version information
#######################################
version() {
    echo "install-claude.sh version $VERSION"
}

#######################################
# Parse command line arguments
#######################################
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verify)
                VERIFY=true
                shift
                ;;
            --help)
                usage
                exit $EXIT_SUCCESS
                ;;
            --version)
                version
                exit $EXIT_SUCCESS
                ;;
            *)
                error_exit "Unknown option: $1" $EXIT_INSTALL_FAILED
                ;;
        esac
    done
}

#######################################
# Check Node.js availability
#######################################
check_nodejs() {
    log "Checking Node.js availability..."

    if ! command -v node &> /dev/null; then
        error_exit "Node.js is not available. Please ensure NodeJS is installed." $EXIT_INSTALL_FAILED
    fi

    if ! command -v npm &> /dev/null; then
        error_exit "npm is not available. Please ensure npm is installed." $EXIT_INSTALL_FAILED
    fi

    local node_version=$(node --version)
    local npm_version=$(npm --version)
    log "Found Node.js $node_version and npm $npm_version" "$GREEN"
}

#######################################
# Install Claude Code via npm
# T043: Claude Code installation via npm
#######################################
install_claude() {
    log "Installing Claude Code CLI via npm..."

    # Install globally with npm
    if npm install -g @anthropic-ai/claude-code; then
        log "Claude Code installed successfully" "$GREEN"
        return 0
    else
        error_exit "Failed to install Claude Code via npm" $EXIT_INSTALL_FAILED
    fi
}

#######################################
# Verify Claude Code installation
# T045: Installation verification
#######################################
verify_installation() {
    log "Verifying Claude Code installation..."

    # Source nvm to ensure PATH is set correctly
    export NVM_DIR="/root/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    # Check if binary exists
    if ! command -v claude &> /dev/null; then
        error_exit "Claude Code binary not found in PATH. Try running: source /root/.nvm/nvm.sh" $EXIT_VERIFY_FAILED
    fi

    # Check if binary is executable
    if ! test -x "$(command -v claude)"; then
        error_exit "Claude Code binary is not executable" $EXIT_VERIFY_FAILED
    fi

    # Check version output
    if ! claude --version &> /dev/null; then
        error_exit "Claude Code version check failed" $EXIT_VERIFY_FAILED
    fi

    local version_output=$(claude --version 2>&1 | head -1)
    log "Claude Code version: $version_output" "$GREEN"
    log "Installation verified successfully" "$GREEN"
}

#######################################
# Main function
#######################################
main() {
    parse_args "$@"

    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GREEN"
    log "Installing Claude Code CLI" "$GREEN"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GREEN"
    echo ""

    check_nodejs
    echo ""
    install_claude

    if [[ "$VERIFY" == "true" ]]; then
        echo ""
        verify_installation
    fi

    echo ""
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GREEN"
    log "✓ Installation complete!" "$GREEN"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GREEN"
    echo ""
    log "Run 'claude --help' to get started" "$GREEN"
}

# Run main function
main "$@"
