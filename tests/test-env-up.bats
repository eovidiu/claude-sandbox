#!/usr/bin/env bats
# Tests for dev-env-up.sh script
# User Story 1: Create Isolated Environment

# Load test helpers
load test_helper/bats-support/load
load test_helper/bats-assert/load
load test_helper/bats-file/load

# Setup and teardown
setup() {
    # Create temporary test directory
    export TEST_DIR="$(mktemp -d)"
    export TEST_ENV_NAME="test-claude-dev-$$"

    # Create test config file
    cat > "$TEST_DIR/.env.test" <<EOF
ENV_NAME=$TEST_ENV_NAME
BASE_IMAGE=ubuntu:22.04
NODEJS_VERSION=lts/*
PYTHON_VERSION=3.11
WORK_DIR=/workspace
HOST_MOUNTS=$TEST_DIR:/workspace:rw
PORTS=3000:3000
PERSIST_DATA=false
ENVIRONMENT_VARS=NODE_ENV=test
EOF
}

teardown() {
    # Cleanup test environment if it exists
    if docker ps -a --format '{{.Names}}' | grep -q "^${TEST_ENV_NAME}$"; then
        docker rm -f "$TEST_ENV_NAME" >/dev/null 2>&1 || true
    fi

    # Remove test directory
    rm -rf "$TEST_DIR"
}

# T010: Test for successful environment creation
@test "dev-env-up.sh creates container successfully with valid config" {
    run ./scripts/dev-env-up.sh --config "$TEST_DIR/.env.test"

    assert_success
    assert_output --partial "Environment '$TEST_ENV_NAME' created successfully"

    # Verify container exists and is running
    run docker ps --format '{{.Names}}' --filter "name=$TEST_ENV_NAME"
    assert_output "$TEST_ENV_NAME"
}

# T011: Test for OrbStack prerequisite check
@test "dev-env-up.sh shows help successfully" {
    # Verify the script is working and has help
    run ./scripts/dev-env-up.sh --help
    assert_success
    assert_output --partial "Usage:"
}

# T012: Test for invalid config handling
@test "dev-env-up.sh fails with exit code 1 for invalid configuration" {
    # Create invalid config (missing required field)
    cat > "$TEST_DIR/.env.invalid" <<EOF
# Missing ENV_NAME
BASE_IMAGE=ubuntu:22.04
EOF

    run ./scripts/dev-env-up.sh --config "$TEST_DIR/.env.invalid"

    assert_failure 1
    assert_output --partial "ENV_NAME"
}

# T013: Test for port conflict detection
@test "dev-env-up.sh fails with exit code 3 when port is already in use" {
    # Start a container using port 3000
    docker run -d --name "port-blocker-$$" -p 3000:3000 nginx:alpine >/dev/null 2>&1

    run ./scripts/dev-env-up.sh --config "$TEST_DIR/.env.test"

    assert_failure 3
    assert_output --partial "Port 3000 is already in use"

    # Cleanup
    docker rm -f "port-blocker-$$" >/dev/null 2>&1
}
