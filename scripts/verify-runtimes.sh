#!/bin/bash
# verify-runtimes.sh - Verify NodeJS and Python runtimes are properly installed
# Part of User Story 3: NodeJS and Python Development Support

set -euo pipefail

# Source nvm if available (for build-time verification)
if [[ -f "$HOME/.nvm/nvm.sh" ]]; then
    export NVM_DIR="$HOME/.nvm"
    . "$NVM_DIR/nvm.sh"
fi

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

#######################################
# Log message with color
#######################################
log() {
    local message="$1"
    local color="${2:-$NC}"
    echo -e "${color}${message}${NC}"
}

#######################################
# Run a verification check
#######################################
check() {
    local name="$1"
    local command="$2"

    ((TOTAL_CHECKS++))

    if eval "$command" >/dev/null 2>&1; then
        log "✓ $name" "$GREEN"
        ((PASSED_CHECKS++))
        return 0
    else
        log "✗ $name" "$RED"
        ((FAILED_CHECKS++))
        return 1
    fi
}

#######################################
# Main verification
#######################################
main() {
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GREEN"
    log "Runtime Verification" "$GREEN"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GREEN"
    echo ""

    # NodeJS checks
    log "NodeJS Runtime:" "$YELLOW"
    check "node command available" "command -v node"
    check "node version check" "node --version"
    check "npm command available" "command -v npm"
    check "npm version check" "npm --version"
    check "yarn command available" "command -v yarn"
    check "yarn version check" "yarn --version"
    check "node can execute JS" "node -e 'console.log(\"ok\")'"
    echo ""

    # Python checks
    log "Python Runtime:" "$YELLOW"
    check "python command available" "command -v python"
    check "python version 3.11+" "python --version | grep -q 'Python 3.11'"
    check "python3 command available" "command -v python3"
    check "pip command available" "command -v pip"
    check "pip version check" "pip --version"
    check "python can execute code" "python -c 'print(\"ok\")'"
    check "venv module available" "python -m venv --help"
    check "virtualenv available" "command -v virtualenv"
    check "pipenv available" "command -v pipenv"
    echo ""

    # Summary
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GREEN"
    log "Summary: $PASSED_CHECKS/$TOTAL_CHECKS checks passed" "$GREEN"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GREEN"

    if [[ $FAILED_CHECKS -gt 0 ]]; then
        log "WARNING: $FAILED_CHECKS checks failed" "$RED"
        exit 1
    fi

    exit 0
}

main "$@"
