# Global Reference — Shared Skill Conventions

This file contains conventions shared across multiple Factory skills. Each
skill's `SKILL.md` references the sections that apply and provides parameter
values for any placeholders.

Sections marked **[MANDATORY]** apply to every skill unconditionally. Skills
do not need to opt into them — they are enforced by default. All other
sections are opt-in: a skill follows them only when its `SKILL.md`
explicitly references them.

---

## Settings Protocol [MANDATORY]

Before starting, read `.factory/settings.json` and resolve this skill's
settings against the declared schema in the `## Settings` section of this
skill file. Use stored values where present, defaults where not, and prompt
for any setting with no default and no stored value.

---

## First-Run Onboarding [MANDATORY]

After resolving settings but before any other check, read
`global.onboarding_shown` from `.factory/settings.json`. If it is `false`
or absent, display the following prompt and then set
`global.onboarding_shown` to `true` in `.factory/settings.json`:

```text
Welcome to Factory -- a pipeline that takes software from idea to production.

  /genesis .... Full guided pipeline (ideation -> spec -> build -> deploy)
  /ideation ... Brainstorm features    /spec ...... Design and specify
  /build ...... Construct with agents  /bugfix .... Fix bugs fast
  /qa ......... Quality control        /security .. Security audit
  /deploy ..... Ship to production     /genesis settings .. Configure

Run any skill with "help" for details. Start with /genesis to build something new.
```

If `global.onboarding_shown` is already `true`, skip silently.

---

## State Tracking [MANDATORY]

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

## CLAUDE.md Drift Sync [MANDATORY]

After resolving settings but before executing main logic, check whether
the project-level `CLAUDE.md` has drifted from the canonical content that
Factory owns. Factory-owned content is any block delimited by
`<!-- factory:*:start -->` / `<!-- factory:*:end -->` marker pairs (e.g.,
`factory:process-rules`, or any future marker namespace).

### Detection

1. Read `CLAUDE.md` in the project root. If it does not exist or contains
   no Factory marker pairs, skip this check.
2. For each marker pair found, extract the content between the start and
   end markers.
3. Compare each extracted block against the corresponding canonical
   template from the `/genesis` skill file. Ignore leading/trailing
   whitespace when comparing. If all blocks match, no action is needed.

### Update

If any block has drifted, gate on the `genesis.update_project_claude_md`
setting:

- **`prompt`** (default): Show a short diff summary (sections
  added/removed/changed) and ask the user to confirm before updating.
- **`auto`**: Replace the stale blocks with the current canonical
  content silently.
- **`skip`**: Do nothing. Leave the stale content in place.

When updating, replace everything between each drifted start and end
marker (inclusive of the markers themselves) with the current canonical
content wrapped in fresh markers. Preserve all content outside Factory
markers.

### Constraints

- This check runs at most once per skill invocation. Do not re-check
  after updating.
- Do not create `CLAUDE.md` if it does not exist -- that is `/genesis`'s
  responsibility.
- Do not modify content outside Factory markers.

---

## Secrets Handling [MANDATORY]

Verify secrets exist but never echo or log their values. Use name-only
listing commands (e.g., `fly secrets list`), not value-revealing commands
(e.g., `fly secrets show`). Never include secret values in commit messages,
PR descriptions, logs, or output files.
