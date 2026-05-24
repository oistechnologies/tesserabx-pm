# Changelog

All notable changes to `tesserabx-pm` are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Pre-1.0 development happens directly on `main`. Phases are tracked here as `[Unreleased]` sections until v1.0.0 is tagged, at which point post-v1 work moves to feature branches per the BUILD-PLAN §4.3.

## [Unreleased]

### Phase 2b: Task and Subtask CRUD on the Agent Surface

- `TaskService@tesserabx-pm` ships full CRUD on `pm_tasks` (BUILD-PLAN §7.1): create / list / get / update / remove / restore. Polymorphic assignee validation rejects half-populated `(assignee_type, assignee_id)` pairs. Status transitions stamp `completed_at` when moving into a status row with `is_completed=true` and clear it (via direct SQL, working around Quick's null-binding behavior on timestamp columns) when moving away. Emits `onPmTaskCreated`, `onPmTaskAssigned`, `onPmTaskStatusChanged` (sync, so the Phase 8 close-on-complete listener can react in-band), and `onPmTaskCompleted`.
- `SubtaskService@tesserabx-pm` ships full CRUD on `pm_subtasks` (BUILD-PLAN §7.1): create / list / get / update / remove / restore. Polymorphic assignee validation matches Task. Toggling `is_completed` stamps or clears `completed_at` in the same direct-SQL pattern. Emits `onPmSubtaskCreated` and `onPmSubtaskCompleted`.
- `ProjectStatusService@tesserabx-pm` lands as a read + hydrate service. `listForProject`, `getStatus`, `defaultStatusForProject`, and `hydrateFromTemplate(projectId, organizationId, templateId)`. The full per-project CRUD UI is deferred to Phase 2c.
- `ProjectService.createProject` now calls `projectStatusService.hydrateFromTemplate` so every new project ships with the default 5-column kanban (Backlog / To Do / In Progress / In Review / Done) from the Phase 1 seeded "Standard Workflow" template. Hydration is wrapped in try/catch and logs warnings; project creation never blocks on hydrate failures.
- `VisibilityService@tesserabx-pm` expanded with task-side Option C: `tasksQueryForViewer(viewer, projectId)` builds the Quick query a contact viewer is allowed to see (own assignment, another-contact-in-org assignment, or `is_client_visible=true`) and `canViewTask(viewer, task)` / `assertCanViewTask(viewer, task)` give the per-row guards.
- New contracts: `ITaskService@tesserabx-pm`, `ISubtaskService@tesserabx-pm` (documentation classes that throw on direct use).
- New DTOs: `TaskDto@tesserabx-pm`, `SubtaskDto@tesserabx-pm` with `fromTask`/`fromTaskArray` and `fromSubtask`/`fromSubtaskArray`. Snake-case structs, null-coalesced, timestamps stringified.
- Agent handlers: `handlers/Tasks.bx` (index by project, show, new, create, edit, update, remove, restore) and `handlers/Subtasks.bx` (new, create, edit, update, complete, reopen, remove). Tasks list is nested under `/agent/pm/projects/:projectId/tasks`; everything else routes by id under `/agent/pm/tasks/*` or `/agent/pm/subtasks/*` because UUIDs are unique.
- Views: `views/tasks/{index,show,new,edit}.bxm` (the index is a column board grouped by status); `views/subtasks/{new,edit}.bxm` (the inline subtask list lives on tasks/show). `views/projects/show.bxm` updated with task-list and create-task links.
- `models/entities/Task.bx` and `Subtask.bx` get `sqltype="decimal"` on `estimated_hours` so the JDBC binder sends a real numeric instead of a varchar.
- New test bundles: `tests/specs/unit/TaskServiceSpec.bx` (9 specs covering create defaults / missing field / invalid priority / invalid assignee / cross-project status / update round-trip / completed_at toggle / soft delete round-trip / sort order) and `tests/specs/unit/SubtaskServiceSpec.bx` (6 specs covering create / completed-on-create / invalid assignee / completion toggle / soft delete round-trip / sort order).
- `InstallSpec.bx` adds 5 new WireBox-binding probes for ProjectStatusService, TaskService, SubtaskService, TaskDto, SubtaskDto. 23 specs total.
- Deferred to Phase 2c: per-project ProjectStatus CRUD UI (rename / recolor / reorder / add); REST API handlers under `/api/v1/pm/*` and the `apiResources` manifest; `config/cbSecurity.bx` per-action `pm.*` permission gating; handler integration tests; assignee-picker (Phase 2b uses a paste-a-UUID input).

### Phase 2a: Project CRUD on the Agent Surface

- `entryPoint` changed from `tesserabx-pm` to `agent/pm` (multi-segment, mirrors the host's nested admin module). PM's own `config/Router.bx` now naturally handles every `/agent/pm/*` URL; the agent firewall covers them by URL regex.
- `routeClaims` reduced from 3 entries to 2: only the cross-surface URLs `/pm` (portal) and `/agent/admin/pm` (admin) need claims now. `/agent/pm` is owned directly by PM's module router.
- `ProjectService@tesserabx-pm` ships full CRUD on `pm_projects`: `getProject`, `listProjects`, `createProject`, `updateProject`, `archiveProject`, `restoreProject`, `removeProject`. Emits `onPmProjectCreated` and `onPmProjectArchived` async events through `EventPayloadBuilder@core`, writes `tesserabx-pm.project_created` and `tesserabx-pm.project_archived` rows to the host audit log via `AuditService@audit.record`.
- `VisibilityService@tesserabx-pm` enforces BUILD-PLAN §3.3 Option C for projects: agents see everything, contacts see `all_org_members` projects in their org plus any `specific_members` project where they have a `pm_project_members` row. Exposes `projectsQueryForViewer`, `canViewProject`, `assertCanViewProject`.
- `IProjectService@tesserabx-pm` contract class documenting the service surface for cross-module callers (BoxLang has no interface keyword; the contract is a documentation-only class that throws on direct instantiation).
- `ProjectDto@tesserabx-pm` singleton with `fromProject` and `fromProjectArray` returning snake_case structs; pattern mirrors the host's `TicketDto@tickets`.
- Agent surface CRUD: `handlers/Projects.bx` + views `views/projects/{index,show,new,edit}.bxm` implementing the full list / detail / create / edit / archive / restore / soft-delete flow with AdminLTE styling and cbmessagebox flash feedback. The page renders inside the host's Agent layout (preHandler sets it).
- New test bundles: `tests/specs/unit/ProjectServiceSpec.bx` (8 specs covering create, update, archive, restore, soft-delete, list filters; uses real organizations fixtures with CASCADE cleanup) and `tests/specs/unit/VisibilityServiceSpec.bx` (6 specs covering viewer validation, agent path, all_org_members, specific_members, assertion guard).
- `InstallSpec.bx` updated for the new routeClaims shape (asserts `/agent/pm` is NOT a claim, the two cross-surface URLs ARE) plus three new probes for `ProjectService`, `VisibilityService`, `ProjectDto` WireBox bindings. 18 specs.
- Deferred to Phase 2b: Task/Subtask services, handlers, and views; per-project ProjectStatus CRUD UI; REST API handlers under `/api/v1/pm/*` and the `apiResources` manifest; `config/cbSecurity.bx` per-action permission gating (Phase 2a relies on the host's agent firewall for coarse `/agent/pm/*` gating).

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
