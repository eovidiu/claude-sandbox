# Contributing to cloudflare-sandbox-mcp

Thank you for your interest in contributing! This project welcomes contributions from the community.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How to Contribute](#how-to-contribute)
- [Development Setup](#development-setup)
- [Testing Guidelines](#testing-guidelines)
- [Commit Guidelines](#commit-guidelines)
- [Pull Request Process](#pull-request-process)
- [Reporting Bugs](#reporting-bugs)
- [Suggesting Features](#suggesting-features)

## Code of Conduct

This project adheres to a simple principle: **Be respectful and constructive**. We welcome contributors of all experience levels and backgrounds.

## How to Contribute

### Good First Issues

Look for issues labeled `good-first-issue` to get started. These are typically:
- Documentation improvements
- Adding examples
- Fixing typos or clarifying error messages
- Adding tests for existing functionality

### Areas We Need Help

- **Cross-platform support**: Testing on different macOS versions (Intel/Apple Silicon)
- **Documentation**: Improving troubleshooting guides and examples
- **Testing**: Adding edge cases and integration tests
- **Features**: Implementing new user stories from the roadmap

## Development Setup

### Prerequisites

- Node 18+
- Docker, for `wrangler dev` and `wrangler deploy` (both build the container image)
- A Cloudflare account on the Workers Paid plan, to deploy

```bash
git clone https://github.com/eovidiu/claude-sandbox.git
cd claude-sandbox
npm install

# Local-only token for `wrangler dev`; this file is gitignored
echo 'MCP_SECRET_TOKEN="local-dev-only-not-a-secret"' > .dev.vars
```

### Running Locally

```bash
npm run typecheck
npm run dev
```

## Testing Guidelines

Verification is done against a running server rather than a unit test suite,
because everything of interest is the interaction between the Worker, the
Durable Object and the container.

With `npm run dev` up, POST JSON-RPC to `http://localhost:8787/mcp`. A change is
good when all of these hold:

- no `Authorization` header returns `401`
- a wrong token returns `401`
- a correct token returns `200`
- `tools/list` returns all five tools
- a `sandbox_write_file` → `sandbox_execute` → `sandbox_read_file` →
  `sandbox_destroy` round trip succeeds against one `sandboxId`

```bash
curl -s -X POST http://localhost:8787/mcp \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -H 'Authorization: Bearer local-dev-only-not-a-secret' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

### Requirements for a change

- ✅ `npm run typecheck` passes
- ✅ The checks above pass locally before you open a PR
- ✅ New tools are exercised by a round trip, not just `tools/list`
- ✅ Sandboxes created while testing are destroyed afterwards

## Commit Guidelines

We follow **Conventional Commits** for clear commit history:

### Commit Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `test`: Adding or updating tests
- `refactor`: Code refactoring (no functional changes)
- `perf`: Performance improvements
- `chore`: Build process or tooling changes

### Examples

```bash
# Feature
git commit -m "feat(scripts): add support for custom Docker networks"

# Bug fix
git commit -m "fix(env-up): handle ports already in use gracefully"

# Documentation
git commit -m "docs(readme): add examples for secret injection"

# Test
git commit -m "test(isolation): add network namespace verification"
```

### Commit Message Guidelines

- ✅ Use present tense ("add feature" not "added feature")
- ✅ Keep subject line under 72 characters
- ✅ Reference issues in footer (e.g., "Fixes #42")
- ✅ Explain **why** not **what** in the body

## Pull Request Process

### Before Submitting

1. ✅ **Typecheck and verify**: `npm run typecheck`, then the round trip above
2. ✅ **Update documentation**: README and CLAUDE.md
3. ✅ **Follow code style**: match the existing TypeScript conventions
4. ✅ **Add inline comments**: explain "why" not "what"
5. ✅ **Check for secrets**: No hardcoded credentials or personal paths

### PR Checklist

- [ ] Tests pass locally
- [ ] Documentation updated
- [ ] No merge conflicts with `main`
- [ ] Commit messages follow guidelines
- [ ] Code follows existing style
- [ ] Security review completed (no secrets)

### PR Description Template

```markdown
## Summary
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
Describe how you tested your changes

## Checklist
- [ ] Tests pass
- [ ] Documentation updated
- [ ] No secrets exposed
```

### Review Process

1. Submit PR with clear description
2. Automated tests will run (if configured)
3. Maintainer will review within 3-5 days
4. Address feedback in new commits
5. Once approved, PR will be merged

## Reporting Bugs

### Before Reporting

1. Check existing issues
2. Verify you're on the latest version
3. Test in a clean environment

### Bug Report Template

```markdown
**Description**
Clear description of the bug

**To Reproduce**
Steps to reproduce:
1. Call tool: `sandbox_execute` with ...
2. See error

**Expected Behavior**
What you expected to happen

**Environment**
- Local or deployed: [wrangler dev / workers.dev]
- Wrangler version: [`npx wrangler --version`]
- Worker version ID: [from `wrangler deploy` output]
- Docker version: [`docker info --format '{{.ServerVersion}}'`, local only]

**Logs**
```bash
# Paste relevant logs here
```

**Additional Context**
Any other relevant information
```

## Suggesting Features

We welcome feature suggestions! Please:

1. Check existing issues/discussions
2. Describe the use case
3. Explain why it's valuable
4. Propose implementation approach (optional)

### Feature Request Template

```markdown
**Problem Statement**
What problem does this solve?

**Proposed Solution**
How should it work?

**Alternatives Considered**
Other approaches you considered

**Additional Context**
Examples, mockups, or references
```

## Code Style Guidelines

### TypeScript

```ts
// Describe every tool argument. The description is what the calling model
// sees, so it is part of the interface, not a comment.
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
```

- Return a failed command as a normal result carrying stderr and the exit code.
  Throwing hides the detail the caller needs to recover.
- Comment the "why" not the "what". The Dockerfile explains why Python is added;
  the auth helper explains why both sides are hashed before comparison.
- Prefer the `sandbox.*` methods over the SDK's internal clients.

### Documentation

- Use clear, concise language
- Include examples
- Keep troubleshooting guide updated
- Add inline comments for complex logic

## Security

### Reporting Security Issues

**Do not open public issues for security vulnerabilities.**

Instead, email: [your-email] with:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (optional)

### Security Guidelines for Contributors

- ✅ Never commit secrets or credentials
- ✅ Use `.gitignore` to exclude sensitive files
- ✅ Validate all user inputs
- ✅ Use proper exit codes for error handling
- ✅ Follow principle of least privilege

## Getting Help

- **Questions**: Open a GitHub Discussion
- **Bugs**: Open a GitHub Issue
- **Chat**: [If you have a Discord/Slack channel]

## Recognition

Contributors will be acknowledged in:
- GitHub contributors page
- Release notes
- Project README (for significant contributions)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing! 🎉
