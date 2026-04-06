# Process Rules Template

The `/genesis` orchestrator owns the process-rules sections of the target
project's `CLAUDE.md`. These sections define how agents work -- worktree
isolation, PR workflow, progress tracking, retro requirements, and
self-updating context. They are not project-specific and do not depend on
the spec.

The `/spec` skill owns the project-specific sections (summary, architecture,
technical standards, quality standards, key features). `/genesis` writes the
process scaffold; `/spec` fills in the project details.

## When to Generate

- **Bootstrap mode (normal pipeline)**: After `/setup` completes (or before
  `/spec` if setup is skipped), generate or update `CLAUDE.md` with the
  process-rules sections. This ensures process rules are in place before
  `/spec` appends project-specific content.
- **Claim mode**: During Step 5 of claim, write the process-rules sections
  into the existing or new `CLAUDE.md`. Respect the `update_project_claude_md`
  setting (prompt/auto/skip).

## Section Markers

Factory-owned content is delimited by HTML comment markers so that
`/spec` and other tools can identify and preserve it:

```markdown
<!-- factory:process-rules:start -->
## Mandatory Process Rules
...
## Agent Communication
...
<!-- factory:process-rules:end -->
```

## Bootstrap Mode Behavior

When generating in bootstrap mode:

1. If `CLAUDE.md` does not exist, create it with a `# [Project Name]`
   heading (derived from `.factory/state.json` `project_name`) followed
   by the Factory-owned sections inside markers.
2. If `CLAUDE.md` exists and contains `<!-- factory:process-rules:start -->`,
   replace everything between the start and end markers with the current
   template.
3. If `CLAUDE.md` exists but has no Factory markers, append the
   Factory-owned sections (inside markers) at the end of the file.

## Claim Mode Behavior

Follow the same logic as bootstrap mode, but gate on the
`update_project_claude_md` setting:

- **`prompt`** (default): Present the proposed process-rules content and
  ask the user to confirm before writing.
- **`auto`**: Write without confirmation.
- **`skip`**: Do not write process-rules sections. Leave `CLAUDE.md`
  unchanged (or do not create it).

## Template

This is the template written inside the Factory markers. Replace `[project]`
with the actual project name from `.factory/state.json`.

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
