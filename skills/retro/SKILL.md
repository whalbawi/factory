---
name: retro
description: >-
  Use when the user wants a "team sync", "standup", "retrospective", "retro",
  "how's the team", "status check", or "review progress". Team retrospective
  that gathers agent status, surfaces coordination issues, checks cross-agent
  alignment, and produces actionable recommendations. Mandatory after /build
  in the Factory pipeline.
---

# /retro — Team Retrospective and Process Synthesis

You are running the `/retro` skill. Your job is to gather status from all agents
and progress artifacts, surface coordination issues, check cross-agent alignment,
and produce an actionable retrospective report.

**Key principles:**

- `/retro` examines PROCESS, not code quality. Code quality is `/qa`'s job.
- Never fabricate status. If data is missing, flag it as a gap.
- Every retro must surface something. Zero findings means shallow analysis.
- All recommendations must be concrete and actionable.
- `/retro` is CONVERSATIONAL. Present findings, discuss with the user, refine
  recommendations based on their input before finalizing.

## Pipeline Position

`/retro` is **mandatory** after `/build` in the v1 pipeline:

```text
/ideation -> /spec -> /prototype -> /setup -> /build -> /retro -> /qa -> /security -> /deploy
```

It serves as a checkpoint between construction and quality gates — a deliberate
pause to assess process health before evaluating product quality.

`/retro` can also be invoked **standalone at any time** during development.
Standalone invocations produce a `RETRO-{date}.md` report but do not advance or
block the pipeline. This makes `/retro` useful for mid-build check-ins, ad hoc
team syncs, or post-deploy reviews.

## Required and Optional Inputs

| Field               | Value                                                    |
|---------------------|----------------------------------------------------------|
| **Required inputs** | At least one completed phase (`status: completed` in `.factory/state.json`) |
| **Optional inputs** | `PROGRESS.md`, `PROGRESS-{PREFIX}.md` files, all phase output files (`SPEC.md`, `QA-REPORT.md`, `SECURITY.md`, etc.) |
| **Outputs**         | `RETRO-{YYYY-MM-DD}.md`                                 |
| **Failure mode**    | Retro summary with gaps noted — missing files are flagged but do not block |

## Process

Follow these five steps in order. Do not skip steps.

### Skill Parameters

For the mandatory sections in [GLOBAL-REFERENCE.md](GLOBAL-REFERENCE.md):

- `{PHASE_NAME}` = `retro`
- `{OUTPUT_FILES}` = `["RETRO-YYYY-MM-DD.md"]`

### Step 1: Gather Status

Read all `PROGRESS-{PREFIX}.md` files and the rolled-up `PROGRESS.md`. For each
agent and task, identify:

- **Completed tasks** since the last retro (or since project start if no prior
  retro exists).
- **In-progress tasks** — current status, blockers, estimated completion.
- **Blocked tasks** — the nature of each blocker: dependency, unclear spec,
  external, or technical.
- **Overdue tasks** — tasks that have taken significantly longer than their
  difficulty rating suggests.

If `PROGRESS.md` or agent-specific progress files are missing, note the gap and
work with whatever status information is available (git log, output files,
`.factory/state.json`). Do NOT infer task completion from git history alone —
that produces unreliable data. Flag the gap and recommend that agents update
their progress files.

### Step 2: Surface Issues

Analyze the gathered status for systemic problems. Look specifically for:

- **Coordination failures** — Agents stepping on each other's work, conflicting
  changes to shared files, merge conflicts requiring manual resolution, or agents
  blocked waiting on each other in cycles.
- **Scope creep** — Tasks or features being implemented that are not in `SPEC.md`
  or domain specs. Work going beyond acceptance criteria without explicit
  approval.
- **Quality concerns** — Patterns of test failures, repeated CI breakages,
  declining code coverage, recurring lint violations, or agents committing
  without tests. Frame these as process issues (e.g., "agents are not running
  tests before committing"), not code-level findings.
- **Velocity trends** — Is the team accelerating, decelerating, or steady? Are
  estimates calibrated? Are later tasks taking longer due to accumulated
  complexity?

### Step 3: Cross-Agent Alignment

Check alignment across all agents involved in the build:

- **Interface contracts honored** — Are agents producing outputs that match the
  contracts defined in domain specs? Are API shapes, data formats, and type
  definitions consistent across boundaries?
- **Naming conventions consistent** — Variable names, file names, endpoint paths,
  error codes — are agents following the conventions in `CLAUDE.md`?
- **Duplicate efforts** — Are two agents building the same utility, validation
  logic, or abstraction independently? Flag overlaps for consolidation.
- **CLAUDE.md updates** — Has `CLAUDE.md` been updated with learnings from the
  build? Are new commands, patterns, or conventions documented?

### Step 4: Recommend Actions

Based on findings from Steps 2 and 3, produce prioritized recommendations.
Consider these categories:

- **Re-prioritize tasks** — If velocity data shows the current ordering is
  suboptimal.
- **Reassign work** — If an agent is blocked or overloaded while another has
  capacity.
- **Update spec** — If scope creep indicates requirements have evolved and the
  spec should be revised to match reality.
- **Schedule focused fixes** — For systemic issues (e.g., "all agents need to
  rebase on main before continuing" or "shared types need to be extracted to a
  common module").
- **Process adjustments** — Communication patterns, commit frequency, PR size, or
  coordination protocols that should change.

Each recommendation MUST be concrete and actionable. Not "improve communication"
but "Backend and Frontend agents should align on the `/api/users` response shape
before either proceeds with dependent tasks."

### Step 5: Present and Discuss

Present your findings to the user BEFORE writing the final report. This is not
optional. The retro is conversational:

1. Share a summary of your findings organized by the sections above.
2. Invite the user to react — they may disagree with assessments, add context
   the retro missed, or re-prioritize recommendations.
3. Incorporate the user's feedback.
4. Only after discussion, write the final `RETRO-{YYYY-MM-DD}.md` file.

## Output Template

Write `RETRO-{YYYY-MM-DD}.md` using this template:

```markdown
# Team Retro — [Date]

## Summary

- **Phases completed**: [list]
- **Active agents**: [list with prefixes]
- **Overall health**: HEALTHY / CONCERNS / AT RISK

## Progress Since Last Retro

| Agent | Tasks Completed | Tasks In Progress | Tasks Blocked |
|-------|----------------|-------------------|---------------|
| ARC   |                |                   |               |
| BE    |                |                   |               |
| FE    |                |                   |               |
| OPS   |                |                   |               |

## Issues Surfaced

### Blockers

[Active blockers preventing progress, with affected agents and tasks]

### Coordination Issues

[Conflicts, duplicate work, communication gaps]

### Quality Concerns

[Test failures, coverage gaps, CI instability, pattern violations]

### Scope Drift

[Work happening outside the spec, with assessment of whether the spec
should be updated or the work should be reverted]

## Velocity

- **Tasks completed this period**: N
- **Tasks remaining**: N
- **Trend**: Accelerating / Steady / Decelerating
- **Calibration**: [Are estimates matching actuals?]

## Cross-Agent Alignment

| Check | Status | Notes |
|-------|--------|-------|
| Interface contracts | OK / DRIFT | |
| Naming conventions  | OK / DRIFT | |
| Duplicate efforts   | NONE / FOUND | |
| CLAUDE.md updated   | YES / NO | |

## Recommendations

[Prioritized, concrete, actionable items — numbered list]

1. [Highest priority action]
2. [Next priority action]
3. ...

## Next Retro

- **When**: [Suggested timing — after next milestone, after N tasks, or on-demand]
- **Focus**: [What to pay attention to next time based on current findings]
```

## Settings

```yaml
settings:
  - name: retro_schedule
    type: enum
    values: ["after_build", "every_n_merges", "on_demand"]
    default: "after_build"
    description: >
      When retros are triggered in the pipeline. "after_build" runs
      once after /build completes (mandatory). "every_n_merges" also
      triggers mid-build retros at the interval set by
      retro_merge_interval. "on_demand" makes retro purely
      user-initiated.
  - name: retro_merge_interval
    type: number
    default: 10
    min: 0
    description: >
      Number of PRs merged to main between mid-build retros. Only
      applies when retro_schedule is "every_n_merges". Set to 0 to
      disable.
```

## Anti-Patterns — Do Not Do These

- **Do not turn retro into code review.** `/retro` examines process,
  coordination, and progress. If you find quality concerns, frame them as process
  issues (e.g., "agents are not running tests before committing"), not as
  code-level findings. Code quality is `/qa`'s job.

- **Do not fabricate status.** If progress files are missing or incomplete, say
  so. Do not infer task completion from git history alone. Flag the gap and
  recommend that agents update their progress files.

- **Do not produce a retro with zero findings.** Every project has friction. If
  you surface nothing, your analysis was not thorough enough. At minimum, note
  what is going well and what could be better, even if there are no critical
  issues.

- **Do not skip the discussion.** Presenting a report and immediately moving on
  defeats the purpose. Always invite the user to react, add context, and adjust
  recommendations before finalizing the `RETRO-{date}.md` file.

- **Do not block on missing inputs.** `/retro` should work with whatever is
  available. A retro with partial data and noted gaps is more valuable than no
  retro at all.
