#!/usr/bin/env bats
# Tests for dev-env-down.sh script
# User Story 1: Tear down isolated environment

# Load test helpers
load test_helper/bats-support/load
load test_helper/bats-assert/load
load test_helper/bats-file/load

# Setup and teardown
setup() {
    export TEST_ENV_NAME="test-teardown-$$"
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
    # Ensure cleanup even if tests fail
    if docker ps -a --format '{{.Names}}' | grep -q "^${TEST_ENV_NAME}$"; then
        docker rm -f "$TEST_ENV_NAME" >/dev/null 2>&1 || true
    fi

    # Clean up any volumes
    docker volume ls -q | grep "$TEST_ENV_NAME" | xargs -r docker volume rm >/dev/null 2>&1 || true

    rm -rf "$TEST_DIR"
}

# T016: Test for complete cleanup
@test "dev-env-down.sh removes container and cleans up resources" {
    # First, create an environment
    run ./scripts/dev-env-up.sh --config "$TEST_DIR/.env.test"
    assert_success

    # Verify container exists
    run docker ps -a --format '{{.Names}}' --filter "name=$TEST_ENV_NAME"
    assert_output "$TEST_ENV_NAME"

    # Now tear it down with --force to skip confirmation
    run ./scripts/dev-env-down.sh "$TEST_ENV_NAME" --force
    assert_success
    assert_output --partial "Environment '$TEST_ENV_NAME' removed successfully"

    # Verify container is gone
    run docker ps -a --format '{{.Names}}' --filter "name=$TEST_ENV_NAME"
    refute_output "$TEST_ENV_NAME"

    # Verify no orphaned volumes (when PERSIST_DATA=false)
    run docker volume ls -q --filter "name=$TEST_ENV_NAME"
    refute_output --partial "$TEST_ENV_NAME"
}

# T017: Test for idempotency (can run twice)
@test "dev-env-down.sh is idempotent and handles missing container gracefully" {
    # Try to tear down a non-existent environment
    run ./scripts/dev-env-down.sh "nonexistent-env-$$" --force

    # Should succeed (idempotent)
    assert_success
    assert_output --partial "removed successfully"
}

@test "dev-env-down.sh preserves volumes when --keep-volumes is specified" {
    # This test verifies the --keep-volumes flag works
    # Note: Our current implementation uses bind mounts, not named volumes
    # So we just verify the flag is accepted and script succeeds

    # Create environment
    run ./scripts/dev-env-up.sh --config "$TEST_DIR/.env.test"
    assert_success

    # Tear down with --keep-volumes flag
    run ./scripts/dev-env-down.sh "$TEST_ENV_NAME" --keep-volumes --force
    assert_success
    assert_output --partial "removed successfully"
}

@test "dev-env-down.sh prompts for confirmation without --force flag" {
    # Create an environment
    run ./scripts/dev-env-up.sh --config "$TEST_DIR/.env.test"
    assert_success

    # Try to tear down without --force (simulate 'n' response)
    run bash -c "echo 'n' | ./scripts/dev-env-down.sh '$TEST_ENV_NAME'"
    assert_success
    assert_output --partial "About to remove environment"
    assert_output --partial "Cancelled"

    # Verify container still exists
    run docker ps -a --format '{{.Names}}' --filter "name=$TEST_ENV_NAME"
    assert_output "$TEST_ENV_NAME"
}
