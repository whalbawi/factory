# Sprint Execution Model -- Domain Spec

## Overview

This spec defines a sprint-based execution model for the Factory pipeline. Instead of
building everything at once and running QA/security only after all construction is complete,
work is sized into ordered sprints during `/spec` and executed serially during `/build`.
After each sprint, QA and security run as checkpoints. This gives incremental validation
with bounded blast radius -- issues found after sprint 2 affect only sprint 2's changes,
not the entire product.

A sprint is an ordered batch of tasks from the task DAG. Sprints execute serially. Within
a sprint, the existing parallel agent model is unchanged -- agents still work in worktrees,
submit PRs, and merge through the Architect. The difference is that the Architect stops
after each sprint's tasks are merged, and QA/security run before the next sprint begins.

**Opt-out**: A project with a single sprint is identical to the current behavior. The spec
skill sizes work into one sprint when the project is small enough, and the build skill
executes it without any checkpoint overhead. No user action required.

---

## Contract

This is a cross-cutting change that modifies four existing skills. No new skills are
introduced.

| Skill | What changes |
|-------|--------------|
| `/spec` | Phase 2b (Decomposition) produces a sprint plan alongside the domain decomposition |
| `/build` | Architect executes one sprint at a time, pausing between sprints for checkpoints |
| `/genesis` | Orchestrates the sprint loop: build(sprint N) -> QA -> security -> build(sprint N+1) |
| `/qa` | Supports scoped-sprint mode alongside full-project mode |
| `/security` | Supports scoped-sprint mode alongside full-project mode |

### Inputs

- `SPEC.md` with a `## Sprint Plan` section (produced by `/spec`)
- Domain specs in `specs/` with tasks tagged by sprint number
- `.factory/state.json` with sprint-level tracking

### Outputs

- `QA-REPORT-sprint-{N}.md` after each sprint checkpoint
- `SECURITY-sprint-{N}.md` after each sprint checkpoint (only if security findings exist)
- `QA-REPORT.md` final consolidated report after all sprints
- `SECURITY.md` final consolidated report after all sprints
- Sprint-level state in `.factory/state.json`

---

## Design Decisions

### 1. Where does sprint sizing happen?

**Decision**: In `/spec` during Phase 2b (Decomposition), as an extension of the existing
execution plan -- not as a new step.

**Rationale**: Phase 2b already produces a build order with parallel batches. Sprints are a
higher-level grouping of those batches. The Architect already has the task DAG, domain
dependencies, and priority ordering at this point. Adding sprint boundaries is a natural
extension of "here is the order to build things."

A separate step would be artificial -- the information needed for sprint sizing (task
dependencies, domain boundaries, priority tiers) is exactly what Phase 2b already computes.

### 2. What defines a sprint?

**Decision**: A sprint is a subset of the task DAG defined by three criteria applied in
order:

1. **Dependency closure**: Every task in a sprint has all its dependencies satisfied by
   tasks in the same sprint or earlier sprints. No forward references.
2. **Priority cohesion**: Higher-priority items from the spec's ordered in-scope list land
   in earlier sprints. Sprint 1 contains the highest-priority work.
3. **Size bound**: A sprint targets 3-8 tasks. Fewer than 3 means checkpoint overhead is
   disproportionate. More than 8 means the blast radius is too large.

Sprints are NOT defined by domain -- a sprint can (and usually does) contain tasks from
multiple domains. They are NOT defined by the parallel batches from Phase 2b -- a sprint
may contain one or more batches depending on task count.

**Sizing heuristic**:

| Total tasks in project | Sprint count | Rationale |
|------------------------|--------------|-----------|
| 1-8 | 1 (no checkpoints) | Checkpoint overhead exceeds benefit |
| 9-16 | 2 | Split at the natural dependency boundary closest to the midpoint |
| 17-30 | 3-4 | Split by priority tiers from the spec's ordered list |
| 31+ | 4-6 | Split by priority tiers, respecting the size bound |

### 3. How are sprints recorded?

**Decision**: In `SPEC.md` as a `## Sprint Plan` section within the existing Domain
Decomposition area. Sprint assignments are also recorded per-task in the Execution Plan.

**Rationale**: The sprint plan is a specification artifact -- it defines what gets built
in what order. It belongs in the spec, not in state.json (which tracks runtime progress,
not plans) or a separate file (which fragments the spec).

Sprint *progress* is tracked in `.factory/state.json` under the build phase.

### 4. How does /build change?

**Decision**: The Architect executes one sprint at a time. Between sprints, the Architect
signals completion and control returns to `/genesis` (or to the user if `/build` was
invoked standalone). QA and security run as checkpoints before the next sprint starts.

**Rationale**: Having `/genesis` orchestrate the sprint loop keeps `/build` focused on
construction and keeps gate skills independent. The Architect should not invoke `/qa` or
`/security` -- those are pipeline concerns, not build concerns. This also means standalone
`/build` invocations work: the Architect finishes one sprint and tells the user "Sprint 1
complete. Run /qa and /security before I start sprint 2."

When `/build` is invoked standalone (not via `/genesis`), the Architect:
1. Reads the sprint plan from `SPEC.md`.
2. Reads sprint progress from `.factory/state.json`.
3. Executes the next incomplete sprint.
4. On completion, informs the user: "Sprint N complete. Run /qa and /security before
   continuing to sprint N+1."
5. Exits. The user invokes `/build` again after checkpoints pass.

When `/build` is invoked via `/genesis`, the orchestrator handles the loop automatically.

### 5. How do QA/security checkpoints work?

**Decision**: Checkpoints are scoped to the sprint's changes by default, with a
full-project regression check. A failing checkpoint blocks the next sprint.

**Checkpoint scope**:
- **Coverage analysis**: Scoped to files changed in the sprint.
- **Test quality audit**: Scoped to new/modified tests in the sprint.
- **Acceptance criteria**: Only criteria addressed by sprint tasks.
- **Edge case hunting**: Scoped to new code paths introduced in the sprint.
- **Regression check**: Full project -- ensures the sprint did not break existing work.
- **Security audit**: Scoped to changed files, but dependency audit is always full-project.

**Gate behavior**: A failing checkpoint (QA status: FAIL, or security status: BLOCKED)
prevents the next sprint from starting. The user must either fix the issues (via `/bugfix`
or manual intervention) and re-run the checkpoint, or explicitly override:

```text
Sprint 2 QA found 1 critical issue. Sprint 3 cannot start until resolved.
Options: [fix and re-run QA / override and continue / abort build]
```

Override is recorded in state with the user's rationale. This is an escape hatch, not a
normal workflow.

**Checkpoint reports**: Each checkpoint produces a sprint-scoped report:
- `QA-REPORT-sprint-{N}.md`
- `SECURITY-sprint-{N}.md` (only produced if there are findings; CLEAR sprints get a
  one-line note in the final consolidated report)

After all sprints complete, a final full-project QA and security pass runs (the existing
behavior). The final reports (`QA-REPORT.md`, `SECURITY.md`) consolidate all sprint
findings and add cross-sprint integration analysis.

### 6. What about /retro?

**Decision**: `/retro` runs once after all sprints complete, not after each sprint.

**Rationale**: Retro is a process reflection skill. It examines team coordination, agent
communication patterns, and build process health. These patterns only emerge across the
full build, not within a single sprint. Running retro per-sprint would produce shallow,
repetitive reports ("we did the same thing again").

The sprint checkpoints (QA/security) serve the role that retro might otherwise fill
mid-build -- they catch problems early. Retro examines the process, not the code.

The pipeline with sprints becomes:

```text
/spec -> ... -> /build(sprint 1) -> QA checkpoint -> security checkpoint
             -> /build(sprint 2) -> QA checkpoint -> security checkpoint
             -> ...
             -> /build(sprint N) -> QA checkpoint -> security checkpoint
             -> /retro -> /qa (full) -> /security (full) -> /deploy
```

### 7. How does this interact with /bugfix?

**Decision**: Bugfixes happen between sprints, during the checkpoint window.

**Rationale**: When a sprint checkpoint finds a critical issue, the natural response is
to fix it before continuing. `/bugfix` is designed for exactly this -- small, scoped fixes
with their own compressed pipeline. The checkpoint window (after QA/security, before the
next sprint) is the natural place for bugfixes.

**Flow**:
1. Sprint N completes.
2. QA checkpoint finds a critical bug.
3. User invokes `/bugfix` to fix it.
4. `/bugfix` runs its own QA/security on the fix.
5. Sprint checkpoint is re-run to confirm the fix and verify no regressions.
6. Sprint N+1 begins.

Bugfixes during the checkpoint window do NOT invalidate the sprint's QA/security reports
because `/bugfix` runs its own gates. However, the sprint checkpoint must be re-run after
the bugfix to capture the updated state (the re-run should be fast since most checks will
pass).

---

## Skill Changes

### /spec SKILL.md Changes

#### Phase 2b Addition: Sprint Sizing

After the Architect produces the domain decomposition and execution plan (parallel
batches), add a sprint sizing step:

**Insert after the Execution Plan in Phase 2b:**

```markdown
### Sprint Plan

After producing the execution plan, the Architect sizes the work into sprints:

1. Count total tasks in the DAG.
2. Apply the sizing heuristic to determine sprint count.
3. Assign tasks to sprints respecting:
   - Dependency closure (all dependencies in same or earlier sprint)
   - Priority ordering (higher-priority tasks in earlier sprints)
   - Size bound (3-8 tasks per sprint, with flexibility for dependency constraints)
4. For each sprint, list the tasks and their parallel batches.

If the project has 8 or fewer tasks, assign all tasks to Sprint 1 (single sprint).
This preserves current behavior -- no checkpoints, no overhead.
```

**New section in the Master Spec Structure (after Agent Assignments):**

```markdown
## Sprint Plan

| Sprint | Tasks | Priority Tier | Dependencies |
|--------|-------|---------------|--------------|
| 1 | T1, T2, T3, T4 | P0 (core functionality) | None |
| 2 | T5, T6, T7 | P1 (essential features) | Sprint 1 complete |
| 3 | T8, T9, T10, T11 | P2 (quality-of-life) | Sprint 2 complete |

### Sprint 1: Core Foundation
- **Goal**: [One sentence describing what this sprint delivers]
- **Tasks**: T1 (storage schema), T2 (auth module), T3 (core API), T4 (API tests)
- **Parallel batches**: Batch 1 [T1], Batch 2 [T2, T3 parallel after T1], Batch 3 [T4]
- **Checkpoint criteria**: Core API responds to all CRUD operations with auth

### Sprint 2: Essential Features
- **Goal**: [One sentence]
- **Tasks**: T5 (search), T6 (notifications), T7 (frontend shell)
- **Parallel batches**: Batch 1 [T5, T6, T7 all parallel]
- **Checkpoint criteria**: Search and notification flows work end-to-end

### Sprint 3: Polish
- **Goal**: [One sentence]
- **Tasks**: T8 (admin panel), T9 (export), T10 (onboarding flow), T11 (perf tuning)
- **Parallel batches**: Batch 1 [T8, T9, T10 parallel], Batch 2 [T11]
- **Checkpoint criteria**: All acceptance criteria from spec satisfied
```

Each sprint has a **checkpoint criteria** field -- a concrete, testable statement of what
the sprint delivers. This feeds directly into the scoped QA pass.

### /build SKILL.md Changes

#### Phase 1 Addition: Sprint Awareness

**Modify Phase 1 (Task Decomposition) to read the sprint plan:**

The Architect reads the `## Sprint Plan` from `SPEC.md` in addition to the existing
inputs. If a sprint plan exists, the Architect:

1. Validates that the sprint plan is consistent with the task DAG (no dependency
   violations, no missing tasks).
2. Identifies the current sprint from `.factory/state.json`.
3. Decomposes only the current sprint's tasks, not the full DAG.
4. Informs agents of the sprint boundary: "You are working on Sprint N. Do not
   implement tasks assigned to later sprints."

If no sprint plan exists in `SPEC.md`, the Architect treats the entire project as a
single sprint (current behavior).

#### Phase 5 Addition: Sprint Completion

**Add after Phase 5 (Architect Coordination):**

```markdown
### Phase 5b: Sprint Completion

When all tasks in the current sprint are merged:

1. The Architect updates `PROGRESS.md` with a sprint summary section.
2. The Architect updates `.factory/state.json` to mark the sprint as complete.
3. If this is the last sprint, the build phase is complete (normal exit).
4. If more sprints remain, the Architect signals that a checkpoint is needed:

   ```text
   Sprint [N] of [total] complete.
   [X] tasks merged, all tests passing.

   Checkpoint required before Sprint [N+1]:
   - Run /qa for sprint validation
   - Run /security for sprint validation
   ```

5. The build skill exits. It will be re-invoked after checkpoints pass.
```

#### New Setting: sprint_checkpoints

```yaml
settings:
  - name: sprint_checkpoints
    type: enum
    values: ["full", "qa_only", "skip"]
    default: "full"
    description: >
      Controls checkpoint behavior between sprints. "full" runs both /qa
      and /security after each sprint (recommended). "qa_only" runs only
      /qa between sprints, deferring security to the final pass.
      "skip" disables sprint checkpoints entirely, making multi-sprint
      builds behave like the pre-sprint single-pass model. Does not
      affect the final full-project QA and security passes.
```

### /genesis SKILL.md Changes

#### Sprint Loop Orchestration

**Modify the Phase Invocation section to handle the sprint loop.**

When the build phase begins and `SPEC.md` contains a `## Sprint Plan` with more than one
sprint, the orchestrator enters a sprint loop instead of a single build invocation:

```text
Sprint loop:
  for each sprint N in sprint_plan:
    1. Invoke /build (builds sprint N only)
    2. Verify /build outputs (PROGRESS.md updated, sprint N tasks merged)
    3. If sprint_checkpoints != "skip":
       a. Invoke /qa in sprint-scoped mode
       b. If sprint_checkpoints == "full": Invoke /security in sprint-scoped mode
       c. If checkpoint fails:
          - Present findings to user
          - Offer: [fix and re-run / override / abort]
          - If override: record override in state, continue
          - If abort: exit build phase with partial completion
    4. Present sprint summary:
       "Sprint N of M complete. QA: PASS. Security: CLEAR.
        Ready for sprint N+1? [Y / review reports / abort]"
    5. If confirm_phase_transition is true, wait for user confirmation

  After all sprints:
    - Proceed to /retro (mandatory, unchanged)
    - Then /qa (full project pass)
    - Then /security (full project pass)
    - Then /deploy
```

**State tracking for sprints:**

The orchestrator writes sprint progress into the build phase state:

```json
{
  "phases": {
    "build": {
      "status": "in_progress",
      "started_at": "2026-04-03T13:00:00Z",
      "sprints": {
        "total": 3,
        "current": 2,
        "completed": [
          {
            "number": 1,
            "started_at": "2026-04-03T13:00:00Z",
            "completed_at": "2026-04-03T15:00:00Z",
            "tasks_merged": 4,
            "checkpoint": {
              "qa": { "status": "passed", "report": "QA-REPORT-sprint-1.md" },
              "security": { "status": "clear", "report": null }
            }
          }
        ],
        "overrides": []
      }
    }
  }
}
```

When `/genesis` resumes after interruption, it reads the sprint state and continues from
the last incomplete sprint.

**Backward navigation interaction:**

If the user navigates backward to `/spec` from mid-sprint-loop, all sprint progress is
reset (existing backward navigation semantics). The user revises the spec (and potentially
the sprint plan), then re-enters the build phase from sprint 1.

If the user navigates backward to `/build` (e.g., from `/retro`), the orchestrator
resumes from the last incomplete sprint, not from sprint 1.

### /qa SKILL.md Changes

#### Sprint-Scoped Mode

**Add a section after the existing Process section:**

```markdown
### Sprint-Scoped Mode

When invoked with sprint context (via `/genesis` sprint loop or with a `--sprint N`
argument), QA runs a scoped pass:

1. **Scope identification**: Read `SPEC.md` Sprint Plan to identify which tasks belong
   to sprint N. Determine the set of files changed by those tasks (from git diff against
   the pre-sprint commit recorded in state).

2. **Step 1 (Coverage)**: Measure coverage for sprint-changed files only. Report both
   sprint-scoped and full-project coverage.

3. **Step 2 (Test Quality)**: Audit only tests added or modified in the sprint.

4. **Step 3 (Acceptance Criteria)**: Verify only criteria addressed by sprint tasks.
   Reference the sprint's checkpoint criteria from the spec.

5. **Step 4 (Edge Case Hunting)**: Probe new code paths introduced in the sprint. Depth
   follows the `edge_case_hunting` setting.

6. **Step 5 (Regression)**: ALWAYS full project. This is the critical check -- the sprint
   must not break anything outside its scope.

7. **Step 6 (Output)**: Write `QA-REPORT-sprint-{N}.md` using the standard template with
   an additional `## Sprint Scope` section listing which tasks and files were in scope.

The sprint-scoped report uses the same template as the full report but adds:

```markdown
## Sprint Scope
- **Sprint**: N of M
- **Tasks**: [list of task IDs]
- **Files changed**: [count] files across [count] domains
- **Pre-sprint commit**: [git SHA]
- **Post-sprint commit**: [git SHA]
```

Sprint-scoped mode is faster because coverage analysis, test audit, and edge case hunting
are scoped. Regression remains full-project to catch cross-sprint breakage.
```

### /security SKILL.md Changes

#### Sprint-Scoped Mode

**Add a section after the existing Process section:**

```markdown
### Sprint-Scoped Mode

When invoked with sprint context, security runs a scoped audit:

1. **Scope identification**: Same as QA -- identify files changed in sprint N.

2. **Steps 1-4 (Dependency audit, static analysis, threat model, auth review)**: Scoped
   to changed files and their dependency trees. The dependency audit is always
   full-project (new dependencies affect the whole project).

3. **Step 5 (Secrets management)**: Scoped to changed files. Check for newly introduced
   secrets, hardcoded credentials, or weakened access patterns.

4. **Step 6 (Output)**: Write `SECURITY-sprint-{N}.md` if any findings exist. If the
   sprint introduces no security-relevant changes and the dependency audit is clean,
   record "Sprint N: CLEAR -- no security-relevant changes" in the final consolidated
   report instead of producing a separate file.

Sprint-scoped security reports use the same template as the full report with an
additional `## Sprint Scope` section (same format as QA).
```

---

## State Schema

### Sprint State in .factory/state.json

Sprint state is nested under the `build` phase. This keeps it co-located with build
progress and avoids polluting the top-level state structure.

```json
{
  "phases": {
    "build": {
      "status": "in_progress",
      "started_at": "...",
      "sprints": {
        "total": 3,
        "current": 2,
        "completed": [
          {
            "number": 1,
            "started_at": "...",
            "completed_at": "...",
            "tasks_merged": 4,
            "pre_sprint_commit": "abc1234",
            "post_sprint_commit": "def5678",
            "checkpoint": {
              "qa": { "status": "passed", "report": "QA-REPORT-sprint-1.md" },
              "security": { "status": "clear", "report": null }
            }
          }
        ],
        "overrides": [
          {
            "sprint": 2,
            "gate": "qa",
            "reason": "User override: minor test quality warning, not blocking",
            "timestamp": "..."
          }
        ]
      }
    }
  }
}
```

When no sprint plan exists (single sprint), the `sprints` field is absent from state.
This preserves backward compatibility -- existing state files without `sprints` are valid.

---

## Acceptance Criteria

### Spec Skill

1. **Sprint plan produced**: When the Architect decomposes a project with 9+ tasks, the
   master spec includes a `## Sprint Plan` section with multiple sprints.
2. **Single-sprint opt-out**: Projects with 8 or fewer tasks get a single sprint (no
   `## Sprint Plan` section, or a single-sprint plan). Behavior is identical to
   pre-sprint pipeline.
3. **Dependency closure**: No task in sprint N depends on a task in sprint N+1 or later.
4. **Priority ordering**: Sprint 1 contains the highest-priority items from the spec.
5. **Checkpoint criteria**: Each sprint has a concrete, testable checkpoint criteria
   statement.

### Build Skill

6. **Sprint-scoped execution**: The Architect builds only tasks in the current sprint.
   Tasks from later sprints are not decomposed or assigned.
7. **Sprint completion signal**: The Architect explicitly signals sprint completion and
   the need for checkpoints before the next sprint.
8. **Resumption**: When `/build` is re-invoked after a checkpoint, it picks up at the
   next sprint without re-executing completed sprints.
9. **Single-sprint compatibility**: When no sprint plan exists, `/build` behaves
   identically to the pre-sprint version.

### Genesis Orchestrator

10. **Sprint loop**: The orchestrator runs QA and security between sprints according to
    the `sprint_checkpoints` setting.
11. **Checkpoint gating**: A failing checkpoint blocks the next sprint until resolved or
    overridden.
12. **Override recording**: User overrides are recorded in state with rationale.
13. **Resumption from sprint**: After interruption, the orchestrator resumes from the
    last incomplete sprint.
14. **Backward navigation**: Going back to `/spec` resets all sprint progress. Going
    back to `/build` resumes from the last incomplete sprint.

### QA Skill

15. **Sprint-scoped reports**: QA produces `QA-REPORT-sprint-{N}.md` with scoped
    coverage, test quality, and acceptance criteria checks.
16. **Full regression**: Sprint-scoped QA always runs full-project regression (Step 5).
17. **Final consolidation**: After all sprints, the final `QA-REPORT.md` consolidates
    all sprint findings.

### Security Skill

18. **Sprint-scoped audit**: Security runs scoped analysis on sprint-changed files.
19. **Full dependency audit**: Dependency audit is always full-project regardless of
    sprint scope.
20. **Clear sprints**: Sprints with no security-relevant changes do not produce a
    separate report file.

### Cross-Cutting

21. **Bugfix integration**: `/bugfix` can run between sprints during the checkpoint
    window. Sprint checkpoints are re-run after bugfixes.
22. **Retro timing**: `/retro` runs once after all sprints complete, not per-sprint.

---

## Decision Log

| # | Decision | Rationale | Reversible |
|---|----------|-----------|------------|
| 1 | Sprint sizing in Phase 2b, not a new step | Phase 2b already has the task DAG, dependencies, and priority data. A separate step would duplicate inputs. | Yes |
| 2 | Sprints defined by dependency closure + priority + size bound | Domain-based sprints would prevent cross-domain integration testing. Priority-based sprints align with the spec's ordered in-scope list. | Yes |
| 3 | Sprint plan in SPEC.md, progress in state.json | Plan is a specification artifact; progress is runtime state. Keeps the separation clean. | Yes |
| 4 | /genesis orchestrates sprint loop, not /build | Keeps /build focused on construction. Gate skills remain independent. Standalone /build still works (user runs checkpoints manually). | Yes |
| 5 | Sprint checkpoints are scoped + full regression | Scoped analysis is faster. Full regression catches cross-sprint breakage. Both are needed. | Yes |
| 6 | /retro runs once after all sprints | Process patterns emerge across the full build. Per-sprint retros would be shallow and repetitive. | Yes |
| 7 | Bugfixes happen between sprints | The checkpoint window is the natural place for fixes. /bugfix's own pipeline handles its gates independently. | Yes |
| 8 | Single sprint = no sprint plan section | Backward compatible. Projects below the threshold get zero overhead. | Yes |
| 9 | 3-8 task size bound per sprint | Fewer than 3: checkpoint overhead dominates. More than 8: blast radius too large. Flexible for dependency constraints. | Yes |
| 10 | Checkpoint override with recorded rationale | Pragmatic escape hatch. Users should not be permanently blocked by a minor QA warning. The audit trail ensures accountability. | Yes |

---

## Open Questions

None. The design resolves all seven questions posed in the task.
