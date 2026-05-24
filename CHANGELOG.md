# Changelog

All notable changes to `tesserabx-pm` are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Pre-1.0 development happens directly on `main`. Phases are tracked here as `[Unreleased]` sections until v1.0.0 is tagged, at which point post-v1 work moves to feature branches per the BUILD-PLAN §4.3.

## [Unreleased]

### Phase 1: Entities, Migrations, Permissions, Roles, Navigation Skeleton

- 17 migrations under `migrations/` creating the PM schema in dependency order: `pm_project_templates`, `pm_projects`, `pm_project_statuses`, `pm_labels`, `pm_custom_fields`, `pm_project_members`, `pm_project_events`, `pm_tasks`, `pm_subtasks`, `pm_task_labels`, `pm_task_tickets`, `pm_comments`, `pm_watchers`, `pm_time_logs`, `pm_custom_field_values`, `pm_attachments`, `pm_mentions`. Every tenant-scoped table carries `organization_id` with `ON DELETE CASCADE` from its first migration.
- `pgvector` columns added on `pm_projects.embedding` and `pm_tasks.embedding` via raw SQL (cfmigrations has no vector DSL); populated by the Phase 12 embedding consumer.
- Seed migration `2026_05_24_000300_seed_pm_default_project_template.cfc` inserts the shared "Standard Workflow" template (Backlog, To Do, In Progress, In Review, Done) with `organization_id = NULL`.
- 17 Quick entity classes under `models/entities/` extending `tesserabx.modules.contacts.models.TesseraBXEntity`. Tenant-scoped entities apply `TenantScope@contacts` in `applyGlobalScopes`. Polymorphic actor columns (`<role>_type` + `<role>_id`) follow BUILD-PLAN §3.4 with no FK enforcement; the service layer carries the integrity contract.
- WireBox bindings for all 17 entities added in `ModuleConfig.bx` `onLoad()`.
- Manifest deltas in `settings.tesserabx`: 6 permissions (`pm.view`, `pm.create`, `pm.edit`, `pm.delete`, `pm.assign-client`, `pm.admin`), 6 roles (4 agent-surface + 2 contact-surface), 2 navigation entries (agent and portal main), 1 admin landing card, 1 per-tenant setting (`pm.default-template-id`), and 3 `routeClaims` for the BUILD-PLAN top-level URLs.
- Routing now uses the new host `routeClaims` contract introduced alongside this phase. PM declares `/agent/pm`, `/pm`, and `/agent/admin/pm` in `settings.tesserabx.routeClaims`; the host's `RouteClaimsRegistry@core` + `AddonRouteClaimsRegistrar` interceptor injects them into ColdBox's main router on `afterAspectsLoad`. PM's own module Router stays minimal (one route at the entry point for parity).
- `tests/specs/unit/EntitiesSpec.bx` covers all 17 entities (WireBox resolution + Quick query builder + table name + relationship function surface) plus a tenant-scope smoke probe and a TaskLabel exemption note. 43 specs pass.
- `tests/specs/InstallSpec.bx` expanded with 12 new probes covering the Phase 1 manifest deltas, including a `RouteClaimsRegistry@core` probe that asserts all three top-level URLs land at the right module/handler/action. 15 specs pass.

### Phase 0: Scaffold the Add-On

- Initial `box.json` with host-matched dependency pins.
- `ModuleConfig.bx` with the `settings.tesserabx` manifest skeleton: `addonId`, `displayName`, `version`, `minCoreVersion`, `requiresAi : false`, and empty arrays for every registry contribution.
- `config/Router.bx` with a placeholder route at the module entry point.
- `handlers/Main.bx` and `views/main/installed.bxm` rendering a "PM installed" confirmation page.
- Folder structure per BUILD-PLAN §5 with `.gitkeep` markers in empty directories.
- `tests/specs/InstallSpec.bx` Phase 0 minimal: asserts the host's `AddonRegistryService@core` reports `tesserabx-pm` as a discovered, compatible add-on. Per-registry probes will be added phase by phase as contributions land.
- `.github/workflows/test.yml` pinned to host commit `ada629a` (after the three host follow-ups merged: `compose.override.yaml` ignored, runner auto-discovers `modules/<addon>/tests/specs/` for add-ons declaring `settings.tesserabx`, EXTENSIONS.md staging filename pattern corrected to match `tasks/Migrate.cfc`).
- `compose.override.yaml.example` documenting the dev bind-mount template.
- Apache 2.0 license, README, and changelog scaffolding.
