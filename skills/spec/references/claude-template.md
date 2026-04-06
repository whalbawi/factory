# CLAUDE.md Generation Templates

## Normal Flow (CLAUDE.md Already Exists)

When `CLAUDE.md` already exists on disk (the normal case when `/genesis` has
run before `/spec`), the Architect:

1. Reads the existing `CLAUDE.md`.
2. Looks for `<!-- spec:project:start -->` and `<!-- spec:project:end -->`
   markers.
3. If markers exist, replaces the content between them with the updated
   spec-owned sections.
4. If markers do not exist, appends the spec-owned sections (inside markers)
   after the Factory-owned sections (or at the end of the file if no Factory
   markers are found).
5. Does NOT modify anything inside
   `<!-- factory:process-rules:start/end -->` markers.

## Standalone Fallback (No CLAUDE.md)

When `CLAUDE.md` does not exist (standalone `/spec` invocation without a prior
`/genesis` run), the Architect generates the full file for backward
compatibility. This includes both Factory-owned and spec-owned sections so that
the project is fully functional without `/genesis`.

The full fallback template includes all sections from both the spec-owned
template below and the process-rules template from `/genesis`. In this case,
Factory markers are still written around the process-rules sections so that
`/genesis` can claim ownership later if it runs.

## Spec-Owned Sections Template

```markdown
<!-- spec:project:start -->
## Project Summary
[1-2 paragraph summary derived from SPEC.md Overview section.]

## Architecture

**Tech stack:** [Languages, frameworks, databases, infrastructure from the spec.]

**Components:**
- **[Component name]**: [What it does, how it communicates.]
[One bullet per major component/domain.]

## Technical Standards
- **Markdown**: Line-wrap at 100 characters. Only use ASCII characters.
[Add project-specific standards from the spec: code style, naming conventions,
 formatting rules, etc.]

## Quality Standards
Quality is non-negotiable. Every agent MUST uphold these standards at all times.

### Code Coverage
The project targets **100% code coverage**. Every new feature, bug fix, or
refactor MUST include tests that cover all code paths -- happy paths, error
paths, and edge cases. If a line of code exists, a test must exercise it.
Coverage regressions are treated as build failures.

[Insert project-specific coverage commands and thresholds here, grouped by
 component. Derive from the tech stack.]

### Test Quality
Tests MUST be meaningful. Do not write tests that exist solely to inflate
coverage numbers. Each test must assert observable behavior that matters. If
a test would still pass after deleting the code it covers, it is a bad test.

### CI Health
The DevOps agent MUST routinely inspect GitHub Actions health:
- **No false positives**: A flaky or spurious CI failure MUST be investigated
  and fixed immediately. If a test fails intermittently, the root cause must be
  found and resolved -- do not re-run and hope for green.
- **No false negatives**: CI must actually catch real problems. Periodically
  verify that disabling a feature or introducing a known bug causes the expected
  gate to fail.
- **Pipeline hygiene**: Unused workflows, stale caches, and unnecessary steps
  must be cleaned up. CI should be fast and reliable.

### CI Pipeline Inspection
Every 5 PRs merged to main, the DevOps agent MUST audit the GitHub Actions
pipeline:
- **False positives**: Introduce a known bug or disable a feature and verify
  the expected CI gate catches it.
- **False negatives**: Investigate any intermittent failures, disabled checks,
  or tests that pass trivially (would still pass if the code under test were
  deleted).
Results are documented in `PROGRESS-OPS.md`.

### Code Review Rigor
Every PR must be reviewed with the assumption that bugs exist in it. Reviewers
must check:
- Edge cases and error handling
- Test coverage of the changed code paths
- Consistency with existing patterns and contracts
- Security implications of the change

Do not approve a PR because it "looks fine." Verify it.

## Key Features
[Bulleted list of v1 features derived from the spec's In Scope section.]
<!-- spec:project:end -->
```

## Standalone Fallback: Process Rules Template

When generating the full file in standalone mode (no existing CLAUDE.md), append
the Factory process-rules sections after the spec-owned sections. Use the same
template that `/genesis` uses, wrapped in Factory markers:

```markdown
<!-- factory:process-rules:start -->
## Mandatory Process Rules
The following rules MUST be followed by each Claude process/agent, for each
change being made. There are no exceptions.

### Lifecycle of a Change

#### Codebase Exploration
Each process/agent MUST explore the relevant portions of the codebase as
indicated by the task at hand.

#### Worktree Isolation
Each Claude process/agent MUST work in a separate git worktree and associated
branch. Create the worktree as a sibling directory (`[project]-wt-<name>`) to
the project source root, and prefix the branch name with `bug/`, `feat/`, etc.

#### Change Implementation Loop
Always implement a change in small incremental commits. A commit MUST be
composed of a self-contained unit of logic that positively improves the overall
system. No commit MUST break any test in the repository. Before committing a
change to `git`, make sure all tests pertinent to the component you are working
on run successfully, and make sure that the code format and lint checks pass.
Rebase on top of `main` frequently to reduce the chances of merge conflicts.

**Squash before merge**: Each PR MUST be merged as a single commit. Before the
final push, squash all commits on the branch into one via interactive rebase
(`git rebase -i origin/main`, mark all but the first as `squash`). Write a
meaningful commit message that describes _what_ and _why_.

Once you are done working on your branch, make sure you run the full test suite.
If a test fails anywhere, think hard about why it failed and bias towards fixing
the root cause rather than artificially making the test pass.

[Insert project-specific test, lint, format, and type-check commands here,
 grouped by component. Derive from the tech stack and domain specs.]

#### Pull Request
Once a branch passes the required gates, the process/agent rebases the branch on
top of `main` and then creates a GitHub PR and monitors CI to make sure all gates
pass. In case of failure, the process/agent applies the "Change Implementation
Loop" process to unblock the CI job. Upon success, the process/agent notifies
the team lead that the PR is ready for merge.

It is the responsibility of the team lead to merge outstanding PRs. The team lead
MUST come up with an ordering that aims to minimize merge conflicts. The only
allowed merge strategy is "rebase+merge". Once a PR is merged, the merging agent
MUST clean up immediately:

1. Delete the remote branch: `git push origin --delete <branch-name>`
2. Remove the local worktree: `git worktree remove <worktree-path>`
3. Delete the local branch: `git branch -D <branch-name>`

### Mandatory Retro After Build
After the build phase completes and all PRs are merged, the team MUST run
`/retro` before proceeding to QA. This is not optional -- it captures process
learnings while they are fresh. The retro output (`RETRO-{date}.md`) is
reviewed by the team lead before QA begins.

### Self-Updating Context (CLAUDE.md Auto-Amendment)
CLAUDE.md MUST be amended whenever a learning or course correction occurs:
- **Autonomous**: When any process/agent discovers something important during
  development (e.g., a new convention, a gotcha, a pattern that works or fails),
  they MUST update the relevant section of CLAUDE.md.
- **User-directed**: When the user gives an instruction that changes how the
  project works, the receiving agent MUST update CLAUDE.md immediately.

CLAUDE.md is the project's living source of truth. Stale context leads to
repeated mistakes.

### Progress Tracking
Every code change MUST be tracked in the relevant `PROGRESS-<prefix>.md` file
using the established format (Task ID, Description, Difficulty, Acceptance
Criteria, Status, Notes). After updating the component ledger, the change MUST
be rolled up into `PROGRESS.md` by the team lead. This MUST NEVER be skipped --
untracked work is invisible work, and invisible work causes coordination failures.

| Agent                | Prefix | Scope                                    |
|----------------------|--------|------------------------------------------|
| Software Architect   | ARC    | Cross-cutting architecture, spec consistency |
[One row per assigned specialist agent, with prefix and scope derived from the
 agent assignment matrix.]

## Agent Communication
Agents should DM each other directly (via SendMessage) for technical questions,
API contract clarifications, and coordination -- don't wait for the team lead to
relay. Route status updates and task completions through the team lead as usual.
<!-- factory:process-rules:end -->
```

## Generation Rules

- **Derive, don't invent.** Every section must trace back to the master spec
  or domain specs. Do not add requirements not in the spec.
- **Fill in concrete commands.** The test/lint/format sections must have
  actual runnable commands, derived from the tech stack choices in the spec.
  Do not leave placeholders.
- **Agent table must match assignments.** The Progress Tracking table must
  list exactly the agents assigned in the master spec, with appropriate
  prefixes and scopes.
- **Project name in worktree pattern.** Replace `[project]` with the actual
  project name.
- **Spec-owned sections only (normal flow).** When CLAUDE.md already exists,
  only write the sections inside `<!-- spec:project:start/end -->` markers.
  Do not touch Factory-owned process rules -- they are `/genesis`'s
  responsibility.
- **Full file (standalone fallback).** When no CLAUDE.md exists, generate
  both spec-owned and Factory-owned sections for backward compatibility.
  Use appropriate markers for each so that `/genesis` can claim ownership
  later.
