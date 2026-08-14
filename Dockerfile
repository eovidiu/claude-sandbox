FROM docker.io/cloudflare/sandbox:0.12.5

# The base image ships Node, npm, npx and bun, but no Python. Sub-agent
# workloads are mostly Python scripts and scrapers, so add the interpreter,
# pip and venv. Kept to these three packages because image size drives
# container cold-start time.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        python3 \
        python3-pip \
        python3-venv \
    && ln -sf /usr/bin/python3 /usr/local/bin/python \
    && rm -rf /var/lib/apt/lists/*

# Documents the ports this application uses (standard Docker convention)
EXPOSE 8080
