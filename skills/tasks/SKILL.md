---
name: tasks
description: Use when the user wants to track work items, create a backlog, or manage
  tasks. Responds to "add a task", "show tasks", "what's in the backlog", "update task",
  "close task", "task board", or when any skill needs to defer work for later. Provides
  CRUD operations on a file-based task store in .factory/tasks/. Not for sprint planning
  (use /spec) or bug tracking (use /bugfix).
---

# /tasks -- Backlog Tracker

Persistent work-item tracking across sessions. Tasks are stored as individual
markdown files with YAML frontmatter in `.factory/tasks/`. Both humans and
agents can create, query, update, and close work items.

`/tasks` is a utility skill, not a pipeline phase. It does not appear in the
`/genesis` sequence and does not modify the main pipeline's phase state.

**Subcommands**: `add`, `list` (default), `show`, `update`, `close`, `board`.

---

## Inputs and Outputs

| Field               | Value                                                     |
|---------------------|-----------------------------------------------------------|
| **Required inputs** | Subcommand (defaults to `list` if omitted)                |
| **Optional inputs** | Task title, task ID, flags (--type, --priority, --status, |
|                     | --sprint, --title)                                        |
| **Outputs**         | Task files in `.factory/tasks/`, stdout summaries,        |
|                     | `.factory/tasks/board.html` (board subcommand only)       |
| **Failure output**  | Error message to stdout                                   |

---

## Process

### Skill Parameters

Read and execute ALL [MANDATORY] sections in [GLOBAL-REFERENCE.md](GLOBAL-REFERENCE.md):

- `{PHASE_NAME}` = `tasks`
- `{OUTPUT_FILES}` = `[]`

### Step 1 -- Parse Subcommand

Parse the user's input to determine the subcommand and arguments.

1. If no argument is provided, default to `list`.
2. The first token determines the subcommand: `add`, `list`, `show`, `update`,
   `close`, or `board`.
3. Remaining tokens are arguments and flags for that subcommand.

If the first token does not match a known subcommand, treat the entire input
as a title for the `add` subcommand (e.g., `/tasks Fix the flaky test` is
equivalent to `/tasks add "Fix the flaky test"`).

---

### Step 2a -- Subcommand: `add`

Create a new task.

1. Parse the title from the argument. If no title is provided, ask the user.
2. Parse optional flags:
   - `--type <bug|feature|debt|improvement>` -- defaults to `feature`.
   - `--priority <P0|P1|P2>` -- defaults to `P1`.
3. Read `.factory/tasks/` to find the highest existing ID. Next ID = max + 1.
   If no tasks exist, start at 1.
4. Create `.factory/tasks/` directory if it does not exist.
5. Write `.factory/tasks/TASK-{NNN}.md` (NNN = zero-padded to 3 digits):

```yaml
---
id: {next_id}
title: "{title}"
type: {type}
status: open
priority: {priority}
created_at: "{ISO 8601 timestamp}"
created_by: user
sprint: null
---
```

6. If the user provided context beyond the title, include it as the markdown
   body below the frontmatter.
7. If a file with that ID already exists (concurrent creation), increment the
   ID and retry.
8. Confirm:

```text
Created TASK-{NNN}: {title}
  Type: {type} | Priority: {priority} | Status: open
```

---

### Step 2b -- Subcommand: `list`

Display all active tasks grouped by priority. This is the default subcommand.

1. Read all `.factory/tasks/TASK-*.md` files.
2. Parse YAML frontmatter from each file.
3. Filter to `status` in (`open`, `in_progress`). Exclude `done` and `closed`.
4. Group by priority: P0 first, then P1, then P2.
5. Within each group, sort by ID ascending.
6. Render:

```text
## P0 -- Critical
| ID  | Title                              | Type    | Status      | Sprint |
|-----|------------------------------------|---------|-------------|--------|
| 005 | Fix auth token expiry handling      | bug     | in_progress | 3      |

## P1 -- Important
| ID  | Title                              | Type    | Status      | Sprint |
|-----|------------------------------------|---------|-------------|--------|
| 001 | Pin actions token to commit SHA     | debt    | open        | --     |

## P2 -- Nice to Have
(none)

3 open, 1 in progress | 4 total active
```

7. If no active tasks exist:

```text
No open tasks. Use /tasks add "<title>" to create one.
```

---

### Step 2c -- Subcommand: `show <id>`

Display a single task's full details.

1. Parse the ID. Accept bare numbers (`3`) or padded (`003`).
2. Read `.factory/tasks/TASK-{NNN}.md`.
3. If the file does not exist: `Task {id} not found.`
4. Display:

```text
TASK-{NNN}: {title}
  Type: {type} | Priority: {priority} | Status: {status}
  Created: {date} by {created_by} | Sprint: {sprint or "--"}

  {markdown body}
```

---

### Step 2d -- Subcommand: `update <id>`

Update one or more fields on an existing task.

1. Parse the ID from the first argument.
2. Parse flags: `--status <status>`, `--priority <priority>`, `--type <type>`,
   `--sprint <number>`, `--title "<title>"`.
3. Read the task file. If it does not exist: `Task {id} not found.`
4. Update only the specified frontmatter fields. Preserve all others unchanged.
5. Write the updated file.
6. Confirm with a diff of changed fields:

```text
Updated TASK-{NNN}:
  status: open -> in_progress
  sprint: -- -> 2
```

---

### Step 2e -- Subcommand: `close <id>`

Close a task. Shorthand for `update <id> --status closed`.

1. Parse the ID.
2. Read the task file. If it does not exist: `Task {id} not found.`
3. Set `status: closed` in the frontmatter.
4. Write the updated file.
5. Confirm:

```text
Closed TASK-{NNN}: {title}
```

---

### Step 2f -- Subcommand: `board`

Render an HTML kanban board and open it in the browser.

1. Read all `.factory/tasks/TASK-*.md` files.
2. Parse YAML frontmatter from each file.
3. Group into four columns by status: Open, In Progress, Done, Closed.
4. Within each column, sort by priority (P0 first) then by ID ascending.
5. Generate `.factory/tasks/board.html` with:
   - Four columns: Open, In Progress, Done, Closed.
   - Each card: ID, title, type badge, priority badge.
   - Priority colors: P0 = red border, P1 = amber border, P2 = grey border.
   - Type badges: bug = red, feature = blue, debt = yellow, improvement = green.
   - Inline CSS only (no external dependencies).
   - Responsive layout.
   - Page title: "Factory Task Board".
6. Open in browser: `open .factory/tasks/board.html`

The board is a snapshot. Re-run `/tasks board` to refresh.

If no tasks exist:

```text
No tasks to display. Use /tasks add "<title>" to create one.
```

---

## Task File Schema

Each task lives at `.factory/tasks/TASK-{NNN}.md` with this structure:

```yaml
---
id: 1
title: "Short description, max 120 characters"
type: feature          # bug | feature | debt | improvement
status: open           # open | in_progress | done | closed
priority: P1           # P0 | P1 | P2
created_at: "2026-04-05T14:30:00Z"
created_by: user       # "user" or skill name (qa, retro, security, etc.)
sprint: null           # sprint number or null
---

Optional markdown body with description, context, references, and notes.
```

**ID assignment**: max(existing IDs) + 1. If no tasks exist, start at 1.
Filename is zero-padded to 3 digits: `TASK-001.md`.

**Collision handling**: If the target file already exists (concurrent
creation), increment the ID and retry.

---

## Auto-Capture Convention

Other skills may create tasks when they defer work or produce recommendations
not acted on immediately. This is opt-in per skill.

**When to auto-capture:**

- `/qa` finds a minor, non-blocking issue.
- `/retro` produces an action item.
- `/security` identifies a low-severity finding that does not block deploy.
- `/build` defers a known optimization or cleanup.
- `/deploy` notes a configuration improvement.

**When NOT to auto-capture:**

- Gate-blocking findings (these halt the pipeline, not defer).
- Items already tracked in `.factory/tasks/`.
- Vague suggestions without actionable scope.

**Auto-captured task conventions:**

- `created_by`: the skill name (e.g., `qa`, `retro`, `security`).
- Body references the source report (e.g., "See QA-REPORT.md, finding #3").
- The capturing skill determines type and priority based on the finding.

Skills that auto-capture write `TASK-{NNN}.md` files directly using the same
ID assignment logic as the `add` subcommand. They do not invoke `/tasks` as a
skill -- they write the file themselves.

---

## Settings

```yaml
settings:
  - name: default_priority
    type: string
    default: P1
    description: >
      Default priority for new tasks when --priority is not specified.
      Must be one of: P0, P1, P2.
  - name: default_type
    type: string
    default: feature
    description: >
      Default type for new tasks when --type is not specified.
      Must be one of: bug, feature, debt, improvement.
```

---

## Anti-Patterns

- **Using /tasks for sprint planning.** `/tasks` is a backlog store, not a
  planner. Use `/spec` Phase 2b to plan sprints -- it reads the backlog
  automatically.
- **Creating vague tasks.** "Fix things" is not a task. Every task must have a
  concrete title and enough body context to act on without the creating
  conversation.
- **Duplicating bug tracking.** `/bugfix` has its own state in
  `.factory/state.json`. Do not create `/tasks` entries for bugs that are
  already tracked by `/bugfix`. Use `/tasks` for bugs discovered outside the
  bugfix pipeline.
- **Treating the board as live.** The board is a generated snapshot. Editing
  `board.html` does nothing -- the source of truth is the `TASK-*.md` files.
- **Auto-capturing gate blockers.** If a finding blocks the pipeline, it must
  be resolved before proceeding. Do not defer it to a task.
- **Skipping the body on auto-capture.** When a skill creates a task, the body
  must include enough context for a future agent to understand and act on it
  without reading the original conversation.
- **Manual ID assignment.** Always derive the ID from the existing files. Never
  hardcode or guess an ID.
