#!/bin/bash
# dev-env-down.sh - Tear down isolated development environment
# Part of User Story 1: Create Isolated Environment

set -euo pipefail

# Script version
VERSION="1.0.0"

# Default values
ENV_NAME=""
FORCE=false
KEEP_VOLUMES=false

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Exit codes
EXIT_SUCCESS=0
EXIT_INVALID_ARGS=1

#######################################
# Print usage information
#######################################
usage() {
    cat <<EOF
Usage: $(basename "$0") ENV_NAME [OPTIONS]

Tear down an isolated development environment.

ARGUMENTS:
    ENV_NAME            Name of the environment to tear down

OPTIONS:
    --force             Skip confirmation prompt
    --keep-volumes      Preserve data volumes (don't remove)
    --help              Display this help message
    --version           Display version information

EXIT CODES:
    0   Success (or environment already removed)
    1   Invalid arguments

EXAMPLES:
    # Tear down with confirmation
    $(basename "$0") my-dev-env

    # Force removal without confirmation
    $(basename "$0") my-dev-env --force

    # Keep volumes for later reuse
    $(basename "$0") my-dev-env --force --keep-volumes

EOF
}

#######################################
# Print version information
#######################################
version() {
    echo "dev-env-down.sh version $VERSION"
}

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
    local exit_code="${2:-$EXIT_INVALID_ARGS}"
    log "ERROR: $message" "$RED" >&2
    exit "$exit_code"
}

#######################################
# Parse command line arguments
# T028: Parse environment name and flags
#######################################
parse_args() {
    # First argument must be environment name
    if [[ $# -eq 0 ]]; then
        error_exit "Environment name is required. Use --help for usage information." $EXIT_INVALID_ARGS
    fi

    ENV_NAME="$1"
    shift

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE=true
                shift
                ;;
            --keep-volumes)
                KEEP_VOLUMES=true
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
                error_exit "Unknown option: $1" $EXIT_INVALID_ARGS
                ;;
        esac
    done
}

#######################################
# Confirm with user before proceeding
# T033: User confirmation prompt
#######################################
confirm_removal() {
    if [[ "$FORCE" == "true" ]]; then
        return 0
    fi

    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
    log "⚠  WARNING: About to remove environment '$ENV_NAME'" "$YELLOW"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
    echo ""

    # Show what will be removed
    if docker ps -a --format '{{.Names}}' | grep -q "^${ENV_NAME}$"; then
        log "This will remove:"
        log "  - Container: $ENV_NAME"

        if [[ "$KEEP_VOLUMES" == "false" ]]; then
            local volumes=$(docker inspect "$ENV_NAME" 2>/dev/null | grep -o '"Name": *"[^"]*"' | grep -v "^\"Name\": *\"$ENV_NAME\"" | cut -d'"' -f4 || echo "")
            if [[ -n "$volumes" ]]; then
                log "  - Associated volumes"
            fi
        else
            log "  - Container only (volumes will be preserved)"
        fi
    else
        log "Environment '$ENV_NAME' not found or already removed" "$YELLOW"
        exit $EXIT_SUCCESS
    fi

    echo ""
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Cancelled" "$YELLOW"
        exit $EXIT_SUCCESS
    fi
}

#######################################
# Stop container gracefully
# T029: Container stop logic
#######################################
stop_container() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${ENV_NAME}$"; then
        log "Container '$ENV_NAME' is not running" "$YELLOW"
        return 0
    fi

    log "Stopping container '$ENV_NAME'..."

    # Graceful stop with 30s timeout
    if ! docker stop -t 30 "$ENV_NAME" >/dev/null 2>&1; then
        log "Warning: Failed to stop container gracefully, forcing..." "$YELLOW"
        docker kill "$ENV_NAME" >/dev/null 2>&1 || true
    fi

    log "Container stopped" "$GREEN"
}

#######################################
# Remove container
# T030: Container removal logic
#######################################
remove_container() {
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${ENV_NAME}$"; then
        log "Container '$ENV_NAME' does not exist" "$YELLOW"
        return 0
    fi

    log "Removing container '$ENV_NAME'..."

    if ! docker rm "$ENV_NAME" >/dev/null 2>&1; then
        error_exit "Failed to remove container '$ENV_NAME'" $EXIT_INVALID_ARGS
    fi

    log "Container removed" "$GREEN"
}

#######################################
# Clean up volumes
# T031: Volume cleanup logic
#######################################
cleanup_volumes() {
    if [[ "$KEEP_VOLUMES" == "true" ]]; then
        log "Skipping volume cleanup (--keep-volumes specified)" "$YELLOW"
        return 0
    fi

    # Find volumes associated with this environment
    local volumes=$(docker volume ls -q --filter "name=$ENV_NAME" || echo "")

    if [[ -z "$volumes" ]]; then
        log "No volumes to clean up"
        return 0
    fi

    log "Removing volumes..."

    for volume in $volumes; do
        log "  Removing volume: $volume"
        docker volume rm "$volume" >/dev/null 2>&1 || \
            log "  Warning: Failed to remove volume: $volume" "$YELLOW"
    done

    log "Volumes cleaned up" "$GREEN"
}

#######################################
# Verify cleanup completed
# T032: Cleanup verification
#######################################
verify_cleanup() {
    local issues=0

    # Check for orphaned containers
    if docker ps -a --format '{{.Names}}' | grep -q "^${ENV_NAME}$"; then
        log "Warning: Container '$ENV_NAME' still exists" "$YELLOW"
        issues=$((issues + 1))
    fi

    # Check for orphaned volumes (if we tried to remove them)
    if [[ "$KEEP_VOLUMES" == "false" ]]; then
        local volumes=$(docker volume ls -q --filter "name=$ENV_NAME" || echo "")
        if [[ -n "$volumes" ]]; then
            log "Warning: Some volumes still exist:" "$YELLOW"
            for volume in $volumes; do
                log "  - $volume" "$YELLOW"
            done
            issues=$((issues + 1))
        fi
    fi

    if [[ $issues -gt 0 ]]; then
        log "Cleanup completed with warnings" "$YELLOW"
    fi
}

#######################################
# Display success information
#######################################
show_success() {
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GREEN"
    log "✓ Environment '$ENV_NAME' removed successfully" "$GREEN"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GREEN"

    if [[ "$KEEP_VOLUMES" == "true" ]]; then
        echo ""
        log "Note: Volumes were preserved. To remove them later, run:"
        log "  docker volume ls --filter 'name=$ENV_NAME'"
        log "  docker volume rm <volume-name>"
    fi
}

#######################################
# Main function
#######################################
main() {
    parse_args "$@"
    confirm_removal
    stop_container
    remove_container
    cleanup_volumes
    verify_cleanup
    show_success
}

# Run main function
main "$@"
