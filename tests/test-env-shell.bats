#!/usr/bin/env bats
# Tests for dev-env-shell.sh script
# User Story 2: Run Claude Code Inside Environment

# Load test helpers
load test_helper/bats-support/load
load test_helper/bats-assert/load
load test_helper/bats-file/load

# Setup and teardown
setup() {
    export TEST_ENV_NAME="test-shell-$$"
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

    # Create environment
    ./scripts/dev-env-up.sh --config "$TEST_DIR/.env.test" >/dev/null 2>&1
}

teardown() {
    # Cleanup test environment
    if docker ps -a --format '{{.Names}}' | grep -q "^${TEST_ENV_NAME}$"; then
        docker rm -f "$TEST_ENV_NAME" >/dev/null 2>&1 || true
    fi
    rm -rf "$TEST_DIR"
}

# T039: Test for shell access
@test "dev-env-shell.sh provides access to environment" {
    # Execute a simple command via the shell script
    run ./scripts/dev-env-shell.sh "$TEST_ENV_NAME" --command "echo 'test'"
    assert_success
    assert_output --partial "test"
}

# T040: Test for command execution (--command flag)
@test "dev-env-shell.sh executes commands with --command flag" {
    # Test single command execution
    run ./scripts/dev-env-shell.sh "$TEST_ENV_NAME" --command "pwd"
    assert_success
    assert_output --partial "/workspace"

    # Test command that generates output
    run ./scripts/dev-env-shell.sh "$TEST_ENV_NAME" --command "node --version"
    assert_success
    assert_output --regexp "v[0-9]+\.[0-9]+\.[0-9]+"

    # Test Python command
    run ./scripts/dev-env-shell.sh "$TEST_ENV_NAME" --command "python --version"
    assert_success
    assert_output --partial "Python 3.11"
}

# T041: Test for user switching (--user flag)
@test "dev-env-shell.sh supports user switching with --user flag" {
    # Run as root (default)
    run ./scripts/dev-env-shell.sh "$TEST_ENV_NAME" --command "whoami"
    assert_success
    assert_output "root"

    # Verify --user flag is accepted (may not have other users yet)
    run ./scripts/dev-env-shell.sh "$TEST_ENV_NAME" --user root --command "whoami"
    assert_success
    assert_output "root"
}

@test "dev-env-shell.sh supports working directory option" {
    # Create a subdirectory in the mounted workspace
    docker exec "$TEST_ENV_NAME" mkdir -p /workspace/subdir

    # Execute command in different working directory
    run ./scripts/dev-env-shell.sh "$TEST_ENV_NAME" --workdir /workspace/subdir --command "pwd"
    assert_success
    assert_output "/workspace/subdir"
}

@test "dev-env-shell.sh fails gracefully for non-existent environment" {
    run ./scripts/dev-env-shell.sh "nonexistent-env-$$" --command "echo test"
    assert_failure
    assert_output --partial "not found"
}

@test "dev-env-shell.sh shows help message" {
    run ./scripts/dev-env-shell.sh --help
    assert_success
    assert_output --partial "Usage:"
}
