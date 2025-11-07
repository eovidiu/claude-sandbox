# Isolated Development Environment
# Base image: Ubuntu 22.04 LTS (chosen for stability and long-term support)
# Includes: NodeJS LTS, Python 3.11+, Claude Code
#
# Layer optimization strategy:
# 1. Base system packages (changes rarely)
# 2. Runtime installations (changes occasionally)
# 3. Project scripts (changes frequently)
# This order maximizes Docker layer cache hit rate during development

FROM ubuntu:22.04

# Avoid prompts from apt (required for non-interactive Docker builds)
ENV DEBIAN_FRONTEND=noninteractive

# Set timezone to UTC (prevents timezone-related issues in logs and timestamps)
ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install basic utilities and dependencies
# build-essential: Required for compiling native Node.js modules (node-gyp)
# ca-certificates: Required for HTTPS connections to npm/pip registries
# iproute2: Provides network diagnostic tools (ip, ss)
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
    && rm -rf /var/lib/apt/lists/*

# Install NodeJS LTS via nvm
# T061: Pin to specific LTS version for reproducibility
# nvm allows version management and is standard in development environments
# lts/iron is Node.js 20.x LTS (Long Term Support until April 2026)
ENV NVM_DIR=/root/.nvm
ENV NODE_VERSION=lts/iron
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash \
    && . "$NVM_DIR/nvm.sh" \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default \
    && npm install -g yarn

# Create symlinks for node, npm, and yarn to make them available globally
# This ensures tools work without sourcing nvm.sh in non-interactive shells
RUN ln -sf $NVM_DIR/versions/node/$(ls $NVM_DIR/versions/node | head -1)/bin/node /usr/local/bin/node \
    && ln -sf $NVM_DIR/versions/node/$(ls $NVM_DIR/versions/node | head -1)/bin/npm /usr/local/bin/npm \
    && ln -sf $NVM_DIR/versions/node/$(ls $NVM_DIR/versions/node | head -1)/bin/yarn /usr/local/bin/yarn

# Add NodeJS to PATH via ENV (use wildcards to match any version)
# This makes node/npm/yarn available in all shells without manual PATH updates
ENV PATH=$NVM_DIR/versions/node/v*/bin:$PATH

# Install Python 3.11+ from deadsnakes PPA
# T062: Pin to Python 3.11 specifically for stability
# deadsnakes PPA provides newer Python versions for Ubuntu (Ubuntu 22.04 ships with Python 3.10)
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

# Upgrade pip and install common Python tools
# T064: Add virtualenv and pipenv for Python environment management
# virtualenv: Isolated Python environments (lighter than venv)
# pipenv: Modern dependency management with Pipfile/Pipfile.lock
RUN python -m pip install --upgrade pip setuptools wheel \
    && pip install virtualenv pipenv

# T065: Copy runtime verification script (can be run manually inside container)
# Not run during build to avoid PATH issues; available as diagnostic tool
COPY scripts/verify-runtimes.sh /usr/local/bin/verify-runtimes.sh
RUN chmod +x /usr/local/bin/verify-runtimes.sh

# Copy Claude Code installation script (can be run inside container)
# Not pre-installed to allow users to opt-in and verify installation
COPY scripts/install-claude.sh /usr/local/bin/install-claude.sh
RUN chmod +x /usr/local/bin/install-claude.sh

# Create workspace directory
# Default working directory for all user projects
RUN mkdir -p /workspace
WORKDIR /workspace

# Copy entrypoint script
# Entrypoint sources nvm and sets up shell environment properly
COPY config/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set entrypoint
# Uses bash as default shell for interactive sessions
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]
