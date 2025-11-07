# Data Model: Isolated Development Environment

**Date**: 2025-11-07
**Feature**: Isolated Development Environment

## Overview

This document defines the data structures and configuration formats used by the isolated development environment system. Since this is an infrastructure tooling feature (not an application with traditional data storage), the "entities" are primarily configuration structures and runtime state.

---

## Entity 1: Environment Configuration

**Purpose**: Defines the configuration for an isolated development environment instance.

### Attributes

| Attribute | Type | Required | Description | Validation Rules |
|-----------|------|----------|-------------|------------------|
| `name` | string | Yes | Unique identifier for the environment | Alphanumeric + hyphens, max 64 chars |
| `base_image` | string | Yes | Container base image to use | Valid OrbStack/Docker image reference |
| `nodejs_version` | string | Yes | NodeJS LTS version to install | Format: `lts/*` or specific version like `20.x` |
| `python_version` | string | Yes | Python version to install | Format: `3.11+` or specific version |
| `work_dir` | string | Yes | Working directory inside container | Absolute path |
| `host_mounts` | array | No | Host directories to mount | Array of Mount objects (see below) |
| `environment_vars` | map | No | Non-secret environment variables | Key-value pairs, no secrets allowed |
| `ports` | array | No | Ports to expose from container | Array of Port objects (see below) |
| `persist_data` | boolean | No | Whether to use named volumes for persistence | Default: false (ephemeral) |

### Sub-Entity: Mount

| Attribute | Type | Required | Description | Validation Rules |
|-----------|------|----------|-------------|------------------|
| `host_path` | string | Yes | Path on host macOS system | Must be absolute path, must exist |
| `container_path` | string | Yes | Path inside container | Must be absolute path |
| `read_only` | boolean | No | Whether mount is read-only | Default: false |

### Sub-Entity: Port

| Attribute | Type | Required | Description | Validation Rules |
|-----------|------|----------|-------------|------------------|
| `host_port` | integer | Yes | Port on host | 1-65535 range |
| `container_port` | integer | Yes | Port inside container | 1-65535 range |
| `protocol` | string | No | Protocol (tcp/udp) | Default: tcp |

### Configuration File Format

**File**: `.env` or passed via command-line arguments

```bash
# Environment name
ENV_NAME=claude-dev-001

# Base configuration
BASE_IMAGE=ubuntu:22.04
NODEJS_VERSION=lts/*
PYTHON_VERSION=3.11

# Working directory
WORK_DIR=/workspace

# Host mounts (comma-separated)
HOST_MOUNTS=/Users/me/projects:/workspace:rw,/Users/me/shared:/shared:ro

# Environment variables (non-secrets)
NODE_ENV=development
PYTHON_ENV=development

# Ports (comma-separated host:container)
PORTS=3000:3000,8000:8000

# Persistence
PERSIST_DATA=false
```

### Relationships

- One Environment Configuration → Many Mounts
- One Environment Configuration → Many Ports
- One Environment Configuration → One Runtime State (see below)

### State Transitions

```
[Not Created]
    ↓ (dev-env-up.sh)
[Creating]
    ↓ (image build + container start)
[Running]
    ↓ (dev-env-down.sh)
[Destroying]
    ↓ (cleanup complete)
[Not Created]
```

### Validation Rules

1. Environment name must be unique per user
2. Host mount paths must exist before environment creation
3. No secrets allowed in environment_vars (enforced by validation)
4. Port conflicts with host checked before container start
5. Base image must be valid and accessible

---

## Entity 2: Secret Configuration

**Purpose**: Represents secrets (API keys, credentials) provided at environment startup, stored only in memory.

### Attributes

| Attribute | Type | Required | Description | Validation Rules |
|-----------|------|----------|-------------|------------------|
| `key` | string | Yes | Secret variable name | Must start with letter, alphanumeric + underscore |
| `value` | string | Yes | Secret value | Any string, supports multi-line |
| `inject_method` | enum | Yes | How secret is injected | `env_var`, `file` |
| `file_path` | string | Conditional | Path inside container if inject_method=file | Required if inject_method=file |

### Secret Injection Methods

**Method 1: Environment Variables**
```bash
# Passed at container start
dev-env-up.sh --secret API_KEY=abc123 --secret DB_PASSWORD=secret
```

**Method 2: Secret Files**
```bash
# Mounted as read-only files
dev-env-up.sh --secret-file /secrets/api-key.txt:/app/secrets/api-key.txt
```

### Security Constraints

1. **NO Persistence**: Secrets MUST NOT be written to:
   - Container filesystem (except tmpfs)
   - Environment configuration files
   - Log files
   - Volume mounts

2. **Memory Only**: Secrets stored in:
   - Container process environment (wiped on container stop)
   - Temporary tmpfs mounts (memory-backed, auto-cleared)

3. **Validation**:
   - Reject if secret appears in non-secret config files
   - Warn if secret longer than 1MB (unusual)
   - Check for common secret patterns (API keys, tokens)

### Relationships

- One Secret Configuration → One Environment Instance (runtime binding)
- Secrets are NOT persisted across environment restarts

### State Lifecycle

```
[Provided at Startup]
    ↓ (inject into container)
[Available in Container]
    ↓ (container stopped/destroyed)
[Removed from Memory]
```

---

## Entity 3: Runtime State

**Purpose**: Tracks the current state and metadata of a running environment instance.

### Attributes

| Attribute | Type | Required | Description | Validation Rules |
|-----------|------|----------|-------------|------------------|
| `container_id` | string | Yes | OrbStack/Docker container ID | UUID format |
| `container_name` | string | Yes | Human-readable container name | Matches environment name |
| `status` | enum | Yes | Current state | `creating`, `running`, `stopped`, `error` |
| `created_at` | timestamp | Yes | When environment was created | ISO 8601 format |
| `last_accessed` | timestamp | No | Last shell access time | ISO 8601 format |
| `pid` | integer | No | Container main process ID | System PID |
| `ip_address` | string | No | Container IP address | IPv4 address |
| `resource_usage` | object | No | CPU/memory usage stats | ResourceUsage object |

### Sub-Entity: ResourceUsage

| Attribute | Type | Description |
|-----------|------|-------------|
| `cpu_percent` | float | CPU usage percentage |
| `memory_mb` | integer | Memory usage in MB |
| `disk_mb` | integer | Disk usage in MB |

### Storage

Runtime state is stored ephemerally:
- OrbStack/Docker maintains container metadata
- Our scripts query state via `docker inspect` or `orb` commands
- No persistent database needed

### Queries

**Get Environment Status**:
```bash
docker inspect <container_name> --format '{{.State.Status}}'
```

**Get Resource Usage**:
```bash
docker stats <container_name> --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}"
```

**List All Environments**:
```bash
docker ps -a --filter "label=type=dev-env" --format "table {{.Names}}\t{{.Status}}\t{{.CreatedAt}}"
```

---

## Entity 4: Development Runtime

**Purpose**: Represents installed language runtimes (NodeJS, Python) with their package managers.

### Attributes

| Attribute | Type | Required | Description | Validation Rules |
|-----------|------|----------|-------------|------------------|
| `runtime_type` | enum | Yes | Type of runtime | `nodejs`, `python` |
| `version` | string | Yes | Installed version | Semantic version format |
| `package_manager` | string | Yes | Package manager binary | `npm`, `yarn`, `pip`, `pipenv` |
| `global_packages` | array | No | Pre-installed global packages | Array of package names |
| `binary_path` | string | Yes | Path to runtime binary | Absolute path in container |

### Pre-Installed Runtimes

**NodeJS Runtime**:
```json
{
  "runtime_type": "nodejs",
  "version": "20.x.x",
  "package_manager": "npm",
  "global_packages": ["yarn"],
  "binary_path": "/usr/local/bin/node"
}
```

**Python Runtime**:
```json
{
  "runtime_type": "python",
  "version": "3.11.x",
  "package_manager": "pip",
  "global_packages": ["virtualenv", "pipenv"],
  "binary_path": "/usr/local/bin/python3"
}
```

### Validation

**At Container Build**:
```bash
# Verify NodeJS installation
node --version
npm --version
yarn --version

# Verify Python installation
python3 --version
pip --version
```

**At Runtime**:
```bash
# Test package installation
npm install --dry-run express
pip install --dry-run requests
```

### Relationships

- One Environment Instance → Many Development Runtimes (NodeJS, Python)
- Development Runtimes are immutable (baked into container image)

---

## Entity 5: Host Volume Mount

**Purpose**: Represents directories from the host macOS system mounted into the environment for code access.

### Attributes

| Attribute | Type | Required | Description | Validation Rules |
|-----------|------|----------|-------------|------------------|
| `mount_id` | string | Yes | Unique identifier | Auto-generated UUID |
| `source_path` | string | Yes | Host system path | Must exist, absolute path |
| `target_path` | string | Yes | Container path | Absolute path |
| `mode` | enum | Yes | Access mode | `ro` (read-only), `rw` (read-write) |
| `type` | enum | No | Mount type | `bind`, `volume`, `tmpfs` |

### Default Mounts

Every environment includes:

1. **Workspace Mount** (read-write):
   - Host: User-specified project directory
   - Container: `/workspace`
   - Mode: `rw`

2. **Temporary Mount** (tmpfs for secrets):
   - Host: N/A (memory)
   - Container: `/tmp/secrets`
   - Mode: `rw` (but tmpfs, wiped on stop)

### Mount Validation

```bash
# Before mount creation
- Check host path exists: `test -d "$HOST_PATH"`
- Check no conflicts: Ensure target path not already mounted
- Check permissions: Verify user can read/write host path

# After mount creation
- Verify mount active: `docker inspect --format '{{.Mounts}}' <container>`
- Test access: Write/read test file if rw mode
```

### Relationships

- One Environment Instance → Many Host Volume Mounts
- Volume Mounts are ephemeral (destroyed with container unless using named volumes)

---

## Data Flow Diagrams

### Environment Creation Flow

```
[User runs dev-env-up.sh]
    ↓
[Parse Configuration]
    ↓
[Validate Inputs]
    ├── Check host paths exist
    ├── Check port availability
    └── Validate secret formats
    ↓
[Build/Pull Container Image]
    ├── Install NodeJS runtime
    ├── Install Python runtime
    └── Install Claude Code
    ↓
[Start Container]
    ├── Apply environment variables
    ├── Mount host directories
    ├── Inject secrets (memory only)
    └── Expose ports
    ↓
[Update Runtime State]
    ↓
[Return Success + Container Info]
```

### Secret Injection Flow

```
[Secrets provided via CLI]
    ↓
[Validate Secret Format]
    ├── Check for common patterns
    ├── Validate not in config files
    └── Check size limits
    ↓
[Inject into Container]
    ├── As environment variables, OR
    └── As tmpfs-mounted files
    ↓
[Secrets available in container memory]
    ↓
[Container stopped]
    ↓
[Secrets wiped from memory]
```

### Environment Cleanup Flow

```
[User runs dev-env-down.sh]
    ↓
[Stop Container]
    ↓
[Remove Container]
    ├── Ephemeral data deleted
    ├── Secrets wiped from memory
    └── Tmpfs mounts cleared
    ↓
[Unmount Volumes]
    ├── Bind mounts released
    └── Named volumes kept (if persist_data=true)
    ↓
[Verify Cleanup]
    ├── Check no orphaned containers
    ├── Check no orphaned volumes (unless persisted)
    └── Check no orphaned networks
    ↓
[Return Success]
```

---

## Configuration Examples

### Minimal Configuration

```bash
# .env.minimal
ENV_NAME=my-dev-env
BASE_IMAGE=ubuntu:22.04
NODEJS_VERSION=lts/*
PYTHON_VERSION=3.11
WORK_DIR=/workspace
HOST_MOUNTS=/Users/me/project:/workspace:rw
```

### Full Configuration

```bash
# .env.full
ENV_NAME=claude-dev-advanced
BASE_IMAGE=ubuntu:22.04
NODEJS_VERSION=20.10.0
PYTHON_VERSION=3.11.5
WORK_DIR=/workspace

# Multiple mounts
HOST_MOUNTS=/Users/me/projects:/workspace:rw,/Users/me/shared:/shared:ro,/Users/me/data:/data:rw

# Environment variables
NODE_ENV=development
PYTHON_ENV=development
LOG_LEVEL=debug

# Port mappings
PORTS=3000:3000,8000:8000,5432:5432

# Persistence
PERSIST_DATA=true
```

### Secret Injection Example

```bash
# Command-line secret injection
dev-env-up.sh \
  --config .env.full \
  --secret API_KEY=sk-abc123xyz \
  --secret DB_PASSWORD="complex!pass@word" \
  --secret-file ~/.ssh/id_rsa:/home/dev/.ssh/id_rsa:ro
```

---

## Validation Schema Summary

### Configuration Validation

1. **Environment Name**: `^[a-zA-Z0-9-]{1,64}$`
2. **Base Image**: Must be pullable from registry
3. **Versions**: Must be valid semantic versions or version specifiers
4. **Paths**: Must be absolute paths
5. **Ports**: Must be integers in range 1-65535
6. **Secrets**: Must not appear in persisted config files

### Runtime Validation

1. **Container must be in 'running' state** before shell access
2. **Mounts must be accessible** (test read/write)
3. **Runtimes must be functional** (version checks pass)
4. **Ports must be listening** (if services started)

### Cleanup Validation

1. **Container removed**: `docker ps -a | grep <name>` returns nothing
2. **Volumes removed**: `docker volume ls | grep <name>` returns nothing (unless persisted)
3. **Networks cleaned**: No orphaned networks
4. **Secrets gone**: No files in host containing secret values
