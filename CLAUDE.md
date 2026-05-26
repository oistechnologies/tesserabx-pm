# CLAUDE.md

## Project

**tesserabx-pm** is a Project Management add-on for the TesseraBX helpdesk platform.

It is a **third-party TesseraBX add-on**, meaning a standard ColdBox 8 module that registers itself with the host through the `settings.tesserabx` manifest contract documented in the host repo at [`docs/EXTENSIONS.md`](../tesserabx/docs/EXTENSIONS.md). It installs into a running TesseraBX deployment at `modules/tesserabx-pm/` and contributes navigation, admin pages, ticket panels, dashboard widgets, automation actions, AI features, API resources, notification templates, help pages, roles, permissions, and per-tenant settings to the host.

This file is intentionally short. The authoritative build plan, architecture, entity model, conventions, and phase definitions all live in [`docs/BUILD-PLAN.md`](docs/BUILD-PLAN.md). Read it in full at the start of every session before doing anything else. Then also re-skim the host's `docs/EXTENSIONS.md` for any phase that adds or modifies a manifest contribution.

## Non-Negotiable Rules

These are inherited from the TesseraBX host plus PM-specific rules.

1. **No em dashes anywhere.** Code, comments, docs, commits, UI copy, error messages. Use commas, parentheses, or sentence breaks.
2. **AI isolation.** Only the host `ai` module imports `bx-ai`. Every PM AI feature calls through `AiMiddleware@ai` and registers via `AiFeatureRegistry@ai` and `EmbeddingConsumerRegistry@ai`. PM never imports `bx-ai`.
3. **AI-off invariant.** When `AI_ENABLED=false`, every PM AI surface must be invisible. Every UI registry contribution that fronts an AI feature declares `requiresAi : true`. PM AI features inherit `requiresAi : true` automatically through the AI feature registry.
4. **Tenant scope.** `Organization` is the tenant boundary, `organization_id` is the column, and the global scope `TenantScope@contacts` is mandatory on every tenant-scoped PM entity from its first migration. No retrofitting.
5. **Two account families.** TesseraBX has `Agent` (provider side, `/agent`) and `Contact` (client side, `/`). PM concepts that refer to "users" (assignees, watchers, mentions, comment authors, time-log users) treat both account types as first-class through polymorphic `*_type` and `*_id` columns.
6. **No commits without Mike's explicit approval.** See BUILD-PLAN §4.4. Phase work happens in the working tree. Commits happen only after tests pass, Mike reviews the diff, Mike tests any UI changes, and Mike says "approved, commit it" (or equivalent).
7. **Feature-branch workflow post v1.0.0.** Pre-1.0 was direct-to-`main`; once v1.0.0 ships, every change lands through a PR with CI green + one approving review. See [`CONTRIBUTING.md`](CONTRIBUTING.md).
8. **Stay within the active phase.** Do not start the next phase until the current one is approved, committed, and CI is green.

## Stack at a Glance

Inherited from the TesseraBX host. PM does not introduce or substitute components.

ColdBox 8+, BoxLang runtime (module is `.bx` and `.bxm` end to end, no `.cfc` or `.cfm`), PostgreSQL 16 with `pgvector`, Redis (CacheBox and cbq backend), Quick ORM, qb, CBWire 4+, AdminLTE 4, CBFS (host's provider), cbSecurity (host's firewalls per surface), cbq (host's worker container), cfmigrations (host's stager), TestBox, mementifier.

## Paths

| Purpose | Path |
| --- | --- |
| PM module repo (remote) | <https://github.com/oistechnologies/tesserabx-pm> |
| PM module repo (local) | `/Users/mrigsby/Data/BoxLang-Dev/TesseraBX/GIT/tesserabx-pm` |
| Host TesseraBX repo (local) | `/Users/mrigsby/Data/BoxLang-Dev/TesseraBX/GIT/tesserabx` |
| Host extension contract | `/Users/mrigsby/Data/BoxLang-Dev/TesseraBX/GIT/tesserabx/docs/EXTENSIONS.md` |
| Host reference add-on | `/Users/mrigsby/Data/BoxLang-Dev/TesseraBX/GIT/tesserabx/sample-addons/example-sync/` |
| Host dev compose files | `compose.yaml` + `compose.dev.yaml` (in host repo root) |
| Container bind-mount target | `/app/modules/tesserabx-pm` |
| Module install path (production) | `modules/tesserabx-pm/` |
| Module slug (`addonId`) | `tesserabx-pm` |

## Common Commands

Run from the **host** TesseraBX repo root (`/Users/mrigsby/Data/BoxLang-Dev/TesseraBX/GIT/tesserabx`) unless noted. PM does not run its own server; it loads as a module inside the host.

```bash
# Bring up the host dev stack with PM bind-mounted via compose override.
docker compose -f compose.yaml -f compose.dev.yaml up

# Stage and run migrations. The host stager copies migrations from
# modules/tesserabx-pm/migrations/ into resources/database/migrations/
# with the host's add-on prefix, then runs them.
box run-script migrate:stage
box run-script migrate:up
box run-script migrate:down

# Run the TestBox suite. PM specs under modules/tesserabx-pm/tests
# are picked up automatically. The PM InstallSpec is the CI gate.
box run-script test:run

# Reinit the framework after a ModuleConfig.bx or Router.bx change.
box reinit
```

## Operating as a TesseraBX Add-on

Every phase touches one or more of these contracts. Before starting a phase, scan the relevant sections of the host's `docs/EXTENSIONS.md`:

* **Manifest** (`settings.tesserabx` in `ModuleConfig.bx`): `addonId`, `displayName`, `version`, `minCoreVersion`, `maxCoreVersion`, `contributesTo`, `requiresAi`.
* **Discovery and enablement**: PM rows land in `addons` at boot; per-tenant rules live in `addon_organization_enablement`.
* **Service contracts**: PM calls host modules through their published contracts under `models/contracts/`. PM never reaches into host entities directly.
* **Tenant scope**: PM tenant entities extend `tesserabx.modules.contacts.models.TesseraBXEntity` and apply `TenantScope@contacts` in `applyGlobalScopes`. Hand-written qb queries use `TenancyGuard@contacts`.
* **Events**: PM announces canonical envelopes built by `EventPayloadBuilder@core` and consumes host events (`onTicketCreated`, `onTicketStatusChanged`, etc.) via interceptors declared in `ModuleConfig.bx`.
* **Registries PM contributes to**: navigation, admin pages, roles, permissions, ticket panels, dashboard widgets, automation actions and triggers, AI features and embedding consumers, API resources, webhook events, notification templates, per-tenant settings, help pages and sections, audit event types, assets.
* **InstallSpec**: PM owns a top-level TestBox spec that asserts every manifest contribution lands in the right registry. Copy the shape from the host's `sample-addons/example-sync/tests/specs/InstallSpec.bx`.

## Session Start Checklist

1. Read [`docs/BUILD-PLAN.md`](docs/BUILD-PLAN.md) and [`CHANGELOG.md`](CHANGELOG.md) to understand shipped state.
2. Read this file plus [`CONTRIBUTING.md`](CONTRIBUTING.md) for the contribution flow.
3. Skim the host `docs/EXTENSIONS.md` sections relevant to the task.
4. Confirm scope with Mike before starting work.
5. Do the work on a feature branch off `main`. Run tests locally inside the host dev stack. **Do not commit to `main` directly.**
6. At task end, produce a summary: file inventory, manifest deltas (the registry entries added or modified), test results, manual UI test checklist, any deferred items or open questions.
7. Wait for Mike's explicit approval.
8. Once approved, commit using Conventional Commits, update `CHANGELOG.md` under `[Unreleased]`, push the branch, and open a PR.
9. Verify CI passes on the PR. If red, push a fix-up commit before requesting review.

## When You Are Unsure

Stop and ask Mike. Do not guess. The PM BUILD-PLAN covers most cases. The host BUILD-PLAN and EXTENSIONS.md cover most of the rest. For anything not covered, asking is always preferred to inferring.
