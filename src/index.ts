import { ContainerUnavailableError, getSandbox } from '@cloudflare/sandbox';
import { McpServer } from '@modelcontextprotocol/server';
import { createMcpHandler } from 'agents/mcp/server';
import { z } from 'zod';
import { getRegistry, type SandboxEntry } from './registry';

// Cloudflare binds the container to this Durable Object class. Removing this
// export makes the Worker undeployable.
export { Sandbox } from '@cloudflare/sandbox';
export { SandboxRegistry } from './registry';

/** Containers idle this long are very likely to have been reclaimed already. */
const IDLE_RECLAIM_MS = 10 * 60 * 1000;

/** destroy() can coalesce onto a hung promise, so callers must bound their own wait. */
const DESTROY_TIMEOUT_MS = 30_000;

/** Enough candidates to choose from without burying the advice that follows. */
const MAX_LISTED_CANDIDATES = 8;

const sandboxId = z
  .string()
  .min(1)
  .describe('Groups calls into one container. The same id reuses the same sandbox.');

function ago(since: number): string {
  const minutes = Math.round((Date.now() - since) / 60_000);
  return minutes < 1 ? 'just now' : `${minutes}m ago`;
}

function describeEntry(entry: SandboxEntry): string {
  const stale = Date.now() - entry.lastUsedAt > IDLE_RECLAIM_MS;
  const note = stale ? '   (idle > 10m, likely already reclaimed)' : '';
  return `  ${entry.sandboxId}   last used ${ago(entry.lastUsedAt)}${note}`;
}

/**
 * Turns a bare capacity error into something the caller can act on.
 *
 * The SDK's own message ends with "try again later", which a caller cannot act
 * on because nothing tells it which sandboxes hold the slots or when one might
 * free. Listing the holders turns a dead end into a reclaim decision.
 */
function slotExhaustedMessage(entries: SandboxEntry[]): string {
  // Stalest first: the caller needs reclaim candidates, and the least recently
  // used sandbox is the safest one to destroy.
  const candidates = [...entries].sort((a, b) => a.lastUsedAt - b.lastUsedAt);
  const shown = candidates.slice(0, MAX_LISTED_CANDIDATES);
  const omitted = candidates.length - shown.length;
  return [
    'All container slots are in use, so no new sandbox could start.',
    `Best reclaim candidates (least recently used first, ${entries.length} known in total):`,
    ...shown.map(describeEntry),
    ...(omitted > 0 ? [`  ...and ${omitted} more, see sandbox_list.`] : []),
    'Call sandbox_destroy on one of these, then retry. Stopped sandboxes do not hold slots.'
  ].join('\n');
}

/** The SDK's own wording for the capacity ceiling; it matches this by substring too. */
const SLOT_EXHAUSTED_TEXT = /maximum number of running container instances exceeded/i;

/**
 * True only for the capacity ceiling, not for a cold start or an unhealthy
 * container, which surface through the same error class.
 *
 * The instanceof check alone is not enough: this error is raised inside the
 * sandbox Durable Object and crosses an RPC boundary to get here, which drops
 * the prototype chain and the custom `reason` field. The message survives, so
 * it is the reliable discriminator.
 */
function isSlotExhausted(error: unknown): boolean {
  if (error instanceof ContainerUnavailableError) {
    return error.reason === 'max_container_instances_exceeded';
  }
  const { name, message } = (error ?? {}) as { name?: string; message?: string };
  return SLOT_EXHAUSTED_TEXT.test(`${name ?? ''} ${message ?? ''}`);
}

/**
 * Records the sandbox in the registry, runs the operation, and replaces a
 * capacity failure with a message naming what holds the slots.
 *
 * The container starts lazily on the first operation rather than in
 * getSandbox(), so the operation is what has to be wrapped.
 */
async function withSandbox<T>(
  env: Env,
  id: string,
  operation: (sandbox: ReturnType<typeof getSandbox>) => Promise<T>
): Promise<T> {
  const registry = getRegistry(env);
  await registry.touch(id);
  try {
    return await operation(getSandbox(env.Sandbox, id));
  } catch (error) {
    if (isSlotExhausted(error)) {
      throw new Error(slotExhaustedMessage(await registry.list()));
    }
    throw error;
  }
}

/** Renders a command result the way a model can act on it, including failures. */
function execText(result: { stdout: string; stderr: string; exitCode: number }): string {
  const parts = [`exit code: ${result.exitCode}`];
  if (result.stdout) parts.push(`stdout:\n${result.stdout}`);
  if (result.stderr) parts.push(`stderr:\n${result.stderr}`);
  return parts.join('\n\n');
}

function text(value: string) {
  return { content: [{ type: 'text' as const, text: value }] };
}

function createServer(env: Env) {
  const server = new McpServer({
    name: 'cloudflare-sandbox-mcp',
    version: '2.0.0'
  });

  server.registerTool(
    'sandbox_execute',
    {
      title: 'Execute a shell command in an edge sandbox',
      description:
        'Runs a shell command inside an ephemeral Cloudflare container. Returns stdout, stderr and the exit code. A non-zero exit is reported, not thrown.',
      inputSchema: z.object({
        sandboxId,
        command: z.string().min(1).describe('Shell command to run, arguments included.')
      })
    },
    async ({ sandboxId, command }) => {
      const result = await withSandbox(env, sandboxId, (s) => s.exec(command));
      return text(execText(result));
    }
  );

  server.registerTool(
    'sandbox_write_file',
    {
      title: 'Write a file in an edge sandbox',
      description:
        'Creates or overwrites a file inside the sandbox. Use this to get scripts and data into the container before executing them.',
      inputSchema: z.object({
        sandboxId,
        path: z.string().min(1).describe('Absolute path, e.g. /workspace/scrape.py'),
        content: z.string().describe('Full file contents.')
      })
    },
    async ({ sandboxId, path, content }) => {
      await withSandbox(env, sandboxId, (s) => s.writeFile(path, content));
      return text(`wrote ${content.length} bytes to ${path}`);
    }
  );

  server.registerTool(
    'sandbox_read_file',
    {
      title: 'Read a file from an edge sandbox',
      description: 'Returns the contents of a file inside the sandbox.',
      inputSchema: z.object({
        sandboxId,
        path: z.string().min(1).describe('Absolute path to read.')
      })
    },
    async ({ sandboxId, path }) => {
      const file = await withSandbox(env, sandboxId, (s) => s.readFile(path));
      return text(file.content);
    }
  );

  server.registerTool(
    'sandbox_list_files',
    {
      title: 'List files in an edge sandbox',
      description: 'Lists directory contents inside the sandbox.',
      inputSchema: z.object({
        sandboxId,
        path: z.string().min(1).default('/workspace').describe('Directory to list.')
      })
    },
    async ({ sandboxId, path }) => {
      const listing = await withSandbox(env, sandboxId, (s) => s.listFiles(path));
      return text(JSON.stringify(listing, null, 2));
    }
  );

  server.registerTool(
    'sandbox_destroy',
    {
      title: 'Destroy an edge sandbox',
      description:
        'Immediately tears down the container and frees its resources. Call this when finished rather than waiting for the idle timeout, which bills against the monthly allowance.',
      inputSchema: z.object({ sandboxId })
    },
    async ({ sandboxId }) => {
      // Concurrent destroy() calls coalesce onto one promise, and if teardown
      // hangs every caller waits on it until the Durable Object is evicted.
      // Bound the wait rather than holding the tool call open indefinitely.
      const timeout = new Promise<never>((_, reject) =>
        scheduler
          .wait(DESTROY_TIMEOUT_MS)
          .then(() => reject(new Error(`destroy timed out after ${DESTROY_TIMEOUT_MS}ms`)))
      );
      await Promise.race([getSandbox(env.Sandbox, sandboxId).destroy(), timeout]);
      await getRegistry(env).forget(sandboxId);
      return text(`destroyed sandbox ${sandboxId}`);
    }
  );

  server.registerTool(
    'sandbox_list',
    {
      title: 'List sandboxes this server has created',
      description:
        'Shows every sandbox this server has created, with how long ago each was used. Call this when a sandbox operation fails because container slots are exhausted, to decide which id to destroy. This reflects what this server created, not what Cloudflare is currently running: idle containers are reclaimed silently, so entries marked as likely reclaimed may already be gone. Destroying an already-reclaimed sandbox is harmless.',
      inputSchema: z.object({})
    },
    async () => {
      const entries = await getRegistry(env).list();
      if (entries.length === 0) return text('No sandboxes recorded.');
      return text(
        [`${entries.length} sandbox(es) known to this server:`, ...entries.map(describeEntry)].join(
          '\n'
        )
      );
    }
  );

  return server;
}

const digest = (value: string) =>
  crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));

/**
 * Compares the presented credential against the expected one in constant time.
 * Both sides are hashed first so the buffers are always the same length, which
 * timingSafeEqual requires and which stops the token length from leaking.
 */
async function isAuthorized(request: Request, secret: string): Promise<boolean> {
  const [presented, expected] = await Promise.all([
    digest(request.headers.get('Authorization') ?? ''),
    digest(`Bearer ${secret}`)
  ]);
  return crypto.subtle.timingSafeEqual(presented, expected);
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    // Fail closed. Without a configured secret every request would otherwise be
    // checked against the literal string "Bearer undefined", which is guessable.
    if (!env.MCP_SECRET_TOKEN) {
      return new Response('MCP_SECRET_TOKEN is not configured', { status: 503 });
    }

    if (!(await isAuthorized(request, env.MCP_SECRET_TOKEN))) {
      return new Response('Unauthorized', {
        status: 401,
        headers: { 'WWW-Authenticate': 'Bearer' }
      });
    }

    return createMcpHandler(() => createServer(env), { route: '/mcp' })(request, env, ctx);
  }
};
