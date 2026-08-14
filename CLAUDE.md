# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Project Overview

An MCP server on Cloudflare Workers exposing sandboxed command execution at the
edge. One Worker, no backend, no local runtime. Sandboxes are Cloudflare
Containers fronted by a Durable Object.

## Architecture

- `src/index.ts` — the whole server: bearer guard, MCP server, five tools.
  Keep `export { Sandbox } from '@cloudflare/sandbox'`; without it the Worker
  will not deploy.
- `wrangler.jsonc` — container, Durable Object binding, SQLite migration.
  Two deliberate changes from the upstream template: `instance_type: basic`
  (`lite`'s 256 MiB is too small for pip installs) and `max_instances: 5`
  (the platform default is 20; this is lower to bound cost).
- `Dockerfile` — `cloudflare/sandbox:0.12.5` plus `python3`, `python3-pip`,
  `python3-venv`. The base image has no Python despite what some docs claim.

## Commands

```sh
npm run typecheck
npm run dev          # requires Docker
npm run deploy
npx wrangler types   # after changing wrangler.jsonc or .dev.vars
```

## Constraints and gotchas

- Containers require the Workers Paid plan. `wrangler deploy` needs a local
  Docker daemon to build and push the image.
- `MCP_SECRET_TOKEN` is a Cloudflare secret. Never commit it and never echo it —
  session transcripts persist to `~/.claude/projects/**/*.jsonl`. Pipe it
  straight from `openssl` into the token file and into `wrangler secret put`.
- `agents` peers on `zod@^4`. Installing zod 3 fails resolution.
- `@modelcontextprotocol/server` v2 takes a full `z.object(...)` as
  `inputSchema`, not the bare shape the older `@modelcontextprotocol/sdk` used.
- `@cloudflare/sandbox` 1.0 will change `exec()` to argv-only and return a
  process handle. Stay on the 0.12.x line until that is handled.
- Cloudflare deprecated `McpAgent` in favour of the stateless
  `createMcpHandler`. Do not reintroduce the Durable Object MCP pattern.
- Do not run `claude mcp list` when output is captured; it prints stdio server
  argv with API keys in plaintext.
- `max_instances` is a hard ceiling on *concurrent running* sandboxes; stopped
  ones do not count. Exceeding it raises `ContainerUnavailableError`, which
  `withSandbox` rewrites into a list of reclaim candidates.
- **That error crosses a Durable Object RPC boundary, which strips the prototype
  chain and the custom `reason` field.** `instanceof ContainerUnavailableError`
  is false by the time the Worker sees it, so `isSlotExhausted` matches on the
  message text — the same way the SDK itself detects this condition. Do not
  "simplify" it back to an instanceof check; it will silently stop firing.
- A container only holds a slot while a command is actually running. A
  backgrounded command (`sleep 60 &`) returns immediately and the container goes
  inactive, so it cannot be used to reproduce the ceiling — use concurrent
  foreground work.
- `wrangler containers instances <app-id>` lists real instances by name; the
  registry is only what this Worker recorded and drifts from it.
- `exit N` inside a sandbox terminates its persistent shell and surfaces as
  `SessionTerminatedError`. That is distinct from a command that merely fails,
  which returns its exit code and stderr as a normal result.
- `wrangler containers list` shows configured capacity in `LIVE INSTANCES`.
  Read `health.instances.active` from `wrangler containers info` instead.

## Verifying a change

`wrangler dev`, then POST JSON-RPC to `http://localhost:8787/mcp`. The checks
worth keeping green: no header and a wrong token both return `401`, a correct
token returns `200`, `tools/list` returns five tools, and a
write → execute → read → destroy round trip succeeds.
