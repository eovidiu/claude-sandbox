# Tasks: Isolated Development Environment

**Input**: Design documents from `/specs/001-isolated-dev-env/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Tests are MANDATORY per constitution (TDD is NON-NEGOTIABLE). Tests written FIRST, verify they FAIL, then implement.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Single project**: `scripts/`, `config/`, `tests/` at repository root
- All shell scripts in `scripts/` directory
- Configuration in `config/` directory
- Tests in `tests/` directory

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [ ] T001 Create project directory structure (scripts/, config/, tests/, docs/)
- [ ] T002 [P] Create .env.template file in config/ with all configuration options
- [ ] T003 [P] Create README.md with project overview and prerequisites

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T004 Create Dockerfile with Ubuntu 22.04 base image at repository root
- [ ] T005 Add NodeJS LTS installation to Dockerfile with npm and yarn
- [ ] T006 Add Python 3.11+ installation to Dockerfile with pip
- [ ] T007 [P] Create config/entrypoint.sh script for container initialization
- [ ] T008 [P] Install bats-core testing framework via Homebrew on host
- [ ] T009 [P] Install bats-support, bats-assert, bats-file helper libraries

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Create Isolated Environment (Priority: P1) 🎯 MVP

**Goal**: Spin up and tear down isolated container environment with validation

**Independent Test**: Environment can be created, verified as isolated, and destroyed cleanly

### Tests for User Story 1 (TDD - WRITE THESE FIRST) ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T010 [P] [US1] Create tests/test-env-up.bats with test for successful environment creation
- [ ] T011 [P] [US1] Add test to tests/test-env-up.bats for OrbStack prerequisite check
- [ ] T012 [P] [US1] Add test to tests/test-env-up.bats for invalid config handling
- [ ] T013 [P] [US1] Add test to tests/test-env-up.bats for port conflict detection
- [ ] T014 [P] [US1] Create tests/test-isolation.bats with test for filesystem isolation
- [ ] T015 [P] [US1] Add test to tests/test-isolation.bats for process isolation
- [ ] T016 [P] [US1] Create tests/test-env-down.bats with test for complete cleanup
- [ ] T017 [P] [US1] Add test to tests/test-env-down.bats for idempotency (can run twice)

### Implementation for User Story 1

- [ ] T018 [US1] Create scripts/dev-env-up.sh with argument parsing (--config, --name, --mount, --port, --verbose, --help)
- [ ] T019 [US1] Add configuration loading logic to scripts/dev-env-up.sh (load .env file if specified)
- [ ] T020 [US1] Add configuration validation to scripts/dev-env-up.sh (check required fields, validate paths)
- [ ] T021 [US1] Add OrbStack prerequisite check to scripts/dev-env-up.sh (verify running, exit code 2 if not)
- [ ] T022 [US1] Add image pull/build logic to scripts/dev-env-up.sh (use Dockerfile from Phase 2)
- [ ] T023 [US1] Add container creation logic to scripts/dev-env-up.sh (docker run with config)
- [ ] T024 [US1] Add container start and health check to scripts/dev-env-up.sh (wait max 30s)
- [ ] T025 [US1] Add success output formatting to scripts/dev-env-up.sh (container info, next steps)
- [ ] T026 [US1] Add verbose logging mode to scripts/dev-env-up.sh (--verbose flag)
- [ ] T027 [US1] Add error handling to scripts/dev-env-up.sh (exit codes 1-5 per contract)
- [ ] T028 [US1] Create scripts/dev-env-down.sh with environment name argument
- [ ] T029 [US1] Add container stop logic to scripts/dev-env-down.sh (graceful stop, 30s timeout)
- [ ] T030 [US1] Add container removal logic to scripts/dev-env-down.sh (remove container)
- [ ] T031 [US1] Add volume cleanup logic to scripts/dev-env-down.sh (unless --keep-volumes)
- [ ] T032 [US1] Add cleanup verification to scripts/dev-env-down.sh (check no orphans)
- [ ] T033 [US1] Add user confirmation prompt to scripts/dev-env-down.sh (unless --force)
- [ ] T034 [US1] Run all tests in tests/test-env-up.bats and verify they PASS
- [ ] T035 [US1] Run all tests in tests/test-isolation.bats and verify they PASS
- [ ] T036 [US1] Run all tests in tests/test-env-down.bats and verify they PASS

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently

---

## Phase 4: User Story 2 - Run Claude Code Inside Environment (Priority: P1)

**Goal**: Install Claude Code in container and provide shell access script

**Independent Test**: Can access environment shell and run Claude Code with --dangerously-skip-permissions

### Tests for User Story 2 (TDD - WRITE THESE FIRST) ⚠️

- [ ] T037 [P] [US2] Create tests/test-claude-install.bats with test for Claude Code installation
- [ ] T038 [P] [US2] Add test to tests/test-claude-install.bats for Claude version check
- [ ] T039 [P] [US2] Create tests/test-env-shell.bats with test for shell access
- [ ] T040 [P] [US2] Add test to tests/test-env-shell.bats for command execution (--command flag)
- [ ] T041 [P] [US2] Add test to tests/test-env-shell.bats for user switching (--user flag)

### Implementation for User Story 2

- [ ] T042 [P] [US2] Create scripts/install-claude.sh for installing Claude Code binary
- [ ] T043 [US2] Add Claude Code download logic to scripts/install-claude.sh (with retries)
- [ ] T044 [US2] Add installation to PATH in scripts/install-claude.sh (/opt/claude or /usr/local/bin)
- [ ] T045 [US2] Add installation verification to scripts/install-claude.sh (--verify flag)
- [ ] T046 [US2] Update Dockerfile to call scripts/install-claude.sh during image build
- [ ] T047 [P] [US2] Create scripts/dev-env-shell.sh with environment name argument
- [ ] T048 [US2] Add shell access logic to scripts/dev-env-shell.sh (docker exec with interactive terminal)
- [ ] T049 [US2] Add command execution mode to scripts/dev-env-shell.sh (--command flag)
- [ ] T050 [US2] Add user switching to scripts/dev-env-shell.sh (--user flag)
- [ ] T051 [US2] Add working directory option to scripts/dev-env-shell.sh (--workdir flag)
- [ ] T052 [US2] Run all tests in tests/test-claude-install.bats and verify they PASS
- [ ] T053 [US2] Run all tests in tests/test-env-shell.bats and verify they PASS

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently

---

## Phase 5: User Story 3 - NodeJS and Python Development Support (Priority: P1)

**Goal**: Verify pre-installed runtimes are functional and ready for development

**Independent Test**: Can execute NodeJS and Python commands with package managers working

### Tests for User Story 3 (TDD - WRITE THESE FIRST) ⚠️

- [ ] T054 [P] [US3] Create tests/test-runtimes.bats with test for NodeJS version check
- [ ] T055 [P] [US3] Add test to tests/test-runtimes.bats for npm version check
- [ ] T056 [P] [US3] Add test to tests/test-runtimes.bats for yarn version check
- [ ] T057 [P] [US3] Add test to tests/test-runtimes.bats for Python version check
- [ ] T058 [P] [US3] Add test to tests/test-runtimes.bats for pip version check
- [ ] T059 [P] [US3] Add test to tests/test-runtimes.bats for npm package installation
- [ ] T060 [P] [US3] Add test to tests/test-runtimes.bats for pip package installation

### Implementation for User Story 3

- [ ] T061 [US3] Update Dockerfile NodeJS installation to pin specific LTS version
- [ ] T062 [US3] Update Dockerfile Python installation to pin version 3.11+
- [ ] T063 [US3] Add npm global packages installation to Dockerfile (yarn)
- [ ] T064 [US3] Add pip global packages installation to Dockerfile (virtualenv, pipenv)
- [ ] T065 [US3] Add runtime verification script to Dockerfile build stage (test versions)
- [ ] T066 [US3] Run all tests in tests/test-runtimes.bats and verify they PASS

**Checkpoint**: All P1 user stories should now be independently functional (MVP complete!)

---

## Phase 6: User Story 4 - Secret Injection on Startup (Priority: P2)

**Goal**: Support secret injection via environment variables and files without disk persistence

**Independent Test**: Secrets available in container but not persisted after destruction

### Tests for User Story 4 (TDD - WRITE THESE FIRST) ⚠️

- [ ] T067 [P] [US4] Create tests/test-secret-injection.bats with test for environment variable injection
- [ ] T068 [P] [US4] Add test to tests/test-secret-injection.bats for secret file mounting
- [ ] T069 [P] [US4] Add test to tests/test-secret-injection.bats for secret availability in container
- [ ] ] T070 [P] [US4] Add test to tests/test-secret-injection.bats for no persistence after destruction
- [ ] T071 [P] [US4] Add test to tests/test-secret-injection.bats for special characters handling
- [ ] T072 [P] [US4] Add test to tests/test-secret-injection.bats for multi-line secret values

### Implementation for User Story 4

- [ ] T073 [US4] Add --secret flag parsing to scripts/dev-env-up.sh (KEY=VALUE format)
- [ ] T074 [US4] Add --secret-file flag parsing to scripts/dev-env-up.sh (HOST:CONTAINER[:MODE] format)
- [ ] T075 [US4] Add secret validation to scripts/dev-env-up.sh (check not in config files)
- [ ] T076 [US4] Add secret injection via docker run --env to scripts/dev-env-up.sh
- [ ] T077 [US4] Add secret file mounting via tmpfs to scripts/dev-env-up.sh (memory-backed)
- [ ] T078 [US4] Add secret sanitization to output logs in scripts/dev-env-up.sh (mask secrets)
- [ ] T079 [US4] Update config/entrypoint.sh to handle secret environment variables
- [ ] T080 [US4] Run all tests in tests/test-secret-injection.bats and verify they PASS

**Checkpoint**: All user stories should now be independently functional

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T081 [P] Create docs/troubleshooting.md with common issues and solutions
- [ ] T082 [P] Update README.md with complete usage instructions from quickstart.md
- [ ] T083 [P] Add usage examples to README.md for all scripts
- [ ] T084 [P] Add inline comments to all scripts explaining "why" not "what"
- [ ] T085 [P] Create .gitignore file (ignore .env, exclude .env.template)
- [ ] T086 Add error message improvements across all scripts (context + suggested actions)
- [ ] T087 [P] Add --help output to all scripts with usage examples
- [ ] T088 Optimize Dockerfile for layer caching (order by change frequency)
- [ ] T089 [P] Add shellcheck linting to all shell scripts
- [ ] T090 Validate all tests pass together (run bats tests/ from root)
- [ ] T091 Performance test: Verify environment spin-up < 5 minutes (after image download)
- [ ] T092 Performance test: Verify environment tear-down < 30 seconds
- [ ] T093 Validate quickstart.md instructions work end-to-end

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-6)**: All depend on Foundational phase completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P1 → P1 → P2)
- **Polish (Phase 7)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P1)**: Can start after Foundational (Phase 2) - No dependencies (Claude install separate from env creation)
- **User Story 3 (P1)**: Can start after Foundational (Phase 2) - No dependencies (runtime verification separate)
- **User Story 4 (P2)**: Can start after Foundational (Phase 2) - Requires User Story 1 for scripts/dev-env-up.sh to exist

### Within Each User Story

- Tests (TDD) MUST be written and FAIL before implementation
- Within US1: Tests first → Script creation → Logic implementation → Error handling → Test verification
- Within US2: Tests first → Claude install script → Shell access script → Test verification
- Within US3: Tests first → Dockerfile updates → Runtime verification → Test verification
- Within US4: Tests first → Secret flag parsing → Injection logic → Test verification

### Parallel Opportunities

- **Phase 1 (Setup)**: All 3 tasks can run in parallel (T002, T003)
- **Phase 2 (Foundational)**: T005-T009 can run in parallel after T004
- **Phase 3 (US1) Tests**: T010-T017 can all run in parallel (different test files)
- **Phase 4 (US2) Tests**: T037-T041 can all run in parallel (different test files)
- **Phase 4 (US2) Implementation**: T042 and T047 can start in parallel (different scripts)
- **Phase 5 (US3) Tests**: T054-T060 can all run in parallel (same test file, different test cases)
- **Phase 6 (US4) Tests**: T067-T072 can all run in parallel (same test file, different test cases)
- **Phase 7 (Polish)**: T081-T085, T087, T089 can all run in parallel (different files)
- **Cross-Story Parallelism**: After Phase 2, can work on US1, US2, US3 simultaneously (US4 needs US1 complete)

---

## Parallel Example: User Story 1 Tests

```bash
# Launch all tests for User Story 1 together (TDD - write these first):
Task T010: "Create tests/test-env-up.bats with test for successful environment creation"
Task T011: "Add test to tests/test-env-up.bats for OrbStack prerequisite check"
Task T012: "Add test to tests/test-env-up.bats for invalid config handling"
Task T013: "Add test to tests/test-env-up.bats for port conflict detection"
Task T014: "Create tests/test-isolation.bats with test for filesystem isolation"
Task T015: "Add test to tests/test-isolation.bats for process isolation"
Task T016: "Create tests/test-env-down.bats with test for complete cleanup"
Task T017: "Add test to tests/test-env-down.bats for idempotency"

# Then implement User Story 1 scripts sequentially (tests will guide implementation)
```

---

## Implementation Strategy

### MVP First (User Stories 1, 2, 3 - All P1)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1 (Create/Destroy Environment)
4. **STOP and VALIDATE**: Test User Story 1 independently
5. Complete Phase 4: User Story 2 (Claude Code + Shell Access)
6. **STOP and VALIDATE**: Test User Story 2 independently
7. Complete Phase 5: User Story 3 (Runtime Verification)
8. **STOP and VALIDATE**: Test User Story 3 independently
9. **MVP COMPLETE** - All P1 stories functional

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Demo (Environment spin-up/down works!)
3. Add User Story 2 → Test independently → Demo (Can run Claude Code inside!)
4. Add User Story 3 → Test independently → Demo (NodeJS/Python ready!)
5. Add User Story 4 → Test independently → Demo (Secrets working!)
6. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1 (T010-T036)
   - Developer B: User Story 2 (T037-T053)
   - Developer C: User Story 3 (T054-T066)
3. Stories complete and integrate independently
4. Developer A (finished first): User Story 4 (T067-T080)
5. All developers: Polish (T081-T093)

---

## Notes

- **TDD ENFORCED**: Per constitution, tests MUST be written first, verified to FAIL, then implement
- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing (red-green-refactor)
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- All shell scripts must be executable: `chmod +x scripts/*.sh`
- All shell scripts should include shebang: `#!/usr/bin/env bash`
- Use absolute paths in scripts (avoid relative path issues)
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence

---

## Total Task Count

- **Setup (Phase 1)**: 3 tasks
- **Foundational (Phase 2)**: 6 tasks
- **User Story 1 (Phase 3)**: 27 tasks (8 tests + 19 implementation)
- **User Story 2 (Phase 4)**: 17 tasks (5 tests + 12 implementation)
- **User Story 3 (Phase 5)**: 13 tasks (7 tests + 6 implementation)
- **User Story 4 (Phase 6)**: 14 tasks (6 tests + 8 implementation)
- **Polish (Phase 7)**: 13 tasks
- **TOTAL**: 93 tasks

**Test Tasks**: 26 (28% of total - ensures quality per TDD requirement)
**Implementation Tasks**: 45 (48%)
**Infrastructure/Polish**: 22 (24%)

**Parallel Opportunities**: 45 tasks marked [P] can run concurrently (48%)

**MVP Scope** (User Stories 1-3): 47 tasks total
**Full Feature** (All User Stories): 80 tasks (excluding polish)
