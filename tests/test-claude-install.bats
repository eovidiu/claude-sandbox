#!/usr/bin/env bats
# Tests for Claude Code installation
# User Story 2: Run Claude Code Inside Environment

# Load test helpers
load test_helper/bats-support/load
load test_helper/bats-assert/load
load test_helper/bats-file/load

# Setup and teardown
setup() {
    export TEST_ENV_NAME="test-claude-$$"
    export TEST_DIR="$(mktemp -d)"

    # Create test config
    cat > "$TEST_DIR/.env.test" <<EOF
ENV_NAME=$TEST_ENV_NAME
BASE_IMAGE=ubuntu:22.04
NODEJS_VERSION=lts/*
PYTHON_VERSION=3.11
WORK_DIR=/workspace
HOST_MOUNTS=$TEST_DIR:/workspace:rw
PORTS=
PERSIST_DATA=false
ENVIRONMENT_VARS=
EOF
}

teardown() {
    # Cleanup test environment
    if docker ps -a --format '{{.Names}}' | grep -q "^${TEST_ENV_NAME}$"; then
        docker rm -f "$TEST_ENV_NAME" >/dev/null 2>&1 || true
    fi
    rm -rf "$TEST_DIR"
}

# T037: Test for Claude Code installation script availability
@test "Claude Code installation script is available in container" {
    # Create environment
    run ./scripts/dev-env-up.sh --config "$TEST_DIR/.env.test"
    assert_success

    # Check if installation script exists
    run docker exec "$TEST_ENV_NAME" test -f /usr/local/bin/install-claude.sh
    assert_success

    # Verify it's executable
    run docker exec "$TEST_ENV_NAME" test -x /usr/local/bin/install-claude.sh
    assert_success
}

# T038: Test for installation script help/version
@test "Claude Code installation script shows help" {
    # Create environment
    run ./scripts/dev-env-up.sh --config "$TEST_DIR/.env.test"
    assert_success

    # Check script help
    run docker exec "$TEST_ENV_NAME" /usr/local/bin/install-claude.sh --help
    assert_success
    assert_output --partial "Usage:"
}

@test "Claude Code installation script can be run independently" {
    skip "Skipping actual Claude installation test - requires network access to Claude downloads"

    # Create a basic container
    docker run -d --name "$TEST_ENV_NAME" ubuntu:22.04 sleep infinity

    # Copy and run the installation script
    docker cp ./scripts/install-claude.sh "$TEST_ENV_NAME:/tmp/install-claude.sh"
    docker exec "$TEST_ENV_NAME" chmod +x /tmp/install-claude.sh

    run docker exec "$TEST_ENV_NAME" /tmp/install-claude.sh
    assert_success

    # Verify installation
    run docker exec "$TEST_ENV_NAME" which claude
    assert_success
}
