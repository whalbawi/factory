# Settings Inventory

Consolidated inventory of Factory-usage behavioral settings. Every setting here controls
how Factory itself operates -- not the target project being built. Project-specific
concerns (coverage targets, test commands, code conventions) belong in the project's
`CLAUDE.md`.

---

## Global Settings

Settings that apply across multiple skills. Declared in `/genesis`'s configuration and
inherited by all skills that reference them.

### open_report

- **Type**: boolean
- **Default**: `false`
- **Description**: Open generated report files (QA-REPORT.md, SECURITY.md,
  RETRO-{date}.md, DEPLOY-RECEIPT.md) in the default editor or browser after creation.
- **Used by**: `/qa`, `/security`, `/retro`, `/deploy`

### auto_commit_outputs

- **Type**: boolean
- **Default**: `false`
- **Description**: Automatically git-commit skill output files (reports, receipts,
  decision docs) after a skill completes successfully. When false, output files are
  written but left uncommitted.
- **Used by**: `/ideation`, `/spec`, `/prototype`, `/qa`, `/security`, `/retro`, `/deploy`

### confirm_phase_transition

- **Type**: boolean
- **Default**: `true`
- **Description**: Require explicit user confirmation before advancing to the next
  pipeline phase. When false, the orchestrator auto-advances after verifying outputs.
- **Used by**: `/genesis`

### parallel_domain_agents

- **Type**: number
- **Default**: `3`
- **Description**: Maximum number of domain-scoped sub-agents to run concurrently during
  skills that support per-domain parallelism. Applies to any skill that fans out work
  across domain specs.
- **Used by**: `/spec`, `/build`, `/qa`, `/security`

### state_file_path

- **Type**: string
- **Default**: `".factory/state.json"`
- **Description**: Path to the pipeline state file relative to the project root. All
  skills read and write this file for state tracking. Changing this affects every skill.
- **Used by**: all skills

---

## Per-Skill Settings

### /genesis (orchestrator)

```yaml
settings:
  - name: auto_detect_artifacts
    type: boolean
    default: true
    description: >
      On first invocation without a state file, scan for existing artifacts
      (SPEC.md, package.json, source code) to infer completed phases and
      suggest a starting point. When false, always start from ideation.

  - name: preserve_stale_outputs
    type: boolean
    default: true
    description: >
      When navigating backward in the pipeline, preserve output files from
      reset phases on disk (marked stale). When false, delete output files
      from reset phases.

  - name: claim_write_claude_md
    type: enum
    values: ["prompt", "auto", "skip"]
    default: "prompt"
    description: >
      Controls CLAUDE.md behavior during /genesis claim. "prompt" asks the
      user before writing; "auto" writes without confirmation; "skip" never
      writes CLAUDE.md during claim.
```

### /ideation

```yaml
settings:
  - name: idea_count
    type: number
    default: 7
    description: >
      Target number of feature ideas to generate in Step 3 (idea generation).
      The skill generates between idea_count-2 and idea_count+1 ideas. Must
      be at least 3.

  - name: max_selected_ideas
    type: number
    default: 3
    description: >
      Maximum number of ideas the user can select for deep dive in Step 4.
      Caps scope to keep the ideation session focused.
```

### /spec

```yaml
settings:
  - name: discovery_track
    type: enum
    values: ["auto", "full", "focused", "fast"]
    default: "auto"
    description: >
      Controls discovery depth. "auto" lets the skill calibrate based on the
      user's first message. "full", "focused", and "fast" force a specific
      track regardless of input signal.

  - name: peer_review_enabled
    type: boolean
    default: true
    description: >
      Enable the peer review pass (Phase 2d) where specialist agents read
      and critique each other's specs. Disabling saves time but reduces
      cross-domain consistency.
```

### /prototype

```yaml
settings:
  - name: prototype_count
    type: number
    default: 3
    description: >
      Target number of alternative prototypes to generate. Must be at least 2
      unless the spec genuinely admits only one approach. Maximum 4.

  - name: auto_run_prototypes
    type: boolean
    default: true
    description: >
      Automatically execute each prototype to verify it runs before presenting
      to the user. When false, prototypes are built but not executed -- the
      user must run them manually.
```

### /setup

No Factory-usage settings. Deployment platform, environment provisioning,
and telemetry are project-level decisions that belong in SPEC.md and
CLAUDE.md.

### /build

```yaml
settings:
  - name: max_parallel_agents
    type: number
    default: 4
    description: >
      Maximum number of specialist agents (BE, FE, OPS, etc.) the Architect
      may run concurrently. Higher values speed up builds but increase
      resource usage. Minimum 1, maximum 8.

  - name: ci_inspection_interval
    type: number
    default: 5
    description: >
      Number of PRs merged to main between CI pipeline inspections. After
      this many merges, the OPS agent inspects for false positives and false
      negatives. Set to 0 to disable periodic inspections.

  - name: progress_tracking
    type: enum
    values: ["full", "rollup_only"]
    default: "full"
    description: >
      "full" requires both per-agent PROGRESS-{PREFIX}.md files and the
      rolled-up PROGRESS.md. "rollup_only" requires only the Architect's
      PROGRESS.md, reducing overhead for small projects.
```

### /retro

```yaml
settings:
  - name: retro_schedule
    type: enum
    values: ["after_build", "every_n_merges", "on_demand"]
    default: "after_build"
    description: >
      When retros are triggered in the pipeline. "after_build" runs once
      after /build completes (mandatory). "every_n_merges" also triggers
      mid-build retros at the interval set by retro_merge_interval.
      "on_demand" makes retro purely user-initiated (still mandatory
      after build in the pipeline).

  - name: retro_merge_interval
    type: number
    default: 10
    description: >
      Number of PRs merged to main between mid-build retros. Only applies
      when retro_schedule is "every_n_merges". Set to 0 to disable.
```

### /qa

```yaml
settings:
  - name: write_missing_tests
    type: boolean
    default: true
    description: >
      When QA finds acceptance criteria without corresponding tests (Step 3),
      automatically write the missing tests. When false, QA only reports
      the gaps without writing tests.

  - name: edge_case_hunting
    type: enum
    values: ["full", "light", "skip"]
    default: "full"
    description: >
      Depth of edge case hunting in Step 4. "full" probes all categories
      (input validation, concurrency, resource exhaustion, state transitions,
      external failures). "light" probes input validation and error paths
      only. "skip" disables edge case hunting (not recommended).
```

### /security

```yaml
settings:
  - name: history_scan_depth
    type: enum
    values: ["full", "recent", "current"]
    default: "full"
    description: >
      How deeply the secrets management review scans git history. "full"
      scans all commits for leaked secrets. "recent" scans the last 100
      commits. "current" scans only the current tree (fastest but misses
      historically leaked secrets).

  - name: threat_model_depth
    type: enum
    values: ["full", "abbreviated"]
    default: "full"
    description: >
      Depth of the STRIDE threat model in Step 3. "full" enumerates all
      attack surfaces and threats per domain. "abbreviated" covers only
      high-risk surfaces (external inputs, auth boundaries, data stores).
```

### /deploy

```yaml
settings:
  - name: auto_archive_receipts
    type: boolean
    default: true
    description: >
      Automatically rename existing DEPLOY-RECEIPT.md to
      DEPLOY-RECEIPT-{timestamp}.md before writing a new receipt. When
      false, overwrite the existing receipt without archiving.
```

---

## Rejected Settings

Settings that were considered but excluded because they fail the scope test or are
redundant.

| Setting | Proposed by | Rejection reason |
|---------|-------------|------------------|
| `coverage_target` | /qa | Belongs in project CLAUDE.md. Coverage targets are project-specific, not Factory behavior. |
| `test_command` | /qa, /build | Belongs in project CLAUDE.md. Test commands are project-specific. |
| `lint_command` | /build | Belongs in project CLAUDE.md. Lint commands are project-specific. |
| `security_severity_threshold` | /security | Belongs in project CLAUDE.md. The gate behavior (BLOCKED on CRITICAL) is baked into the skill by design and should not be configurable -- weakening it undermines the security gate. |
| `tech_stack` | /setup | Belongs in project SPEC.md and CLAUDE.md. The tech stack is a project decision, not a Factory behavior setting. |
| `deploy_region` | /deploy, /setup | Belongs in project fly.toml / infra config. Region is infrastructure-specific, not Factory behavior. |
| `branch_naming_prefix` | /build | Belongs in project CLAUDE.md. Branch naming conventions are project-level. |
| `pr_merge_strategy` | /build | Belongs in project CLAUDE.md. Merge strategy (squash, rebase) is a project convention. CLAUDE.md already mandates squash-before-merge. |
| `ci_provider` | /setup | Belongs in project config. The CI provider is an infrastructure choice, not Factory behavior. Currently hardcoded to GitHub Actions. |
| `max_ideas` | /ideation | Renamed to `idea_count` and kept. The original name was ambiguous. |
| `deployment_platform` | /setup | Belongs in SPEC.md. Platform is a project decision. |
| `create_environments` | /setup | Belongs in SPEC.md. Environment provisioning is project-level. |
| `telemetry_enabled` | /setup | Belongs in SPEC.md. Telemetry is a project decision. |
| `alpha_deploy_enabled` | /build | Alpha deploy opt-in is a build-time coordination concern, not a persistent setting. |
| `mutation_testing` | /qa | Too granular. QA skill already adapts based on stack support. |
| `default_target` | /deploy | Deploy target should be explicit per invocation, not a default that could lead to accidental prod deploys. |
| `staging_auto_rollback` | /deploy | Staging rollback is manual by design. Making it auto undermines investigation. |
| `prod_confirmation` | /deploy | Prod confirmation is mandatory by design. Weakening it is too risky. |
| `retro_mandatory` | /retro | Rejected. Retro is mandatory by pipeline design (CLAUDE.md). Making it configurable undermines the pipeline's quality model. |
| `gate_override` | /security, /qa | Rejected. Allowing gate overrides undermines the purpose of gates. If a CRITICAL finding exists, deployment must be blocked. This is a design principle, not a setting. |
| `auto_promote` | /deploy | Rejected. Automatic promotion from staging to prod without user confirmation is too risky. The skill requires explicit confirmation for prod by design. The `prod_confirmation: skip_if_promoted` setting is the controlled relaxation of this. |
