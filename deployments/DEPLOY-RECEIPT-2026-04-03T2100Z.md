# Deployment Receipt -- 2026-04-03

## Deployment

- **Status**: SUCCESS
- **Version**: v0.2.0 (b758126)
- **Previous version**: v0.1.0 (798e524)
- **Environment**: prod
- **Platform**: GitHub Pages + GitHub Releases (tag)
- **Deployed at**: 2026-04-03

## What Was Deployed

- **Tag**: v0.2.0 pushed to origin
- **Marketplace**: `.claude-plugin/marketplace.json` ref updated to v0.2.0
- **Plugin version**: `.claude-plugin/plugin.json` bumped to 0.2.0
- **Landing page**: <https://whalbawi.github.io/factory/> (200 OK)

## Changes Since v0.1.0

- Settings system (5 global + 17 per-skill settings with schema, storage,
  command, validation, and first-run discovery)
- /factory claim mode for onboarding existing codebases
- Deploy gate hardening (parse actual files, commit tracking)
- All security findings resolved (install.sh, CI pinning, command safety)
- Retro learnings applied (gate finality, progress tracking, no direct
  commits)
- Deployment guidelines in CLAUDE.md
- Cross-reference warnings resolved (removed obsolete SPEC-core-skills.md)
- Release flow documented (tag first, update marketplace second)

## Gate Checks

| Gate | Required | Status | Notes |
|------|----------|--------|-------|
| QA Report | YES | PASS | Tested at b758126 |
| Security Report | YES | CLEAR | Tested at b758126 |
| CI Checks | YES | PASS | Success at b758126 |
| User Confirmation | YES | CONFIRMED | User confirmed deploy |

## Post-Deploy Verification

| Check | Status | Notes |
|-------|--------|-------|
| GitHub Pages live | PASS | 200 OK |
| Tag exists | PASS | v0.2.0 at b758126 |
| Marketplace updated | PASS | ref: v0.2.0 |
| Plugin version bumped | PASS | 0.2.0 |

## Rollback Info

- **Previous version**: v0.1.0
- **Rollback command**: `git tag -d v0.2.0 && git push origin :refs/tags/v0.2.0`
- **Rollback performed**: NO
