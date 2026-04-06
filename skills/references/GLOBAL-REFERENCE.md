<!-- markdownlint-disable MD046 -->
# Global Reference — Shared Skill Conventions

**STOP. Before executing the skill's main logic, run every [MANDATORY]
section below in order.** This is not optional. Execute each one as a
concrete step -- read the condition, perform the action, then move to
the next.

1. Settings Protocol
2. First-Run Onboarding
3. CLAUDE.md Drift Sync
4. (Execute the skill's main logic)
5. Spec Maintenance
6. Output File Handling

Sections not marked [MANDATORY] are opt-in -- follow them only when the
skill's `SKILL.md` explicitly references them.

---

## Settings Protocol [MANDATORY]

Before starting, read `.factory/settings.json` and resolve this skill's
settings against the declared schema in the `## Settings` section of this
skill file. Use stored values where present, defaults where not, and prompt
for any setting with no default and no stored value.

After resolving each setting, validate it against the skill's declared
schema. If a stored value does not match the declared type (boolean,
number, string, enum), enum values, or min/max constraints, ignore the
invalid value, use the schema default, and warn the user:

    WARNING: Setting "{key}" has invalid value "{value}".
    Expected: {type constraint}. Using default: {default}.

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
- This check is skipped by sub-agents spawned during `/build`. Only the
  top-level skill invocation runs drift sync.
- Do not create `CLAUDE.md` if it does not exist -- that is `/genesis`'s
  responsibility.
- Do not modify content outside Factory markers.

---

## Secrets Handling [MANDATORY]

Verify secrets exist but never echo or log their values. Use name-only
listing commands (e.g., `fly secrets list`), not value-revealing commands
(e.g., `fly secrets show`). Never include secret values in commit messages,
PR descriptions, logs, or output files.

---

## Spec Maintenance [MANDATORY]

After completing work that changes the system's behavior, update the
relevant spec files in `specs/` to reflect the current state. Specs are
living documents -- they describe what IS, not what WAS planned.

- **Remove** sections that describe features or behavior that no longer
  exist.
- **Update** sections where the implementation differs from what the spec
  originally described.
- **Add** sections for new behavior that was introduced but not yet
  documented in the spec.

If the skill's work did not change any system behavior (e.g., a pure
documentation or process change), skip this step.

This check runs after the skill's main logic completes, before output
file handling.

---

## Output File Handling [MANDATORY]

After writing output files, check `global.open_report` from
`.factory/settings.json`. If true, convert each output file to HTML and
open it in the browser:

1. Convert markdown to HTML (use `uv run --with markdown` or equivalent).
2. Open the HTML file: `open /tmp/<filename>.html`

This applies to all skill output files: reports, decision documents,
receipts, triage documents, and ideation output.
