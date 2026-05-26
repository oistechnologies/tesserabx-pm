# tesserabx-pm: Usage

A surface-by-surface walkthrough of every PM feature that ships in v1.0.0. Each section assumes you have the add-on installed and migrations applied, and that you have an agent or contact account with the appropriate PM role.

## Roles

PM ships six roles via the host's role registry. They are not granted automatically; assign them through the host's agent / contact admin pages.

| Role | Surface | Includes |
| --- | --- | --- |
| `pm-admin` | agent | every PM permission including `pm.admin` (templates, statuses, custom fields, per-tenant settings) |
| `pm-manager` | agent | view + create + edit + delete + `pm.assign-client` |
| `pm-contributor` | agent | view + create + edit |
| `pm-viewer` | agent | view only |
| `pm-client-viewer` | contact | view only, on the portal |
| `pm-client-contributor` | contact | view + edit, on the portal |

## Agent surface (`/agent/pm/...`)

### Project list — `/agent/pm`

The landing page for agents.

- Search box filters by project name.
- Organization + status (`active` / `archived` / `completed`) + "include archived" toggle in the filter card.
- Each row shows the project name, an optional description (clamped to two visible lines, hover for full text), organization, visibility chip (**ORG** = all org members, **MEMBERS** = explicit project members only), lifecycle status, start / end dates, created date, and an Actions column with two icon buttons: kanban (jump to the task board) and a chart icon (jump to the overview report).
- Click any project name to open its show page.

### Project show — `/agent/pm/projects/:id`

The project's home base. Action bar at the top includes:

- **Overview** — opens the read-only report (see below).
- **Edit** — opens the edit form.
- **Archive** / **Restore** — soft-lifecycle changes.
- **Delete** — soft-deletes the project.

Main column:

- Description card.
- Quick links into the task board.
- Statuses card with a "Manage statuses" button.
- Custom fields card with a "Manage custom fields" button.

Right column:

- Details (collapsible, default closed): organization, visibility, lifecycle status, time-tracking flag, dates, template source.
- Labels card with the configured label badges + a "Manage labels" icon button.
- Activity feed (collapsible, default closed): newest-first project event log, filterable by actor family (agent / contact / system).

### Project overview report — `/agent/pm/projects/:id/overview`

Read-only dashboard the agent can show to a stakeholder. Headline cards show task counts (total / open / completed / overdue / due-soon), subtask completion ratio, total time logged, and embedding-backlog status. Breakdown cards show tasks-by-status, tasks-by-priority, tasks-by-assignee, and labels-with-counts. Below the cards, every status with at least one task renders as a card containing every task in that status with priority chip, label chips, due date (red if overdue), assignee with display name, and estimated hours.

Click **Open printable view** at the top-right to open the same content in PM's minimal Print layout (no chrome). The print toolbar (Close + Print) hides via `@media print`, so the on-paper output is the report only.

### Task board — `/agent/pm/projects/:id/tasks`

The kanban. Columns are the project's statuses in sort_order. Cards can be dragged between columns (status change) or within a column (reorder). Each card shows the title, priority chip, label chips, due-date / SLA chip if relevant, and an assignee icon.

Filter bar across the top: search, priority, assignee type + id, multi-select label filter, plus a "Clear filters" button. Filters are URL-persisted (`?q=...&priority=...&labelIds=...`).

Quick-add: every column footer has a single-field "+ Add a task" input. Hitting Enter creates the task in that status.

Click any card to open the off-canvas detail panel: shows the task title in the header, a quick-comment composer (8 rows) with internal-note toggle, and an "Open full task page" button in the footer.

### Task list view — `/agent/pm/projects/:id/tasks/list`

Same filters as the board, table layout instead of columns. Sortable column headers. Inline edit for status / priority / due-date (the due-date input renders with a native calendar icon picker, fixed via PM's `board.css` overriding AdminLTE's default).

### Task calendar view — `/agent/pm/projects/:id/tasks/calendar`

Monthly grid (Mon–Sun ISO week order, always 6 rows). Tasks placed by due date. Prev / Today / Next buttons in the header. Click a task chip to jump to its detail page. URL-persisted (`?year=...&month=...`).

### Task detail — `/agent/pm/tasks/:id`

Header: title, status chip, priority chip, completed badge if applicable, client-visibility toggle, Edit / Delete buttons.

Main column:

- Description.
- Comments (with @mention chips, internal-note toggle on the composer, Summarize button when AI is on).
- Subtasks list with inline complete-toggles + edit + delete + "+ New subtask" link.
- Custom fields form (per-project schema).
- Time-tracking logger.

Right column (collapsible cards, default closed except Labels + Watchers):

- Label picker.
- Watchers (Watch toggle for the current viewer + per-row remove + an "Add a watcher" type+account dropdown).
- Related tasks (semantic similarity, AI-gated — the entire card is invisible when AI is off or no relatives exist).
- Linked tickets (with link-type changer + unlink).
- Details (assignee with resolved display name, dates, estimated hours).
- Activity feed (newest-first event log filtered to this task's subjects).

### Per-project Statuses admin — `/agent/pm/projects/:id/statuses`

Add, rename, recolor, reorder, and delete project statuses. Two switch flags per status:

- **Default** — new tasks land in this status (exactly one default per project; flipping demotes the previous).
- **Completed** — moving a task to this status auto-fills `completed_at`; moving away clears it.

Guards: cannot delete a status that has tasks assigned to it (move them first); cannot delete the last remaining status.

### Per-project Labels admin — `/agent/pm/projects/:id/labels`

CRUD for labels. Color is an HTML5 picker. Existing labels render in their picked color.

### Per-project Custom fields admin — `/agent/pm/projects/:id/custom-fields`

CRUD for the seven supported field types (string / text / number / boolean / date / select / multiselect). Values land in `pm_custom_field_values` and surface on the task detail page through the `CustomFieldsForm` wire.

### My Tasks — `/agent/pm/my-tasks`

Cross-project view: every open task across every project where the agent is the assignee OR a watcher. Filter chips (search / priority / due-before / include completed). Group-by switcher (project / due date / none). Saved filters persist via `pm_saved_filters`; default filter loads on mount.

### Time reports — `/agent/pm/time-reports`

Filterable time-log report (project / user / from / to / billable). Aggregates total hours + billable hours; per-row detail with edit + delete actions.

## Admin surface (`/agent/admin/pm`)

### Admin landing — `/agent/admin/pm`

Headline-stat cards (active projects / open + completed tasks / templates / embedding backlog). Two shortcut cards:

- **Project templates** — links to `/agent/admin/pm/templates`.
- **AI embeddings** — when AI is on, a "Run backfill now" button POSTs to the in-app embedding scheduler (returns a messagebox with the per-consumer report). When AI is off, this card explains the feature is disabled.

Below the shortcuts:

- **Default project template** picker — pick an organization, pick a template; saves a per-tenant override via the host's `SettingsRegistry@core`.
- **Add-on status** card — addon id, version, compatibility flag, compatibility message if any.

### Templates admin — `/agent/admin/pm/templates`

CRUD over `pm_project_templates`. Inline "New template" form supports either a blank template or a snapshot taken from an existing project. Per-row icon bar:

- **Preview** — expands an inline panel showing the actual snapshot structure (status names with colors, label list with colors, custom-field types, task list with priority + subtask count).
- **Duplicate** — clones the template (`(copy)` name suffix; preserves snapshot + shared flag).
- **Edit** — inline edit of name + description + shared flag.
- **Delete** — hard delete (projects created from the template are not affected).

## Client portal surface (`/pm/...`)

### Portal landing — `/pm`

Redirects to `/pm/projects` for signed-in contacts; redirects to `/login` for anonymous.

### Portal project list — `/pm/projects`

The contact sees every PM project they are entitled to view, scoped through `VisibilityService` (Option C: visible if `visibility_scope=all_org_members` and project shares the contact's org, OR `visibility_scope=specific_members` and the contact is an explicit member).

### Portal project show — `/pm/projects/:id`

Project header + the per-project task list, all subject to visibility filtering. Tasks not marked `is_client_visible=true` are hidden from contacts even if they otherwise pass project visibility.

### Portal task show — `/pm/tasks/:id`

Task title + priority + due-date / completed chips in the header, plus a **Watch / Unwatch** toggle that lets the contact self-subscribe. Description (when present), comment thread (contact comments are forced `is_internal=false` by the service layer), and a comment composer.

## AI features

All gated on `AI_ENABLED=true` and the host's AI provider being configured.

| Feature | Surface | Notes |
| --- | --- | --- |
| Task embedding | Background (`onPmTaskCreated` interceptor + hourly sweep + on-demand backfill button) | Indexes title + description into `pm_tasks.embedding` (pgvector 1536-d). The first embed lands seconds after task creation; the hourly sweep catches drift |
| Related tasks | Right column of task show | Top-5 cosine-nearest tasks (excluding self) with a similarity % badge. Card hides entirely when zero matches |
| Summarize thread | Comments card on task show | Calls `AiMiddleware.complete` and renders the returned `{summary, keyPoints, nextStep}` |
| Suggest assignee | Task edit form | Top-3 historical assignee picks based on semantic similarity to the task's title + description, project-scoped. Click a pick to set the assignee select |
| Priority widget | Agent home dashboard | "My recommended next task" widget shows the highest-scored open task assigned to the current agent. Score is deterministic (priority weight + due-date pressure + age bonus, capped at 100). When AI is on, an **Explain** button asks the model to translate the breakdown into a one-sentence rationale |

When `AI_ENABLED=false`, every UI surface above either hides itself entirely (Related tasks, Summarize, Suggest, Explain) or renders the deterministic part only (Priority widget renders the score; the Explain button is absent).

## Notifications

PM dispatches in-app + email notifications for every lifecycle event through the host's `NotificationsService`:

- `task_assigned` → the assignee (agent + contact templates)
- `comment_added` → every watcher of the commentable, minus the author (agent + contact templates)
- `mentioned` → the mentioned user (one notification per mention)
- `task_completed` → every watcher minus the actor
- `task_status_changed` → every watcher minus the actor (in-app only)
- `task_due_soon` → the assignee (every 15 min via PM's scheduler)
- `task_overdue` → the assignee (every 15 min)

Per-tenant template overrides go in the `notification_templates` DB table (host-managed); PM's manifest declares the defaults.

## REST API

See [`docs/API.md`](API.md) for the full endpoint catalog and authentication notes.
