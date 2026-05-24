# tesserabx-pm Build Plan

## 1. Overview

**Module name:** `tesserabx-pm`
**Type:** ColdBox extension module
**Parent application:** TesseraBX helpdesk and customer support platform
**Repository:** https://github.com/oistechnologies/tesserabx-pm
**Local repo path:** `/Users/mrigsby/Data/BoxLang-Dev/TesseraBX/GIT/tesserabx-pm`

`tesserabx-pm` adds a full-featured Project Management capability to TesseraBX. It supports projects scoped to organizations, three-level work hierarchy (Project, Task, Subtask), customizable kanban workflows, optional time tracking, project templates, custom fields, bidirectional ticket integration, client portal visibility, @mentions and notifications, and pgvector-backed AI augmentation.

This document is the authoritative source of truth for the module. Claude Code sessions should read this file at the start of every session.

---

## 2. Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | ColdBox 8 |
| Runtime | BoxLang (with CFML compatibility) |
| Database | PostgreSQL 16 with pgvector extension |
| ORM | Quick |
| Query builder | qb |
| Interactive UI | CBWire 4 |
| UI framework | AdminLTE 4 |
| File storage | CBFS |
| Authorization | cbSecurity |
| Migrations | cfmigrations |
| Testing | TestBox |
| Async / queues | ColdBox AsyncManager (cbq optional) |

---

## 3. Architectural Decisions

These decisions are locked. Any deviation requires an explicit ADR (Architecture Decision Record) in `docs/adr/`.

### 3.1 Hierarchy

Three levels: **Project > Task > Subtask**.

* Tasks live on the kanban board and carry full status, custom fields, labels, and embeddings.
* Subtasks are intentionally lighter. They have title, description, assignee, due date, estimated hours, and a binary complete state. They do not appear on the board and do not carry full statuses or custom fields.
* No checklists in v1. If finer granularity is needed, use subtasks.

### 3.2 Statuses

Per-project custom statuses. Each project owns its kanban columns. A sensible default template (Backlog, To Do, In Progress, In Review, Done) is applied on project creation and can be edited.

### 3.3 Client Visibility (Option C)

A client user can see a task when any of the following is true:

1. The task is assigned to them.
2. The task is assigned to another user in their organization.
3. The task has `is_client_visible = true`.

Staff users always see everything within projects they have access to. Clients never see internal-flagged comments. Only staff users may assign a task to a client user.

### 3.4 Comments

Polymorphic across Project, Task, and Subtask. Every comment carries an `is_internal` boolean.

* Staff-authored comments default to `is_internal = true`.
* Client-authored comments are always `is_internal = false`.
* Clients only see non-internal comments.

### 3.5 Ticket Integration

Bidirectional via a `task_tickets` join table.

* Task detail shows linked tickets.
* Ticket detail shows linked tasks.
* "Convert ticket to task" action on ticket detail.
* "Create task from selected tickets" bulk action on ticket list.
* Optional opt-in: closing a parent task prompts the user to close linked tickets.
* SLA awareness: tasks linked to tickets with active SLAs surface that urgency on the board.

### 3.6 Time Tracking

Optional per-project, controlled by `time_tracking_enabled` on the project. Time logs attach polymorphically to Task and Subtask. Subtask hours roll up to the parent task; task hours roll up to the project. Estimates exist on both Task and Subtask. Billable flag supported per log.

### 3.7 Templates

Project templates stored as a JSON snapshot of structure (statuses, labels, custom fields, tasks with relative date offsets, subtasks). When applied, the template service hydrates a real project with calculated dates.

### 3.8 Notifications

Per-user notification preferences by event type and channel (in_app, email). Default preferences populated on user creation. Events that produce notifications:

* Task assigned to you
* You are @mentioned in a comment
* A comment is added to a task you watch
* Status change on a task you watch
* Due date 24 hours away on a task assigned to you
* Due date passed on a task assigned to you
* A ticket is linked to your task

Daily digest is a stretch goal for v1.

### 3.9 Watchers

Auto-watch on assignment. Auto-watch on commenting. Manual watch via a button on the task. Distinguished by an `auto_added` flag for future "auto-unwatch when unassigned" behavior.

### 3.10 AI Features

Powered by pgvector embeddings and on-demand LLM calls.

* **Semantic similarity:** Tasks embed title + description on create and update. "Related Tasks" panel on task detail. "Find similar tasks" suggestion when creating a task or converting a ticket.
* **Comment summarization:** On-demand "Summarize this thread" button. Not automatic.
* **Suggestion service:** Returns assignee and label suggestions based on historical patterns. Stubbed in v1, lights up as data accrues.
* **Priority scoring:** Deterministic scorer (priority weight + due date proximity + blocked flag + assignment count) drives a "My Recommended Next Task" widget. AI explanation layer is optional and on-demand.

### 3.11 Primary Keys and Soft Delete

* UUID primary keys throughout, using PostgreSQL `gen_random_uuid()`.
* Soft delete (`deleted_at` timestamp) on Project, Task, Subtask, Comment, TimeLog. Hard delete elsewhere.

### 3.12 Realtime

Board updates via CBWire polling refresh. No WebSocket fan-out in v1.

### 3.13 API

REST API namespace at `/api/v1`. JSend response format. Built alongside MVC handlers in each phase, not deferred to a separate phase.

---

## 4. Conventions

### 4.1 Writing and Documentation

* **No em dashes anywhere.** Use commas, parentheses, or sentence breaks. This applies to code comments, READMEs, docs, commit messages, error strings, and UI copy.
* American English spelling.
* Markdown for all docs.

### 4.2 Code

* Conventional Commits (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`).
* Quick entities in `models/entities/`. Domain services in `models/services/`. AI services in `models/ai/`. CBWire components in `wires/`.
* All client-visible queries enforce visibility scope at the service layer, not the handler.
* Interceptors handle cross-cutting concerns (activity logging, mention detection, notification dispatch).
* No business logic in handlers. Handlers orchestrate; services do the work.
* No SQL in handlers or views. All data access through Quick or qb in services.

### 4.3 Branching Strategy

**For the initial v1 build, all work commits directly to `main`.** No feature branches, no pull requests. The phase commit gate in Section 4.4 provides the review checkpoint; with a solo developer plus Claude Code during this build, PR ceremony adds overhead without meaningful benefit.

**Post-v1.0.0, this changes.** Once the module ships, future development adopts a feature-branch-per-change strategy with pull requests into `main`, branch protection requiring CI pass and one approving review, and the same commit gate per Section 4.4. The transition happens at the `v1.0.0` release tag. Until then, direct-to-main is the rule.

CI still runs on every push to `main`. A red CI run after a commit means the phase is not yet closed and a fix-up commit is needed before moving on.

### 4.4 Phase Completion and Commit Gate

**This rule is strict and non-negotiable.**

Claude Code does not commit during phase work. A phase is considered ready for commit only when **all** of the following are true:

1. All TestBox specs for the phase pass locally.
2. Mike has reviewed the diff in detail.
3. Mike has manually tested any UI components introduced or modified in the phase.
4. Mike has given explicit written approval ("Approved, commit it" or equivalent).

Until all four conditions are satisfied, Claude Code stays in the working state and makes no commits. When ready, Claude Code surfaces a phase summary with:

* What was built (file inventory).
* Test results.
* Manual UI test checklist (for Mike to walk through).
* Any open questions or deferred items.

Mike then reviews. Once approved, Claude Code commits to `main` using Conventional Commits (one logical commit per area where reasonable) and pushes. CI runs against the new commits on `main`; a green CI run closes the phase.

### 4.5 Testing

* TestBox for everything.
* Service tests cover business logic and visibility rules at the unit level.
* Handler tests cover routes, permissions, and response shape at the integration level.
* CBWire component tests cover state transitions.
* Each phase concludes with passing tests before review begins.
* Migrations have up and down test coverage.

### 4.6 Migrations

* cfmigrations format.
* One migration per logical schema change.
* Sequentially numbered with timestamp prefix.
* Always reversible (`down` implemented).
* No data migrations mixed with schema migrations. Separate them.

---

## 5. Module Layout

```
tesserabx-pm/
├── box.json
├── ModuleConfig.cfc
├── README.md
├── LICENSE
├── CHANGELOG.md
├── .github/workflows/test.yml
├── config/
│   ├── Router.cfc
│   └── cbSecurity.cfc
├── handlers/
│   ├── Projects.cfc
│   ├── Tasks.cfc
│   ├── Subtasks.cfc
│   ├── Boards.cfc
│   ├── Comments.cfc
│   ├── TimeLogs.cfc
│   ├── Templates.cfc
│   ├── CustomFields.cfc
│   ├── Labels.cfc
│   ├── Notifications.cfc
│   └── api/v1/
│       ├── Projects.cfc
│       ├── Tasks.cfc
│       ├── Subtasks.cfc
│       ├── Comments.cfc
│       └── TimeLogs.cfc
├── models/
│   ├── entities/
│   │   ├── Project.cfc
│   │   ├── ProjectMember.cfc
│   │   ├── ProjectStatus.cfc
│   │   ├── Task.cfc
│   │   ├── Subtask.cfc
│   │   ├── Comment.cfc
│   │   ├── Watcher.cfc
│   │   ├── Mention.cfc
│   │   ├── ActivityLog.cfc
│   │   ├── TimeLog.cfc
│   │   ├── Label.cfc
│   │   ├── TaskLabel.cfc
│   │   ├── CustomField.cfc
│   │   ├── CustomFieldValue.cfc
│   │   ├── TaskTicket.cfc
│   │   ├── Attachment.cfc
│   │   ├── Notification.cfc
│   │   ├── NotificationPreference.cfc
│   │   └── ProjectTemplate.cfc
│   ├── services/
│   │   ├── ProjectService.cfc
│   │   ├── TaskService.cfc
│   │   ├── SubtaskService.cfc
│   │   ├── BoardService.cfc
│   │   ├── CommentService.cfc
│   │   ├── WatcherService.cfc
│   │   ├── MentionService.cfc
│   │   ├── ActivityLogService.cfc
│   │   ├── TimeTrackingService.cfc
│   │   ├── LabelService.cfc
│   │   ├── CustomFieldService.cfc
│   │   ├── TaskTicketService.cfc
│   │   ├── TemplateService.cfc
│   │   ├── NotificationService.cfc
│   │   └── VisibilityService.cfc
│   └── ai/
│       ├── EmbeddingService.cfc
│       ├── SimilarityService.cfc
│       ├── SummarizationService.cfc
│       ├── SuggestionService.cfc
│       └── PriorityScoringService.cfc
├── interceptors/
│   ├── ActivityLogger.cfc
│   ├── MentionDetector.cfc
│   ├── NotificationDispatcher.cfc
│   └── EmbeddingUpdater.cfc
├── wires/
│   ├── KanbanBoard.cfc
│   ├── TaskCard.cfc
│   ├── TaskDetail.cfc
│   ├── TaskList.cfc
│   ├── CalendarView.cfc
│   ├── MyTasks.cfc
│   ├── CommentThread.cfc
│   ├── TimeLogger.cfc
│   ├── NotificationDropdown.cfc
│   ├── TemplatePicker.cfc
│   ├── LabelManager.cfc
│   ├── CustomFieldBuilder.cfc
│   └── StatusColumnManager.cfc
├── views/
│   ├── projects/
│   ├── tasks/
│   ├── subtasks/
│   ├── boards/
│   ├── templates/
│   ├── customfields/
│   └── api/
├── layouts/
│   └── Main.cfm
├── migrations/
├── resources/
│   ├── lang/
│   └── assets/
└── tests/
    ├── specs/
    │   ├── unit/
    │   ├── integration/
    │   └── wires/
    └── Application.cfc
```

---

## 6. Local Development Environment

### 6.1 Paths

| Purpose | Path |
|---------|------|
| TesseraBX staging clone | `/Users/mrigsby/Data/BoxLang-Dev/TesseraBX/LOCAL-STAGING/` |
| tesserabx-pm repo | `/Users/mrigsby/Data/BoxLang-Dev/TesseraBX/GIT/tesserabx-pm` |
| Remote module repo | https://github.com/oistechnologies/tesserabx-pm |

### 6.2 Docker Setup

The module is developed inside the LOCAL-STAGING TesseraBX container via bind mount. This gives live editing without reinstalling the module after each change.

**Use a `docker-compose.override.yml`** in `LOCAL-STAGING/` rather than editing the main `docker-compose.yml`. Override files are automatically merged by Docker Compose, and conventionally gitignored, so local dev paths do not leak into the TesseraBX repo.

Example `docker-compose.override.yml`:

```yaml
services:
  app:
    volumes:
      - /Users/mrigsby/Data/BoxLang-Dev/TesseraBX/GIT/tesserabx-pm:/app/modules/tesserabx-pm
```

Adjust the service name (`app`) and container path (`/app/modules/tesserabx-pm`) to match the actual TesseraBX docker-compose service name and module directory convention.

**Postgres image must include pgvector.** Verify the LOCAL-STAGING postgres service uses an image such as `pgvector/pgvector:pg16` (or a custom Dockerfile that installs the extension). Vanilla `postgres:16` will not work for AI features.

### 6.3 Module Installation Methods

Because the module is not yet on ForgeBox, `box install tesserabx-pm` (the registry shorthand) is not valid. Use one of the following until v1.0.0 publishes to ForgeBox:

**From GitHub:**

```
box install https://github.com/oistechnologies/tesserabx-pm
```

To pin a specific branch:

```
box install https://github.com/oistechnologies/tesserabx-pm#development
```

**From local path:**

```
box install /Users/mrigsby/Data/BoxLang-Dev/TesseraBX/GIT/tesserabx-pm
```

**Note on bind-mount development:** When the module directory is bind-mounted into the container's `modules/` folder, no `box install` is needed for the parent TesseraBX. The mount itself acts as the install. Do not list `tesserabx-pm` as a dependency in TesseraBX's `box.json` during local development; that is only added at the point of integration.

### 6.4 Databases

Run two databases inside the LOCAL-STAGING postgres service:

* `tesserabx_pm_dev` for local development data.
* `tesserabx_pm_test` for TestBox test runs.

Test runs wipe and reseed `tesserabx_pm_test` between specs. Dev data in `tesserabx_pm_dev` is untouched.

### 6.5 Common Commands

All commands run from inside the container unless noted.

| Task | Command |
|------|---------|
| Install module dependencies | `box install` |
| Run all migrations (dev) | `box migrate up` |
| Roll back last migration (dev) | `box migrate down` |
| Run migrations against test DB | `box migrate up --schema=test` (or env switch) |
| Run TestBox suite | `box testbox run` |
| Reinit ColdBox after config changes | `box reinit` (or `?fwreinit=true` in browser) |
| Tail logs | `box server log --follow` |

### 6.6 Module Reinit

After changes to `ModuleConfig.cfc`, `Router.cfc`, or anything that affects ColdBox bootstrapping, reinit the framework. Handler, service, view, and CBWire changes generally do not require reinit when ColdBox is configured for development mode (cache off).

### 6.7 CommandBox Version

Pin CommandBox in `box.json` engines:

```json
"engines": [
  { "type": "commandbox", "version": ">=6.0.0" }
]
```

This avoids drift between local dev and CI.

---

## 7. Entity Model

Twenty entities, grouped by purpose.

### 7.1 Core Hierarchy

**Project**
* `id` (uuid), `org_id`, `name`, `description`
* `visibility_scope` (enum: `all_org_members`, `specific_users`)
* `lifecycle_status` (enum: `active`, `archived`, `completed`)
* `start_date`, `end_date`
* `time_tracking_enabled` (boolean)
* `is_template` (boolean), `template_source_id` (nullable)
* `embedding` (vector)
* `created_by`, `updated_by`, timestamps, `deleted_at`

**Task**
* `id` (uuid), `project_id`, `status_id`
* `title`, `description`
* `priority` (enum: `low`, `medium`, `high`, `urgent`)
* `assignee_id` (nullable)
* `due_date`, `start_date`
* `estimated_hours` (decimal, nullable)
* `is_client_visible` (boolean, default false)
* `sort_order` (integer, within status column)
* `completed_at` (nullable)
* `embedding` (vector)
* `created_by`, timestamps, `deleted_at`

**Subtask**
* `id` (uuid), `task_id`
* `title`, `description`
* `assignee_id` (nullable)
* `due_date`, `estimated_hours`
* `is_completed` (boolean), `completed_at`
* `sort_order`
* `created_by`, timestamps, `deleted_at`

### 7.2 Access and Configuration

**ProjectMember** records explicit member access when project visibility scope is `specific_users`. Fields: `project_id`, `user_id`, `role` (owner, manager, contributor, viewer), `is_client`, `added_by`, `added_at`.

**ProjectStatus** holds per-project kanban columns. Fields: `project_id`, `name`, `color`, `sort_order`, `is_default`, `is_completed`.

### 7.3 Engagement and History

**Comment** is polymorphic. Fields: `commentable_type`, `commentable_id`, `parent_comment_id` (nullable, for threading), `author_id`, `body`, `is_internal`, timestamps, `deleted_at`.

**Watcher** tracks follows. Fields: `watchable_type`, `watchable_id`, `user_id`, `auto_added`, timestamps.

**Mention** records @mentions. Fields: `comment_id`, `mentioned_user_id`, `notified_at`, `read_at`.

**ActivityLog** captures changes. Fields: `project_id`, `subject_type`, `subject_id`, `actor_id`, `action`, `changes` (jsonb), `created_at`.

### 7.4 Tracking

**TimeLog** is polymorphic across Task and Subtask. Fields: `loggable_type`, `loggable_id`, `user_id`, `hours` (decimal), `logged_at`, `description`, `is_billable`, timestamps, `deleted_at`.

### 7.5 Categorization

**Label** per project. Fields: `project_id`, `name`, `color`, `sort_order`.

**TaskLabel** join. Fields: `task_id`, `label_id`.

**CustomField** per project. Fields: `project_id`, `name`, `field_type` (enum: text, number, date, dropdown, multiselect, checkbox, url), `options` (jsonb for dropdowns), `is_required`, `applies_to` (enum: task, subtask, both), `sort_order`.

**CustomFieldValue** polymorphic. Fields: `custom_field_id`, `valuable_type`, `valuable_id`, `value` (text, normalized for type).

### 7.6 Integration

**TaskTicket** bidirectional join. Fields: `task_id`, `ticket_id`, `link_type` (enum: related, blocks, fixes), `linked_by`, `linked_at`.

**Attachment** polymorphic across Task, Subtask, Comment. Backed by CBFS. Fields: `attachable_type`, `attachable_id`, `file_path`, `file_name`, `file_size`, `mime_type`, `uploaded_by`, timestamps.

### 7.7 Notifications

**Notification** per user. Fields: `user_id`, `type`, `subject_type`, `subject_id`, `data` (jsonb), `read_at`, `sent_email_at`, timestamps.

**NotificationPreference** per user, per event type. Fields: `user_id`, `event_type`, `channel` (in_app, email), `enabled`.

### 7.8 Templates

**ProjectTemplate**. Fields: `name`, `description`, `structure` (jsonb snapshot of statuses, labels, custom fields, tasks with relative date offsets, subtasks), `created_by`, `is_shared`, timestamps.

---

## 8. Build Phases

Each phase has a goal, a deliverables list, and acceptance criteria. A phase is not considered complete until acceptance criteria pass, tests are green, **and Mike has reviewed and approved per Section 4.4**.

### Phase 0: Project Scaffolding

**Goal:** An installable, empty module that loads cleanly inside the LOCAL-STAGING TesseraBX.

**Deliverables:**
* GitHub repo at https://github.com/oistechnologies/tesserabx-pm initialized with `.gitignore`, `LICENSE` (Apache 2.0), `README.md`, `CHANGELOG.md`.
* `box.json` with dependencies on coldbox, quick, qb, cbwire, cbsecurity, cbfs, cfmigrations. CommandBox version pinned in engines.
* `ModuleConfig.cfc` with parent settings merge, module dependencies, interceptor registration stubs.
* `config/Router.cfc` with a root route serving a "Module installed" placeholder.
* Full folder structure per Section 5.
* TestBox configured with `tests/Application.cfc` and a passing smoke test.
* GitHub Actions workflow (`.github/workflows/test.yml`) running TestBox on every push, with a pgvector-enabled postgres service container.
* cfmigrations initialized with empty migrations folder.
* `docker-compose.override.yml` example documented in README for LOCAL-STAGING bind mount.

**Acceptance:**
* Module loaded via bind mount in LOCAL-STAGING TesseraBX returns the placeholder page at `/pm`.
* `box install https://github.com/oistechnologies/tesserabx-pm` succeeds against a fresh CommandBox install (verified out-of-band).
* `box install /Users/mrigsby/Data/BoxLang-Dev/TesseraBX/GIT/tesserabx-pm` succeeds against a fresh CommandBox install.
* CI passes on push.
* Mike reviews and approves; commits pushed to `main`.

### Phase 1: Core Entity Model and Migrations

**Goal:** Database schema in place. Quick entities defined with relationships.

**Deliverables:**
* Migrations for all 20 tables in Section 7, in dependency order.
* Migration to enable `vector` and `uuid-ossp` (or `pgcrypto`) extensions.
* Quick entity CFC for each table with primary key, timestamps, soft delete trait where applicable.
* Relationship methods: belongsTo, hasMany, belongsToMany, morphTo, morphMany as appropriate.
* Seed data migration for default project status template (Backlog, To Do, In Progress, In Review, Done).
* Unit tests instantiating each entity and verifying relationships.

**Acceptance:**
* `box migrate up` creates all tables in `tesserabx_pm_dev` and `tesserabx_pm_test`.
* `box migrate down` cleanly reverses all migrations.
* All relationship methods return the expected types.
* All entity tests pass in CI.
* Mike reviews and approves; commits pushed to `main`.

### Phase 2: Project and Task CRUD

**Goal:** Staff can manage projects, tasks, and subtasks via web UI.

**Deliverables:**
* `ProjectService`, `TaskService`, `SubtaskService` with create, update, soft delete, restore, archive (project only).
* `Projects`, `Tasks`, `Subtasks` handlers with REST-style actions.
* `VisibilityService` enforcing org-scoped and member-scoped visibility, used by all read operations.
* Basic AdminLTE views (no CBWire yet): project index, project detail with task list, task detail, edit forms.
* cbSecurity rules: staff full access, clients read-scoped per Option C, only staff can assign tasks to clients.
* Custom status management UI (CRUD on `ProjectStatus`).
* Org assignment and visibility scope selection on project create.
* Unit tests for services. Integration tests for handlers and permissions.

**Acceptance:**
* Create a project, assign org, set visibility scope.
* Add tasks and subtasks, assign them to staff and client users.
* Attempt to assign a task to a client as a client user, get denied.
* See tasks per Option C visibility rules from a client login.
* Mike completes manual UI walkthrough and approves; commits pushed to `main`.

### Phase 3: Kanban Board

**Goal:** Drag-and-drop kanban board with live updates.

**Deliverables:**
* `BoardService` that groups tasks by status, applies filters, returns board state.
* `KanbanBoard` CBWire component rendering columns and cards.
* `TaskCard` CBWire component with title, assignee avatar, due date, priority indicator, label chips, linked ticket count.
* Drag-and-drop reordering with `sort_order` and `status_id` persistence (SortableJS or equivalent).
* Quick-add task input at the top of each column.
* `TaskDetail` CBWire component opened as a flyout or modal, supporting inline editing.
* Filters: assignee, label, priority, search query.
* Status column management UI accessible from the board.

**Acceptance:**
* Open a project, see the kanban board populated with tasks.
* Drag a task between columns, status updates persist.
* Drag a task within a column, sort order persists.
* Click a task, see and edit details inline.
* Filter by assignee, only matching tasks remain visible.
* Mike completes manual UI walkthrough and approves; commits pushed to `main`.

### Phase 4: Comments, Watchers, Mentions, Activity Log

**Goal:** Collaboration features.

**Deliverables:**
* `CommentService` with create, update, soft delete, list scoped by `is_internal` and viewer role.
* `CommentThread` CBWire component with threaded display, optimistic UI for new comments.
* `MentionService` parsing `@username` references in comment bodies.
* Mention autocomplete dropdown in the comment composer.
* `WatcherService` with auto-watch on assignment, auto-watch on comment, manual watch toggle.
* `ActivityLogger` interceptor listening to all entity create/update/delete events.
* `ActivityFeed` view per project and per task.
* `is_internal` toggle on staff comment composer, visible only to staff.

**Acceptance:**
* Post a comment on a task. Staff comment defaults to internal.
* @mention a user, the mention is recorded.
* Watch a task manually. Auto-watch fires on assignment.
* See an activity feed showing entity changes with actor and timestamp.
* As a client, only non-internal comments are visible.
* Mike completes manual UI walkthrough and approves; commits pushed to `main`.

### Phase 5: Notifications and Email

**Goal:** Users receive in-app and email notifications.

**Deliverables:**
* `NotificationService` with create, list, mark read, mark all read.
* `NotificationPreference` defaults seeded on user creation (via interceptor on the parent app's user creation event, with safe fallback).
* `NotificationDispatcher` interceptor listening to events from Phase 4 and elsewhere.
* Email templates for each notification type (HTML and plain text), branded for staff and client recipients.
* `NotificationDropdown` CBWire component in the top nav showing unread notifications with mark-read action.
* Email sending via ColdBox `mail` service, queued through AsyncManager.
* User notification preference settings UI.

**Acceptance:**
* @mention a user, they receive an in-app notification and an email.
* Assign a task to a user, same.
* Comment on a watched task, watchers are notified.
* Notification preferences UI lets users toggle each event type per channel.
* Disabling email for an event type results in in-app only.
* Mike completes manual UI walkthrough and approves; commits pushed to `main`.

### Phase 6: Time Tracking

**Goal:** Log hours against tasks and subtasks.

**Deliverables:**
* `TimeTrackingService` with create, update, delete, list, rollup queries.
* `TimeLogger` CBWire component embedded on Task and Subtask detail.
* Estimate input fields on Task and Subtask.
* Time log list per task with totals and per-user breakdown.
* Per-project `time_tracking_enabled` toggle, UI hides time controls when disabled.
* Reports: time by user, time by project, time by date range, billable vs non-billable.
* Billable filter on reports.

**Acceptance:**
* Enable time tracking on a project, time controls appear on its tasks.
* Log hours on a subtask, they roll up to the parent task and to the project.
* Run a time report by user, see correct totals.
* Disable time tracking, controls disappear.
* Mike completes manual UI walkthrough and approves; commits pushed to `main`.

### Phase 7: Labels and Custom Fields

**Goal:** Flexible task metadata.

**Deliverables:**
* `LabelService` with CRUD scoped per project.
* `LabelManager` CBWire component.
* Label picker on task detail with multi-select.
* `CustomFieldService` with CRUD on field definitions and value storage.
* `CustomFieldBuilder` CBWire component for defining fields per project.
* Custom field rendering on task and subtask detail, dynamic by `field_type`.
* Validation per field type (number range, date format, required, dropdown options).
* Filtering by label and by custom field value on board, list, and calendar views.

**Acceptance:**
* Create a label, apply it to tasks, filter the board by it.
* Create a custom field (text, number, date, dropdown, multiselect, checkbox, url), set values on tasks, filter by them.
* Required custom fields enforced on task create and update.
* Mike completes manual UI walkthrough and approves; commits pushed to `main`.

### Phase 8: Templates

**Goal:** Repeatable project structures.

**Deliverables:**
* `TemplateService` with snapshot generation (from existing project), hydration (to new project), CRUD on templates.
* `TemplatePicker` CBWire component in the new-project flow.
* Template management UI (list, create from project, edit, delete).
* Relative date offsets stored in the template structure, resolved to absolute dates at hydration using the new project's start date.
* Statuses, labels, custom fields, tasks, and subtasks all hydrated from the template.

**Acceptance:**
* Create a template from an existing project.
* Create a new project from the template, statuses and labels and custom fields are recreated.
* Tasks and subtasks are created with dates offset from the new project's start date.
* Edit a template, the source project is unchanged.
* Mike completes manual UI walkthrough and approves; commits pushed to `main`.

### Phase 9: Bidirectional Ticket Integration

**Goal:** Tickets and tasks are mutually aware.

**Deliverables:**
* `TaskTicketService` with link, unlink, list operations.
* "Convert ticket to task" action on the parent app's ticket detail (added via module interceptor on the ticket UI).
* "Create task from selected tickets" bulk action on ticket list.
* "Linked tickets" panel on task detail with link type selector.
* "Linked tasks" panel injected into ticket detail.
* Close-on-complete prompt: when a task with linked tickets is moved to a status with `is_completed = true`, prompt the user to close linked tickets.
* SLA awareness: linked ticket SLAs surfaced on the task card via a visual indicator.

**Acceptance:**
* From a ticket, convert to a task. Task is created with title and description prefilled, link is recorded.
* From a list of tickets, bulk-create a task linking all of them.
* On task detail, see linked tickets with their statuses and SLAs.
* Complete a task, see the prompt to close linked tickets, accept it, tickets are closed.
* Mike completes manual UI walkthrough and approves; commits pushed to `main`.

### Phase 10: Views Beyond Kanban

**Goal:** Multiple perspectives on the same data.

**Deliverables:**
* `TaskList` CBWire component: sortable table with column visibility toggles, inline editing where safe.
* `CalendarView` CBWire component: monthly grid with tasks placed by due date, click to open task detail.
* `MyTasks` CBWire component: cross-project view of tasks assigned to the current user, grouped by project or by due date.
* View switcher in the project header (Board, List, Calendar).
* Saved filters per view per user.

**Acceptance:**
* Switch between Board, List, and Calendar views on a project.
* On My Tasks, see tasks from all projects you have access to.
* Save a filter on the Board view, reload, filter is still applied.
* Mike completes manual UI walkthrough and approves; commits pushed to `main`.

### Phase 11: Client Portal Integration

**Goal:** Customer-facing PM views.

**Deliverables:**
* Client-side project list page showing projects in the client's organizations.
* Client-side project detail with visibility-scoped task list per Option C.
* Client-side task detail showing non-internal comments only.
* Client comment composer that forces `is_internal = false`.
* "Make visible to client" toggle on task detail, staff-only.
* Client notification emails branded and routed through the parent app's client portal templates.
* Client cannot edit task structure, status, or assignment. Read and comment only.

**Acceptance:**
* Log into the client portal, see projects for organizations the client belongs to.
* See tasks per Option C rules: assigned to me, assigned to my org, or explicitly client-visible.
* Post a comment, it appears for staff and other clients in the org.
* Toggle `is_client_visible` as staff, the client sees the task appear.
* Mike completes manual UI walkthrough and approves; commits pushed to `main`.

### Phase 12: AI Features

**Goal:** AI augmentation across the module.

**Deliverables:**
* `EmbeddingService` that generates and stores embeddings for tasks (title + description) on create and update, using the configured provider.
* `EmbeddingUpdater` interceptor wiring task lifecycle to the embedding service.
* Backfill command (`box task run pm:embed-backfill`) to populate embeddings for existing tasks.
* `SimilarityService` returning top-N related tasks by cosine distance, with thresholds.
* "Related Tasks" panel on task detail.
* "Find similar tasks" suggestion when creating a task or converting a ticket, with one-click link.
* `SummarizationService` exposing a "Summarize this thread" action on comment threads, calling the configured LLM with the thread content.
* `SuggestionService` returning assignee and label suggestions based on historical patterns. Returns empty gracefully when data is sparse.
* `PriorityScoringService` with deterministic scoring (priority weight + due date proximity + blocked flag + assignment count) plus optional AI explanation.
* "My Recommended Next Task" dashboard widget showing top scored tasks with explanations.

**Acceptance:**
* Create a task, an embedding is generated and stored.
* Run the backfill, all existing tasks have embeddings.
* See related tasks on a task detail with reasonable similarity.
* Summarize a long comment thread, get a coherent summary.
* See assignee and label suggestions on a new task once enough data exists.
* The dashboard widget shows ranked tasks with explanations.
* Mike completes manual UI walkthrough and approves; commits pushed to `main`.

### Phase 13: Polish, Tests, and Release

**Goal:** Production-ready module.

**Deliverables:**
* Comprehensive test coverage: services, handlers, CBWire components, migrations.
* Performance pass: indexes verified on all foreign keys and common filters, N+1 queries eliminated, board pagination if a project exceeds a threshold.
* Accessibility pass on AdminLTE views: keyboard navigation, ARIA labels, contrast.
* Documentation: `README.md` with installation and configuration, `docs/USAGE.md` with feature walkthrough, `docs/API.md` with REST endpoint reference, `docs/ADR/` for any architecture decision records.
* ForgeBox publishing setup with `box publish` workflow.
* Semantic versioning, tagged `v1.0.0` release.
* **Transition to feature-branch workflow**: at v1.0.0 tag, enable branch protection on `main` (require CI pass, require one approving review). All post-v1 work moves to feature branches with PRs per Section 4.3.

**Acceptance:**
* All tests pass.
* Docs render correctly on GitHub.
* Module installs cleanly via `box install https://github.com/oistechnologies/tesserabx-pm` and (post-publish) via `box install tesserabx-pm` from ForgeBox.
* No critical accessibility or performance issues outstanding.
* Branch protection enabled and feature-branch workflow documented in `CONTRIBUTING.md`.
* Mike reviews and approves; release tagged.

---

## 9. Testing Strategy and Continuous Integration

### 9.1 Test Layers

**Unit tests**
* Each service has a corresponding spec.
* Visibility rules tested explicitly with fixtures covering staff, client in org, client outside org.
* Edge cases: empty projects, archived projects, soft-deleted entities, circular template references.

**Integration tests**
* Each handler tested for happy path, permission denied, validation errors.
* Migrations tested up and down.
* End-to-end flows: create project from template, convert ticket to task, complete task with linked tickets.

**Component tests**
* CBWire components tested for initial render, state transitions, event emissions.
* Kanban drag-and-drop tested for sort order and status persistence.

### 9.2 Test Data

* Fixtures via TestBox `BaseSpec` helpers.
* Each test gets a clean transaction that rolls back.
* Tests target `tesserabx_pm_test` database, never `tesserabx_pm_dev`.

### 9.3 GitHub Actions CI

A workflow at `.github/workflows/test.yml` runs on every push to `main`. It must include:

* A `pgvector/pgvector:pg16` service container exposing port 5432.
* CommandBox setup (pinned to the version in `box.json` engines).
* `box install` to pull module dependencies.
* `box migrate up` against the test database.
* `box testbox run` with non-zero exit on any failure.
* Test result reporting visible on the commit in GitHub.

During the v1 build (direct-to-main), a red CI run after a phase commit means the phase is not yet closed; a fix-up commit is required before moving on. Post-v1.0.0, branch protection enforces CI pass before merge.

### 9.4 Pre-Commit Local Verification

Before requesting Mike's review at the end of a phase, Claude Code must:

1. Run the full TestBox suite locally and confirm all green.
2. Run migrations up and down against the test database to confirm reversibility.
3. Surface a summary of test results, manual test checklist, and any deferred items.

---

## 10. Dependencies on Parent TesseraBX

The module assumes these are present and stable in the parent:

* `Organization` entity with `id`, members relationship.
* `User` entity with `id`, `is_staff`, `is_client`, `organization_id` (or many-to-many membership).
* `Ticket` entity with `id`, `status`, `sla_*` fields, `organization_id`.
* CBFS root configured for module file storage.
* cbSecurity user context with role resolution.
* Mail service configured.
* AsyncManager available.

If any of these names differ in the actual parent, capture the mapping in `config/ModuleConfig.cfc` settings and use those settings everywhere downstream. Do not hard-code parent table or entity names.

---

## 11. Out of Scope for v1

These are explicitly deferred to post-v1 and should not be built unless promoted:

* Recurring tasks.
* General-purpose automation rules engine.
* Gantt or timeline view.
* Milestones above the Task level.
* Mobile-specific UI (the AdminLTE views are responsive but not mobile-first).
* Real-time WebSocket fan-out (CBWire polling is the v1 approach).
* Public API authentication beyond what cbSecurity provides for the `/api/v1` namespace.
* Multi-tenancy isolation beyond org scoping.

---

## 12. Open Items to Resolve During Build

These need resolution but can be addressed inline during the relevant phase:

* Which LLM provider and model to use for embeddings (Phase 12). Anthropic does not currently offer an embeddings endpoint; likely candidates are OpenAI `text-embedding-3-small`, Voyage AI, Cohere, or a self-hosted option such as `nomic-embed-text` via Ollama. Decide before Phase 12 begins.
* Email branding: does the parent app already have an email layout the module should extend, or does the module ship its own? Decide before Phase 5.
* Whether to expose project settings (statuses, labels, custom fields) to org admins on the client side, or keep them staff-only. Default staff-only, revisit if requested.

---

## 13. Working with Claude Code

When starting a Claude Code session against this repo:

1. Open the session with: "Read BUILD-PLAN.md and confirm the current phase before proceeding."
2. Identify the active phase by checking `CHANGELOG.md` and the latest commits on `main`.
3. Work strictly within the active phase. Do not start the next phase until the current phase is approved and committed.
4. Honor all conventions in Section 4. The em dash rule and the commit gate are non-negotiable.
5. **Do not commit during phase work.** Make changes, run tests locally, and stop. Only commit after Mike's explicit approval per Section 4.4.
6. When a phase introduces ambiguity, stop and ask rather than guessing.
7. At phase end, surface a phase summary with file inventory, test results, manual UI test checklist, and any deferred items. Wait for Mike's approval before committing.
8. Update `CHANGELOG.md` as the closing action of each phase, in the same commit batch as the approved changes.

---

*End of plan.*
