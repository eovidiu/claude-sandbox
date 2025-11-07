#!/usr/bin/env bats
# Tests for NodeJS and Python runtime support
# User Story 3: NodeJS and Python Development Support

# Load test helpers
load test_helper/bats-support/load
load test_helper/bats-assert/load
load test_helper/bats-file/load

# Setup and teardown
setup() {
    export TEST_ENV_NAME="test-runtimes-$$"
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

# T054: Test for NodeJS version check
@test "NodeJS is installed and version can be checked" {
    run ./scripts/dev-env-shell.sh "$TEST_ENV_NAME" --command "node --version"
    assert_success
    assert_output --regexp "v[0-9]+\.[0-9]+\.[0-9]+"
}

# T055: Test for npm version check
@test "npm is installed and version can be checked" {
    run ./scripts/dev-env-shell.sh "$TEST_ENV_NAME" --command "npm --version"
    assert_success
    assert_output --regexp "[0-9]+\.[0-9]+\.[0-9]+"
}

# T056: Test for yarn version check
@test "yarn is installed and version can be checked" {
    run ./scripts/dev-env-shell.sh "$TEST_ENV_NAME" --command "yarn --version"
    assert_success
    assert_output --regexp "[0-9]+\.[0-9]+\.[0-9]+"
}

# T057: Test for Python version check
@test "Python 3.11+ is installed and version can be checked" {
    run ./scripts/dev-env-shell.sh "$TEST_ENV_NAME" --command "python --version"
    assert_success
    assert_output --partial "Python 3.11"
}

# T058: Test for pip version check
@test "pip is installed and version can be checked" {
    run ./scripts/dev-env-shell.sh "$TEST_ENV_NAME" --command "pip --version"
    assert_success
    assert_output --regexp "pip [0-9]+\.[0-9]+"
}

# T059: Test for npm package installation
@test "npm can install packages successfully" {
    # Install a small test package
    run ./scripts/dev-env-shell.sh "$TEST_ENV_NAME" --command "npm install --no-save lodash 2>&1 | tail -5"
    assert_success

    # Verify package can be required
    run ./scripts/dev-env-shell.sh "$TEST_ENV_NAME" --command "node -e \"require('lodash')\""
    assert_success
}

# T060: Test for pip package installation
@test "pip can install packages successfully" {
    # Install a small test package
    run ./scripts/dev-env-shell.sh "$TEST_ENV_NAME" --command "pip install requests >/dev/null 2>&1 && echo 'Success'"
    assert_success
    assert_output --partial "Success"

    # Verify package can be imported
    run ./scripts/dev-env-shell.sh "$TEST_ENV_NAME" --command "python -c 'import requests; print(requests.__version__)'"
    assert_success
    assert_output --regexp "[0-9]+\.[0-9]+\.[0-9]+"
}

@test "NodeJS can execute JavaScript code" {
    run ./scripts/dev-env-shell.sh "$TEST_ENV_NAME" --command "node -e \"console.log('Hello from Node')\""
    assert_success
    assert_output "Hello from Node"
}

@test "Python can execute Python code" {
    run ./scripts/dev-env-shell.sh "$TEST_ENV_NAME" --command "python -c \"print('Hello from Python')\""
    assert_success
    assert_output "Hello from Python"
}

@test "npm can create and run a simple package.json project" {
    # Create a simple package.json
    run ./scripts/dev-env-shell.sh "$TEST_ENV_NAME" --command "echo '{\"name\":\"test\",\"version\":\"1.0.0\"}' > /workspace/package.json && npm install --silent && echo 'OK'"
    assert_success
    assert_output --partial "OK"
}

@test "Python virtual environment can be created" {
    # Test that venv module is available
    run ./scripts/dev-env-shell.sh "$TEST_ENV_NAME" --command "python -m venv /tmp/test_venv && echo 'venv created'"
    assert_success
    assert_output --partial "venv created"
}
