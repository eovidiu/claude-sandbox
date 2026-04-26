# Claude Sandbox Setup Guide

This guide covers how to set up Claude Sandbox for daily development use.

## Quick Start

```bash
# Clone the repository
git clone https://github.com/eovidiu/claude-sandbox
cd claude-sandbox

# Run the install script
./scripts/install-sandbox.sh

# Edit your API keys
nano ~/.claude-sandbox-env

# Reload shell
source ~/.zshrc

# Start using!
cd /path/to/your/project
sandbox
```

## Prerequisites

- **Docker**: Install Docker Desktop or OrbStack (recommended for macOS)
- **SSH Keys**: Required for git push/pull operations
- **Git**: Configured with your name and email

### Check Prerequisites

```bash
# Docker
docker --version

# SSH keys (one of these should exist)
ls ~/.ssh/id_ed25519 ~/.ssh/id_rsa

# Git config
git config --global user.name
git config --global user.email
```

## Installation

### Option 1: Automatic (Recommended)

Run the install script:

```bash
./scripts/install-sandbox.sh
```

This will:
1. Create `~/.claude-sandbox-env` with template
2. Add sandbox functions to `~/.zshrc`
3. Verify SSH keys exist
4. Pull the latest Docker image

### Option 2: Manual

1. Copy the env template:
   ```bash
   cp config/claude-sandbox-env.template ~/.claude-sandbox-env
   chmod 600 ~/.claude-sandbox-env
   ```

2. Add sandbox functions to `~/.zshrc` (see [Sandbox Functions](#sandbox-functions))

3. Pull the Docker image:
   ```bash
   docker pull ghcr.io/eovidiu/claude-sandbox:latest
   ```

## Configuration

### MCP API Keys

Edit `~/.claude-sandbox-env` to add your API keys:

```bash
# Railway - Deploy and manage infrastructure
# Get token: https://railway.app/account/tokens
RAILWAY_TOKEN=your_token_here

# Supabase - Database and backend services
# Get token: https://supabase.com/dashboard/account/tokens
SUPABASE_ACCESS_TOKEN=your_token_here

# Context7 - Documentation lookup
# Get key: https://context7.com
CONTEXT7_API_KEY=your_key_here
```

**Note**: Servers with empty/missing keys are automatically skipped. Playwright MCP is always enabled (no key required).

### Getting API Keys

| Service | URL | Notes |
|---------|-----|-------|
| Railway | https://railway.app/account/tokens | Create a new token |
| Supabase | https://supabase.com/dashboard/account/tokens | Access token, not service role |
| Context7 | https://context7.com | Free tier available |

## Usage

### Basic Commands

```bash
# Start sandbox in current project
cd /path/to/project
sandbox
```

### What Happens When You Run `sandbox`

1. Starts a fresh transient container with:
   - Current directory mounted to `/workspace`
   - Docker bridge networking
   - `ANTHROPIC_API_KEY` forwarded from the host when set
   - MCP API keys passed as env vars
2. Generates MCP configuration from env vars
3. Launches Claude Code
4. Removes the container on exit

### Git Operations

Git identity is forwarded from your host `git config --global user.name` and
`user.email`. SSH keys are not mounted by default; if you need SSH push access,
use the direct Docker command and add an explicit read-only SSH mount.

```bash
# Inside the sandbox, these just work:
git status
git add .
git commit -m "message"
git push origin main
```

### MCP Servers

The following MCP servers are pre-installed and configured:

| Server | Purpose | API Key Required |
|--------|---------|------------------|
| Playwright | Browser automation | No |
| Railway | Infrastructure deployment | Yes |
| Supabase | Database operations | Yes |
| Context7 | Documentation lookup | Yes |

On each `sandbox` launch, the MCP configuration is regenerated from your env vars. This means you can update `~/.claude-sandbox-env` and the changes take effect on the next `sandbox` command.

## Sandbox Functions

These functions are added to your `~/.zshrc`:

```bash
# Start Claude Code in isolated container
sandbox() { ... }
```

See [install-sandbox.sh](../scripts/install-sandbox.sh) for the full implementation.

## Troubleshooting

### "Permission denied" on git push

SSH keys are not mounted by default. If you need SSH operations from inside the
container, add an explicit read-only mount:

```bash
docker run -it --rm \
  --network bridge \
  -v "$PWD:/workspace:rw" \
  -v "$HOME/.ssh:/home/dev/.ssh:ro" \
  -e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
  ghcr.io/eovidiu/claude-sandbox:latest
```

### MCP server not working

Check if the API key is set:
```bash
grep RAILWAY_TOKEN ~/.claude-sandbox-env
```

Check the MCP configuration inside the container:
```bash
cat ~/.claude/mcp.json
```

### Container won't start

Check Docker is running:
```bash
docker info
```

Check for port conflicts if you added `-p` mappings:
```bash
docker ps -a | grep 3000
```

### Old container state persisting

The default `sandbox` command is transient and removes the container on exit:
```bash
sandbox
```

## Updating

### Update Docker Image

```bash
docker pull ghcr.io/eovidiu/claude-sandbox:latest

# Start a fresh container with the new image
sandbox
```

### Update Sandbox Functions

Re-run the install script (it's idempotent):
```bash
./scripts/install-sandbox.sh
```

Or manually update the functions in `~/.zshrc`.
