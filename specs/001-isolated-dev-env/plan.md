# Implementation Plan: Isolated Development Environment

**Branch**: `001-isolated-dev-env` | **Date**: 2025-11-07 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-isolated-dev-env/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Create an isolated development environment using containerization that allows running Claude Code with --dangerously-skip-permissions flag safely, pre-configured with NodeJS and Python runtimes, supporting secret injection at startup without persistence, and providing simple spin-up/tear-down commands. The environment isolates all operations from the host macOS system while enabling code sharing via volume mounts.

## Technical Context

**Language/Version**: Shell scripting (Bash/Zsh) for orchestration, Dockerfile for image definition
**Primary Dependencies**: OrbStack for containerization (chosen for macOS performance and native Apple Silicon support)
**Storage**: Container volumes for isolated filesystem, bind mounts for host code access
**Testing**: bats-core (Bash Automated Testing System) with bats-assert, bats-support, bats-file helper libraries
**Target Platform**: macOS (x86_64 and ARM64/Apple Silicon)
**Project Type**: Infrastructure/tooling - single project with scripts and configuration files
**Performance Goals**: Environment spin-up < 5 minutes (after image download), tear-down < 30 seconds
**Constraints**: Must support both Intel and Apple Silicon Macs, no GUI requirements, must isolate completely from host
**Scale/Scope**: Single-user development environments, designed for individual developer use (not multi-tenant)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Library-First Architecture
- ✅ **PASS**: Environment scripts will be self-contained and independently testable
- ✅ **PASS**: Dockerfile and orchestration scripts are reusable components

### II. Portable & Self-Contained
- ✅ **PASS**: Core requirement - entire feature is about portability and reproducibility
- ✅ **PASS**: No hardcoded paths, all dependencies declared in Dockerfile
- ✅ **PASS**: Setup scripts will be idempotent

### III. Test-Driven Development (NON-NEGOTIABLE)
- ✅ **PASS**: Will write tests for spin-up/tear-down operations before implementation
- ✅ **PASS**: Will write tests for isolation verification before implementation
- ✅ **PASS**: Will write tests for secret injection/non-persistence before implementation

### IV. Simplicity & YAGNI
- ✅ **PASS**: Starting with single container (not orchestration)
- ✅ **PASS**: No complex networking, just standard port mapping
- ✅ **PASS**: Standard volume mounts, no custom storage drivers

### V. Package Management & Dependencies
- ✅ **PASS**: Dockerfile will pin versions for NodeJS and Python
- ✅ **PASS**: Will use lock files for any script dependencies
- ✅ **PASS**: Minimal dependencies - only container runtime required on host

### VI. Documentation & Reproducibility
- ✅ **PASS**: Will create quickstart.md with < 5 steps (requirement)
- ✅ **PASS**: README will document setup and troubleshooting
- ✅ **PASS**: Inline comments in scripts for "why" not "what"

### VII. Observability & Debugging
- ✅ **PASS**: Scripts will output structured logs
- ✅ **PASS**: Error messages will include context
- ✅ **PASS**: Container logs accessible for debugging

### Quality Standards - Security
- ✅ **PASS**: Secrets not persisted (core requirement FR-008)
- ✅ **PASS**: No hardcoded credentials in Dockerfile or scripts
- ✅ **PASS**: Input validation for secret injection

**Overall Status**: ✅ **ALL GATES PASSED** - Proceeding to Phase 0 research

## Project Structure

### Documentation (this feature)

```text
specs/001-isolated-dev-env/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
.
├── Dockerfile                 # Container image definition with NodeJS, Python, Claude Code
├── docker-compose.yml         # Optional: orchestration for easier management
├── scripts/
│   ├── dev-env-up.sh         # Spin up isolated environment
│   ├── dev-env-down.sh       # Tear down and cleanup environment
│   ├── dev-env-shell.sh      # Access environment shell
│   └── install-claude.sh     # Install Claude Code in container
├── config/
│   ├── .env.template         # Template for environment variables (no secrets)
│   └── entrypoint.sh         # Container entrypoint script
├── tests/
│   ├── test-isolation.sh     # Verify host isolation
│   ├── test-secret-injection.sh  # Verify secret handling
│   ├── test-runtimes.sh      # Verify NodeJS and Python
│   └── test-cleanup.sh       # Verify complete teardown
└── docs/
    └── troubleshooting.md    # Common issues and solutions
```

**Structure Decision**: Using single project structure as this is infrastructure tooling. The repository root contains all scripts, Dockerfile, and configuration. This aligns with Simplicity & YAGNI principles - no complex layering needed for shell scripts and container configuration.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

**No complexity violations** - All constitution checks passed. Project follows YAGNI principles with simple shell scripts and single container architecture.

---

## Post-Phase 1 Constitution Re-Check

*Re-evaluated after completing research, data model, contracts, and quickstart*

### I. Library-First Architecture
- ✅ **PASS**: Shell scripts are self-contained and independently testable (contracts defined)
- ✅ **PASS**: Dockerfile is reusable component

### II. Portable & Self-Contained
- ✅ **PASS**: Quickstart demonstrates < 5 steps to running system
- ✅ **PASS**: All dependencies declared (OrbStack, bats-core)
- ✅ **PASS**: Configuration templates provided (.env.template)

### III. Test-Driven Development (NON-NEGOTIABLE)
- ✅ **PASS**: bats-core selected for testing framework
- ✅ **PASS**: Contract tests defined for all scripts
- ✅ **PASS**: Test structure documented (tests/*.bats files)

### IV. Simplicity & YAGNI
- ✅ **PASS**: Single container (not orchestration)
- ✅ **PASS**: Standard volume mounts and port mapping
- ✅ **PASS**: No unnecessary abstractions

### V. Package Management & Dependencies
- ✅ **PASS**: OrbStack and bats-core via Homebrew (reproducible)
- ✅ **PASS**: NodeJS and Python versions pinned in Dockerfile
- ✅ **PASS**: Minimal dependencies documented

### VI. Documentation & Reproducibility
- ✅ **PASS**: Quickstart.md provides < 5 steps
- ✅ **PASS**: Research.md documents technology decisions (ADRs)
- ✅ **PASS**: Troubleshooting section in quickstart

### VII. Observability & Debugging
- ✅ **PASS**: Scripts output structured logs (--verbose flag)
- ✅ **PASS**: Error messages include context and suggested actions
- ✅ **PASS**: Container logs accessible via docker logs

**Final Status**: ✅ **ALL CONSTITUTION CHECKS PASSED** - Ready for implementation

---

## Implementation Readiness

**Phase 0 Complete**: ✅
- Research.md completed
- Technology decisions made (OrbStack, bats-core)

**Phase 1 Complete**: ✅
- Data model defined (5 entities)
- Contracts documented (4 shell scripts)
- Quickstart guide created (< 5 steps)
- Agent context updated (CLAUDE.md)

**Ready for Phase 2**: ✅ `/speckit.tasks`
- All design artifacts complete
- Constitution compliance verified
- Can proceed to task generation
