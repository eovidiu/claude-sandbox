# cloudflare-sandbox-mcp

An MCP server on Cloudflare Workers that runs commands in ephemeral edge
containers. Claude Code stays on your machine; the workloads it runs go to a
Cloudflare Sandbox that has no access to your local files.

> This replaced a Docker/OrbStack sandbox that ran Claude Code *inside* a
> container with your project bind-mounted. That version is frozen at tag
> `docker-sandbox-final` (image: `ghcr.io/eovidiu/claude-sandbox:v1.2.1`).

## Requirements

- Cloudflare **Workers Paid** plan — Containers are not available on the free tier
- Docker running locally, only for `wrangler deploy` (it builds the container image)
- Node 18+

## Tools

| Tool | Arguments |
|---|---|
| `sandbox_execute` | `sandboxId`, `command` |
| `sandbox_write_file` | `sandboxId`, `path`, `content` |
| `sandbox_read_file` | `sandboxId`, `path` |
| `sandbox_list_files` | `sandboxId`, `path` |
| `sandbox_destroy` | `sandboxId` |

Reusing a `sandboxId` reuses the same container, so a write / execute / read
sequence shares state. A non-zero exit comes back as a normal result carrying
stdout, stderr and the exit code rather than as an error, so the caller can
read the failure and react to it.

The image is `cloudflare/sandbox` plus Python. The base image ships Node, npm,
npx and bun but no Python interpreter, so the Dockerfile adds `python3`,
`python3-pip` and `python3-venv`.

## Deploy

```sh
npm install
npx wrangler deploy
```

The endpoint returns `503` until a token is set, so there is no window in which
it is reachable without one. Generate a token and install it in both places:

```sh
mkdir -p ~/.config/cf-sandbox-mcp && chmod 700 ~/.config/cf-sandbox-mcp
openssl rand -hex 32 | tr -d '\n' > ~/.config/cf-sandbox-mcp/token
chmod 600 ~/.config/cf-sandbox-mcp/token
npx wrangler secret put MCP_SECRET_TOKEN < ~/.config/cf-sandbox-mcp/token
```

Nothing in that sequence prints the token.

## Connect Claude Code

Create `~/.config/cf-sandbox-mcp/hdr.sh`, mode 700:

```sh
#!/bin/sh
printf '{"Authorization":"Bearer %s"}' "$(cat "$HOME/.config/cf-sandbox-mcp/token")"
```

Register the server so it reads the header from that helper, which keeps the
token out of `~/.claude.json`:

```sh
claude mcp add-json cloudflare-sandbox -s user "$(jq -nc \
  --arg h "$HOME/.config/cf-sandbox-mcp/hdr.sh" \
  '{type:"http",url:"https://<worker>.workers.dev/mcp",headersHelper:$h}')"
```

Claude Code runs the helper on each connection and re-runs it automatically
after a `401`, so rotating the token only means rewriting the file and running
`wrangler secret put` again.

MCP servers are loaded when a session starts; a session already running when you
add the server will not see it until restarted.

## Using it from Claude Code

There is nothing to start. The server is remote and always on, so just run
`claude` and ask for what you want in plain language:

> In a Cloudflare sandbox called `scrape-1`, install requests, fetch
> example.com, print the page title, then destroy the sandbox.

Confirm the server is connected with `/mcp`.

Four things worth knowing before you rely on it:

1. **The sandbox cannot see your repository.** It is a fresh container in
   Cloudflare with no copy of your files. Get code in with `sandbox_write_file`,
   or `git clone` inside the sandbox.
2. **`sandboxId` is the unit of isolation.** Reuse an id to keep state across
   calls; use a different id when work must not share a filesystem.
3. **Three concurrent sandboxes maximum** (`max_instances`). A fourth fails with
   `ContainerUnavailableError`. For batch work, destroy each sandbox before
   starting the next.
4. **Destroy sandboxes when finished.** An idle container holds its slot for
   about ten minutes and bills against the monthly allowance until it sleeps.

Non-interactively, name the tools you want to allow:

```sh
claude -p "run uname -a in sandbox test-1" \
  --allowedTools "mcp__cloudflare-sandbox__sandbox_execute"
```

## Turning it off

| Goal | How |
|---|---|
| Off for now, keep config | `/mcp`, select the server, toggle it off |
| Off permanently, keep config | `"disabledMcpServers": ["cloudflare-sandbox"]` in `~/.claude/settings.json` |
| Off for a single run | `claude --disallowedTools "mcp__cloudflare-sandbox__sandbox_execute" ...` |
| Ignore every configured MCP server | `claude --strict-mcp-config --mcp-config '{"mcpServers":{}}'` |
| Remove the client config | `claude mcp remove cloudflare-sandbox -s user` |

To disable the service itself, so no client can reach it regardless of local
configuration, delete the secret. The Worker fails closed and answers `503`:

```sh
npx wrangler secret delete MCP_SECRET_TOKEN
```

`npx wrangler delete` goes further and removes the Worker and its container
application entirely.

## Security

The bearer token is the only barrier between the public internet and arbitrary
shell execution billed to your account, and the container has outbound network
access. Treat a leak as worse than a leaked API key, and rotate with
`wrangler secret put`.

Two properties the Worker guarantees:

- **Fails closed.** With `MCP_SECRET_TOKEN` unset every request gets `503`, so
  the gap between a first deploy and setting the secret is not exploitable.
- **Constant-time comparison.** Both sides are SHA-256 hashed before comparison,
  which keeps the buffers equal-length for `timingSafeEqual` and stops the token
  length from leaking.

For defence in depth, put Cloudflare Access in front of the Worker.

## Cost

`basic` instances (1/4 vCPU, 1 GiB, 4 GB disk) against the allowance included
with Workers Paid work out to roughly 25 container-hours per month. Containers
idle for about 10 minutes before sleeping, so call `sandbox_destroy` when you
are finished rather than waiting them out.

`npx wrangler containers info <id>` reports what is actually running; read
`health.instances.active`, not the `LIVE INSTANCES` column of
`wrangler containers list`, which shows configured capacity.

## Development

```sh
npm run typecheck
npm run dev          # needs Docker; builds the image locally
npx wrangler types   # regenerate Env after changing wrangler.jsonc or .dev.vars
```

`.dev.vars` holds a local-only `MCP_SECRET_TOKEN` for `wrangler dev` and is
gitignored.
