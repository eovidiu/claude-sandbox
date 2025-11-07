# Quickstart: Isolated Development Environment

**Feature**: Isolated Development Environment for Claude Code
**Goal**: Get up and running with an isolated dev environment in < 5 steps

---

## Prerequisites

Before you begin, ensure you have:

1. **macOS** (Intel or Apple Silicon)
2. **OrbStack** installed
   ```bash
   brew install orbstack
   ```
3. **Terminal** access

**Time to Complete**: ~5 minutes (after OrbStack installation)

---

## Quick Start (5 Steps)

### Step 1: Install Prerequisites

```bash
# Install OrbStack (if not already installed)
brew install orbstack

# Verify installation
orb --version
```

**Expected Output**:
```
OrbStack version 1.x.x
```

---

### Step 2: Clone or Navigate to Repository

```bash
# Navigate to the dev-setup repository
cd /path/to/dev-setup

# Or clone it (if not already done)
# git clone <repository-url>
# cd dev-setup
```

---

### Step 3: Create Your Environment Configuration

```bash
# Copy the template
cp config/.env.template .env

# Edit the configuration (optional - defaults work for most cases)
# nano .env
```

**Default Configuration** (.env.template):
```bash
# Environment name
ENV_NAME=claude-dev

# Base image
BASE_IMAGE=ubuntu:22.04

# Language versions
NODEJS_VERSION=lts/*
PYTHON_VERSION=3.11

# Working directory
WORK_DIR=/workspace

# Host mounts (update the path to your project)
HOST_MOUNTS=/Users/YOUR_USERNAME/projects:/workspace:rw

# Ports (optional)
PORTS=3000:3000,8000:8000

# Persistence
PERSIST_DATA=false
```

**Important**: Update `HOST_MOUNTS` to point to your actual project directory!

---

### Step 4: Start Your Isolated Environment

```bash
# Start the environment
./scripts/dev-env-up.sh

# Or with verbose output to see what's happening
./scripts/dev-env-up.sh --verbose
```

**What Happens**:
- OrbStack pulls Ubuntu 22.04 base image (first time only)
- NodeJS LTS and Python 3.11 are installed
- Claude Code is installed
- Your project directory is mounted at `/workspace`
- Container starts and becomes ready

**Expected Output**:
```
✓ Environment 'claude-dev' created successfully

Container ID: abc123def456
Container Name: claude-dev
Status: running
IP Address: 192.168.65.3
Workspace: /workspace → /Users/you/projects
Ports: 3000:3000, 8000:8000

Access shell: ./scripts/dev-env-shell.sh claude-dev
Stop environment: ./scripts/dev-env-down.sh claude-dev
```

**Time**: ~3-5 minutes (first time with image download), ~30 seconds (subsequent runs)

---

### Step 5: Access Your Environment

```bash
# Open a shell inside the environment
./scripts/dev-env-shell.sh claude-dev
```

**You're In!** You now have an isolated shell with:
- NodeJS and npm/yarn installed
- Python and pip installed
- Claude Code ready to use
- Your project code at `/workspace`

**Test It Out**:
```bash
# Inside the container
node --version     # Should show NodeJS LTS version
python3 --version  # Should show Python 3.11+
npm --version      # Should show npm version
pip --version      # Should show pip version

# Try Claude Code
claude --version   # Should show Claude Code version

# Check your project files
ls /workspace      # Should show your mounted project files
```

---

## Common Tasks

### Run Claude Code with Skip-Permissions

```bash
# Inside the environment shell
claude --dangerously-skip-permissions

# Now Claude Code runs without permission prompts!
```

### Inject Secrets at Startup

```bash
# Stop the current environment (if running)
./scripts/dev-env-down.sh claude-dev --force

# Restart with secrets
./scripts/dev-env-up.sh \
  --secret API_KEY=sk-abc123xyz \
  --secret DB_PASSWORD=mypassword

# Access the environment
./scripts/dev-env-shell.sh claude-dev

# Inside container, secrets are available
echo $API_KEY      # Shows: sk-abc123xyz
```

**Important**: Secrets are NOT persisted - they're only in memory and cleared when you stop the environment.

### Stop and Clean Up

```bash
# Stop and remove the environment
./scripts/dev-env-down.sh claude-dev

# Force removal without confirmation
./scripts/dev-env-down.sh claude-dev --force
```

### Run a One-Off Command

```bash
# Run a command without entering the shell
./scripts/dev-env-shell.sh claude-dev --command "npm test"
./scripts/dev-env-shell.sh claude-dev --command "python app.py"
```

---

## Configuration Examples

### Minimal Setup (Default)

```bash
ENV_NAME=my-env
BASE_IMAGE=ubuntu:22.04
NODEJS_VERSION=lts/*
PYTHON_VERSION=3.11
WORK_DIR=/workspace
HOST_MOUNTS=/Users/me/project:/workspace:rw
```

### Multi-Project Setup

```bash
ENV_NAME=multi-project-env
BASE_IMAGE=ubuntu:22.04
NODEJS_VERSION=20.10.0
PYTHON_VERSION=3.11
WORK_DIR=/workspace

# Mount multiple directories
HOST_MOUNTS=/Users/me/project1:/workspace:rw,/Users/me/shared:/shared:ro,/Users/me/data:/data:rw

# Expose multiple ports
PORTS=3000:3000,3001:3001,8000:8000,5432:5432
```

### With Persistent Data

```bash
ENV_NAME=persistent-env
BASE_IMAGE=ubuntu:22.04
NODEJS_VERSION=lts/*
PYTHON_VERSION=3.11
WORK_DIR=/workspace
HOST_MOUNTS=/Users/me/project:/workspace:rw

# Keep volumes even after env is destroyed
PERSIST_DATA=true
```

---

## Troubleshooting

### OrbStack Not Running

**Error**:
```
ERROR: OrbStack is not running
Please start OrbStack and try again.
```

**Solution**:
```bash
# Start OrbStack
open -a OrbStack

# Wait for OrbStack to start, then retry
./scripts/dev-env-up.sh
```

---

### Port Already in Use

**Error**:
```
ERROR: Port 3000 is already in use
Port 3000 is occupied by another service.
```

**Solution**:

Option 1: Use different ports
```bash
# Edit .env and change PORTS
PORTS=3001:3000,8001:8000
```

Option 2: Stop the conflicting service
```bash
# Find what's using port 3000
lsof -i :3000

# Kill the process or stop the service
```

---

### Mount Path Does Not Exist

**Error**:
```
ERROR: Mount path does not exist
/Users/me/nonexistent does not exist.
```

**Solution**:
```bash
# Create the directory
mkdir -p /Users/me/nonexistent

# Or update .env to point to an existing directory
```

---

### Environment Already Exists

**Error**:
```
ERROR: Environment 'my-env' already exists
A container with name 'my-env' is already running.
```

**Solution**:

Option 1: Stop and remove existing environment
```bash
./scripts/dev-env-down.sh my-env --force
./scripts/dev-env-up.sh
```

Option 2: Use a different name
```bash
./scripts/dev-env-up.sh --name my-env-2
```

---

### Container Won't Start

**Error**:
```
ERROR: Container failed to start
Check logs for details.
```

**Solution**:
```bash
# Check OrbStack logs
docker logs claude-dev

# Check if there's a resource issue
docker info

# Try with verbose output
./scripts/dev-env-up.sh --verbose
```

---

## Next Steps

### Learn More

- **Full Documentation**: See `docs/troubleshooting.md` for detailed help
- **Advanced Configuration**: See `config/.env.template` for all options
- **Testing**: See `tests/` for test examples

### Customize Your Environment

1. **Add More Languages**: Modify the Dockerfile to install additional runtimes
2. **Pre-Install Packages**: Add global npm/pip packages to the Dockerfile
3. **Custom Entrypoint**: Modify `config/entrypoint.sh` for startup tasks

### Integrate with Your Workflow

```bash
# Add to your .bashrc or .zshrc for quick access
alias dev-up='cd ~/dev-setup && ./scripts/dev-env-up.sh'
alias dev-down='cd ~/dev-setup && ./scripts/dev-env-down.sh claude-dev --force'
alias dev-shell='cd ~/dev-setup && ./scripts/dev-env-shell.sh claude-dev'
```

---

## FAQ

**Q: Do I need to install NodeJS/Python on my host Mac?**

A: No! The environment comes with NodeJS and Python pre-installed. Your host Mac only needs OrbStack.

**Q: Will this affect my host system?**

A: No. Everything runs in an isolated container. Your host system remains untouched.

**Q: What happens to my data when I destroy the environment?**

A: By default, all container data is deleted. To keep data, set `PERSIST_DATA=true` in your `.env` file or use `--keep-volumes` when destroying.

**Q: Can I run multiple environments at once?**

A: Yes! Just use different names and ensure ports don't conflict.

**Q: How do I update NodeJS or Python versions?**

A: Edit the `.env` file to change `NODEJS_VERSION` or `PYTHON_VERSION`, then destroy and recreate the environment.

**Q: Are my secrets safe?**

A: Yes. Secrets are only stored in container memory and never written to disk. They're completely cleared when the environment is destroyed.

**Q: Can I use this on Windows or Linux?**

A: Not currently. This version is designed for macOS only. However, the Dockerfile and scripts could be adapted for other platforms.

---

## Success Criteria

You've successfully set up the isolated development environment if:

1. ✅ Environment spins up in < 5 minutes
2. ✅ You can access the shell inside the environment
3. ✅ NodeJS and Python are available and functional
4. ✅ Claude Code runs with `--dangerously-skip-permissions`
5. ✅ Your project files are accessible at `/workspace`
6. ✅ Environment can be destroyed cleanly in < 30 seconds

**Congratulations!** You now have a safe, isolated development environment for experimenting with Claude Code.
