# Isolated Development Environment

Create safe, isolated development environments for running Claude Code with relaxed permissions, pre-configured with NodeJS and Python.

## Overview

This project provides scripts and configuration to spin up isolated containerized development environments on macOS. The primary use case is running Claude Code with `--dangerously-skip-permissions` safely without affecting your host system.

## Features

- ✅ **Isolated Environment**: Complete isolation from host macOS system
- ✅ **Pre-configured Runtimes**: NodeJS LTS and Python 3.11+ pre-installed
- ✅ **Claude Code Ready**: Easy npm-based installation script included
- ✅ **Secret Management**: Inject secrets at startup without disk persistence
- ✅ **Simple Commands**: Single-command spin-up and tear-down
- ✅ **Fast**: ~4 second spin-up (with cached image), 30 second tear-down

## Prerequisites

- **macOS** (Intel or Apple Silicon)
- **OrbStack** (recommended) or Docker Desktop
  ```bash
  brew install orbstack
  ```
- **bats-core** (for running tests)
  ```bash
  brew install bats-core bats-support bats-assert bats-file
  ```

## Quick Start

### 1. Configure Your Environment

```bash
# Copy the template
cp config/.env.template config/.env

# Edit config/.env to set your project directory mount path
# Example: HOST_MOUNTS=/Users/yourname/projects:/workspace:rw
nano config/.env
```

### 2. Start Your Environment

```bash
# Basic usage
./scripts/dev-env-up.sh

# With custom configuration
./scripts/dev-env-up.sh --config .env

# With secrets
./scripts/dev-env-up.sh --secret API_KEY=abc123 --secret DB_PASSWORD=secret
```

### 3. Access Your Environment

```bash
# Interactive shell
./scripts/dev-env-shell.sh claude-dev

# Run a single command
./scripts/dev-env-shell.sh claude-dev --command "node --version"
```

### 4. Stop Your Environment

```bash
# With confirmation
./scripts/dev-env-down.sh claude-dev

# Force removal without confirmation
./scripts/dev-env-down.sh claude-dev --force
```

## Detailed Usage

### Creating Environments

**Basic creation:**
```bash
./scripts/dev-env-up.sh
```

**With custom configuration:**
```bash
./scripts/dev-env-up.sh --config my-config.env
```

**With additional mounts:**
```bash
./scripts/dev-env-up.sh --mount /host/data:/container/data:ro
```

**With port mappings:**
```bash
./scripts/dev-env-up.sh --port 8080:8080 --port 5432:5432
```

**With secrets (memory-only, not persisted):**
```bash
./scripts/dev-env-up.sh \
  --secret "API_KEY=sk-1234567890" \
  --secret "DB_PASSWORD=secure-pass" \
  --secret "JWT_SECRET=secret-key"
```

**Combined example:**
```bash
./scripts/dev-env-up.sh \
  --name my-project \
  --mount ~/projects/my-app:/workspace:rw \
  --port 3000:3000 \
  --secret "API_KEY=abc123" \
  --verbose
```

### Accessing Environments

**Interactive shell:**
```bash
./scripts/dev-env-shell.sh claude-dev
```

**Execute single command:**
```bash
./scripts/dev-env-shell.sh claude-dev --command "node --version"
```

**Run as different user:**
```bash
./scripts/dev-env-shell.sh claude-dev --user root --command "apt-get update"
```

**Change working directory:**
```bash
./scripts/dev-env-shell.sh claude-dev --workdir /tmp --command "pwd"
```

**NodeJS development:**
```bash
# Check versions
./scripts/dev-env-shell.sh claude-dev --command "node --version"
./scripts/dev-env-shell.sh claude-dev --command "npm --version"
./scripts/dev-env-shell.sh claude-dev --command "yarn --version"

# Install packages
./scripts/dev-env-shell.sh claude-dev --command "npm install express"

# Run your app
./scripts/dev-env-shell.sh claude-dev --command "node app.js"
```

**Python development:**
```bash
# Check versions
./scripts/dev-env-shell.sh claude-dev --command "python --version"
./scripts/dev-env-shell.sh claude-dev --command "pip --version"

# Install packages
./scripts/dev-env-shell.sh claude-dev --command "pip install requests"

# Create virtual environment
./scripts/dev-env-shell.sh claude-dev --command "python -m venv venv"

# Use pipenv
./scripts/dev-env-shell.sh claude-dev --command "pipenv install flask"
```

**Claude Code usage:**
```bash
# Install Claude Code via npm (one-time, inside container)
./scripts/dev-env-shell.sh claude-dev --command "install-claude.sh --verify"

# Access interactive shell (Claude Code is available in PATH)
./scripts/dev-env-shell.sh claude-dev

# Inside the container:
claude --help
claude --dangerously-skip-permissions
```

**Note:** Claude Code is installed globally via npm (`@anthropic-ai/claude-code`). The entrypoint automatically makes it available in interactive shells.

### Destroying Environments

**With confirmation prompt:**
```bash
./scripts/dev-env-down.sh claude-dev
```

**Force removal (no prompt):**
```bash
./scripts/dev-env-down.sh claude-dev --force
```

**Keep volumes:**
```bash
./scripts/dev-env-down.sh claude-dev --keep-volumes --force
```

### Utility Scripts

**Verify runtimes:**
```bash
./scripts/dev-env-shell.sh claude-dev --command "verify-runtimes.sh"
```

**Install Claude Code:**
```bash
./scripts/dev-env-shell.sh claude-dev --command "install-claude.sh --verify"
```

## Scripts Reference

| Script | Purpose | Key Options |
|--------|---------|-------------|
| `scripts/dev-env-up.sh` | Create isolated environment | `--config`, `--name`, `--secret`, `--mount`, `--port`, `--verbose` |
| `scripts/dev-env-down.sh` | Destroy environment | `--force`, `--keep-volumes` |
| `scripts/dev-env-shell.sh` | Access shell or run commands | `--command`, `--user`, `--workdir` |
| `scripts/install-claude.sh` | Install Claude Code binary | `--verify`, `--install-dir` |
| `scripts/verify-runtimes.sh` | Verify NodeJS/Python setup | (run inside container) |

## Configuration

Configuration file: `config/.env.template`

Key settings:
- `ENV_NAME`: Container name (default: claude-dev)
- `HOST_MOUNTS`: Host→Container directory mappings
- `PORTS`: Port mappings (HOST:CONTAINER)
- `NODEJS_VERSION`: NodeJS version (default: lts/iron)
- `PYTHON_VERSION`: Python version (default: 3.11)
- `ENVIRONMENT_VARS`: Non-secret environment variables

**Never put secrets in config files!** Use `--secret` flag instead.

## Testing

Run tests to verify installation:

```bash
# Run all tests
bats tests/

# Run specific test suite
bats tests/test-env-up.bats
```

## Architecture

- **Base Image**: Ubuntu 22.04
- **Container Runtime**: OrbStack (Docker-compatible)
- **Runtimes**: NodeJS LTS, Python 3.11+
- **Testing**: bats-core

## Documentation

- See `specs/001-isolated-dev-env/` for detailed specifications and design documents
- See `docs/troubleshooting.md` for common issues and solutions
- All scripts support `--help` flag for detailed usage information

## Development

This project follows Test-Driven Development (TDD):
1. Tests are written first (in `tests/`)
2. Tests verified to fail
3. Implementation added to pass tests
4. Refactor while keeping tests green

## License

[Your License Here]

## Contributing

[Contributing guidelines here]
