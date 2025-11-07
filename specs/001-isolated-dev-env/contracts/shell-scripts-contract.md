# Shell Scripts Contract

**Date**: 2025-11-07
**Feature**: Isolated Development Environment

## Overview

This document defines the contract (interface and behavior) for the shell scripts that manage isolated development environments. These contracts ensure consistent behavior and enable automated testing.

---

## Script 1: dev-env-up.sh

**Purpose**: Spin up an isolated development environment

### Interface

```bash
./scripts/dev-env-up.sh [OPTIONS]
```

### Options

| Option | Required | Description | Example |
|--------|----------|-------------|---------|
| `--config FILE` | No | Configuration file path | `--config .env.dev` |
| `--name NAME` | No | Environment name (overrides config) | `--name my-env` |
| `--secret KEY=VALUE` | No | Inject secret as environment variable | `--secret API_KEY=abc123` |
| `--secret-file HOST:CONTAINER[:MODE]` | No | Mount secret file | `--secret-file ~/.ssh/id_rsa:/root/.ssh/id_rsa:ro` |
| `--mount HOST:CONTAINER[:MODE]` | No | Additional host directory mount | `--mount /Users/me/data:/data:rw` |
| `--port HOST:CONTAINER` | No | Additional port mapping | `--port 8080:80` |
| `--verbose` | No | Enable verbose logging | `--verbose` |
| `--help` | No | Show help message | `--help` |

### Behavior

**Success Path**:
1. Parse command-line arguments
2. Load configuration file (if specified)
3. Validate configuration and arguments
4. Check prerequisites (OrbStack running, images available)
5. Pull/build container image if needed
6. Create container with specified configuration
7. Start container
8. Wait for container to be healthy (max 30 seconds)
9. Output container information
10. Exit with code 0

**Error Handling**:
- Invalid arguments → print error, show help, exit code 1
- Configuration file not found → print error, exit code 1
- OrbStack not running → print error with instructions, exit code 2
- Port conflict → print error with conflicting service info, exit code 3
- Mount path doesn't exist → print error, exit code 4
- Container fails to start → print logs, cleanup, exit code 5

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Invalid arguments or configuration |
| 2 | Prerequisites not met (OrbStack not running) |
| 3 | Resource conflict (port, name) |
| 4 | Invalid paths (mount points) |
| 5 | Container creation/start failure |

### Output Format

**Success Output**:
```
✓ Environment 'my-env' created successfully

Container ID: abc123def456
Container Name: my-env
Status: running
IP Address: 192.168.65.3
Workspace: /workspace → /Users/me/project
Ports: 3000:3000, 8000:8000

Access shell: ./scripts/dev-env-shell.sh my-env
Stop environment: ./scripts/dev-env-down.sh my-env
```

**Verbose Output** (with --verbose):
```
[INFO] Loading configuration from .env.dev
[INFO] Validating configuration...
[INFO] ✓ Environment name: my-env
[INFO] ✓ Base image: ubuntu:22.04
[INFO] ✓ Host mounts: /Users/me/project exists
[INFO] ✓ Ports available: 3000, 8000
[INFO] Checking OrbStack status...
[INFO] ✓ OrbStack is running
[INFO] Pulling image ubuntu:22.04...
[INFO] Building custom image with NodeJS 20.x and Python 3.11...
[INFO] Creating container my-env...
[INFO] Mounting /Users/me/project to /workspace (rw)
[INFO] Injecting 2 secrets
[INFO] Starting container...
[INFO] Waiting for container to be healthy...
[INFO] ✓ Container healthy
[INFO] Environment ready
```

### Preconditions

- OrbStack installed and running
- User has permissions to run containers
- Host mount paths exist (if specified)
- Ports not already in use (if specified)
- Environment name not already in use

### Postconditions

- Container created and running
- All mounts active
- All ports mapped
- Secrets injected into container memory
- Container accessible via `dev-env-shell.sh`
- Exit code 0 returned

### Idempotency

**Behavior when environment already exists**:
- If container with same name already running → error with instructions to stop first
- If container with same name exists but stopped → ask user to remove or start existing
- NOT idempotent by design (to prevent accidental overwrites)

### Example Usage

```bash
# Minimal usage with defaults from .env
./scripts/dev-env-up.sh

# With custom config and secrets
./scripts/dev-env-up.sh \
  --config .env.production \
  --secret API_KEY=sk-abc123 \
  --secret-file ~/.ssh/id_rsa:/root/.ssh/id_rsa:ro

# With additional mounts and ports
./scripts/dev-env-up.sh \
  --name dev-001 \
  --mount /Users/me/data:/data:rw \
  --port 8080:80 \
  --verbose
```

---

## Script 2: dev-env-down.sh

**Purpose**: Stop and destroy an isolated development environment

### Interface

```bash
./scripts/dev-env-down.sh [NAME] [OPTIONS]
```

### Arguments

| Argument | Required | Description | Example |
|----------|----------|-------------|---------|
| `NAME` | Yes | Environment name to destroy | `my-env` |

### Options

| Option | Required | Description | Example |
|--------|----------|-------------|---------|
| `--keep-volumes` | No | Keep named volumes (don't delete) | `--keep-volumes` |
| `--force` | No | Force removal (no confirmation) | `--force` |
| `--verbose` | No | Enable verbose logging | `--verbose` |
| `--help` | No | Show help message | `--help` |

### Behavior

**Success Path**:
1. Parse arguments
2. Confirm environment exists
3. Ask for confirmation (unless --force)
4. Stop container gracefully (30 second timeout)
5. Remove container
6. Remove volumes (unless --keep-volumes)
7. Clean up any orphaned resources
8. Verify complete cleanup
9. Output confirmation
10. Exit with code 0

**Error Handling**:
- Environment not found → print error, exit code 1
- Container won't stop → force kill after timeout, exit code 0
- Cleanup verification fails → print warning, exit code 0 (best effort)

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success (or best effort success) |
| 1 | Environment not found |
| 2 | User cancelled operation |

### Output Format

**Success Output**:
```
Stopping environment 'my-env'...
✓ Container stopped
✓ Container removed
✓ Volumes cleaned up
✓ Secrets cleared

Environment 'my-env' has been completely removed.
```

**With Confirmation Prompt**:
```
This will destroy environment 'my-env' and all associated data.
Are you sure? [y/N]: y

Stopping environment 'my-env'...
✓ Container stopped
✓ Container removed
...
```

### Preconditions

- Environment exists (container created by dev-env-up.sh)
- User has permissions to remove containers

### Postconditions

- Container stopped
- Container removed
- Volumes removed (unless --keep-volumes)
- Secrets cleared from memory
- No orphaned resources
- Exit code 0

### Idempotency

**Idempotent**: Running multiple times on same environment is safe
- First run → removes environment
- Subsequent runs → reports "Environment not found" (exit code 1)

### Example Usage

```bash
# Basic usage with confirmation
./scripts/dev-env-down.sh my-env

# Force removal without confirmation
./scripts/dev-env-down.sh my-env --force

# Keep volumes for data persistence
./scripts/dev-env-down.sh my-env --keep-volumes

# Verbose output
./scripts/dev-env-down.sh my-env --verbose --force
```

---

## Script 3: dev-env-shell.sh

**Purpose**: Access the shell inside a running isolated environment

### Interface

```bash
./scripts/dev-env-shell.sh [NAME] [OPTIONS]
```

### Arguments

| Argument | Required | Description | Example |
|----------|----------|-------------|---------|
| `NAME` | Yes | Environment name to access | `my-env` |

### Options

| Option | Required | Description | Example |
|--------|----------|-------------|---------|
| `--user USER` | No | User to run shell as | `--user root` |
| `--workdir DIR` | No | Working directory in shell | `--workdir /workspace` |
| `--command CMD` | No | Run command instead of interactive shell | `--command "npm test"` |
| `--help` | No | Show help message | `--help` |

### Behavior

**Success Path** (interactive shell):
1. Parse arguments
2. Verify environment is running
3. Execute interactive shell in container
4. When user exits shell, return to host
5. Exit with code 0

**Success Path** (with --command):
1. Parse arguments
2. Verify environment is running
3. Execute specified command in container
4. Output command results
5. Exit with command's exit code

**Error Handling**:
- Environment not found → print error, exit code 1
- Environment not running → print error with start instructions, exit code 2
- Command fails → exit with command's exit code

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success (or command succeeded) |
| 1 | Environment not found |
| 2 | Environment not running |
| N | Command exit code (when using --command) |

### Output Format

**Interactive Shell**:
```
Accessing shell for environment 'my-env'...

dev@my-env:/workspace$
```

**Command Execution**:
```
Executing command in environment 'my-env': npm test

> test
> jest

PASS ./test.js
...
Test Suites: 1 passed, 1 total
```

### Preconditions

- Environment exists and is running
- User has permissions to access container

### Postconditions

- User has access to container shell or command executed
- Exit code reflects success/failure

### Idempotency

**Idempotent**: Can be run multiple times safely
- Each invocation creates new shell session

### Example Usage

```bash
# Interactive shell
./scripts/dev-env-shell.sh my-env

# Run specific command
./scripts/dev-env-shell.sh my-env --command "python --version"

# Access as root user
./scripts/dev-env-shell.sh my-env --user root

# Start in specific directory
./scripts/dev-env-shell.sh my-env --workdir /data
```

---

## Script 4: install-claude.sh

**Purpose**: Install Claude Code inside the container environment

### Interface

```bash
# Run inside container during image build or after container start
./scripts/install-claude.sh [OPTIONS]
```

### Options

| Option | Required | Description | Example |
|--------|----------|-------------|---------|
| `--version VERSION` | No | Claude Code version to install | `--version 1.5.0` |
| `--install-dir DIR` | No | Installation directory | `--install-dir /opt/claude` |
| `--verify` | No | Verify installation after install | `--verify` |
| `--help` | No | Show help message | `--help` |

### Behavior

**Success Path**:
1. Download Claude Code binary
2. Install to specified directory
3. Set execute permissions
4. Add to PATH
5. Verify installation (if --verify)
6. Exit with code 0

**Error Handling**:
- Download fails → retry 3 times, then exit code 1
- Installation directory not writable → print error, exit code 2
- Verification fails → print error, exit code 3

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Download failure |
| 2 | Installation failure |
| 3 | Verification failure |

### Output Format

```
Installing Claude Code...
✓ Downloaded Claude Code v1.5.0
✓ Installed to /opt/claude
✓ Added to PATH
✓ Verification passed

Claude Code is ready to use.
Run: claude --dangerously-skip-permissions
```

### Preconditions

- Network connectivity available
- Installation directory writable
- Sufficient disk space

### Postconditions

- Claude Code binary installed
- Binary in PATH
- Executable permissions set
- Exit code 0

### Example Usage

```bash
# Default installation
./scripts/install-claude.sh

# Specific version with verification
./scripts/install-claude.sh --version 1.5.0 --verify

# Custom install location
./scripts/install-claude.sh --install-dir /usr/local/bin
```

---

## Common Patterns

### Error Message Format

All scripts use consistent error formatting:

```
ERROR: <Short description>
<Detailed explanation>
<Suggested action>

Example:
ERROR: Environment 'my-env' not found
No container with name 'my-env' exists.
Run './scripts/dev-env-up.sh' to create a new environment.
```

### Success Message Format

```
✓ <Action completed>

Example:
✓ Environment created successfully
```

### Logging Levels

When `--verbose` flag is used:

- `[INFO]` - Informational messages
- `[WARN]` - Warnings (non-fatal issues)
- `[ERROR]` - Error messages
- `[DEBUG]` - Debug information (very verbose)

### Exit Code Convention

- `0` - Success
- `1` - General error (invalid input, not found)
- `2` - Precondition failure (dependency not met)
- `3` - Resource conflict
- `4` - Invalid paths/files
- `5` - Operation failure
- `N` - Command-specific exit codes (for dev-env-shell.sh)

---

## Testing Contracts

### Contract Tests

Each script must have contract tests that verify:

1. **Interface**: All documented options work as described
2. **Exit Codes**: Correct exit codes returned for each scenario
3. **Output Format**: Output matches documented format
4. **Preconditions**: Script validates preconditions correctly
5. **Postconditions**: Script achieves documented postconditions
6. **Idempotency**: Idempotency guarantees hold (where applicable)
7. **Error Handling**: All documented error scenarios handled correctly

### Test File Locations

```
tests/
├── test-dev-env-up.bats
├── test-dev-env-down.bats
├── test-dev-env-shell.bats
└── test-install-claude.bats
```

### Example Contract Test

```bash
#!/usr/bin/env bats

@test "dev-env-up.sh returns exit code 0 on success" {
  run ./scripts/dev-env-up.sh --name test-env --config test.env
  [ "$status" -eq 0 ]
}

@test "dev-env-up.sh returns exit code 3 on port conflict" {
  # Start environment on port 3000
  ./scripts/dev-env-up.sh --name env1 --port 3000:3000

  # Try to start another on same port
  run ./scripts/dev-env-up.sh --name env2 --port 3000:3000
  [ "$status" -eq 3 ]

  # Cleanup
  ./scripts/dev-env-down.sh env1 --force
}

@test "dev-env-up.sh output contains container ID" {
  run ./scripts/dev-env-up.sh --name test-env
  [[ "$output" == *"Container ID:"* ]]

  # Cleanup
  ./scripts/dev-env-down.sh test-env --force
}
```

---

## Integration Points

### Between Scripts

```
dev-env-up.sh
    ↓ (creates container)
dev-env-shell.sh
    ↓ (accesses container)
dev-env-down.sh
    ↓ (destroys container)
```

### With OrbStack/Docker

All scripts use OrbStack/Docker CLI commands:
- `docker run` - Start containers
- `docker exec` - Run commands in containers
- `docker stop` - Stop containers
- `docker rm` - Remove containers
- `docker ps` - List containers
- `docker inspect` - Get container details

### With Configuration Files

Scripts read from:
- `.env` files (environment configuration)
- `.env.template` (template for users to copy)
- Command-line arguments (override config file values)

Priority order:
1. Command-line arguments (highest)
2. Environment variables
3. Configuration file
4. Default values (lowest)
