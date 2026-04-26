# Claude Sandbox

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker Build](https://github.com/eovidiu/claude-sandbox/actions/workflows/publish-docker-image.yml/badge.svg)](https://github.com/eovidiu/claude-sandbox/actions/workflows/publish-docker-image.yml)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Docker](https://img.shields.io/badge/Docker-Required-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Tests](https://img.shields.io/badge/Tests-40%20passing-success)](tests/)

**Run Claude Code with `--dangerously-skip-permissions` safely in an isolated container.**

Pre-configured with Node.js LTS (v20.x) and Python 3.11+ for full-stack development.

---

## Why Use This?

When you run Claude Code with `--dangerously-skip-permissions`, it can execute any command on your system. This sandbox provides:

- **Complete isolation** - Claude can't touch your host filesystem, only mounted directories
- **Safe experimentation** - Let Claude install packages, modify files, run scripts freely
- **Pre-configured runtimes** - Node.js, npm, yarn, Python, pip, virtualenv ready to go
- **Secret injection** - Pass API keys at runtime without persisting to disk
- **Fast iteration** - ~4s spin-up, 30s tear-down

---

## Recommended Setup (One-Time)

Add a `sandbox` command to your shell for instant access from any project.

### Step 1: Add to ~/.zshrc (or ~/.bashrc)

```bash
nano ~/.zshrc
```

Add this at the end:

```bash
# =============================================================================
# Claude Sandbox - Isolated development environment for Claude Code
# Usage: cd into any project directory and run 'sandbox'
# =============================================================================

export ANTHROPIC_API_KEY="your-api-key-here"

sandbox() {
    docker run -it --rm \
        --network bridge \
        -v "$PWD:/workspace:rw" \
        -e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
        ghcr.io/eovidiu/claude-sandbox:latest
}
```

### Step 2: Reload shell

```bash
source ~/.zshrc
```

### Step 3: Pull the image (optional, happens automatically)

```bash
docker pull ghcr.io/eovidiu/claude-sandbox:latest
```

---

## Daily Workflow

```bash
cd ~/work/any-project
sandbox
# Claude Code launches automatically with --dangerously-skip-permissions
```

Each run starts a fresh container and removes it on exit. Your current directory remains mounted read/write at `/workspace`.

---

## Shell Commands Reference

| Command | What it does |
|---------|--------------|
| `sandbox` | Launch Claude Code in sandbox for current directory |

---

## Alternative: Direct Docker (No Setup)

If you don't want to modify your shell config:

```bash
# Run with your current project mounted
docker run -it --rm \
  --network bridge \
  -v "$PWD:/workspace:rw" \
  -e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
  ghcr.io/eovidiu/claude-sandbox:latest

# Claude Code launches automatically with --dangerously-skip-permissions
```

---

## Alternative: Clone Repository (Advanced)

For additional features like configuration files and helper scripts:

```bash
git clone https://github.com/eovidiu/claude-sandbox.git
cd claude-sandbox

# Configure your workspace
cp config/.env.template config/.env
# Edit config/.env to set HOST_MOUNTS to your project directory

# Start environment
./scripts/dev-env-up.sh --secret ANTHROPIC_API_KEY=your-key
```

---

## Common Use Cases

### Use Case 1: Let Claude Code Build Your Project

Mount your project and give Claude full access to modify, test, and build:

```bash
docker run -it --rm \
  --network bridge \
  -v "$PWD:/workspace:rw" \
  -e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
  ghcr.io/eovidiu/claude-sandbox:latest

# Inside container
install-claude.sh --verify
cd /workspace
claude --dangerously-skip-permissions
# Ask Claude: "Set up this project and run the dev server"
```

### Use Case 2: Isolated Package Experimentation

Let Claude install any npm/pip packages without affecting your host:

```bash
docker run -it --rm \
  --network bridge \
  -v "$PWD:/workspace:rw" \
  ghcr.io/eovidiu/claude-sandbox:latest

# Inside container
npm install -g typescript ts-node
pip install pandas numpy matplotlib
# Nothing installed on your host system
```

### Use Case 3: Multi-Project Development

Run multiple isolated environments simultaneously:

```bash
# Terminal 1: Frontend project
docker run -it --rm --name frontend \
  --network bridge \
  -v "$PWD:/workspace:rw" \
  -p 3000:3000 \
  ghcr.io/eovidiu/claude-sandbox:latest

# Terminal 2: Backend project
docker run -it --rm --name backend \
  --network bridge \
  -v "$PWD:/workspace:rw" \
  -p 8000:8000 \
  ghcr.io/eovidiu/claude-sandbox:latest
```

### Use Case 4: CI/CD Testing Locally

Test your CI pipeline commands in the same environment:

```bash
docker run --rm \
  --network bridge \
  -v "$PWD:/workspace:rw" \
  ghcr.io/eovidiu/claude-sandbox:latest \
  bash -c "npm ci && npm test && npm run build"
```

---

## Command Cheatsheet

### Shell Commands (after setup)

| Command | What it does |
|---------|--------------|
| `sandbox` | Enter sandbox for current project |

### Inside Container

| Command | What it does |
|---------|--------------|
| `claude --dangerously-skip-permissions` | Run Claude with full permissions |
| `verify-runtimes.sh` | Check Node.js and Python setup |
| `exit` | Leave the sandbox |

### Direct Docker (without shell setup)

| Task | Command |
|------|---------|
| **Interactive Claude** | `docker run -it --rm --network bridge -v "$PWD:/workspace:rw" -e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" ghcr.io/eovidiu/claude-sandbox:latest` |
| **Run single command** | `docker run --rm --network bridge -v "$PWD:/workspace:rw" ghcr.io/eovidiu/claude-sandbox:latest node -v` |
| **With ports** | `docker run -it --rm --network bridge -v "$PWD:/workspace:rw" -e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" -p 3000:3000 ghcr.io/eovidiu/claude-sandbox:latest` |

---

## Using Helper Scripts

If you cloned the repository, use the helper scripts for more control:

### Create Environment

```bash
# Basic
./scripts/dev-env-up.sh

# With secrets (recommended for API keys)
./scripts/dev-env-up.sh --secret ANTHROPIC_API_KEY=sk-xxx --secret DB_PASSWORD=secret

# With additional mounts and ports
./scripts/dev-env-up.sh \
  --name my-project \
  --mount ~/data:/data:ro \
  --port 3000:3000 \
  --port 8000:8000
```

### Access Environment

```bash
# Interactive shell
./scripts/dev-env-shell.sh claude-dev

# Run command
./scripts/dev-env-shell.sh claude-dev --command "npm test"

# Run as different user
./scripts/dev-env-shell.sh claude-dev --user root --command "apt update"
```

### Destroy Environment

```bash
# With confirmation prompt
./scripts/dev-env-down.sh claude-dev

# Force removal
./scripts/dev-env-down.sh claude-dev --force

# Keep volumes
./scripts/dev-env-down.sh claude-dev --keep-volumes --force
```

---

## Configuration

### Environment Variables

Create `config/.env` from the template:

```bash
cp config/.env.template config/.env
```

Key settings:

| Variable | Description | Default |
|----------|-------------|---------|
| `ENV_NAME` | Container name | `claude-dev` |
| `BASE_IMAGE` | Docker image | `ghcr.io/eovidiu/claude-sandbox:latest` |
| `HOST_MOUNTS` | Volume mounts (HOST:CONTAINER:MODE) | - |
| `PORTS` | Port mappings (HOST:CONTAINER) | `3000:3000,8000:8000` |
| `NODEJS_VERSION` | Node.js version | `lts/*` |
| `PYTHON_VERSION` | Python version | `3.11` |

**Security**: Never put secrets in config files. Use `--secret` flag or `-e` with docker run.

### Example Configuration

```bash
# config/.env
ENV_NAME=my-dev-env
HOST_MOUNTS=/Users/me/projects:/workspace:rw,/Users/me/data:/data:ro
PORTS=3000:3000,5000:5000,8000:8000
```

---

## What's Included

### Pre-installed Runtimes

| Runtime | Version | Package Managers |
|---------|---------|-----------------|
| Node.js | LTS v20.x (via nvm) | npm, yarn |
| Python | 3.11+ | pip, virtualenv, pipenv |

### Pre-installed Tools

- git, curl, wget
- build-essential (for native modules)
- verify-runtimes.sh (diagnostic script)
- install-claude.sh (Claude Code installer)

### Container Specs

- **Base**: Ubuntu 22.04 LTS
- **Size**: ~800MB
- **Platforms**: linux/amd64, linux/arm64 (Apple Silicon)
- **User**: Runs as non-root `dev` user (UID 1000) - required for Claude Code
- **Sudo**: Available for installing system packages when needed

---

## Security Model

### Isolation Guarantees

1. **Filesystem isolation** - Container has its own filesystem; only mounted directories are accessible
2. **Network isolation** - Only exposed ports are accessible from host
3. **Process isolation** - Container processes can't see or affect host processes
4. **Secret handling** - Secrets passed via `-e` or `--secret` exist only in memory

### What Claude CAN Do (Inside Container)

- Read/write any file in mounted directories
- Install any packages (npm, pip, apt)
- Execute any command
- Start services on any port
- Modify system configuration

### What Claude CANNOT Do

- Access unmounted host directories
- See or modify host processes
- Access host network services (except explicitly exposed)
- Persist data outside mounted volumes (unless configured)

---

## Integration Patterns

### Recommended: Shell Function

After the [Recommended Setup](#recommended-setup-one-time), just use:

```bash
cd ~/work/any-project
sandbox
```

Each project gets its own persistent container with Claude pre-installed.

### Alternative: Docker Compose

If you prefer Docker Compose for your project:

```yaml
# docker-compose.dev.yml
services:
  sandbox:
    image: ghcr.io/eovidiu/claude-sandbox:latest
    volumes:
      - .:/workspace:rw
    ports:
      - "3000:3000"
      - "8000:8000"
    environment:
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
    stdin_open: true
    tty: true
```

Run with: `docker compose -f docker-compose.dev.yml run sandbox`

### Alternative: Makefile

```makefile
.PHONY: sandbox

sandbox:
	docker run -it --rm \
		--network bridge \
		-v "$$(PWD):/workspace:rw" \
		-e ANTHROPIC_API_KEY="$${ANTHROPIC_API_KEY}" \
		ghcr.io/eovidiu/claude-sandbox:latest
```

Run with: `make sandbox`

---

## Troubleshooting

### Quick Fixes

| Problem | Solution |
|---------|----------|
| `sandbox: command not found` | Run `source ~/.zshrc` to reload shell |
| `claude: command not found` | Run `install-claude.sh --verify` inside container |
| `node: command not found` | Run `. ~/.nvm/nvm.sh` or re-enter with `sandbox` |
| Port already in use | Stop the host process using that port or change the `-p` mapping |
| Container name exists | Use the transient `sandbox` function or remove the named container with `docker rm -f <name>` |
| Permission denied on mount | Check host directory permissions |

### Verify Installation

```bash
# Inside container
verify-runtimes.sh         # Check Node.js and Python
install-claude.sh --verify # Check Claude Code
```

### Reset a Project's Sandbox

```bash
sandbox                 # Every run creates a fresh transient container
```

### Refresh Image

```bash
# Remove and re-pull image
docker rmi ghcr.io/eovidiu/claude-sandbox:latest
docker pull ghcr.io/eovidiu/claude-sandbox:latest
```

For more issues, see [docs/troubleshooting.md](docs/troubleshooting.md).

---

## Building from Source

### Build Locally

```bash
# Clone repository
git clone https://github.com/eovidiu/claude-sandbox.git
cd claude-sandbox

# Build image
docker build -t claude-sandbox:local .

# Run local build
docker run -it --rm --network bridge -v "$PWD:/workspace:rw" claude-sandbox:local
```

### Use Rebuilt Image

If you rebuild the image, the transient `sandbox` function will use the rebuilt tag on the next run:

```bash
# Pull new image (if using remote) or rebuild locally
docker pull ghcr.io/eovidiu/claude-sandbox:latest
# OR: docker build -t ghcr.io/eovidiu/claude-sandbox:latest .

# Start a fresh transient container
sandbox
```

### Run Tests

```bash
brew install bats-core bats-support bats-assert bats-file
bats tests/
```

### Push to Registry (Maintainers)

```bash
# Build multi-platform image
docker buildx build --platform linux/amd64,linux/arm64 \
  -t ghcr.io/eovidiu/claude-sandbox:latest \
  -t ghcr.io/eovidiu/claude-sandbox:v1.1.0 \
  --push .
```

---

## Project Structure

```
claude-sandbox/
├── scripts/
│   ├── dev-env-up.sh      # Create environment
│   ├── dev-env-down.sh    # Destroy environment
│   ├── dev-env-shell.sh   # Access shell/run commands
│   ├── install-claude.sh  # Install Claude Code (in container)
│   └── verify-runtimes.sh # Verify runtimes (in container)
├── config/
│   ├── .env.template      # Configuration template
│   └── entrypoint.sh      # Container entrypoint
├── tests/                 # BATS test suite
├── docs/
│   └── troubleshooting.md # Troubleshooting guide
├── Dockerfile             # Container definition
└── README.md              # This file
```

---

## Performance

| Operation | Time |
|-----------|------|
| First pull | ~2 min (800MB download) |
| Container start | ~4 seconds |
| Claude Code install | ~30 seconds |
| Container stop | ~1 second |
| Full teardown | ~30 seconds |

**Tip**: Use [OrbStack](https://orbstack.dev) instead of Docker Desktop for faster startup on macOS.

---

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Support

- **Issues**: [GitHub Issues](https://github.com/eovidiu/claude-sandbox/issues)
- **Documentation**: [docs/troubleshooting.md](docs/troubleshooting.md)
- **Scripts help**: Run any script with `--help` flag
