# Isolated Development Environment
# Base image: Ubuntu 22.04 LTS (chosen for stability and long-term support)
# Includes: NodeJS LTS, Python 3.11+, Claude Code
#
# Layer optimization strategy:
# 1. Base system packages (changes rarely)
# 2. Runtime installations (changes occasionally)
# 3. User setup and project scripts (changes frequently)
# This order maximizes Docker layer cache hit rate during development

FROM ubuntu:22.04

# OCI labels for GitHub Container Registry
LABEL org.opencontainers.image.source=https://github.com/eovidiu/claude-sandbox
LABEL org.opencontainers.image.description="Isolated development environment for running Claude Code safely with pre-configured NodeJS and Python runtimes"
LABEL org.opencontainers.image.licenses=MIT
LABEL org.opencontainers.image.title="Claude Sandbox"
LABEL org.opencontainers.image.vendor="Ovidiu Eftimie"

# Avoid prompts from apt (required for non-interactive Docker builds)
ENV DEBIAN_FRONTEND=noninteractive

# Set timezone to UTC (prevents timezone-related issues in logs and timestamps)
ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install basic utilities and dependencies
# build-essential: Required for compiling native Node.js modules (node-gyp)
# ca-certificates: Required for HTTPS connections to npm/pip registries
# iproute2: Provides network diagnostic tools (ip, ss)
# sudo: Required for dev user to run privileged commands when needed
# Cleanup apt cache to reduce image size
# Combined into single RUN to reduce layer count
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    ca-certificates \
    gnupg \
    lsb-release \
    iproute2 \
    software-properties-common \
    sudo \
    jq \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Install Python 3.11+ from deadsnakes PPA (system-wide, before user creation)
# deadsnakes PPA provides newer Python versions for Ubuntu (Ubuntu 22.04 ships with 3.10)
# python3.11-venv: Required for creating virtual environments
# python3.11-dev: Required for compiling Python packages with C extensions
RUN add-apt-repository ppa:deadsnakes/ppa -y \
    && apt-get update \
    && apt-get install -y \
        python3.11 \
        python3.11-venv \
        python3.11-dev \
        python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Set Python 3.11 as default
# This ensures 'python' and 'python3' commands use Python 3.11
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1 \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1

# Upgrade pip and install common Python tools (system-wide)
# virtualenv: Isolated Python environments (lighter than venv)
# pipenv: Modern dependency management with Pipfile/Pipfile.lock
RUN python -m pip install --upgrade pip setuptools wheel \
    && pip install virtualenv pipenv

# Create non-root user 'dev' for running Claude Code
# Claude Code refuses to run as root for security reasons
# UID 1000 is standard for first non-root user
ARG DEV_USER=dev
ARG DEV_UID=1000
ARG DEV_GID=1000

RUN groupadd --gid $DEV_GID $DEV_USER \
    && useradd --uid $DEV_UID --gid $DEV_GID --shell /bin/bash --create-home $DEV_USER \
    && echo "$DEV_USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/$DEV_USER \
    && chmod 0440 /etc/sudoers.d/$DEV_USER

# Create workspace directory and set ownership
RUN mkdir -p /workspace && chown $DEV_USER:$DEV_USER /workspace

# Switch to dev user for NVM and Node.js installation
USER $DEV_USER
WORKDIR /home/$DEV_USER

# Install NodeJS LTS via nvm for the dev user
# lts/iron is Node.js 20.x LTS (Long Term Support until April 2026)
ENV NVM_DIR=/home/$DEV_USER/.nvm
ENV NODE_VERSION=lts/iron

RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash \
    && . "$NVM_DIR/nvm.sh" \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default \
    && npm install -g yarn \
    && npm install -g @anthropic-ai/claude-code \
    && npm install -g ccstatusline \
    && npm install -g @playwright/mcp \
    && npm install -g @railwayapp/railway-mcp-server \
    && npm install -g @supabase/mcp-server-supabase \
    && npm install -g @upstash/context7-mcp

# Create Claude Code settings with statusline configuration
RUN mkdir -p /home/$DEV_USER/.claude \
    && echo '{"statusLine":{"type":"command","command":"ccstatusline","padding":0}}' > /home/$DEV_USER/.claude/settings.json

# Add nvm initialization to .bashrc for interactive shells
RUN echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bashrc \
    && echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.bashrc \
    && echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> ~/.bashrc

# Pre-populate SSH known hosts for common Git providers (GitHub, GitLab, Bitbucket)
# This prevents "host key verification failed" errors on first git push
RUN mkdir -p /home/$DEV_USER/.ssh \
    && ssh-keyscan github.com gitlab.com bitbucket.org >> /home/$DEV_USER/.ssh/known_hosts 2>/dev/null \
    && chmod 700 /home/$DEV_USER/.ssh \
    && chmod 644 /home/$DEV_USER/.ssh/known_hosts

# Switch back to root for system-wide installations
USER root

# Create symlinks for node, npm, yarn, claude, and ccstatusline to make them available globally
# This ensures tools work without sourcing nvm.sh in non-interactive shells
RUN ln -sf /home/$DEV_USER/.nvm/versions/node/$(ls /home/$DEV_USER/.nvm/versions/node | head -1)/bin/node /usr/local/bin/node \
    && ln -sf /home/$DEV_USER/.nvm/versions/node/$(ls /home/$DEV_USER/.nvm/versions/node | head -1)/bin/npm /usr/local/bin/npm \
    && ln -sf /home/$DEV_USER/.nvm/versions/node/$(ls /home/$DEV_USER/.nvm/versions/node | head -1)/bin/yarn /usr/local/bin/yarn \
    && ln -sf /home/$DEV_USER/.nvm/versions/node/$(ls /home/$DEV_USER/.nvm/versions/node | head -1)/bin/claude /usr/local/bin/claude \
    && ln -sf /home/$DEV_USER/.nvm/versions/node/$(ls /home/$DEV_USER/.nvm/versions/node | head -1)/bin/ccstatusline /usr/local/bin/ccstatusline

# Copy runtime verification script (can be run manually inside container)
COPY scripts/verify-runtimes.sh /usr/local/bin/verify-runtimes.sh
RUN chmod +x /usr/local/bin/verify-runtimes.sh

# Copy Claude Code installation script (can be run inside container)
COPY scripts/install-claude.sh /usr/local/bin/install-claude.sh
RUN chmod +x /usr/local/bin/install-claude.sh

# Copy MCP setup script (generates mcp.json from environment variables)
COPY scripts/setup-mcp.sh /usr/local/bin/setup-mcp.sh
RUN chmod +x /usr/local/bin/setup-mcp.sh

# Copy entrypoint script
COPY config/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Switch to dev user for runtime
USER $DEV_USER
WORKDIR /workspace

# Set entrypoint
# Uses bash as default shell for interactive sessions
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]
