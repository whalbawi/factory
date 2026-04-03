# /build — Agent-Team Construction Phase

The `/build` skill is the primary agentic skill in the Factory pipeline. It decomposes a
specified product into parallelizable tasks, assigns them to specialist agents working in
isolated git worktrees, and coordinates merging through an Architect agent. This is the only
skill that routinely spawns multiple sub-agents for concurrent work.

## Contract

**Required inputs**:

- `SPEC.md` — product specification with acceptance criteria
- `CLAUDE.md` — build conventions, commands, and project rules
- `specs/` — domain specs (`SPEC-{domain}.md`) defining bounded contexts
- Project scaffold — directory structure, dependencies, CI/CD (output of `/setup`)

**Optional inputs**:

- `PROTOTYPE-DECISION.md` — chosen prototype direction and architectural implications

**Outputs**:

- Source code — production implementation across all domains
- Pull requests — one per task, reviewed and merged in dependency order
- `PROGRESS.md` — rolled-up task status with per-agent breakdowns

**Failure mode**:

- `PROGRESS.md` with incomplete tasks, their status, and blocking reasons. Each task records
  its last known state so the build can be resumed.

## Category

**Agentic skill** — spawns sub-agents for parallel work. The Architect agent orchestrates
task assignment, dependency ordering, and merge coordination. Specialist agents execute
tasks concurrently in isolated git worktrees. This is the most resource-intensive skill in
the pipeline and the only one that requires multi-agent coordination as its default mode.

## Agent Team

Not all agents are active for every project. The Architect assigns agents based on the
project's domain decomposition and the agent assignment matrix from the spec.

| Prefix | Role               | Responsibility                                      |
|--------|--------------------|-----------------------------------------------------|
| ARC    | Software Architect | Orchestrator — task breakdown, merge, coordination   |
| BE     | Backend            | APIs, data layer, business logic, server-side code   |
| FE     | Frontend           | UI components, client-side logic, styling            |
| OPS    | DevOps             | Infrastructure, CI/CD tweaks, deployment configs     |
| SEC    | Security           | Auth implementation, input validation, hardening     |
| QA     | QA                 | Test authoring, coverage gaps, integration tests     |
| PD     | Product Design     | UX flows, accessibility, interaction patterns        |
| TW     | Tech Writing       | API docs, inline documentation, user-facing copy     |

### Worktree Naming

Each agent works in an isolated git worktree named:

```
{project}-wt-{agent-prefix}-{task}
```

Branch naming follows the pattern `feat/{task-description}` or `fix/{fix-description}`.

## Process

### Phase 1: Task Decomposition

The Architect reads `SPEC.md`, `specs/`, and `CLAUDE.md` and produces a task breakdown:

- Each task maps to a domain spec item or acceptance criterion
- Tasks are sized for a single PR (reviewable in one sitting)
- Dependencies between tasks are explicit and form a DAG
- Priority matches the spec's priority ordering
- Each task has an ID, description, difficulty estimate, and acceptance criteria

### Phase 2: Agent Assignment

The Architect assigns tasks to specialist agents based on:

- Domain ownership — tasks go to the agent whose domain they fall in
- Role match — backend tasks to BE, frontend to FE, infrastructure to OPS
- Dependency ordering — agents working on foundational tasks start first
- Load balancing — no single agent gets a disproportionate share

The Architect communicates assignments via `SendMessage`, including:

- Task ID and description
- Acceptance criteria
- Dependencies (which tasks must complete first)
- Relevant spec sections to read
- Branch name to use

### Phase 3: Parallel Execution in Worktrees

Agents work simultaneously, each in their own git worktree:

1. Agent creates a worktree: `{project}-wt-{PREFIX}-{task}`
2. Agent reads the relevant domain spec and `CLAUDE.md` conventions
3. Implementation follows small, incremental commits
4. Tests must pass before each commit
5. Lint and format must pass before each commit
6. Agent updates `PROGRESS-{PREFIX}.md` after each meaningful milestone

Agents must not modify files outside their assigned domain without coordinating with
the owning agent first.

### Phase 4: PR Workflow

When an agent completes a task:

1. Squash commits on the feature branch into a clean history
2. Rebase on latest `main`
3. Create PR via `gh pr create` with:
   - Title: task description
   - Body: acceptance criteria checklist, implementation notes
4. Monitor CI — if CI fails, fix and force-push the branch
5. Notify the Architect via `SendMessage` that the PR is ready for merge

### Phase 5: Architect Coordination

The Architect is responsible for integration:

- Merges PRs in dependency order using rebase-and-merge strategy
- Resolves merge conflicts (or delegates back to the conflicting agents)
- Updates `CLAUDE.md` with new learnings discovered during build
- Updates `PROGRESS.md` with rolled-up task status
- Notifies agents to rebase when `main` advances with new merges
- Detects integration issues early and reassigns work if needed

### Phase 6: Progress Tracking

Progress is tracked at two levels:

**Per-agent**: Each agent maintains `PROGRESS-{PREFIX}.md`:

```markdown
# Progress — {Agent Role}

| Task ID | Description | Difficulty | Acceptance Criteria | Status | Notes |
|---------|-------------|------------|---------------------|--------|-------|
```

**Rolled-up**: The Architect maintains `PROGRESS.md`:

```markdown
# Build Progress

## Summary
- **Total tasks**: N
- **Completed**: X
- **In progress**: Y
- **Blocked**: Z

## Tasks
| Task ID | Description | Assigned To | Status | PR | Notes |
|---------|-------------|-------------|--------|----|-------|
```

Status values: `pending`, `in_progress`, `blocked`, `in_review`, `merged`.

## State Tracking

Every skill must update `.factory/state.json` on invocation and completion, even when
invoked standalone outside the `/factory` pipeline. If no state file exists, create one.

**On start** — set the build phase to `in_progress`:

```json
{
  "phases": {
    "build": {
      "status": "in_progress",
      "started_at": "2026-04-03T13:00:00Z"
    }
  }
}
```

**On completion** — set to `completed` with outputs:

```json
{
  "phases": {
    "build": {
      "status": "completed",
      "started_at": "2026-04-03T13:00:00Z",
      "completed_at": "2026-04-03T18:30:00Z",
      "outputs": ["PROGRESS.md", "src/", "tests/"]
    }
  }
}
```

**On failure** — set to `failed` with reason:

```json
{
  "phases": {
    "build": {
      "status": "failed",
      "started_at": "2026-04-03T13:00:00Z",
      "failed_at": "2026-04-03T16:00:00Z",
      "failure_reason": "3 of 12 tasks blocked — see PROGRESS.md for details"
    }
  }
}
```

The state file must be updated atomically. Read the existing file, merge the build phase
state, and write back. Do not overwrite other phases' state.

## Communication

Agents communicate using `SendMessage` for direct coordination. The communication model
has two channels:

**Direct agent-to-agent**: For technical questions, interface negotiations, and
dependency handoffs. Agents must not wait for the Architect to relay technical
questions — DM the relevant agent directly.

Examples:

- BE -> FE: "The `/api/users` endpoint now returns `{ users: User[], cursor: string }`.
  Updated the type in `specs/SPEC-api.md`."
- FE -> PD: "The modal component is ready for review. Can you check the interaction
  flow?"
- QA -> BE: "The `createOrder` function throws on empty cart but the test expects a
  validation error response. Which is correct?"

**Status updates through the Architect**: Task completion notifications, blocker
escalation, and progress updates route through ARC. The Architect is the single source
of truth for overall build status.

### Communication Anti-Pattern

Do not broadcast status updates to all agents. Each agent should only receive messages
relevant to their work. The Architect handles rollup and cross-cutting coordination.

## Anti-Patterns

- **Monolith PRs**: Do not let a single PR contain changes across multiple domains. One
  task, one PR, one domain.

- **Prototype leakage**: Never copy code from `prototypes/` into production. Prototypes
  validated the approach, not the implementation.

- **Implicit dependencies**: Every dependency between tasks must be declared in the task
  breakdown. Agents discovering undeclared dependencies must notify the Architect
  immediately.

- **Gold plating**: Implement what the spec says. Features not in the spec do not get
  built. If an agent identifies a gap, they raise it to the Architect, who decides
  whether to update the spec or defer.

- **Silent failure**: If a task is blocked or failing, the agent must update their
  progress file and notify the Architect immediately. Do not spend cycles retrying
  without escalation.

- **Skipping tests**: Every task must include tests that verify its acceptance criteria.
  "I'll add tests later" is not acceptable — tests are part of the task definition.

- **Cross-domain edits without coordination**: Modifying files owned by another agent's
  domain causes merge conflicts and integration issues. Coordinate first via
  `SendMessage`.
