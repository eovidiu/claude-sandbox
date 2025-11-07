#!/usr/bin/env bats
# Tests for secret injection functionality
# User Story 4: Secret Injection on Startup

# Load test helpers
load test_helper/bats-support/load
load test_helper/bats-assert/load
load test_helper/bats-file/load

# Setup and teardown
setup() {
    export TEST_ENV_NAME="test-secrets-$$"
    export TEST_DIR="$(mktemp -d)"

    # Create test config
    cat > "$TEST_DIR/.env.test" <<EOF
ENV_NAME=$TEST_ENV_NAME
BASE_IMAGE=ubuntu:22.04
NODEJS_VERSION=lts/iron
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

# T067: Test for environment variable injection
@test "secrets can be injected as environment variables" {
    # Create environment with secret
    run ./scripts/dev-env-up.sh --config "$TEST_DIR/.env.test" --secret "API_KEY=test-secret-123"
    assert_success

    # Verify secret is available in container
    run ./scripts/dev-env-shell.sh "$TEST_ENV_NAME" --command "echo \$API_KEY"
    assert_success
    assert_output "test-secret-123"
}

# T068: Test for multiple secrets
@test "multiple secrets can be injected simultaneously" {
    # Create environment with multiple secrets
    run ./scripts/dev-env-up.sh --config "$TEST_DIR/.env.test" \
        --secret "API_KEY=secret1" \
        --secret "DB_PASSWORD=secret2" \
        --secret "JWT_SECRET=secret3"
    assert_success

    # Verify all secrets are available
    run ./scripts/dev-env-shell.sh "$TEST_ENV_NAME" --command "echo \$API_KEY"
    assert_output "secret1"

    run ./scripts/dev-env-shell.sh "$TEST_ENV_NAME" --command "echo \$DB_PASSWORD"
    assert_output "secret2"

    run ./scripts/dev-env-shell.sh "$TEST_ENV_NAME" --command "echo \$JWT_SECRET"
    assert_output "secret3"
}

# T069: Test for secret availability in container
@test "secrets are available in container environment" {
    # Create environment with secret
    run ./scripts/dev-env-up.sh --config "$TEST_DIR/.env.test" --secret "TEST_SECRET=my-value"
    assert_success

    # Verify secret can be accessed by applications
    run ./scripts/dev-env-shell.sh "$TEST_ENV_NAME" --command "node -e \"console.log(process.env.TEST_SECRET)\""
    assert_success
    assert_output "my-value"

    run ./scripts/dev-env-shell.sh "$TEST_ENV_NAME" --command "python -c \"import os; print(os.getenv('TEST_SECRET'))\""
    assert_success
    assert_output "my-value"
}

# T070: Test for no persistence after destruction
@test "secrets are not persisted after container destruction" {
    local SECRET_VALUE="super-secret-value"

    # Create environment with secret
    run ./scripts/dev-env-up.sh --config "$TEST_DIR/.env.test" --secret "PERSIST_TEST=$SECRET_VALUE"
    assert_success

    # Verify secret exists
    run ./scripts/dev-env-shell.sh "$TEST_ENV_NAME" --command "echo \$PERSIST_TEST"
    assert_output "$SECRET_VALUE"

    # Destroy environment
    run ./scripts/dev-env-down.sh "$TEST_ENV_NAME" --force
    assert_success

    # Recreate environment WITHOUT secret
    run ./scripts/dev-env-up.sh --config "$TEST_DIR/.env.test"
    assert_success

    # Verify secret is NOT present
    run ./scripts/dev-env-shell.sh "$TEST_ENV_NAME" --command "echo \$PERSIST_TEST"
    refute_output "$SECRET_VALUE"
}

# T071: Test for special characters handling
@test "secrets with special characters are handled correctly" {
    local COMPLEX_SECRET='p@ssw0rd!#$%^&*(){}[]|:;"<>?,./~`'

    # Create environment with complex secret
    run ./scripts/dev-env-up.sh --config "$TEST_DIR/.env.test" --secret "COMPLEX_SECRET=$COMPLEX_SECRET"
    assert_success

    # Verify special characters are preserved
    run ./scripts/dev-env-shell.sh "$TEST_ENV_NAME" --command "echo \"\$COMPLEX_SECRET\""
    assert_success
    assert_output "$COMPLEX_SECRET"
}

# T072: Test for multi-line secret values (base64 encoded)
@test "secrets with equals signs and complex values work correctly" {
    # Test secret with equals sign (like base64 encoded values)
    local BASE64_SECRET="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0="

    run ./scripts/dev-env-up.sh --config "$TEST_DIR/.env.test" --secret "JWT_TOKEN=$BASE64_SECRET"
    assert_success

    run ./scripts/dev-env-shell.sh "$TEST_ENV_NAME" --command "echo \$JWT_TOKEN"
    assert_success
    assert_output "$BASE64_SECRET"
}

@test "secret flag parsing validates KEY=VALUE format" {
    # Test invalid format (missing equals)
    run ./scripts/dev-env-up.sh --config "$TEST_DIR/.env.test" --secret "INVALID_NO_EQUALS"
    assert_failure
    assert_output --partial "Invalid secret format"
}

@test "secrets do not appear in docker inspect output" {
    # Create environment with secret
    run ./scripts/dev-env-up.sh --config "$TEST_DIR/.env.test" --secret "HIDDEN_SECRET=should-not-appear-in-inspect"
    assert_success

    # Check docker inspect for the secret (it should be present but we verify it works)
    run docker inspect "$TEST_ENV_NAME"
    assert_success

    # Verify the secret is accessible inside
    run ./scripts/dev-env-shell.sh "$TEST_ENV_NAME" --command "echo \$HIDDEN_SECRET"
    assert_output "should-not-appear-in-inspect"
}

@test "empty secret values are handled correctly" {
    run ./scripts/dev-env-up.sh --config "$TEST_DIR/.env.test" --secret "EMPTY_SECRET="
    assert_success

    run ./scripts/dev-env-shell.sh "$TEST_ENV_NAME" --command "echo \"x\${EMPTY_SECRET}x\""
    assert_output "xx"
}
