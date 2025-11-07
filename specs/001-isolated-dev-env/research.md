# Research: Isolated Development Environment

**Date**: 2025-11-07
**Feature**: Isolated Development Environment for Claude Code

## Overview

This document captures research findings and technology decisions for creating an isolated development environment on macOS. The research focused on resolving two key technical unknowns identified during planning.

---

## Decision 1: Container Runtime for macOS

### Decision: OrbStack

**Chosen Solution**: OrbStack (https://orbstack.dev)

### Rationale

OrbStack is the optimal choice for an individual developer on macOS creating isolated development environments:

1. **Performance Excellence**
   - Fastest startup time: ~2 seconds vs 15-30 seconds for alternatives
   - Lowest idle CPU usage: <0.1% vs 2-30% for competitors
   - Native integration with macOS through Apple's Virtualization Framework
   - Dynamic memory management optimized for macOS

2. **Developer Experience**
   - Native macOS GUI application with menu bar integration
   - Automatic domain names for containers (e.g., `myapp.local`)
   - Seamless file system and networking integration
   - Zero configuration required - works out of the box

3. **Licensing for Individual Use**
   - Free for personal use (matches our use case)
   - Only $8/user/month for commercial use if needed later
   - No restrictions on company size for personal projects

4. **Architecture Support**
   - Excellent support for Apple Silicon (M1/M2/M3/M4)
   - Supports both ARM64 and x86_64 architectures
   - Built specifically for Apple Silicon with Intel compatibility

### Alternatives Considered

| Option | Pros | Why Rejected |
|--------|------|--------------|
| **Docker Desktop** | Industry standard, extensive ecosystem | Resource-intensive (5-30% idle CPU), slower startup (15-30 seconds), commercial licensing restrictions for large companies |
| **Colima** | Free and open-source (MIT), good performance | Command-line only (no GUI), requires more manual configuration, slower startup (20-30 seconds) |
| **Podman** | Free and open-source, rootless security, daemonless | Less mature on macOS, Podman Desktop GUI still improving, ecosystem tooling gaps |
| **Lima** | Open-source foundation | Lower-level tool requiring more setup, less polished developer experience |

### Implementation Notes

**Installation:**
```bash
brew install orbstack
# Or download from https://orbstack.dev
```

**Key Features for Our Use Case:**
- Isolated environments via containers or VMs
- Automatic cleanup capabilities
- Easy secret management through environment variables
- Native macOS integration means better stability

**Architecture Support:**
- Run ARM64 containers natively on Apple Silicon
- Rosetta 2 integration for x86_64 emulation when needed
- Multi-platform builds supported

**Considerations:**
- Proprietary software (not open-source) - less transparency than alternatives
- macOS-only solution (lock-in to Apple ecosystem)
- If commercial use becomes needed, budget $8/month

---

## Decision 2: Testing Framework for Shell Scripts

### Decision: bats-core

**Chosen Solution**: bats-core (Bash Automated Testing System)

### Rationale

Bats-core is the best fit for testing shell scripts in our isolated development environment setup:

1. **Simplicity Aligned with YAGNI**
   - Minimal setup: `brew install bats-core` and ready to use
   - Straightforward syntax similar to actual bash scripts
   - No steep learning curve - can write tests immediately
   - TAP-compliant output (Test Anything Protocol)

2. **Practical Testing Capabilities**
   - Built-in `run` command for testing commands and scripts
   - Automatic capture of exit codes, stdout, and stderr
   - Setup/teardown hooks for test isolation
   - Helper libraries available (bats-assert, bats-support, bats-file)

3. **Infrastructure Testing Fit**
   - Excellent for testing isolation mechanisms
   - Easy to test cleanup operations (files, containers, processes)
   - Can test secret handling (environment variables, file permissions)
   - Works well with Docker/container commands

4. **CI/CD Ready**
   - Produces TAP and JUnit XML output
   - Fast execution
   - Parallel execution support with GNU parallel
   - Widely adopted with good documentation

5. **Ecosystem & Community**
   - Most popular shell testing framework
   - Active maintenance
   - Extensive documentation at bats-core.readthedocs.io

### Alternatives Considered

| Option | Pros | Why Rejected |
|--------|------|--------------|
| **ShellSpec** | Most feature-rich (BDD style, mocking, parameterized tests), POSIX compatible | Over-engineered for our needs (violates YAGNI), more complex syntax with DSL, longer learning curve |
| **shunit2** | xUnit-based (familiar pattern), supports Bourne-based shells | Less active development, older framework with fewer modern features, limited documentation |
| **Simple Bash Scripts** | Ultimate simplicity, no dependencies | No standardized structure, have to reinvent test reporting, no TAP output for CI integration |

### Implementation Notes

**Installation:**
```bash
# macOS via Homebrew
brew install bats-core

# Also install helpful libraries
brew install bats-support bats-assert bats-file
```

**Basic Test Structure:**
```bash
#!/usr/bin/env bats

setup() {
  # Runs before each test
  export TEST_DIR="$(mktemp -d)"
}

teardown() {
  # Runs after each test (cleanup)
  rm -rf "$TEST_DIR"
}

@test "container isolation works" {
  run docker run --rm ubuntu echo "hello"
  [ "$status" -eq 0 ]
  [ "$output" = "hello" ]
}

@test "secrets not exposed in logs" {
  export SECRET_VAR="sensitive"
  run ./your-script.sh
  [[ "$output" != *"sensitive"* ]]
}
```

**Testing Our Use Cases:**

**Isolation Testing:**
```bash
@test "container has no access to host secrets" {
  run docker run --rm ubuntu cat /host/secrets.txt
  [ "$status" -ne 0 ]
}
```

**Cleanup Testing:**
```bash
@test "cleanup removes all containers" {
  ./scripts/dev-env-up.sh
  ./scripts/dev-env-down.sh
  run docker ps -a
  [[ "$output" != *"dev-environment"* ]]
}
```

**Secret Handling:**
```bash
@test "environment variables not persisted" {
  ./scripts/dev-env-up.sh --env SECRET=value
  ./scripts/dev-env-down.sh
  run grep -r "SECRET=value" .
  [ "$status" -ne 0 ]
}
```

**Running Tests:**
```bash
# Run all tests
bats tests/

# Run specific test file
bats tests/test-isolation.sh

# Run with TAP output for CI
bats --tap tests/ | tee test-results.tap

# Run with JUnit XML for CI systems
bats --formatter junit tests/ > test-results.xml
```

---

## Summary

### Final Technology Stack

**Container Runtime**: OrbStack
- Free for personal use
- Best macOS performance and developer experience
- Native Apple Silicon support
- 2-second startup time

**Testing Framework**: bats-core
- Simple and aligned with YAGNI principle
- Perfect for infrastructure testing
- Easy setup via Homebrew
- TAP/JUnit output for CI integration

### Key Testing Principles

1. **Test Isolation**: Each test cleans up after itself (use setup/teardown)
2. **Test Containers**: Verify containers are properly isolated from host
3. **Test Secrets**: Ensure no secrets leak into logs or are accessible improperly
4. **Test Cleanup**: Verify all resources are removed (containers, volumes, networks)
5. **Fast Feedback**: Keep tests fast (< 1 second each when possible)

### Implementation Dependencies

```bash
# Required installations
brew install orbstack
brew install bats-core bats-support bats-assert bats-file
```

### Next Steps

With these decisions made, we can proceed to Phase 1:
- Define data model for environment configuration
- Create quickstart documentation
- Define shell script structure and conventions
