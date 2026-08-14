import { getSandbox } from '@cloudflare/sandbox';
import { McpServer } from '@modelcontextprotocol/server';
import { createMcpHandler } from 'agents/mcp/server';
import { z } from 'zod';

// Cloudflare binds the container to this Durable Object class. Removing this
// export makes the Worker undeployable.
export { Sandbox } from '@cloudflare/sandbox';

const sandboxId = z
  .string()
  .min(1)
  .describe('Groups calls into one container. The same id reuses the same sandbox.');

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
      const result = await getSandbox(env.Sandbox, sandboxId).exec(command);
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
      await getSandbox(env.Sandbox, sandboxId).writeFile(path, content);
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
      const file = await getSandbox(env.Sandbox, sandboxId).readFile(path);
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
      const listing = await getSandbox(env.Sandbox, sandboxId).listFiles(path);
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
      await getSandbox(env.Sandbox, sandboxId).destroy();
      return text(`destroyed sandbox ${sandboxId}`);
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
