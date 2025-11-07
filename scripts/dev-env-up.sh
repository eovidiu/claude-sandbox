#!/bin/bash
# dev-env-up.sh - Create isolated development environment
# Part of User Story 1: Create Isolated Environment

set -euo pipefail

# Script version
VERSION="1.0.0"

# Default values
CONFIG_FILE=""
ENV_NAME=""
VERBOSE=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SECRETS=()  # T073: Array to store secrets

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Exit codes (per contract)
EXIT_SUCCESS=0
EXIT_INVALID_ARGS=1
EXIT_PREREQ_NOT_MET=2
EXIT_RESOURCE_CONFLICT=3
EXIT_INVALID_PATHS=4
EXIT_CONTAINER_FAILURE=5

#######################################
# Print usage information
#######################################
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Create an isolated development environment for running Claude Code.

OPTIONS:
    --config FILE       Path to configuration file (default: config/.env)
    --name NAME         Override environment name from config
    --mount PATH:PATH:MODE  Add additional mount (can be used multiple times)
    --port HOST:CONTAINER   Add additional port mapping (can be used multiple times)
    --secret KEY=VALUE  Inject secret as environment variable (can be used multiple times)
    --verbose           Enable verbose output
    --help              Display this help message
    --version           Display version information

EXIT CODES:
    0   Success
    1   Invalid arguments or configuration
    2   Prerequisites not met (OrbStack not running)
    3   Resource conflict (port or name already in use)
    4   Invalid paths (mount points don't exist)
    5   Container creation/start failure

EXAMPLES:
    # Use default config
    $(basename "$0")

    # Use custom config
    $(basename "$0") --config my-config.env

    # Override environment name
    $(basename "$0") --name my-dev-env

    # Add additional mounts and ports
    $(basename "$0") --mount /host/path:/container/path:ro --port 8080:8080

    # Inject secrets (not persisted, memory-only)
    $(basename "$0") --secret API_KEY=abc123 --secret DB_PASSWORD=secret

EOF
}

#######################################
# Print version information
#######################################
version() {
    echo "dev-env-up.sh version $VERSION"
}

#######################################
# Log message with optional color
# Arguments:
#   $1 - Message to log
#   $2 - Color code (optional)
#######################################
log() {
    local message="$1"
    local color="${2:-$NC}"
    echo -e "${color}${message}${NC}"
}

#######################################
# Log verbose message
#######################################
log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        log "[VERBOSE] $1" "$YELLOW"
    fi
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
# T018: Argument parsing
#######################################
parse_args() {
    ADDITIONAL_MOUNTS=()
    ADDITIONAL_PORTS=()

    while [[ $# -gt 0 ]]; do
        case $1 in
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --name)
                ENV_NAME="$2"
                shift 2
                ;;
            --mount)
                ADDITIONAL_MOUNTS+=("$2")
                shift 2
                ;;
            --port)
                ADDITIONAL_PORTS+=("$2")
                shift 2
                ;;
            --secret)
                # T073: Parse and validate secret
                SECRETS+=("$2")
                shift 2
                ;;
            --verbose)
                VERBOSE=true
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

    # Set default config file if not specified
    if [[ -z "$CONFIG_FILE" ]]; then
        CONFIG_FILE="$PROJECT_ROOT/config/.env"
    fi

    log_verbose "Parsed arguments: CONFIG_FILE=$CONFIG_FILE, ENV_NAME=$ENV_NAME, VERBOSE=$VERBOSE"
}

#######################################
# Load configuration from file
# T019: Configuration loading
#######################################
load_config() {
    log_verbose "Loading configuration from: $CONFIG_FILE"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        error_exit "Configuration file not found: $CONFIG_FILE" $EXIT_INVALID_ARGS
    fi

    # Source the config file
    set -a  # Mark variables for export
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
    set +a

    # Override ENV_NAME if provided via command line
    if [[ -n "${ENV_NAME:-}" ]] && [[ "$ENV_NAME" != "" ]]; then
        log_verbose "Using environment name from command line: $ENV_NAME"
    elif [[ -z "${ENV_NAME:-}" ]]; then
        error_exit "ENV_NAME not set in config file or command line" $EXIT_INVALID_ARGS
    fi

    log_verbose "Configuration loaded successfully"
}

#######################################
# Validate configuration
# T020: Configuration validation
#######################################
validate_config() {
    log_verbose "Validating configuration..."

    # Required fields
    [[ -z "${ENV_NAME:-}" ]] && error_exit "ENV_NAME is required" $EXIT_INVALID_ARGS
    [[ -z "${BASE_IMAGE:-}" ]] && error_exit "BASE_IMAGE is required" $EXIT_INVALID_ARGS
    [[ -z "${WORK_DIR:-}" ]] && error_exit "WORK_DIR is required" $EXIT_INVALID_ARGS

    # Validate ENV_NAME format (alphanumeric + hyphens, max 64 chars)
    if [[ ! "$ENV_NAME" =~ ^[a-zA-Z0-9-]{1,64}$ ]]; then
        error_exit "ENV_NAME must be alphanumeric with hyphens, max 64 characters" $EXIT_INVALID_ARGS
    fi

    # Validate HOST_MOUNTS paths exist
    if [[ -n "${HOST_MOUNTS:-}" ]]; then
        IFS=',' read -ra MOUNTS <<< "$HOST_MOUNTS"
        for mount in "${MOUNTS[@]}"; do
            IFS=':' read -r host_path container_path mode <<< "$mount"
            if [[ ! -e "$host_path" ]]; then
                error_exit "Mount path does not exist: $host_path" $EXIT_INVALID_PATHS
            fi
        done
    fi

    log_verbose "Configuration validated successfully"
}

#######################################
# Validate secrets
# T075: Secret validation
#######################################
validate_secrets() {
    if [[ ${#SECRETS[@]} -eq 0 ]]; then
        return 0
    fi

    log_verbose "Validating secrets..."

    for secret in "${SECRETS[@]}"; do
        # Check KEY=VALUE format
        if [[ ! "$secret" =~ ^[A-Za-z_][A-Za-z0-9_]*=.*$ ]]; then
            error_exit "Invalid secret format: '$secret'. Must be KEY=VALUE" $EXIT_INVALID_ARGS
        fi

        # Extract key for logging
        local key="${secret%%=*}"
        log_verbose "Secret validated: $key"
    done

    log_verbose "All secrets validated successfully"
}

#######################################
# Check prerequisites
# T021: OrbStack prerequisite check
#######################################
check_prerequisites() {
    log_verbose "Checking prerequisites..."

    # Check if docker command is available
    if ! command -v docker &> /dev/null; then
        error_exit "Docker command not found. Please install OrbStack or Docker." $EXIT_PREREQ_NOT_MET
    fi

    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        error_exit "Docker daemon is not running. Please start OrbStack or Docker." $EXIT_PREREQ_NOT_MET
    fi

    log_verbose "Prerequisites check passed"
}

#######################################
# Check for resource conflicts
# T023: Port and name conflict detection
#######################################
check_conflicts() {
    log_verbose "Checking for resource conflicts..."

    # Check if container name already exists
    if docker ps -a --format '{{.Names}}' | grep -q "^${ENV_NAME}$"; then
        error_exit "Container with name '$ENV_NAME' already exists" $EXIT_RESOURCE_CONFLICT
    fi

    # Check for port conflicts
    if [[ -n "${PORTS:-}" ]]; then
        IFS=',' read -ra PORT_MAPPINGS <<< "$PORTS"
        for port_mapping in "${PORT_MAPPINGS[@]}"; do
            IFS=':' read -r host_port container_port <<< "$port_mapping"
            if lsof -Pi :$host_port -sTCP:LISTEN -t >/dev/null 2>&1; then
                error_exit "Port $host_port is already in use" $EXIT_RESOURCE_CONFLICT
            fi
        done
    fi

    log_verbose "No resource conflicts detected"
}

#######################################
# Build or pull Docker image
# T022: Image pull/build logic
#######################################
prepare_image() {
    log_verbose "Preparing Docker image..."

    local dockerfile="$PROJECT_ROOT/Dockerfile"

    if [[ -f "$dockerfile" ]]; then
        log "Building Docker image from $dockerfile..."
        docker build -t "isolated-dev-env:latest" "$PROJECT_ROOT" || \
            error_exit "Failed to build Docker image" $EXIT_CONTAINER_FAILURE
    else
        log "Pulling base image: $BASE_IMAGE..."
        docker pull "$BASE_IMAGE" || \
            error_exit "Failed to pull image: $BASE_IMAGE" $EXIT_CONTAINER_FAILURE
    fi

    log_verbose "Image prepared successfully"
}

#######################################
# Create and start container
# T023: Container creation logic
# T024: Container start and health check
#######################################
create_container() {
    log_verbose "Creating container '$ENV_NAME'..."

    local docker_args=()

    # Basic configuration
    docker_args+=("--name" "$ENV_NAME")
    docker_args+=("-w" "$WORK_DIR")
    docker_args+=("-d")  # Detached mode
    docker_args+=("-it") # Interactive with TTY

    # Add volume mounts
    if [[ -n "${HOST_MOUNTS:-}" ]]; then
        IFS=',' read -ra MOUNTS <<< "$HOST_MOUNTS"
        for mount in "${MOUNTS[@]}"; do
            IFS=':' read -r host_path container_path mode <<< "$mount"
            if [[ -n "$mode" ]] && [[ "$mode" == "ro" ]]; then
                docker_args+=("-v" "$host_path:$container_path:ro")
            else
                docker_args+=("-v" "$host_path:$container_path")
            fi
        done
    fi

    # Add additional mounts from command line
    for mount in "${ADDITIONAL_MOUNTS[@]:-}"; do
        IFS=':' read -r host_path container_path mode <<< "$mount"
        if [[ -n "$mode" ]] && [[ "$mode" == "ro" ]]; then
            docker_args+=("-v" "$host_path:$container_path:ro")
        else
            docker_args+=("-v" "$host_path:$container_path")
        fi
    done

    # Add port mappings
    if [[ -n "${PORTS:-}" ]]; then
        IFS=',' read -ra PORT_MAPPINGS <<< "$PORTS"
        for port_mapping in "${PORT_MAPPINGS[@]}"; do
            # Skip empty port mappings
            if [[ -n "$port_mapping" ]]; then
                docker_args+=("-p" "$port_mapping")
            fi
        done
    fi

    # Add additional ports from command line
    for port in "${ADDITIONAL_PORTS[@]:-}"; do
        if [[ -n "$port" ]]; then
            docker_args+=("-p" "$port")
        fi
    done

    # Add environment variables
    if [[ -n "${ENVIRONMENT_VARS:-}" ]]; then
        IFS=',' read -ra ENV_VARS <<< "$ENVIRONMENT_VARS"
        for env_var in "${ENV_VARS[@]}"; do
            # Skip empty environment variables
            if [[ -n "$env_var" ]]; then
                docker_args+=("-e" "$env_var")
            fi
        done
    fi

    # T076: Inject secrets as environment variables
    for secret in "${SECRETS[@]:-}"; do
        if [[ -n "$secret" ]]; then
            docker_args+=("-e" "$secret")
            # T078: Log secret key (not value) for debugging
            local key="${secret%%=*}"
            log_verbose "Injecting secret: $key"
        fi
    done

    # Determine which image to use
    local image_name="isolated-dev-env:latest"
    if [[ ! -f "$PROJECT_ROOT/Dockerfile" ]]; then
        image_name="$BASE_IMAGE"
    fi

    # Create and start container
    log "Creating environment '$ENV_NAME'..."
    if ! docker run "${docker_args[@]}" "$image_name" /bin/bash; then
        error_exit "Failed to create container" $EXIT_CONTAINER_FAILURE
    fi

    # Wait for container to be healthy (T024)
    log_verbose "Waiting for container to be ready..."
    local max_wait=30
    local waited=0
    while [[ $waited -lt $max_wait ]]; do
        if docker ps --filter "name=$ENV_NAME" --format '{{.Status}}' | grep -q "Up"; then
            log_verbose "Container is ready"
            break
        fi
        sleep 1
        ((waited++))
    done

    if [[ $waited -ge $max_wait ]]; then
        error_exit "Container failed to start within ${max_wait}s" $EXIT_CONTAINER_FAILURE
    fi

    log_verbose "Container created and started successfully"
}

#######################################
# Display success information
# T025: Success output formatting
#######################################
show_success() {
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GREEN"
    log "✓ Environment '$ENV_NAME' created successfully!" "$GREEN"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GREEN"
    echo ""
    log "Container Information:"
    log "  Name: $ENV_NAME"
    log "  Image: $(docker inspect --format='{{.Config.Image}}' "$ENV_NAME")"
    log "  Status: $(docker inspect --format='{{.State.Status}}' "$ENV_NAME")"
    echo ""
    log "Next Steps:"
    log "  1. Access shell:    ./scripts/dev-env-shell.sh $ENV_NAME"
    log "  2. Tear down:       ./scripts/dev-env-down.sh $ENV_NAME"
    echo ""
    log "Working Directory: $WORK_DIR"

    if [[ -n "${PORTS:-}" ]]; then
        log "Port Mappings:"
        IFS=',' read -ra PORT_MAPPINGS <<< "$PORTS"
        for port in "${PORT_MAPPINGS[@]}"; do
            log "  - $port"
        done
    fi
}

#######################################
# Main function
#######################################
main() {
    parse_args "$@"
    load_config
    validate_config
    validate_secrets  # T075: Validate secrets before proceeding
    check_prerequisites
    check_conflicts
    prepare_image
    create_container
    show_success
}

# Run main function
main "$@"
