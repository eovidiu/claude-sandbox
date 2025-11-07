# Troubleshooting Guide

Common issues and solutions for the Isolated Development Environment.

## Table of Contents

- [Docker/OrbStack Issues](#dockerorbstack-issues)
- [Environment Creation Issues](#environment-creation-issues)
- [Runtime Issues](#runtime-issues)
- [Secret Injection Issues](#secret-injection-issues)
- [Performance Issues](#performance-issues)

---

## Docker/OrbStack Issues

### Error: "Docker daemon is not running"

**Symptoms:**
```
ERROR: Docker daemon is not running. Please start OrbStack or Docker.
```

**Solutions:**
1. **Start Docker Desktop:**
   ```bash
   open -a "Docker"
   ```
   Wait 10-15 seconds for Docker to fully start.

2. **Start OrbStack (if installed):**
   ```bash
   orbctl start
   ```

3. **Verify Docker is running:**
   ```bash
   docker ps
   ```

4. **Check Docker socket permissions:**
   ```bash
   ls -la ~/.docker/run/docker.sock
   ```

### Error: "Cannot connect to Docker daemon"

**Symptoms:**
```
Cannot connect to the Docker daemon at unix:///Users/.../.docker/run/docker.sock
```

**Solutions:**
1. Ensure Docker Desktop is running
2. Restart Docker Desktop: Docker menu → Restart
3. Check Docker context:
   ```bash
   docker context ls
   docker context use desktop-linux
   ```

---

## Environment Creation Issues

### Error: "Port already in use"

**Symptoms:**
```
ERROR: Port 3000 is already in use
```

**Solutions:**
1. **Find what's using the port:**
   ```bash
   lsof -i :3000
   ```

2. **Kill the process:**
   ```bash
   kill <PID>
   ```

3. **Use different ports:**
   Edit `config/.env` or use `--port` flag with different ports:
   ```bash
   ./scripts/dev-env-up.sh --port 3001:3000
   ```

### Error: "Container name already exists"

**Symptoms:**
```
ERROR: Container with name 'claude-dev' already exists
```

**Solutions:**
1. **Remove the existing container:**
   ```bash
   ./scripts/dev-env-down.sh claude-dev --force
   ```

2. **Use a different name:**
   ```bash
   ./scripts/dev-env-up.sh --name claude-dev-2
   ```

3. **List all containers:**
   ```bash
   docker ps -a
   ```

### Error: "Mount path does not exist"

**Symptoms:**
```
ERROR: Mount path does not exist: /Users/...
```

**Solutions:**
1. **Create the directory:**
   ```bash
   mkdir -p /Users/YOUR_USERNAME/projects
   ```

2. **Update config/.env:**
   Edit `HOST_MOUNTS` to point to an existing directory:
   ```
   HOST_MOUNTS=/Users/YOUR_USERNAME/existing-dir:/workspace:rw
   ```

3. **Verify path exists:**
   ```bash
   ls -la /Users/YOUR_USERNAME/projects
   ```

### Error: "Failed to build Docker image"

**Symptoms:**
```
ERROR: Failed to build Docker image
```

**Solutions:**
1. **Check internet connection** (needed for downloading packages)

2. **Clear Docker build cache:**
   ```bash
   docker system prune -af
   docker builder prune -af
   ```

3. **Rebuild without cache:**
   ```bash
   docker build --no-cache -t isolated-dev-env:latest .
   ```

4. **Check Dockerfile syntax:**
   Look for recent changes that might have introduced errors

---

## Runtime Issues

### Claude Code installation or command not found

**Symptoms:**
```bash
./scripts/dev-env-shell.sh claude-dev --command "claude --help"
# claude: command not found
```

**Solutions:**
1. **Install Claude Code first:**
   ```bash
   ./scripts/dev-env-shell.sh claude-dev --command "install-claude.sh --verify"
   ```

2. **Use interactive shell (recommended):**
   ```bash
   ./scripts/dev-env-shell.sh claude-dev
   # Inside container, claude is automatically in PATH
   claude --help
   ```

3. **For non-interactive commands, source nvm:**
   ```bash
   ./scripts/dev-env-shell.sh claude-dev --command "source /root/.nvm/nvm.sh && claude --help"
   ```

**Note:** Claude Code is installed via npm globally and requires nvm to be sourced. Interactive shells automatically have it in PATH.

### Error: "node: command not found"

**Symptoms:**
```bash
./scripts/dev-env-shell.sh claude-dev --command "node --version"
# node: command not found
```

**Solutions:**
1. **Check if NodeJS layer was built:**
   ```bash
   docker exec claude-dev which node
   ```

2. **Manually source nvm in command:**
   ```bash
   ./scripts/dev-env-shell.sh claude-dev --command ". ~/.nvm/nvm.sh && node --version"
   ```

3. **Rebuild the image:**
   ```bash
   docker build -t isolated-dev-env:latest .
   ```

### Error: "pip: command not found"

**Symptoms:**
```bash
./scripts/dev-env-shell.sh claude-dev --command "pip --version"
# pip: command not found
```

**Solutions:**
1. **Use python -m pip instead:**
   ```bash
   ./scripts/dev-env-shell.sh claude-dev --command "python -m pip --version"
   ```

2. **Check Python installation:**
   ```bash
   ./scripts/dev-env-shell.sh claude-dev --command "python --version"
   ```

3. **Verify runtime verification:**
   ```bash
   ./scripts/dev-env-shell.sh claude-dev --command "verify-runtimes.sh"
   ```

### Package installation fails inside container

**Symptoms:**
```
npm ERR! network timeout
```

**Solutions:**
1. **Check container has internet access:**
   ```bash
   ./scripts/dev-env-shell.sh claude-dev --command "curl -I https://registry.npmjs.org"
   ```

2. **Check DNS resolution:**
   ```bash
   ./scripts/dev-env-shell.sh claude-dev --command "ping -c 1 google.com"
   ```

3. **Restart Docker networking:**
   ```bash
   docker network prune
   ```

---

## Secret Injection Issues

### Secret not available in container

**Symptoms:**
```bash
./scripts/dev-env-shell.sh claude-dev --command "echo \$API_KEY"
# (empty output)
```

**Solutions:**
1. **Verify secret was passed during creation:**
   ```bash
   # Correct:
   ./scripts/dev-env-up.sh --secret "API_KEY=value"

   # Wrong (secret added after creation):
   ./scripts/dev-env-up.sh
   export API_KEY=value  # This won't work
   ```

2. **Check secret format:**
   ```bash
   # Correct:
   --secret "KEY=VALUE"

   # Wrong:
   --secret "KEY VALUE"    # Missing =
   --secret "KEY"          # Missing value
   ```

3. **Recreate container with secret:**
   ```bash
   ./scripts/dev-env-down.sh claude-dev --force
   ./scripts/dev-env-up.sh --secret "API_KEY=newvalue"
   ```

### Error: "Invalid secret format"

**Symptoms:**
```
ERROR: Invalid secret format: 'INVALID'. Must be KEY=VALUE
```

**Solutions:**
1. **Use correct KEY=VALUE format:**
   ```bash
   ./scripts/dev-env-up.sh --secret "API_KEY=abc123"
   ```

2. **Quote secrets with special characters:**
   ```bash
   ./scripts/dev-env-up.sh --secret "PASSWORD=p@ss\$word!"
   ```

3. **Use single quotes for complex values:**
   ```bash
   ./scripts/dev-env-up.sh --secret 'JWT=eyJhbGciOiJIUzI1NiJ9.eyJzdWIi'
   ```

---

## Performance Issues

### Slow environment spin-up (>5 minutes)

**Solutions:**
1. **First time is slow** (downloading base images):
   - Ubuntu 22.04: ~300MB
   - NodeJS packages: ~100MB
   - Python packages: ~50MB

   Subsequent runs are much faster (cached layers).

2. **Check available disk space:**
   ```bash
   df -h
   docker system df
   ```

3. **Clean up unused Docker resources:**
   ```bash
   docker system prune -a
   ```

4. **Use OrbStack instead of Docker Desktop:**
   - OrbStack starts in ~2 seconds
   - Docker Desktop can take 15-30 seconds

### Slow package installation inside container

**Solutions:**
1. **Use yarn instead of npm:**
   ```bash
   ./scripts/dev-env-shell.sh claude-dev --command "yarn add express"
   ```

2. **Use npm ci for faster installs:**
   ```bash
   ./scripts/dev-env-shell.sh claude-dev --command "npm ci"
   ```

3. **Pre-install common packages in Dockerfile:**
   Edit `Dockerfile` to add global packages used frequently

---

## General Tips

### Verify Installation

Run the full test suite to verify everything works:
```bash
bats tests/
```

### Check Logs

View container logs for debugging:
```bash
docker logs claude-dev
```

### Access Container Directly

For deep debugging, access the container shell:
```bash
./scripts/dev-env-shell.sh claude-dev
```

### Reset Everything

If all else fails, complete reset:
```bash
# Remove all containers
./scripts/dev-env-down.sh claude-dev --force

# Remove all images
docker rmi isolated-dev-env:latest

# Clear all cache
docker system prune -af
docker builder prune -af

# Rebuild from scratch
docker build --no-cache -t isolated-dev-env:latest .

# Recreate environment
./scripts/dev-env-up.sh
```

### Get Help

1. Check script help:
   ```bash
   ./scripts/dev-env-up.sh --help
   ./scripts/dev-env-down.sh --help
   ./scripts/dev-env-shell.sh --help
   ```

2. Run runtime verification:
   ```bash
   ./scripts/dev-env-shell.sh claude-dev --command "verify-runtimes.sh"
   ```

3. Check project documentation:
   - `README.md` - Quick start guide
   - `specs/001-isolated-dev-env/` - Detailed specifications

---

## Still Having Issues?

If you've tried the solutions above and still have problems:

1. Collect diagnostic information:
   ```bash
   docker --version
   docker info
   docker ps -a
   ./scripts/dev-env-shell.sh claude-dev --command "verify-runtimes.sh"
   ```

2. Check for known issues in the project repository

3. Create a new issue with:
   - Error message
   - Steps to reproduce
   - Output from diagnostic commands above
   - Your macOS version
