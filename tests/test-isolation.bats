#!/usr/bin/env bats
# Tests for environment isolation
# User Story 1: Verify that the isolated environment is truly isolated from host

# Load test helpers
load test_helper/bats-support/load
load test_helper/bats-assert/load
load test_helper/bats-file/load

# Setup and teardown
setup() {
    export TEST_ENV_NAME="test-isolation-$$"
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

# T014: Test for filesystem isolation
@test "container filesystem is isolated from host filesystem" {
    # Create the environment
    run ./scripts/dev-env-up.sh --config "$TEST_DIR/.env.test"
    assert_success

    # Create a file on the host in a non-mounted directory
    HOST_TEST_FILE="/tmp/host-only-file-$$"
    echo "host content" > "$HOST_TEST_FILE"

    # Try to access it from the container - should NOT exist
    run docker exec "$TEST_ENV_NAME" test -f "$HOST_TEST_FILE"
    assert_failure

    # Verify container can create its own files without affecting host
    run docker exec "$TEST_ENV_NAME" touch /tmp/container-only-file
    assert_success

    # This file should NOT exist on host
    assert [ ! -f "/tmp/container-only-file" ]

    # Cleanup
    rm -f "$HOST_TEST_FILE"
}

# T015: Test for process isolation
@test "container processes are isolated from host processes" {
    # Create the environment
    run ./scripts/dev-env-up.sh --config "$TEST_DIR/.env.test"
    assert_success

    # Start a process in the container
    docker exec -d "$TEST_ENV_NAME" sleep 3600

    # Get the PID from inside the container
    CONTAINER_PID=$(docker exec "$TEST_ENV_NAME" pgrep sleep)

    # Verify we can see it from inside the container
    run docker exec "$TEST_ENV_NAME" ps aux
    assert_output --partial "sleep 3600"

    # The host should not be able to kill it directly using the container's PID
    # (because PIDs are namespaced)
    run kill -0 "$CONTAINER_PID" 2>/dev/null
    assert_failure
}

@test "container uses its own network namespace" {
    # Create the environment
    run ./scripts/dev-env-up.sh --config "$TEST_DIR/.env.test"
    assert_success

    # Get container's IP
    CONTAINER_IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$TEST_ENV_NAME")

    # Container IP should be different from host
    assert [ -n "$CONTAINER_IP" ]
    assert [ "$CONTAINER_IP" != "127.0.0.1" ]

    # Container should have its own network interfaces
    run docker exec "$TEST_ENV_NAME" ip addr show
    assert_success
    assert_output --partial "lo"
    assert_output --partial "eth0"
}
