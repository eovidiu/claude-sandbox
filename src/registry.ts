import { DurableObject } from 'cloudflare:workers';

/** What the Worker knows about one sandbox it created. */
export interface SandboxEntry {
  sandboxId: string;
  createdAt: number;
  lastUsedAt: number;
}

const KEY_PREFIX = 's:';

/**
 * Tracks which sandboxes this Worker has created.
 *
 * Neither the Sandbox SDK nor DurableObjectNamespace can enumerate live
 * sandboxes, so without this there is no way to answer "what is holding a
 * container slot". A single instance owns the whole map, which keeps writes
 * strongly consistent and makes a read immediately after a write correct.
 *
 * This is a record of what the Worker did, not of what Cloudflare is running:
 * idle containers are reclaimed silently, so an entry can outlive its sandbox.
 * Resolving that by probing would be self-defeating, because touching a sandbox
 * wakes it and consumes the very slot we are trying to account for.
 */
export class SandboxRegistry extends DurableObject {
  async touch(sandboxId: string): Promise<void> {
    const key = KEY_PREFIX + sandboxId;
    const existing = await this.ctx.storage.get<SandboxEntry>(key);
    const now = Date.now();
    await this.ctx.storage.put<SandboxEntry>(key, {
      sandboxId,
      createdAt: existing?.createdAt ?? now,
      lastUsedAt: now
    });
  }

  async forget(sandboxId: string): Promise<void> {
    await this.ctx.storage.delete(KEY_PREFIX + sandboxId);
  }

  /** Most recently used first, so the staleest reclaim candidates sort last. */
  async list(): Promise<SandboxEntry[]> {
    const stored = await this.ctx.storage.list<SandboxEntry>({ prefix: KEY_PREFIX });
    return [...stored.values()].sort((a, b) => b.lastUsedAt - a.lastUsedAt);
  }
}

/** The registry is a singleton; every Worker request addresses the same instance. */
export function getRegistry(env: Env): DurableObjectStub<SandboxRegistry> {
  return env.SandboxRegistry.getByName('registry');
}
