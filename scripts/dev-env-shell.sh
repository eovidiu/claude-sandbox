#!/bin/bash
# dev-env-shell.sh - Access shell in isolated development environment
# Part of User Story 2: Run Claude Code Inside Environment

set -euo pipefail

# Script version
VERSION="1.0.0"

# Default values
ENV_NAME=""
COMMAND=""
USER="root"
WORKDIR=""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Exit codes
EXIT_SUCCESS=0
EXIT_INVALID_ARGS=1
EXIT_ENV_NOT_FOUND=2

#######################################
# Print usage information
#######################################
usage() {
    cat <<EOF
Usage: $(basename "$0") ENV_NAME [OPTIONS]

Access shell or execute commands in an isolated development environment.

ARGUMENTS:
    ENV_NAME            Name of the environment to access

OPTIONS:
    --command CMD       Execute a single command instead of interactive shell
    --user USER         Run as specified user (default: root)
    --workdir DIR       Set working directory (default: container's WORKDIR)
    --help              Display this help message
    --version           Display version information

EXIT CODES:
    0   Success
    1   Invalid arguments
    2   Environment not found or not running

EXAMPLES:
    # Interactive shell
    $(basename "$0") my-dev-env

    # Execute single command
    $(basename "$0") my-dev-env --command "node --version"

    # Run as different user in specific directory
    $(basename "$0") my-dev-env --user developer --workdir /app --command "npm install"

    # Run Claude Code with --dangerously-skip-permissions
    $(basename "$0") my-dev-env --command "claude --dangerously-skip-permissions"

EOF
}

#######################################
# Print version information
#######################################
version() {
    echo "dev-env-shell.sh version $VERSION"
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
# T047: Environment name argument
#######################################
parse_args() {
    # First argument must be environment name
    if [[ $# -eq 0 ]]; then
        error_exit "Environment name is required. Use --help for usage information." $EXIT_INVALID_ARGS
    fi

    # Check if first argument is a flag
    if [[ "$1" == --* ]]; then
        if [[ "$1" == "--help" ]]; then
            usage
            exit $EXIT_SUCCESS
        elif [[ "$1" == "--version" ]]; then
            version
            exit $EXIT_SUCCESS
        else
            error_exit "Environment name is required. Use --help for usage information." $EXIT_INVALID_ARGS
        fi
    fi

    ENV_NAME="$1"
    shift

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --command)
                COMMAND="$2"
                shift 2
                ;;
            --user)
                USER="$2"
                shift 2
                ;;
            --workdir)
                WORKDIR="$2"
                shift 2
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
# Verify environment exists and is running
#######################################
verify_environment() {
    # Check if container exists
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${ENV_NAME}$"; then
        error_exit "Environment '$ENV_NAME' not found. Use dev-env-up.sh to create it." $EXIT_ENV_NOT_FOUND
    fi

    # Check if container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${ENV_NAME}$"; then
        log "Environment '$ENV_NAME' is not running. Starting..." "$YELLOW"
        if ! docker start "$ENV_NAME" >/dev/null 2>&1; then
            error_exit "Failed to start environment '$ENV_NAME'" $EXIT_ENV_NOT_FOUND
        fi
        log "Environment started" "$GREEN"
    fi
}

#######################################
# Execute interactive shell
# T048: Shell access logic with interactive terminal
#######################################
exec_shell() {
    local docker_args=("-it")

    # Add user flag
    docker_args+=("--user" "$USER")

    # Add workdir if specified
    if [[ -n "$WORKDIR" ]]; then
        docker_args+=("--workdir" "$WORKDIR")
    fi

    # Add container name
    docker_args+=("$ENV_NAME")

    # Use bash as default shell
    docker_args+=("/bin/bash")

    log "Accessing shell in '$ENV_NAME'..." "$GREEN"
    log "Type 'exit' or press Ctrl+D to leave the shell" "$YELLOW"
    echo ""

    # Execute interactive shell
    docker exec "${docker_args[@]}"
}

#######################################
# Execute single command
# T049: Command execution mode
#######################################
exec_command() {
    local docker_args=()

    # Add user flag
    docker_args+=("--user" "$USER")

    # Add workdir if specified
    if [[ -n "$WORKDIR" ]]; then
        docker_args+=("--workdir" "$WORKDIR")
    fi

    # Add container name
    docker_args+=("$ENV_NAME")

    # Add shell to execute command
    docker_args+=("/bin/bash" "-c" "$COMMAND")

    # Execute command (without -it flags for non-interactive)
    docker exec "${docker_args[@]}"
}

#######################################
# Main function
#######################################
main() {
    parse_args "$@"
    verify_environment

    # T049: Execute command or start interactive shell
    if [[ -n "$COMMAND" ]]; then
        exec_command
    else
        exec_shell
    fi
}

# Run main function
main "$@"
