# CLAUDE.md

## Project

**tesserabx-pm** is a Project Management extension module for the TesseraBX helpdesk platform.

This file is intentionally short. The authoritative build plan, architecture, entity model, conventions, and phase definitions all live in **`docs/BUILD-PLAN.md`**. Read it in full at the start of every session before doing anything else.

## Non-Negotiable Rules

1. **No em dashes anywhere.** Code, comments, docs, commits, UI copy, error messages. Use commas, parentheses, or sentence breaks.
2. **No commits without Mike's explicit approval.** See Section 4.4 of the BUILD-PLAN. Phase work happens in the working tree. Commits happen only after tests pass, Mike reviews the diff, Mike tests any UI changes, and Mike says "approved, commit it" (or equivalent).
3. **Direct to `main` during v1.** No feature branches, no PRs until `v1.0.0` ships. Branch protection and feature-branch workflow turn on at the v1 release.
4. **Stay within the active phase.** Do not start the next phase until the current one is approved, committed, and CI is green.

## Stack at a Glance

ColdBox 8, BoxLang (with CFML compatibility), PostgreSQL 16 + pgvector, Quick ORM, qb, CBWire 4, AdminLTE 4, CBFS, cbSecurity, cfmigrations, TestBox.

## Paths

| Purpose | Path |
|---------|------|
| Module repo (remote) | https://github.com/oistechnologies/tesserabx-pm |
| Module repo (local) | `/Users/mrigsby/Data/BoxLang-Dev/TesseraBX/GIT/tesserabx-pm` |
| TesseraBX staging clone | `/Users/mrigsby/Data/BoxLang-Dev/TesseraBX/LOCAL-STAGING/` |
| Container mount target | `/app/modules/tesserabx-pm` |
| Dev database | `tesserabx_pm_dev` |
| Test database | `tesserabx_pm_test` |

## Common Commands

Run inside the LOCAL-STAGING container unless noted.

```bash
box install              # install module dependencies
box migrate up           # run migrations against dev DB
box migrate down         # roll back last migration
box testbox run          # run full TestBox suite
box reinit               # reinit ColdBox after config changes
box server log --follow  # tail logs
```

## Session Start Checklist

1. Read `docs/BUILD-PLAN.md` in full.
2. Determine the active phase from `CHANGELOG.md` and the latest commits on `main`.
3. Confirm the phase with Mike before starting work.
4. Do the phase work. Run tests locally. **Do not commit.**
5. At phase end, produce a summary: file inventory, test results, manual UI test checklist, any deferred items or open questions.
6. Wait for Mike's explicit approval.
7. Once approved, commit using Conventional Commits in logical batches, update `CHANGELOG.md` in the same batch, and push to `main`.
8. Verify CI passes. If red, produce a fix-up commit before considering the phase closed.

## When You Are Unsure

Stop and ask Mike. Do not guess. The BUILD-PLAN covers most cases; for anything not covered, asking is always preferred to inferring.
