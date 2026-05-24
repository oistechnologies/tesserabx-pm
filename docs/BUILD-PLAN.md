# tesserabx-pm Build Plan

## 1. Overview

**Module name:** `tesserabx-pm`
**Type:** TesseraBX third-party add-on (a standard ColdBox 8 BoxLang module that participates in the `settings.tesserabx` manifest contract)
**Parent application:** TesseraBX helpdesk and customer support platform
**Repository:** <https://github.com/oistechnologies/tesserabx-pm>
**Local repo path:** `/Users/mrigsby/Data/BoxLang-Dev/TesseraBX/GIT/tesserabx-pm`
**Host repo (local):** `/Users/mrigsby/Data/BoxLang-Dev/TesseraBX/GIT/tesserabx`
**Host extension contract:** [`docs/EXTENSIONS.md`](../../tesserabx/docs/EXTENSIONS.md) in the host repo
**Host reference add-on:** [`sample-addons/example-sync/`](../../tesserabx/sample-addons/example-sync/) in the host repo

`tesserabx-pm` adds a full-featured Project Management capability to TesseraBX. Projects are scoped to organizations through the host's tenant scope primitive. Work is organized in a three-level hierarchy (Project, Task, Subtask). The module supports customizable kanban workflows, optional per-project time tracking, project templates, per-project custom fields, bidirectional ticket integration through the host's automation and ticket-panel registries, client portal visibility per Option C, @mentions and notifications through the host's notification fan-out module, and pgvector-backed AI augmentation through the host's `AiMiddleware@ai` facade.

This document is the authoritative source of truth for the PM add-on. The host TesseraBX repo's `CLAUDE.md` plus its `docs/BUILD-PLAN.md` plus its `docs/EXTENSIONS.md` are the authoritative source of truth for the platform PM rides on. Where the PM plan and the host plan appear to disagree, the host wins and the disagreement is worth raising with Mike.

---

## 2. Tech Stack

PM inherits the host stack. It does not introduce or substitute components.

| Layer | Technology | Owner |
| --- | --- | --- |
| Framework | ColdBox 8+ | host |
| Runtime | BoxLang | host |
| Database | PostgreSQL 16 with pgvector | host |
| ORM | Quick | host |
| Query builder | qb | host |
| Interactive UI | CBWire 4+ | host |
| UI framework | AdminLTE 4 | host |
| File storage | CBFS (configured provider) | host |
| Authorization | cbSecurity + cbauth | host |
| Migrations | cfmigrations via host's `tasks/Migrate.bx` stager | host |
| Async / queues | cbq (single worker container on the host) | host |
| AI access | `AiMiddleware@ai` (host's `ai` module is the only code that imports `bx-ai`) | host |
| Testing | TestBox | host |
| Serialization | mementifier | host |

PM ships no infrastructure of its own. The PM repo's `box.json` declares the dependencies needed to install the source tree standalone (for ForgeBox), but at runtime PM uses whatever the host has installed.

---

## 3. Architectural Decisions

These decisions are locked. Any deviation requires Mike's explicit approval in the session that introduces it.

### 3.1 Hierarchy

Three levels: **Project > Task > Subtask**.

* Tasks live on the kanban board and carry full status, custom fields, labels, embeddings, time logs.
* Subtasks are intentionally lighter: title, description, polymorphic assignee, due date, estimated hours, binary completion. They do not appear on the board and do not carry full statuses or custom fields.
* No checklists in v1. If finer granularity is needed, use subtasks.

### 3.2 Statuses

Per-project custom statuses. Each project owns its kanban columns through `ProjectStatus` rows. A default template (Backlog, To Do, In Progress, In Review, Done) is applied on project creation and can be edited.

### 3.3 Tenant Scope and Client Visibility

**Tenancy** is the host's, applied to every PM entity that carries per-tenant data:

* Every tenant-scoped PM entity carries `organization_id` from its first migration.
* Every such entity extends `tesserabx.modules.contacts.models.TesseraBXEntity`.
* `applyGlobalScopes( builder )` calls `getInstance( "TenantScope@contacts" ).apply( arguments.builder )`.
* Hand-written qb queries call `wirebox.getInstance( "TenancyGuard@contacts" ).applyScope( q, organizationId )`.

**Client visibility (Option C)** sits on top of tenancy. A `Contact` user can see a task when any of the following is true within their organization (the tenant scope already enforces the org cut):

1. The task is assigned to them.
2. The task is assigned to another `Contact` in their organization.
3. The task has `is_client_visible = true`.

Provider `Agent` users see every task within every project they have access to, subject to RBAC. Clients never see comments flagged `is_internal = true`. Only `Agent` users may assign a task to a `Contact`.

### 3.4 Two Account Families

The host has `Agent` (provider, `/agent`) and `Contact` (client, `/`) as separate entities. PM treats both as first-class actors through polymorphic columns:

* `assignee_type` (`'agent'` or `'contact'`) + `assignee_id`
* `author_type` + `author_id` on Comment
* `actor_type` + `actor_id` on ProjectEvent and ActivityLog reads
* `watcher_type` + `watcher_id` on Watcher
* `mentioned_user_type` + `mentioned_user_id` on Mention
* `user_type` + `user_id` on TimeLog (time logs may be billable; an agent or a contact may both log time if the project allows it)
* `created_by_type` + `created_by_id` on every PM entity

The PM `VisibilityService` evaluates the visibility rule per surface in terms of the viewer's account type.

### 3.5 Comments

Polymorphic across Project, Task, and Subtask. Every comment carries `is_internal`.

* Agent-authored comments default to `is_internal = true`.
* Contact-authored comments are always `is_internal = false`. The composer on the portal surface forces the flag.
* Clients never see `is_internal = true` comments anywhere in the UI or the API.

### 3.6 Ticket Integration

Bidirectional. PM owns the `TaskTicket` join table that links a PM task to a host `Ticket`.

* **Task detail**: a "Linked tickets" panel rendered by PM's own view, hitting host `TicketsService@tickets` through its contract.
* **Ticket detail**: a "Linked tasks" panel registered via the host's `ticketPanels` manifest entry, mounted on the right column of the agent ticket detail.
* **Convert ticket to task**: an automation action contributed via `automationActions` in the manifest. Selecting it from a ticket creates a PM task with title and description prefilled and the link recorded.
* **Bulk create task from selected tickets**: a bulk action on the agent ticket list. Implemented in PM as a handler that PM contributes via routes; the trigger UI is registered via the agent module's bulk-action registry if and only if such a registry exists at build time. If not, this is deferred.
* **Close-on-complete prompt**: PM listens on `onPmTaskStatusChanged`. When a task moves to a status with `is_completed = true` and the task has linked tickets, PM prompts the agent to close the linked tickets via `TicketsService@tickets`.
* **SLA awareness**: linked-ticket SLAs are surfaced on the task card via a visual indicator. The data comes from the host `sla` module's service layer; PM never reads `sla` entities directly.

### 3.7 Time Tracking

Optional per-project, controlled by `time_tracking_enabled` on Project. Time logs attach polymorphically to Task and Subtask. Subtask hours roll up to the parent task; task hours roll up to the project. Estimates exist on both Task and Subtask. Billable flag supported per log.

If the host `agent` module ships its own time-tracking facility before PM Phase 5, the PM `TimeLog` aligns with whatever it exposes (column naming, billable semantics) so an operator can pivot reporting across both. Today the host has no agent-level time tracking, so PM is greenfield here.

### 3.8 Templates

Project templates stored as a JSON snapshot of structure (statuses, labels, custom fields, tasks with relative date offsets, subtasks). When applied, `TemplateService` hydrates a new project with calculated dates.

`ProjectTemplate.organization_id` is required for tenant-scoped templates; templates intended to be shared across all organizations carry `organization_id IS NULL` and are gated by an admin permission.

### 3.9 Notifications

PM does **not** ship its own notification service. PM contributes to the host `notifications` module:

* PM declares `notificationTemplates` in `settings.tesserabx`, one per `(eventKey, channel, recipientType)` tuple.
* PM announces canonical event envelopes (`onPmTaskAssigned`, `onPmCommentAdded`, etc.) via `EventPayloadBuilder@core` and the interceptor service.
* The host `notifications` module looks up subscribers, applies their preferences from `NotificationPreference` rows owned by the host, and fans out to in-app, email, and any add-on channels.
* User notification preference UI lives in the host. PM's job is to make sure every PM event is declared as a webhook event (for outbound webhook subscribers) and as a notification-template tuple (for delivery).

Events that produce notifications in v1:

* Task assigned to you
* You are @mentioned in a comment
* A comment is added to a task you watch
* Status change on a task you watch
* Due date 24 hours away on a task assigned to you (scheduled task)
* Due date passed on a task assigned to you (scheduled task)
* A ticket is linked to your task

### 3.10 Watchers

Auto-watch on assignment. Auto-watch on commenting. Manual watch via a button on the task. Distinguished by an `auto_added` flag.

### 3.11 Activity Log

PM owns its own `ProjectEvent` entity for the domain timeline (parallel to how the host's `tickets` module owns `TicketEvent` for the ticket timeline). `ProjectEvent` is what the project activity feed renders.

In addition, PM writes cross-cutting compliance events to the host `AuditService@audit` log. These are the events that an org admin or auditor cares about across the platform, not the granular UI timeline. PM declares its compliance event types in the manifest's `auditEvents` array so they appear in the admin audit search dropdown before they have ever fired:

* `tesserabx-pm.project_created`
* `tesserabx-pm.project_archived`
* `tesserabx-pm.project_deleted`
* `tesserabx-pm.task_assigned_to_contact` (significant because it crosses an account-family boundary)
* `tesserabx-pm.template_applied`
* `tesserabx-pm.ticket_linked`

Granular events (status changes, comment edits, label toggles) live in `ProjectEvent` only.

### 3.12 AI Features

Powered by the host's pgvector + AI middleware. PM never imports `bx-ai`.

* **Embeddings**: PM declares an `embeddingConsumers` entry (`tesserabx-pm.task`) whose implementation lives in PM and writes vectors to `pm_tasks.embedding`. The host scheduler iterates the embedding registry and re-embeds stale entries.
* **Semantic similarity**: "Related Tasks" panel on task detail. "Find similar tasks" suggestion when creating a task or converting a ticket. Both panels carry `requiresAi : true` and are hidden when `AI_ENABLED=false`.
* **Comment summarization**: an on-demand "Summarize this thread" action on comment threads, calling `AiMiddleware@ai.complete( feature : "tesserabx-pm.summarize-thread", ... )`. Hidden when AI is off.
* **Suggestion service**: PM `SuggestionService` returns assignee and label suggestions based on historical patterns. Stubbed in v1, lights up as data accrues. Hidden when AI is off.
* **Priority scoring**: deterministic scorer (priority weight + due date proximity + blocked flag + assignment count) drives a "My Recommended Next Task" dashboard widget. The scoring itself works without AI. An **optional AI explanation layer** for the widget is gated on `AI_ENABLED=true`.

All PM AI features are declared in `aiFeatures` in the manifest with explicit `defaultSystemPrompt` values. The host's AI prompts admin page may override prompts at runtime.

**Belt-and-braces gating.** The UI registries automatically hide entries with `requiresAi : true` when `AI_ENABLED=false`, but per the host contract every PM call site must additionally call `AiCapability.isFeatureEnabled( featureId )` before invoking `AiMiddleware`. Hiding the UI is not enough on its own; the call path must also guard so that API requests, scheduled tasks, and any other non-UI entry points respect the flag.

### 3.13 Primary Keys and Soft Delete

* UUID primary keys throughout, generated via PostgreSQL `gen_random_uuid()` (the host already requires `pgcrypto`).
* Soft delete (`deleted_at` timestamp) on Project, Task, Subtask, Comment, TimeLog. Hard delete elsewhere.

### 3.14 Realtime

Board updates via CBWire polling refresh. No WebSocket fan-out in v1. (The host does not currently ship WebSocket fan-out either; if it adopts one post-v1, PM revisits.)

### 3.15 API

REST API namespace at `/api/v1/pm/...`, served by a PM `api` entrypoint declared in `ModuleConfig.bx`. Every endpoint is registered in `ApiResourceRegistry@api` through the manifest's `apiResources` array so cbswagger and admin diagnostics surface the catalog automatically. JWT auth is the host's. PM does not implement its own auth.

### 3.16 Custom Fields (PM-local)

PM keeps **per-project** custom fields, distinct from the host's per-tenant custom fields. This is a deliberate deviation from the host's generalized `CustomFieldsService@tickets`.

Rationale: TesseraBX's existing custom fields are scoped per entity type and per tenant (e.g., all tickets in org X share the same field set). PM users need fields scoped to a specific project (a marketing project's "Channel" field is irrelevant to an engineering project). This is a different cardinality than the host pattern supports, hence PM owns its own `CustomField` and `CustomFieldValue` tables.

Open question: whether PM should *additionally* surface the host's per-tenant fields on tasks. Deferred to §13.

---

## 4. Conventions

### 4.1 Writing and Documentation

* **No em dashes anywhere.** Use commas, parentheses, or sentence breaks. Applies to code comments, READMEs, docs, commit messages, error strings, and UI copy.
* American English spelling.
* Markdown for all docs.

### 4.2 Code

* Conventional Commits (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`).
* BoxLang native end to end. Class files are `.bx`, view templates are `.bxm`. No `.cfc` or `.cfm` files in this module.
* Quick entities in `models/entities/`. Domain services in `models/services/`. Contract classes for cross-module consumers in `models/contracts/`. DTO mappers in `models/dtos/`. AI services in `models/ai/`. CBWire components in `wires/`.
* All visibility-scoped queries enforce visibility at the **service layer**, not in handlers. The tenant scope handles the org cut. The service layer applies Option C on top.
* Interceptors handle cross-cutting concerns (activity logging, mention detection, event announce). PM interceptors are declared in `ModuleConfig.bx` per the host's interceptor pattern.
* No business logic in handlers. Handlers orchestrate; services do the work.
* No SQL in handlers or views. All data access through Quick or qb in services.
* Cross-module access: PM calls host modules through their **service contracts** (e.g., `wirebox.getInstance( "TicketsService@tickets" )` typed against `ITicketsService`). PM never reaches into host entities directly.

### 4.3 Branching Strategy

**During the initial v1 build, all work commits directly to `main`.** No feature branches, no pull requests. The phase commit gate in §4.4 provides the review checkpoint; with a solo developer plus Claude Code, PR ceremony adds overhead without meaningful benefit.

**Post-v1.0.0, this changes.** Feature-branch-per-change with PRs into `main`, branch protection requiring CI pass and one approving review, and the same commit gate per §4.4. The transition happens at the `v1.0.0` release tag.

CI runs on every push to `main`. A red CI run after a commit means the phase is not yet closed and a fix-up commit is needed.

### 4.4 Phase Completion and Commit Gate

**Strict and non-negotiable.**

PM Claude Code does not commit during phase work. A phase is ready for commit only when all of the following are true:

1. All TestBox specs for the phase pass locally (PM specs run inside the host dev stack).
2. PM's `InstallSpec` is green: every manifest contribution the phase introduced lands in the right host registry.
3. Mike has reviewed the diff in detail.
4. Mike has manually tested any UI components introduced or modified in the phase.
5. Mike has given explicit written approval.

Until all five conditions are satisfied, PM Claude Code stays in the working state and makes no commits. When ready, Claude Code surfaces a phase summary with:

* File inventory.
* **Manifest deltas**: which `settings.tesserabx.<registry>` arrays grew, and what entries.
* Test results.
* Manual UI test checklist (for Mike to walk through).
* Any open questions or deferred items.

Mike then reviews. Once approved, Claude Code commits to `main` using Conventional Commits (one logical commit per area where reasonable) and pushes. CI runs against the new commits on `main`; a green CI run closes the phase.

### 4.5 Testing

* TestBox for everything. PM specs run inside the host dev stack (the host's `box run-script test:run` discovers PM specs under `modules/tesserabx-pm/tests/`).
* **InstallSpec is the CI gate.** It asserts every PM manifest contribution lands in the right host registry. Copy the shape from `sample-addons/example-sync/tests/specs/InstallSpec.bx`.
* Service tests cover business logic and visibility rules at the unit level. Visibility tests use fixtures for both account families plus the accountless case.
* Handler tests cover routes, permissions, and response shape at the integration level.
* CBWire component tests cover state transitions.
* Each phase concludes with passing tests before review begins.
* Migrations have up and down test coverage.

### 4.6 Migrations

* cfmigrations format. Live in `migrations/` at the PM module root.
* The host's `tasks/Migrate.bx` stager discovers PM migrations and copies them into `resources/database/migrations/` with a host-defined add-on prefix before running them. The host's `.gitignore` filters staged files via `*_addon-*_*.cfc`; the host's `EXTENSIONS.md` documents `_addon_<slug>_<original>.cfc`. The two disagree on hyphen-vs-underscore; verify the actual stager output at Phase 0 and reconcile (and consider filing a host doc fix).
* One migration per logical schema change.
* Sequentially numbered with the host's timestamp prefix (`YYYY_MM_DD_HHmmss_<name>.cfc`). Note the file extension: cfmigrations expects `.cfc` for migration files even in a BoxLang module; this matches the host convention.
* Always reversible (`down` implemented).
* No data migrations mixed with schema migrations.
* Every tenant-scoped table includes `organization_id` (`string( "organization_id", 36 )` with FK to `organizations` and `ON DELETE CASCADE`) from its first migration.

---

## 5. Module Layout

```
tesserabx-pm/
├── box.json
├── ModuleConfig.bx                      # settings.tesserabx manifest lives here
├── README.md
├── LICENSE
├── CHANGELOG.md
├── .github/workflows/test.yml
├── docs/
│   └── BUILD-PLAN.md
├── config/
│   ├── Router.bx
│   └── cbSecurity.bx                     # PM's module-level rules under both surfaces
├── handlers/
│   ├── Projects.bx
│   ├── Tasks.bx
│   ├── Subtasks.bx
│   ├── Boards.bx
│   ├── Comments.bx
│   ├── TimeLogs.bx
│   ├── Templates.bx
│   ├── CustomFields.bx
│   ├── Labels.bx
│   ├── admin/
│   │   ├── Connection.bx                 # /agent/admin/pm landing
│   │   └── Settings.bx
│   └── api/v1/
│       ├── Projects.bx
│       ├── Tasks.bx
│       ├── Subtasks.bx
│       ├── Comments.bx
│       └── TimeLogs.bx
├── models/
│   ├── entities/
│   │   ├── Project.bx
│   │   ├── ProjectMember.bx
│   │   ├── ProjectStatus.bx
│   │   ├── Task.bx
│   │   ├── Subtask.bx
│   │   ├── Comment.bx
│   │   ├── Watcher.bx
│   │   ├── Mention.bx
│   │   ├── ProjectEvent.bx
│   │   ├── TimeLog.bx
│   │   ├── Label.bx
│   │   ├── TaskLabel.bx
│   │   ├── CustomField.bx
│   │   ├── CustomFieldValue.bx
│   │   ├── TaskTicket.bx
│   │   ├── Attachment.bx
│   │   └── ProjectTemplate.bx
│   ├── services/
│   │   ├── ProjectService.bx
│   │   ├── TaskService.bx
│   │   ├── SubtaskService.bx
│   │   ├── BoardService.bx
│   │   ├── CommentService.bx
│   │   ├── WatcherService.bx
│   │   ├── MentionService.bx
│   │   ├── ProjectEventService.bx
│   │   ├── TimeTrackingService.bx
│   │   ├── LabelService.bx
│   │   ├── CustomFieldService.bx
│   │   ├── TaskTicketService.bx
│   │   ├── TemplateService.bx
│   │   ├── VisibilityService.bx
│   │   └── PriorityScoringService.bx
│   ├── ai/
│   │   ├── TaskEmbeddingConsumer.bx       # registered via embeddingConsumers manifest entry
│   │   ├── SimilarityService.bx           # calls AiMiddleware@ai.embed under the hood
│   │   ├── SummarizationService.bx        # calls AiMiddleware@ai.complete
│   │   └── SuggestionService.bx
│   ├── contracts/
│   │   ├── IProjectService.bx
│   │   ├── ITaskService.bx
│   │   └── ITaskTicketService.bx
│   ├── dtos/
│   │   ├── ProjectDto.bx
│   │   ├── TaskDto.bx
│   │   └── SubtaskDto.bx
│   └── automation/
│       ├── CreateTaskFromTicketExecutor.bx  # registered via automationActions
│       └── TaskFromBulkTicketsExecutor.bx
├── interceptors/
│   ├── ProjectEventLogger.bx
│   ├── MentionDetector.bx
│   ├── PmEventAnnouncer.bx               # builds canonical envelopes via EventPayloadBuilder@core
│   ├── PmTaskLifecycleListener.bx        # listens on onPmTaskStatusChanged for close-on-complete
│   └── EmbeddingUpdater.bx
├── wires/
│   ├── KanbanBoard.bx
│   ├── TaskCard.bx
│   ├── TaskDetail.bx
│   ├── TaskList.bx
│   ├── CalendarView.bx
│   ├── MyTasks.bx
│   ├── CommentThread.bx
│   ├── TimeLogger.bx
│   ├── TemplatePicker.bx
│   ├── LabelManager.bx
│   ├── CustomFieldBuilder.bx
│   ├── StatusColumnManager.bx
│   └── TicketDetailLinkedTasksPanel.bx   # mounted via ticketPanels manifest entry
├── views/
│   ├── projects/
│   ├── tasks/
│   ├── subtasks/
│   ├── boards/
│   ├── templates/
│   ├── customfields/
│   ├── admin/
│   ├── panels/                            # ticket panel partials
│   ├── widgets/                           # dashboard widget partials
│   └── api/
├── migrations/
├── resources/
│   ├── help/                              # markdown files referenced from helpPages manifest entries
│   ├── lang/
│   └── assets/
└── tests/
    ├── specs/
    │   ├── InstallSpec.bx                 # the CI gate
    │   ├── unit/
    │   ├── integration/
    │   └── wires/
    └── Application.bx
```

Layout notes:

* No top-level `Application.bx` at the module root; the module loads inside the host's `Application.bx`.
* `wires/` and `views/wires/` together follow the host's CBWire convention.
* Bulk views or partials for ticket panels live under `views/panels/` and are referenced by `partial` in the manifest.

---

## 6. Local Development Environment

### 6.1 Paths

| Purpose | Path |
| --- | --- |
| Host TesseraBX repo | `/Users/mrigsby/Data/BoxLang-Dev/TesseraBX/GIT/tesserabx` |
| PM module repo | `/Users/mrigsby/Data/BoxLang-Dev/TesseraBX/GIT/tesserabx-pm` |
| Remote module repo | <https://github.com/oistechnologies/tesserabx-pm> |
| Container bind-mount target | `/app/modules/tesserabx-pm` |

### 6.2 Docker Setup

PM uses the host's existing dev stack (`compose.yaml` + `compose.dev.yaml`, both in the host repo root). PM is bind-mounted into the host's `app` and `worker` containers via a **compose override**.

Add a `compose.override.yaml` in the host repo root. As of today the host's `.gitignore` does **not** exclude this filename, so Phase 0 includes a one-line PR to the host repo adding `compose.override.yaml` to `.gitignore`. Until that PR merges, add the line to the host repo's `.git/info/exclude` locally so the override is not tracked. Example override file:

```yaml
services:
  app:
    volumes:
      - /Users/mrigsby/Data/BoxLang-Dev/TesseraBX/GIT/tesserabx-pm:/app/modules/tesserabx-pm
  worker:
    volumes:
      - /Users/mrigsby/Data/BoxLang-Dev/TesseraBX/GIT/tesserabx-pm:/app/modules/tesserabx-pm
  scheduler:
    volumes:
      - /Users/mrigsby/Data/BoxLang-Dev/TesseraBX/GIT/tesserabx-pm:/app/modules/tesserabx-pm
```

The host's `app` image already includes BoxLang, ColdBox, and the migration tooling. The host's Postgres service already includes `pgvector`. The host's Redis already backs CacheBox and cbq. PM brings no infrastructure of its own.

### 6.3 Module Discovery

On boot, the host's `AddonDiscoveryInterceptor` finds PM via the `settings.tesserabx` manifest, validates `minCoreVersion` against the host's `appVersion`, and upserts a row into `addons`. The host's `appVersion` is read from `config/Coldbox.bx`; today it is `"0.0.1"`. PM declares `minCoreVersion : "0.0.1"` for the v1 build.

### 6.4 Database

PM shares the host's database. There is **one** database, multi-tenant by `organization_id`. PM does not provision or expect its own database. Test runs roll back per spec against the same database the host's specs use.

### 6.5 Common Commands

All commands run from the host repo root. PM does not run its own server.

| Task | Command |
| --- | --- |
| Bring up dev stack | `docker compose -f compose.yaml -f compose.dev.yaml up` |
| Stage PM migrations into host runner | `box run-script migrate:stage` |
| Run all pending migrations | `box run-script migrate:up` |
| Roll back last migration | `box run-script migrate:down` |
| Run full TestBox suite (PM specs included) | `box run-script test:run` |
| Reinit framework after ModuleConfig.bx changes | `box reinit` |

### 6.6 Reinit Triggers

After changes to PM's `ModuleConfig.bx`, `config/Router.bx`, `config/cbSecurity.bx`, or the manifest, reinit the framework. Handler, service, view, wire, and migration changes do not require reinit when the host runs in development mode.

### 6.7 CommandBox Version

Inherited from the host's `box.json` engines. PM does not pin a separate version.

---

## 7. Entity Model

Seventeen entities defined here (an eighteenth, `SavedFilter`, is added in Phase 10). Every one is BoxLang native, and (where tenant-scoped) extends `tesserabx.modules.contacts.models.TesseraBXEntity` with `applyGlobalScopes` calling `TenantScope@contacts`.

Polymorphic actor columns follow the convention `<role>_type` + `<role>_id`, where `<role>_type` is one of `'agent'`, `'contact'`, or `'system'` and `<role>_id` is a UUID. Foreign keys are not enforced on polymorphic columns; integrity is enforced at the service layer.

### 7.1 Core Hierarchy

**Project**
* `id` (uuid, pk), `organization_id` (uuid, not null, FK)
* `name`, `description`
* `visibility_scope` (enum: `all_org_members`, `specific_members`)
* `lifecycle_status` (enum: `active`, `archived`, `completed`)
* `start_date`, `end_date`
* `time_tracking_enabled` (boolean)
* `is_template` (boolean), `template_source_id` (nullable, FK to `ProjectTemplate`)
* `embedding` (vector, populated by the embedding consumer)
* `created_by_type`, `created_by_id`, `updated_by_type`, `updated_by_id`
* timestamps, `deleted_at`

**Task**
* `id`, `project_id`, `organization_id` (denormalized for direct tenant scoping), `status_id`
* `title`, `description`
* `priority` (enum: `low`, `medium`, `high`, `urgent`)
* `assignee_type` (nullable, `'agent'` or `'contact'`), `assignee_id` (nullable)
* `due_date`, `start_date`
* `estimated_hours` (decimal, nullable)
* `is_client_visible` (boolean, default false)
* `sort_order` (integer, within status column)
* `completed_at` (nullable)
* `embedding` (vector)
* `created_by_type`, `created_by_id`
* timestamps, `deleted_at`

**Subtask**
* `id`, `task_id`, `organization_id` (denormalized)
* `title`, `description`
* `assignee_type`, `assignee_id` (nullable)
* `due_date`, `estimated_hours`
* `is_completed` (boolean), `completed_at`
* `sort_order`
* `created_by_type`, `created_by_id`
* timestamps, `deleted_at`

### 7.2 Access and Configuration

**ProjectMember** records explicit membership when `Project.visibility_scope = 'specific_members'`.
* `id`, `project_id`, `organization_id` (denormalized)
* `member_type`, `member_id` (polymorphic across Agent and Contact)
* `role` (enum: `owner`, `manager`, `contributor`, `viewer`)
* `added_by_type`, `added_by_id`, `added_at`

**ProjectStatus** is a per-project kanban column.
* `id`, `project_id`, `organization_id` (denormalized)
* `name`, `color`, `sort_order`
* `is_default` (boolean), `is_completed` (boolean, marks terminal status)

### 7.3 Engagement and History

**Comment** is polymorphic across Project, Task, Subtask.
* `id`, `commentable_type`, `commentable_id`, `organization_id` (denormalized)
* `parent_comment_id` (nullable, for threading)
* `author_type`, `author_id`
* `body`, `is_internal`
* timestamps, `deleted_at`

**Watcher** tracks follows.
* `id`, `watchable_type`, `watchable_id`, `organization_id` (denormalized)
* `watcher_type`, `watcher_id`
* `auto_added` (boolean)
* timestamps

**Mention** records @mentions resolved at comment save time.
* `id`, `comment_id`, `organization_id` (denormalized)
* `mentioned_user_type`, `mentioned_user_id`
* `notified_at`, `read_at`

**ProjectEvent** captures the project's domain timeline (parallel to `TicketEvent` in the host).
* `id`, `project_id`, `organization_id` (denormalized)
* `subject_type`, `subject_id`
* `actor_type`, `actor_id`
* `action` (string)
* `changes` (jsonb)
* `created_at`

### 7.4 Time Tracking

**TimeLog** polymorphic across Task and Subtask.
* `id`, `loggable_type`, `loggable_id`, `organization_id` (denormalized)
* `user_type`, `user_id`
* `hours` (decimal), `logged_at`, `description`
* `is_billable` (boolean)
* timestamps, `deleted_at`

### 7.5 Categorization

**Label** per project.
* `id`, `project_id`, `organization_id` (denormalized)
* `name`, `color`, `sort_order`

**TaskLabel** join.
* `id`, `task_id`, `label_id`

**CustomField** per project (PM-local; see §3.16).
* `id`, `project_id`, `organization_id` (denormalized)
* `name`, `field_type` (enum: text, number, date, dropdown, multiselect, checkbox, url)
* `options` (jsonb, for dropdowns)
* `is_required`, `applies_to` (enum: task, subtask, both)
* `sort_order`

**CustomFieldValue** polymorphic.
* `id`, `custom_field_id`, `valuable_type`, `valuable_id`, `organization_id` (denormalized)
* `value` (text, normalized for the field type)

### 7.6 Integration

**TaskTicket** bidirectional join with the host `tickets` module's `Ticket`.
* `id`, `task_id`, `ticket_id`, `organization_id` (denormalized; nullable when the ticket is accountless)
* `link_type` (enum: `related`, `blocks`, `fixes`)
* `linked_by_type`, `linked_by_id`
* `linked_at`

Note: `ticket_id` is a UUID FK into the host `tickets` table. PM does not own the ticket. The FK has `ON DELETE CASCADE` so deleting a ticket removes its link rows; the task remains.

**Attachment** polymorphic across Task, Subtask, Comment. Stored via the host's CBFS provider.
* `id`, `attachable_type`, `attachable_id`, `organization_id` (denormalized)
* `file_path` (CBFS-relative key)
* `file_name`, `file_size`, `mime_type`
* `uploaded_by_type`, `uploaded_by_id`
* timestamps

### 7.7 Templates

**ProjectTemplate**
* `id`, `organization_id` (nullable for shared global templates)
* `name`, `description`
* `structure` (jsonb snapshot of statuses, labels, custom fields, tasks with relative date offsets, subtasks)
* `created_by_type`, `created_by_id`
* `is_shared` (boolean)
* timestamps

### 7.8 Entities Explicitly Not Owned by PM

PM does **not** own these. The host owns them, and PM consumes them through service contracts:

* `Organization`, `Office`, `Contact` (host `contacts` module)
* `Agent` (host `agent` module)
* `Ticket`, `TicketMessage`, `TicketEvent`, `Tag` (host `tickets` module)
* `AuditEvent` (host `audit` module)
* `Notification`, `NotificationPreference` (host `notifications` module)
* `AiInteraction` (host `ai` module)

---

## 8. Manifest Contract

PM's `ModuleConfig.bx` carries a `settings.tesserabx` block. The block grows phase by phase; the full Phase 13 shape is summarized here. Each phase in §9 names the manifest deltas it introduces.

```boxlang
// Sketch only; actual values are filled in across phases.
settings = {
    tesserabx : {
        addonId        : "tesserabx-pm",
        displayName    : "Project Management",
        version        : "0.0.1",
        minCoreVersion : "0.0.1",
        contributesTo  : [ /* enumerated below */ ],
        requiresAi     : false,

        permissions             : [ /* Phase 1 */ ],
        roles                   : [ /* Phase 1 */ ],
        navigation              : [ /* Phase 1, expanded through Phase 11 */ ],
        adminPages              : [ /* Phase 1, expanded */ ],
        settings                : [ /* Phase 1 */ ],
        auditEvents             : [ /* Phase 4 */ ],
        ticketPanels            : [ /* Phase 8 */ ],
        dashboardWidgets        : [ /* Phases 3, 5, 12 */ ],
        apiResources            : [ /* Phases 2 onward */ ],
        webhookEvents           : [ /* Phases 4, 8 */ ],
        notificationTemplates   : [ /* Phase 9 */ ],
        helpSections            : [ /* Phase 0 + later */ ],
        helpPages               : [ /* per phase */ ],
        automationActions       : [ /* Phase 8 */ ],
        automationTriggers      : [ /* Phase 8 */ ],
        aiFeatures              : [ /* Phase 12 */ ],
        embeddingConsumers      : [ /* Phase 12 */ ],
        assets                  : [ /* phases that ship CSS/JS */ ]
    }
};
```

PM does **not** contribute to:

* `channelAdapters` (not a transport for inbound messages)
* `notificationChannels` (host's three are sufficient)
* `entityExtensionTables` on host entities (PM owns its own tables instead)

---

## 9. Build Phases

Each phase has a goal, a deliverables list, an explicit list of manifest deltas, and acceptance criteria. A phase is complete only when acceptance passes, tests are green (including PM's `InstallSpec`), **and Mike approves per §4.4**.

### Phase 0: Scaffold the Add-On

**Goal:** An installable, empty add-on that the host discovers cleanly and that ships a passing `InstallSpec`.

**Deliverables:**
* GitHub repo at <https://github.com/oistechnologies/tesserabx-pm> initialized with `.gitignore`, `LICENSE` (Apache 2.0), `README.md`, `CHANGELOG.md`.
* `box.json` with dependencies on coldbox, quick, qb, cbwire, cbsecurity, cbfs, cfmigrations (matched to the host's pinned versions where reasonable).
* `ModuleConfig.bx` with: `entryPoint = "tesserabx-pm"`, `modelNamespace = "tesserabx-pm"`, `cfmapping = "tesserabx.modules.tesserabx-pm"`, `dependencies = [ "core", "contacts", "audit", "notifications", "ai", "api", "help" ]`, and a `settings.tesserabx` block with `addonId`, `displayName`, `version`, `minCoreVersion : "0.0.1"`, `requiresAi : false`. Empty arrays for every registry contribution.
* `config/Router.bx` with a placeholder route `/agent/pm` rendering a "PM installed" page.
* Full folder structure per §5 (empty directories OK).
* `tests/specs/InstallSpec.bx` modeled on `sample-addons/example-sync/tests/specs/InstallSpec.bx`. It currently asserts only that `AddonRegistryService@core` (or the host's equivalent lookup) reports `tesserabx-pm` as a discovered, compatible add-on. Registry-walking probes are added as registries are exercised in later phases.
* GitHub Actions workflow that:
  1. Checks out the host repo at a pinned reference. Until the host begins tagging releases (its `appVersion` is `0.0.1` and no tags exist yet), this is a pinned commit SHA on `main`; switch to a pinned tag once the host adopts them.
  2. Bind-mounts PM into the host via a compose override (CI version).
  3. Brings up Postgres (with pgvector) and Redis.
  4. Runs `box run-script migrate:up` and `box run-script test:run`.
  5. Reports the InstallSpec result on the commit.
* `compose.override.yaml.example` in PM repo with the bind-mount template a developer copies into the host repo root.
* One-line PR to the host repo (`tesserabx`) adding `compose.override.yaml` to its `.gitignore` so developer overrides do not get tracked.

**Manifest deltas:** the initial `settings.tesserabx` block (above), nothing else.

**Acceptance:**
* Host dev stack with PM bind-mounted boots cleanly; `/agent/pm` returns the placeholder.
* Host `/agent/admin/addons` lists PM with `compatible : true`.
* PM `InstallSpec` passes locally and in CI.
* Mike reviews and approves.

### Phase 1: Entities, Migrations, Permissions, Roles, Navigation Skeleton

**Goal:** Schema is in place; PM appears in nav and admin; CRUD is not built yet.

**Deliverables:**
* Migrations for all 17 PM tables defined in §7, in dependency order. Every tenant-scoped table includes `organization_id` from its first migration with an FK to `organizations` and `ON DELETE CASCADE`.
* A migration that seeds the default `ProjectStatus` template constants used by `ProjectService` (Backlog, To Do, In Progress, In Review, Done).
* Quick entity classes for each table. Tenant-scoped entities extend `TesseraBXEntity` and apply `TenantScope@contacts`. Relationships use `belongsTo`, `hasMany`, `belongsToMany`, `morphTo`, `morphMany` as appropriate. Polymorphic actor columns are wired explicitly.
* Unit tests instantiating each entity, asserting tenant scope applies, asserting relationships return expected types.
* Manifest declarations for permissions and roles (full list).
* Manifest declarations for the top-level navigation entries on `agent/main` and `portal/main`.
* A single admin landing card at `/agent/admin/pm`.

**Manifest deltas:**

```boxlang
permissions : [
    { id : "pm.view",         label : "View PM projects and tasks" },
    { id : "pm.create",       label : "Create PM projects and tasks" },
    { id : "pm.edit",         label : "Edit PM projects and tasks" },
    { id : "pm.delete",       label : "Delete PM projects and tasks" },
    { id : "pm.assign-client",label : "Assign tasks to client users" },
    { id : "pm.admin",        label : "Administer PM (statuses, fields, templates)" }
],
roles : [
    { id : "pm-admin",        surface : "agent",   permissions : [ "pm.view", "pm.create", "pm.edit", "pm.delete", "pm.assign-client", "pm.admin" ] },
    { id : "pm-manager",      surface : "agent",   permissions : [ "pm.view", "pm.create", "pm.edit", "pm.delete", "pm.assign-client" ] },
    { id : "pm-contributor",  surface : "agent",   permissions : [ "pm.view", "pm.create", "pm.edit" ] },
    { id : "pm-viewer",       surface : "agent",   permissions : [ "pm.view" ] },
    { id : "pm-client-viewer",      surface : "contact", permissions : [ "pm.view" ] },
    { id : "pm-client-contributor", surface : "contact", permissions : [ "pm.view", "pm.edit" ] }
],
navigation : [
    { id : "pm.agent.main",   surface : "agent",   menu : "main",   label : "Projects", route : "/agent/pm", icon : "bi bi-kanban", sortWeight : 200, requiresAuth : true, requiredPermission : "pm.view" },
    { id : "pm.portal.main",  surface : "portal",  menu : "main",   label : "Projects", route : "/pm",       icon : "bi bi-kanban", sortWeight : 200, requiresAuth : true, requiredPermission : "pm.view" }
],
adminPages : [
    { id : "pm.admin.landing", title : "Project Management", description : "Configure PM templates, custom fields, and per-tenant settings.", route : "/agent/admin/pm", icon : "bi bi-kanban", sortWeight : 600, requiredPermission : "pm.admin" }
],
settings : [
    { key : "pm.default-template-id", type : "string", label : "Default project template", description : "Optional template to apply on project creation.", default : "", secret : false, perTenant : true }
]
```

**Acceptance:**
* `box run-script migrate:up` and `migrate:down` succeed.
* Every PM entity has a passing tenant-scope test.
* PM permissions and roles appear in `PermissionRegistry@agent` and `RoleRegistry@agent` via the InstallSpec.
* "Projects" nav appears in `/agent` for users with `pm.view`, hidden otherwise.
* "Project Management" card appears on `/agent/admin` for users with `pm.admin`.
* Mike reviews and approves.

### Phase 2: Project, Task, Subtask CRUD and Visibility

**Goal:** Agents can manage projects, tasks, and subtasks via basic AdminLTE views. Clients can read within Option C.

**Deliverables:**
* `ProjectService`, `TaskService`, `SubtaskService` with create, update, soft delete, restore, archive (project only).
* `Projects.bx`, `Tasks.bx`, `Subtasks.bx` handlers under `/agent/pm/...`.
* `VisibilityService` enforcing Option C on top of the tenant scope. All read paths route through it.
* Contract classes: `IProjectService`, `ITaskService`, `ISubtaskService` under `models/contracts/` for cross-module callers.
* DTO mappers: `ProjectDto`, `TaskDto`, `SubtaskDto` under `models/dtos/`.
* Custom status management UI (CRUD on `ProjectStatus`) at `/agent/pm/projects/:id/statuses`.
* Org and visibility-scope selection on project create.
* `cbSecurity.bx` module-level rules under `/agent/pm/*` (agent firewall) and `/pm/*` (portal firewall).
* Unit tests for services (visibility rules tested with fixtures for both account families).
* Integration tests for handlers and permissions.
* REST API handlers under `/api/v1/pm/...` for projects, tasks, subtasks (CRUD + list).

**Manifest deltas:**

```boxlang
apiResources : [
    { id : "pm.projects.list",     method : "GET",    path : "/api/v1/pm/projects",          version : "v1", handler : "api.v1.Projects",  action : "index",   summary : "List PM projects",     requiresAuth : true, requiredPermission : "pm.view" },
    { id : "pm.projects.show",     method : "GET",    path : "/api/v1/pm/projects/:id",      version : "v1", handler : "api.v1.Projects",  action : "show",    summary : "Show a PM project",    requiresAuth : true, requiredPermission : "pm.view" },
    { id : "pm.projects.create",   method : "POST",   path : "/api/v1/pm/projects",          version : "v1", handler : "api.v1.Projects",  action : "create",  summary : "Create a PM project",  requiresAuth : true, requiredPermission : "pm.create" },
    { id : "pm.projects.update",   method : "PATCH",  path : "/api/v1/pm/projects/:id",      version : "v1", handler : "api.v1.Projects",  action : "update",  summary : "Update a PM project",  requiresAuth : true, requiredPermission : "pm.edit" },
    { id : "pm.projects.archive",  method : "POST",   path : "/api/v1/pm/projects/:id/archive", version : "v1", handler : "api.v1.Projects", action : "archive", summary : "Archive a PM project", requiresAuth : true, requiredPermission : "pm.edit" },
    /* tasks, subtasks: index/show/create/update/delete */
]
```

**Acceptance:**
* Agent creates a project, assigns an org, picks visibility scope.
* Agent adds tasks and subtasks, assigns them to agents and contacts.
* Contact attempting to assign a task to another contact is denied (`pm.assign-client` is agent-only).
* Contact sees tasks per Option C from their org login.
* REST endpoints round-trip through DTOs.
* Mike manually walks the UI and approves.

### Phase 3: Kanban Board

**Goal:** Drag-and-drop kanban with CBWire.

**Deliverables:**
* `BoardService` grouping tasks by status, applying filters, returning board state.
* `KanbanBoard` CBWire component rendering columns and cards.
* `TaskCard` CBWire component with title, assignee chip (agent or contact), due date, priority indicator, label chips, linked-ticket count.
* Drag-and-drop reordering with `sort_order` and `status_id` persistence (SortableJS or equivalent, served as a PM asset).
* Quick-add task input per column.
* `TaskDetail` CBWire flyout or modal with inline editing.
* Filters: assignee, label, priority, search query.
* Status column management UI accessible from the board.

**Manifest deltas:**

```boxlang
dashboardWidgets : [
    { id : "pm.recentActivity", title : "Recent project activity", partial : "widgets/recent_activity", module : "tesserabx-pm", dataProvider : "BoardService@tesserabx-pm", dataMethod : "recentActivityForAgent", defaultGridSize : "col-12 col-md-6", sortWeight : 500, requiredPermission : "pm.view", zone : "agent-home" }
],
assets : [
    { kind : "js",  surface : "agent", src  : "/modules/tesserabx-pm/resources/js/board.js",  sortWeight : 500, defer : true },
    { kind : "css", surface : "agent", href : "/modules/tesserabx-pm/resources/css/board.css", sortWeight : 500 }
]
```

**Acceptance:**
* Open a project; the kanban populates with tasks.
* Drag tasks between columns; status persists.
* Drag tasks within a column; sort order persists.
* Click a task; details open and inline edits persist.
* Filter by assignee; only matching tasks remain visible.
* Mike manually walks the UI and approves.

### Phase 4: Comments, Watchers, Mentions, Project Event Log

**Goal:** Collaboration features, with both account families as first-class actors.

**Deliverables:**
* `CommentService` with create, update, soft delete, list scoped by `is_internal` and viewer account type.
* `CommentThread` CBWire component with threaded display and optimistic UI.
* `MentionService` parsing `@username` references in comment bodies. Supports both `@agent:slug` and `@contact:slug` mention forms; the autocomplete dropdown disambiguates.
* `WatcherService` with auto-watch on assignment, auto-watch on comment, manual toggle.
* `ProjectEventLogger` interceptor listening to PM entity create/update/delete events.
* `PmEventAnnouncer` interceptor that emits canonical envelopes via `EventPayloadBuilder@core` for every PM-relevant event.
* Project event feed view; per-task event view; both filterable by actor type.
* `is_internal` toggle on agent comment composer; absent and forced false on contact composer.

**Manifest deltas:**

```boxlang
auditEvents : [
    { type : "tesserabx-pm.project_created",  label : "PM: project created",  severity : "info" },
    { type : "tesserabx-pm.project_archived", label : "PM: project archived", severity : "info" },
    { type : "tesserabx-pm.project_deleted",  label : "PM: project deleted",  severity : "warning" },
    { type : "tesserabx-pm.task_assigned_to_contact", label : "PM: task assigned to a contact", severity : "info" },
    { type : "tesserabx-pm.template_applied", label : "PM: template applied", severity : "info" }
],
webhookEvents : [
    { key : "tesserabx-pm.project_created",   label : "PM project created" },
    { key : "tesserabx-pm.task_created",      label : "PM task created" },
    { key : "tesserabx-pm.task_assigned",     label : "PM task assigned" },
    { key : "tesserabx-pm.task_status_changed", label : "PM task status changed" },
    { key : "tesserabx-pm.comment_added",     label : "PM comment added" },
    { key : "tesserabx-pm.task_completed",    label : "PM task completed" }
]
```

**PM-announced events** (canonical envelope, all async unless noted):

* `onPmProjectCreated`, `onPmProjectArchived`
* `onPmTaskCreated`, `onPmTaskUpdated`, `onPmTaskAssigned`, `onPmTaskStatusChanged` (sync), `onPmTaskCompleted`
* `onPmSubtaskCreated`, `onPmSubtaskCompleted`
* `onPmCommentAdded`, `onPmMentioned`

**Acceptance:**
* Agent and contact can both post comments; agent default is internal; contact is always external.
* @mention an agent and a contact; both rows land in `Mention` with the right polymorphic type.
* Watch a task; auto-watch fires on assignment.
* Project event feed shows entity changes with actor type, actor id, and timestamp.
* Contact sees only non-internal comments.
* PM-announced events appear in the host interception log with the canonical envelope shape.
* PM compliance events appear in `/agent/admin/audit` with `source = "tesserabx-pm"`.
* Mike manually walks the UI and approves.

### Phase 5: Time Tracking

**Goal:** Log hours against tasks and subtasks, with rollups.

**Deliverables:**
* `TimeTrackingService` with create, update, delete, list, rollup queries.
* `TimeLogger` CBWire component embedded on Task and Subtask detail.
* Estimate input fields on Task and Subtask.
* Per-project `time_tracking_enabled` toggle; UI hides time controls when disabled.
* Reports: time by user (agent or contact), time by project, time by date range, billable vs non-billable.
* Billable filter on reports.

**Manifest deltas:**

```boxlang
dashboardWidgets : [
    { id : "pm.timeThisWeek", title : "Time logged this week", partial : "widgets/time_this_week", module : "tesserabx-pm", dataProvider : "TimeTrackingService@tesserabx-pm", dataMethod : "weeklyForAgent", defaultGridSize : "col-12 col-md-4", sortWeight : 600, requiredPermission : "pm.view", zone : "agent-home" }
]
```

**Acceptance:**
* Enable time tracking on a project; time controls appear on its tasks.
* Log hours on a subtask; they roll up to the parent task and to the project.
* Run a time report by user; totals are correct.
* Disable time tracking; controls disappear.
* Mike manually walks the UI and approves.

### Phase 6: Labels and Per-Project Custom Fields

**Goal:** Flexible task metadata. The rationale for PM-local per-project custom fields lives in §3.16.

**Deliverables:**
* `LabelService` CRUD scoped per project. `LabelManager` CBWire component.
* Label picker on task detail with multi-select.
* `CustomFieldService` with CRUD on field definitions and value storage.
* `CustomFieldBuilder` CBWire component for defining fields per project.
* Custom field rendering on task and subtask detail, dynamic by `field_type`.
* Validation per field type (number range, date format, required, dropdown options).
* Filtering by label and by custom field value on the board view. (List and calendar view filter support lands with those views in Phase 10.)

**Manifest deltas:** none (labels and custom fields are PM-internal CRUD; no new registries touched).

**Acceptance:**
* Create a label; apply it to tasks; filter the board by it.
* Create a custom field of each type; set values on tasks; filter by them.
* Required custom fields enforced on task create and update.
* Mike manually walks the UI and approves.

### Phase 7: Templates

**Goal:** Repeatable project structures.

**Deliverables:**
* `TemplateService` with snapshot (from existing project), hydration (to new project), CRUD on templates.
* `TemplatePicker` CBWire component in the new-project flow.
* Template management UI (list, create from project, edit, delete) at `/agent/admin/pm/templates`.
* Relative date offsets in the structure, resolved at hydration using the new project's start date.
* Statuses, labels, custom fields, tasks, and subtasks all hydrated.
* Hydration writes a `tesserabx-pm.template_applied` audit event.

**Manifest deltas:**

```boxlang
adminPages : [
    { id : "pm.admin.templates", title : "PM Templates", description : "Manage project templates.", route : "/agent/admin/pm/templates", icon : "bi bi-file-earmark-text", sortWeight : 610, requiredPermission : "pm.admin" }
]
```

**Acceptance:**
* Create a template from an existing project.
* Create a new project from the template; statuses, labels, custom fields recreated.
* Tasks and subtasks created with offset dates.
* Edit a template; source project unchanged.
* Mike manually walks the UI and approves.

### Phase 8: Bidirectional Ticket Integration

**Goal:** PM tasks and host tickets are mutually aware through the host extension contracts.

**Deliverables:**
* `TaskTicketService` with link, unlink, list.
* "Linked tasks" ticket panel registered via `ticketPanels`. Partial under `views/panels/linked_tasks.bxm`.
* "Linked tickets" panel on PM task detail, populated from `TicketsService@tickets` through `ITicketsService`.
* `CreateTaskFromTicketExecutor` registered via `automationActions`. Action available in the host's automation rules editor.
* `TaskFromBulkTicketsExecutor` registered as an automation action (for bulk runs) plus optional UI bulk button if the host's bulk-action registry is available; otherwise the bulk path is the automation route only.
* `PmTaskLifecycleListener` interceptor listening on `onPmTaskStatusChanged` for the close-on-complete prompt. When a PM task that has linked tickets moves to a status with `is_completed = true`, prompt the agent to close linked tickets via `TicketsService@tickets`.
* SLA indicator on `TaskCard` driven by the host `sla` module's service.

**Manifest deltas:**

```boxlang
ticketPanels : [
    { id : "pm.linkedTasks", position : "right", label : "Linked PM tasks", partial : "panels/linked_tasks", module : "tesserabx-pm", sortWeight : 500, requiredPermission : "pm.view", defaultCollapsed : false }
],
automationActions : [
    { id : "tesserabx-pm.createTaskFromTicket", label : "Create a PM task from this ticket", description : "Creates a new PM task linked to the triggering ticket.", executor : "CreateTaskFromTicketExecutor@tesserabx-pm", parameterSchema : [ { name : "projectId", label : "Project", type : "select", required : true } ] },
    { id : "tesserabx-pm.createTaskFromBulkTickets", label : "Create one PM task linking these tickets", description : "Bulk path; creates a single PM task and links every selected ticket.", executor : "TaskFromBulkTicketsExecutor@tesserabx-pm", parameterSchema : [ { name : "projectId", label : "Project", type : "select", required : true } ] }
],
webhookEvents : [
    { key : "tesserabx-pm.ticket_linked",   label : "Ticket linked to a PM task" },
    { key : "tesserabx-pm.ticket_unlinked", label : "Ticket unlinked from a PM task" }
]
```

**Acceptance:**
* From a ticket detail, the automation "Create a PM task from this ticket" creates a task and records the link.
* The ticket detail's right column shows the "Linked PM tasks" panel.
* The PM task detail shows linked tickets with statuses and SLAs.
* Completing a PM task with linked tickets prompts to close them; accepting closes them.
* Mike manually walks the UI and approves.

### Phase 9: Notification Templates and Event Wiring

**Goal:** Every PM event the user cares about delivers through the host `notifications` module.

**Deliverables:**
* `notificationTemplates` manifest declarations for every PM event x channel x recipient-type tuple (in-app and email at minimum; slack if a slack channel is registered in the host).
* Email content in the templates uses placeholders consistent with the host's existing notification templates.
* Scheduled tasks (under the host scheduler) that fire `onPmTaskDueSoon` and `onPmTaskOverdue` async events, with notification templates declared for each.
* Manual verification: user notification preferences UI in the host correctly lists the PM event types.

**Manifest deltas:**

```boxlang
notificationTemplates : [
    { eventKey : "tesserabx-pm.task_assigned",       channel : "inapp", recipientType : "agent",   titleTemplate : "{{actorLabel}} assigned you {{taskTitle}}",        bodyTemplate : "Project {{projectName}}, due {{dueDate}}.", linkTemplate : "{{appBaseUrl}}/agent/pm/tasks/{{taskId}}",  placeholders : [ "actorLabel", "taskTitle", "projectName", "dueDate", "taskId" ] },
    { eventKey : "tesserabx-pm.task_assigned",       channel : "email", recipientType : "agent",   titleTemplate : "[PM] {{taskTitle}} assigned to you",               bodyTemplate : "{{actorLabel}} assigned you the task {{taskTitle}} in project {{projectName}}.", linkTemplate : "{{appBaseUrl}}/agent/pm/tasks/{{taskId}}", placeholders : [ "actorLabel", "taskTitle", "projectName", "taskId" ] },
    { eventKey : "tesserabx-pm.task_assigned",       channel : "inapp", recipientType : "contact", titleTemplate : "You have a new task: {{taskTitle}}",               bodyTemplate : "Project {{projectName}}, due {{dueDate}}.", linkTemplate : "{{appBaseUrl}}/pm/tasks/{{taskId}}",         placeholders : [ "taskTitle", "projectName", "dueDate", "taskId" ] },
    /* one entry per (event, channel, recipientType) combination */
]
```

**Acceptance:**
* Assigning a task to an agent produces an in-app notification and an email (if the agent's preference allows email).
* Assigning a task to a contact does the same on the contact side.
* @mention produces a notification.
* Watcher receives a notification on watched-task changes.
* Due-soon and overdue scheduled tasks fire correctly and deliver.
* Mike manually walks the preference UI and approves.

### Phase 10: Views Beyond Kanban

**Goal:** Multiple perspectives on the same data.

**Deliverables:**
* `TaskList` CBWire: sortable table with column visibility toggles, inline editing where safe.
* `CalendarView` CBWire: monthly grid with tasks placed by due date, click to open detail.
* `MyTasks` CBWire: cross-project view for the current viewer, grouped by project or by due date. Works for both agents and contacts.
* View switcher in the project header (Board, List, Calendar).
* Saved filters per view per user, stored in a PM-owned `SavedFilter` entity (added in this phase).

**Manifest deltas:** none.

**Acceptance:**
* Switch between Board, List, Calendar on a project.
* My Tasks shows tasks from all accessible projects.
* Save a filter; reload; filter still applied.
* Mike manually walks the UI and approves.

### Phase 11: Client Portal Integration

**Goal:** Contact-facing PM views on the portal surface.

**Deliverables:**
* Client project list at `/pm` showing projects in the contact's organizations.
* Client project detail with visibility-scoped task list per Option C.
* Client task detail showing non-internal comments only.
* Client comment composer forces `is_internal = false`.
* "Make visible to client" toggle on task detail, gated to `pm.edit` (agent).
* Notification emails to contacts branded through the host's client-portal templates.
* Contacts cannot edit task structure, status, or assignment unless they hold `pm.edit` (i.e., the `pm-client-contributor` role).

**Manifest deltas:** (any portal-specific nav entries already declared in Phase 1; this phase confirms the routing).

**Acceptance:**
* Log into the portal; see projects for the contact's orgs.
* Tasks visible per Option C.
* Post a comment; it appears for agents and for other contacts in the same org.
* Toggle `is_client_visible` as agent; contact sees the task appear.
* Mike manually walks the portal UI and approves.

### Phase 12: AI Features Through the Host Middleware

**Goal:** AI augmentation, gated on `AI_ENABLED`.

**Deliverables:**
* `TaskEmbeddingConsumer` (in `models/ai/`) registered via `embeddingConsumers`. Implements `getTextForEmbedding(taskId)`, `saveEmbedding(taskId, vector)`, `listEntitiesNeedingIndex()`.
* `SimilarityService` calling `AiMiddleware@ai.embed` to embed search input and qb to query nearest-neighbors by cosine distance.
* "Related Tasks" panel on task detail. `requiresAi : true`.
* "Find similar tasks" suggestion at task create and ticket-to-task conversion. `requiresAi : true`.
* `SummarizationService` calling `AiMiddleware@ai.complete` with `feature : "tesserabx-pm.summarize-thread"`.
* "Summarize this thread" action on `CommentThread`. `requiresAi : true`.
* `SuggestionService` for assignee and label suggestions based on historical patterns. Returns empty when data is sparse. `requiresAi : true`.
* `PriorityScoringService` (deterministic; works without AI). Drives a "My Recommended Next Task" dashboard widget. The widget renders the score without AI; an "Explain" button shows an AI-generated explanation gated on `AI_ENABLED`.
* Backfill command (`box task run tasks/EmbedBacklog.bx`) to populate embeddings for existing tasks.

**Manifest deltas:**

```boxlang
aiFeatures : [
    { id : "tesserabx-pm.summarize-thread",  label : "Summarize a PM comment thread", description : "Generates a short summary of a comment thread on a project or task.",  defaultSystemPrompt : "You write concise, neutral summaries of project conversations.", defaultModel : "", kind : "completion" },
    { id : "tesserabx-pm.suggest-assignee",  label : "Suggest a task assignee",       description : "Returns a ranked list of suggested assignees based on history.",         defaultSystemPrompt : "You suggest the most appropriate assignee from the given context.", defaultModel : "", kind : "completion" },
    { id : "tesserabx-pm.explain-priority",  label : "Explain task priority score",   description : "Generates a one-paragraph rationale for a deterministic priority score.", defaultSystemPrompt : "You explain priority scoring in plain English.", defaultModel : "", kind : "completion" }
],
embeddingConsumers : [
    { id : "tesserabx-pm.task", label : "PM tasks", description : "Indexes task titles and descriptions for semantic search.", feature : "tesserabx-pm.task-embed", mapping : "TaskEmbeddingConsumer@tesserabx-pm", dimension : 1536 }
],
dashboardWidgets : [
    { id : "pm.recommendedNextTask", title : "My recommended next task", partial : "widgets/recommended_next_task", module : "tesserabx-pm", dataProvider : "PriorityScoringService@tesserabx-pm", dataMethod : "topForAgent", defaultGridSize : "col-12 col-md-6", sortWeight : 700, requiredPermission : "pm.view", zone : "agent-home" }
]
```

**Acceptance:**
* Create a task; an embedding is generated when `AI_ENABLED=true`. When off, the consumer no-ops.
* Run the backfill; existing tasks gain embeddings.
* Related Tasks panel populates; hidden entirely when AI is off.
* Summarize a long comment thread; coherent summary returned; button absent when AI is off.
* Assignee and label suggestions populate once enough data exists.
* "My recommended next task" widget renders deterministic scores at all times; "Explain" button visible only when AI is on.
* Mike manually walks the UI in both `AI_ENABLED=true` and `false` states and approves.

### Phase 13: Polish, Tests, and Release

**Goal:** Production-ready add-on.

**Deliverables:**
* Comprehensive test coverage: services, handlers, CBWire components, migrations, every manifest contribution covered by InstallSpec.
* Performance pass: indexes verified on all foreign keys and common filters, N+1 queries eliminated, board pagination above a threshold per project.
* Accessibility pass on AdminLTE views: keyboard navigation, ARIA labels, contrast.
* Documentation: `README.md` (install, configuration, link to host's EXTENSIONS.md), `docs/USAGE.md` (feature walkthrough), `docs/API.md` (REST endpoint reference).
* ForgeBox publishing workflow (`box publish`).
* Semantic versioning; tag `v1.0.0`.
* **Transition to feature-branch workflow**: at v1.0.0 tag, enable branch protection on `main` (require CI pass, require one approving review). All post-v1 work moves to feature branches per §4.3.

**Acceptance:**
* All tests pass.
* Docs render correctly on GitHub.
* Module installs cleanly via `box install https://github.com/oistechnologies/tesserabx-pm` and (post-publish) via `box install tesserabx-pm` from ForgeBox.
* No critical accessibility or performance issues outstanding.
* Branch protection enabled and feature-branch workflow documented in `CONTRIBUTING.md`.
* Mike reviews and approves; release tagged.

---

## 10. Testing Strategy and Continuous Integration

### 10.1 Test Layers

**Unit tests**
* Each service has a spec.
* Visibility rules tested with fixtures covering agent, contact in org, contact outside org, accountless.
* Edge cases: empty projects, archived projects, soft-deleted entities, circular template references.
* Polymorphic actor columns: both account-family values exercised per spec.

**Integration tests**
* Each handler tested for happy path, permission denied, validation errors.
* Migrations tested up and down through the host stager.
* End-to-end flows: create project from template, convert ticket to task, complete task with linked tickets.

**Component tests**
* CBWire components tested for initial render, state transitions, event emissions.
* Kanban drag-and-drop tested for sort order and status persistence.

**InstallSpec**
* The top-level CI gate. Walks every host registry PM contributes to and asserts every manifest entry lands.
* Modeled on `sample-addons/example-sync/tests/specs/InstallSpec.bx`.

### 10.2 Test Data

* Fixtures via TestBox `BaseSpec` helpers shared with the host (use the host's `TenantContextProbe@contacts` to seed agents, contacts, organizations).
* Each test runs in a transaction that rolls back.
* Tests target the host's test database, never the dev database. The host's testing convention prevails.

### 10.3 GitHub Actions CI

PM's `.github/workflows/test.yml` runs on every push to `main`. It must:

* Check out the host TesseraBX repo at a pinned tag or branch (configurable per release line).
* Bind-mount PM into the host repo via a CI-specific compose override.
* Bring up Postgres (`pgvector/pgvector:pg16`) and Redis.
* Install dependencies in the host repo.
* Run `box run-script migrate:up` (which stages PM migrations and applies them).
* Run `box run-script test:run` (which discovers and runs PM specs including the InstallSpec).
* Report test results on the commit.

During the v1 build (direct-to-main), a red CI run after a phase commit means the phase is not yet closed; a fix-up commit is required.

### 10.4 Pre-Commit Local Verification

Before requesting Mike's review at phase end, Claude Code must:

1. Run the full TestBox suite locally inside the host dev stack; confirm green.
2. Run migrations up and down against the test database to confirm reversibility.
3. Confirm the PM InstallSpec is green for every manifest delta the phase introduced.
4. Surface a phase summary with file inventory, manifest deltas, test results, manual UI test checklist, and any deferred items.

---

## 11. Host Surface PM Depends On

PM consumes these host contracts. Names match `models/contracts/` interfaces in each host module.

| Contract / WireBox alias | What PM uses it for |
| --- | --- |
| `IContactsService` (`ContactsService@contacts`) | Resolve organization context, contact records for assignees and visibility. |
| `ITicketsService` (`TicketsService@tickets`) | Read tickets, append messages, transition status on close-on-complete. |
| `IAuditService` (`AuditService@audit`) | Write cross-cutting compliance events. |
| `INotificationsService` (`NotificationsService@notifications`) | (Indirect: PM emits events that the notifications module consumes.) |
| `IAiMiddleware` (`AiMiddleware@ai`) | Embeddings and completions for AI features. |
| `IAiProvider` (registry; called via middleware) | Not directly; surfaced only through the middleware. |
| `TenantScope@contacts` | Quick global scope on every PM tenant entity. |
| `TenancyGuard@contacts` | Imperative qb tenant guard. |
| `TesseraBXEntity` (`tesserabx.modules.contacts.models.TesseraBXEntity`) | Base class for tenant entities. |
| `EventPayloadBuilder@core` | Canonical event envelope construction. |
| `SettingsRegistry@core` | Per-tenant settings read and write. |
| `NavigationRegistry@core`, `AdminPagesRegistry@admin`, `RoleRegistry@agent`, `PermissionRegistry@agent`, `TicketPanelRegistry@tickets`, `DashboardWidgetRegistry@reporting`, `ActionRegistry@automation`, `TriggerRegistry@automation`, `AiFeatureRegistry@ai`, `EmbeddingConsumerRegistry@ai`, `ApiResourceRegistry@api`, `WebhookEventRegistry@api`, `NotificationTemplateRegistry@notifications`, `HelpSectionRegistry@help`, `HelpPageRegistry@help` | The registries PM contributes to via its manifest. |

PM does **not** depend on `channels`, `sla` (as a writer), `widget`, or `portal` (as a writer). PM reads from `sla` for the SLA indicator and reads from `tickets` for linked-ticket data. PM contributes to `portal` only through navigation entries.

---

## 12. Out of Scope for v1

These are deferred unless explicitly promoted:

* Recurring tasks.
* General-purpose automation engine inside PM (the host has one; PM contributes actions and triggers to it).
* Gantt or timeline view.
* Milestones above the Task level.
* Mobile-specific UI (the AdminLTE views are responsive but not mobile-first).
* Real-time WebSocket fan-out (CBWire polling is the v1 approach; revisit if the host adopts WebSockets).
* Public API auth beyond what host cbSecurity provides for `/api/v1`.
* Multi-tenancy isolation beyond org scoping (host hard-rejects schema-per-tenant and database-per-tenant).
* Surfacing host per-tenant custom fields *additionally* on PM tasks (open question; see §13).
* PM-owned notification channels (host's three channels are sufficient).
* Daily digest notifications (host concern; PM only declares the events).

---

## 13. Open Items to Resolve During Build

These need resolution but can be addressed inline during the relevant phase. Convert each to a decision when the phase that needs it begins.

* **Embedding model and provider** (Phase 12). PM uses whatever the host's `AiMiddleware` resolves; the open item is which model the host should be configured for. Likely candidates: OpenAI `text-embedding-3-small`, Voyage AI, Cohere, or self-hosted `nomic-embed-text` via Ollama. Decide before Phase 12 with Mike and the host owner.
* **Host per-tenant custom fields on tasks** (Phase 6). PM keeps per-project custom fields. Should it *additionally* surface the host's per-tenant custom fields on tasks (using `CustomFieldsService@tickets` with a `task` entity type)? Default: no. Revisit if needed.
* **Time tracking alignment with future agent module** (Phase 5). If the host `agent` module ships time tracking before PM v1.0.0, align column names and billable semantics.
* **Slack notifications for PM events** (Phase 9). Whether to declare slack channel templates depends on whether the host's slack channel is wired up at that time. Decide before Phase 9.
* **Bulk "Create task from selected tickets" UI** (Phase 8). Requires a bulk-action registry on the host's ticket list. Confirm availability when Phase 8 starts; otherwise the bulk path is automation-only.
* **Help pages content** (every phase). PM declares help sections and pages in the manifest as features land. Decide on tone, voice, and screenshots policy with Mike before Phase 0 closes.

---

## 14. Working with Claude Code

When starting a Claude Code session against this repo:

1. Open with: "Read CLAUDE.md and BUILD-PLAN.md and confirm the current phase before proceeding."
2. Skim the host `docs/EXTENSIONS.md` sections relevant to the active phase.
3. Identify the active phase by checking `CHANGELOG.md` and the latest commits on `main`.
4. Work strictly within the active phase. Do not start the next phase until the current is approved and committed.
5. Honor all conventions in §4. The em-dash rule, the AI isolation rule, the tenant-scope rule, the two-account-family rule, and the commit gate are non-negotiable.
6. **Do not commit during phase work.** Make changes, run tests inside the host dev stack, and stop. Only commit after Mike's explicit approval per §4.4.
7. When a phase introduces ambiguity, stop and ask rather than guessing.
8. At phase end, surface a phase summary with file inventory, **manifest deltas**, test results, manual UI test checklist, and any deferred items. Wait for Mike's approval before committing.
9. Update `CHANGELOG.md` as the closing action of each phase, in the same commit batch as the approved changes.

---

*End of plan.*
