# Global Reference — Shared Skill Conventions

This file contains conventions shared across multiple Factory skills. Each
skill's `SKILL.md` defines which sections apply and provides parameter values
for any placeholders. Do not read this file standalone — read it from a skill
that references it.

---

## Settings Protocol

Before starting, read `.factory/settings.json` and resolve this skill's
settings against the declared schema in the `## Settings` section of this
skill file. Use stored values where present, defaults where not, and prompt
for any setting with no default and no stored value.

---

## State Tracking

Update `.factory/state.json` on invocation and completion. If no state file
or `.factory/` directory exists, create them. Read the existing file, merge
the `{PHASE_NAME}` phase state, and write back. Do not overwrite other
phases' state.

**On start** -- set the `{PHASE_NAME}` phase to `in_progress`:

```json
{
  "phases": {
    "{PHASE_NAME}": {
      "status": "in_progress",
      "started_at": "<ISO-8601 timestamp>"
    }
  }
}
```

**On completion** -- set the `{PHASE_NAME}` phase to `completed`:

```json
{
  "phases": {
    "{PHASE_NAME}": {
      "status": "completed",
      "started_at": "<original start time>",
      "completed_at": "<ISO-8601 timestamp>",
      "outputs": {OUTPUT_FILES}
    }
  }
}
```

**On failure** -- set the `{PHASE_NAME}` phase to `failed`:

```json
{
  "phases": {
    "{PHASE_NAME}": {
      "status": "failed",
      "started_at": "<original start time>",
      "failed_at": "<ISO-8601 timestamp>",
      "failure_reason": "<what went wrong>"
    }
  }
}
```

---

## Post-Merge Cleanup

After a PR is merged to main, the merging agent MUST clean up immediately:

1. Delete the remote branch: `git push origin --delete <branch-name>`
2. Remove the local worktree: `git worktree remove <worktree-path>`
3. Delete the local branch: `git branch -D <branch-name>`

This prevents stale branches and worktrees from accumulating.

---

## Gate Verification

Do NOT trust `.factory/state.json` for gate status -- always read the actual
report file. Verify that the `Tested commit` field in the report matches the
current `git rev-parse HEAD`. If it does not match, the report is stale --
halt and inform the user that the gate skill must be re-run.

---

## Secrets Handling

Verify secrets exist but never echo or log their values. Use name-only
listing commands (e.g., `fly secrets list`), not value-revealing commands
(e.g., `fly secrets show`). Never include secret values in commit messages,
PR descriptions, logs, or output files.
