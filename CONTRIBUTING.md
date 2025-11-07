# Contributing to Isolated Development Environment

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

- macOS (Intel or Apple Silicon)
- OrbStack or Docker Desktop
- bats-core (for running tests)

```bash
# Install bats testing framework
brew install bats-core bats-support bats-assert bats-file

# Clone the repository
git clone https://github.com/eovidiu/dev-setup.git
cd dev-setup

# Copy configuration template
cp config/.env.template config/.env

# Edit config/.env with your settings
nano config/.env
```

### Running Tests

```bash
# Run all tests
bats tests/

# Run specific test file
bats tests/test-env-up.bats

# Run with verbose output
bats -t tests/
```

### Building the Docker Image

```bash
# Build the image
docker build -t isolated-dev-env:latest .

# Test the image
./scripts/dev-env-up.sh
./scripts/dev-env-shell.sh claude-dev --command "verify-runtimes.sh"
./scripts/dev-env-down.sh claude-dev --force
```

## Testing Guidelines

All contributions should include tests. We use **bats-core** for testing.

### Test Structure

```bash
#!/usr/bin/env bats
# Tests for [feature name]

load test_helper/bats-support/load
load test_helper/bats-assert/load

setup() {
    # Setup test environment
}

teardown() {
    # Cleanup test environment
}

@test "descriptive test name" {
    run ./scripts/your-script.sh
    assert_success
    assert_output --partial "expected output"
}
```

### Test Requirements

- ✅ All new features must have tests
- ✅ Tests must pass locally before submitting PR
- ✅ Tests should be isolated (no dependencies between tests)
- ✅ Use descriptive test names
- ✅ Clean up resources in `teardown()`

### Running Specific Tests

```bash
# Run tests for a specific feature
bats tests/test-secret-injection.bats

# Run a single test
bats tests/test-env-up.bats --filter "creates container successfully"
```

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

1. ✅ **Run all tests**: `bats tests/`
2. ✅ **Update documentation**: README, troubleshooting guide, etc.
3. ✅ **Follow code style**: Match existing shell script conventions
4. ✅ **Add inline comments**: Explain "why" not "what"
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
1. Run command: `./scripts/dev-env-up.sh`
2. See error

**Expected Behavior**
What you expected to happen

**Environment**
- macOS version: [e.g., Sonoma 14.5]
- Architecture: [Intel/Apple Silicon]
- Docker/OrbStack version: [e.g., OrbStack 1.5.0]
- Script version: [from git commit hash]

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

### Shell Scripts

```bash
#!/bin/bash
# Script description
# Part of User Story X

set -euo pipefail  # Always use strict mode

# Use meaningful variable names
ENV_NAME="claude-dev"

# Functions have documentation
#######################################
# Description of what function does
# Globals:
#   VARIABLE_NAME
# Arguments:
#   $1 - Description
# Returns:
#   0 - Success
#   1 - Failure
#######################################
function_name() {
    local param="$1"
    # Implementation
}

# Use descriptive error messages
error_exit "Configuration file not found: $CONFIG_FILE" $EXIT_INVALID_ARGS

# Comment the "why" not the "what"
# Use symlinks instead of PATH modification to avoid shell-specific issues
ln -sf /usr/local/bin/node /usr/bin/node
```

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
