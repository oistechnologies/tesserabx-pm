# Changelog

All notable changes to `tesserabx-pm` are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Pre-1.0 development happens directly on `main`. Phases are tracked here as `[Unreleased]` sections until v1.0.0 is tagged, at which point post-v1 work moves to feature branches per the BUILD-PLAN §4.3.

## [Unreleased]

### Phase 8b: Bidirectional Ticket Integration (Automation + Lifecycle + SLA)

- `CreateTaskFromTicketExecutor@tesserabx-pm` registered through `automationActions` as `tesserabx-pm.createTaskFromTicket`. Implements the `execute( action, ticket, rule )` signature `ActionRegistry@automation` actually calls (note: the example-sync sample addon uses `dispatch`, which the live registry ignores). Creates a PM task seeded from the ticket subject + description, maps ticket priority to PM priority, then immediately links the new task back to the ticket with a `fixes` relation. Rule-editor parameter schema is a single `value` text field today (the dropdown rich type lands when the host's parameterSchema renderer supports dynamic option providers; per the storage note in `EXTENSIONS.md` rules persist a single `{ type, value }` shape).
- `LinkedTasksPanel@tesserabx-pm` (new CBWire) replaces the static Phase 8a `linked_tasks.bxm` partial. The ticket-side right-column panel now always renders, lists linked PM tasks when present, and exposes an inline "Create a PM task" form (title pre-seeded from the ticket subject + project dropdown + link-type select) so an agent can spawn + link a task in one click without round-tripping through the automation rules editor. The "+ New task" header button toggles the form on tickets that already have links; on unlinked tickets the form opens by default. Unlink + per-row delete also lift over from the previous static partial.
- `PmTaskLifecycleListener` interceptor listens to `onPmTaskCompleted` (sync); logs a diagnostic when a completed task still carries linked tickets. The "close linked tickets?" UX itself is data-driven, not event-driven, so the listener is observation-only today; future close-on-complete automation hangs off this attachment point.
- `CloseOnCompletePrompt@tesserabx-pm` CBWire embedded on the task show page renders a Bootstrap modal whenever the current task is completed AND has linked tickets in non-resolved status. Per-ticket checkboxes plus a "Close selected" action that calls `TicketsService.changeStatus` for each picked id. Dismiss is per-page-lifecycle (reload returns the prompt if the task is still completed); the modal auto-dismisses once every linked ticket is resolved.
- `BoardService.buildBoard` and `buildColumn` now return a `slaByTask` map alongside the existing `labelsByTask` map. Walks `pm_task_tickets` for the task batch in one query, resolves `SlaService@sla.slaSummaryForTicket` per unique ticket (cached), bubbles up the worst SLA status per task. Worst-of severity ordering: breached > approaching > ok > paused > met > none. Kanban TaskCards render a red "SLA breached" or yellow "SLA approaching" badge when warranted; lower statuses stay silent so the card does not get noisy.
- `TaskTicketService.link` and `unlink` now fire sync `onPmTicketLinked` / `onPmTicketUnlinked` canonical envelopes through `EventPayloadBuilder@core`. Manifest declares the matching `tesserabx-pm.ticket_linked` + `tesserabx-pm.ticket_unlinked` webhook event keys.
- Manifest deltas: `automationActions` populated with the one executor; `webhookEvents` extended with the two link-lifecycle keys; `customInterceptionPoints` extended with `onPmTicketLinked` + `onPmTicketUnlinked`; `interceptors` registers `PmTaskLifecycleListener`; `contributesTo` extended with `automationActions`.
- `InstallSpec` adds 2 new probes: `tesserabx-pm.createTaskFromTicket` in `ActionRegistry@automation` and both webhook keys in `WebhookEventRegistry@api`. 55 specs total in InstallSpec.
- Deferred from this phase per BUILD-PLAN: `TaskFromBulkTicketsExecutor` ("creates a single PM task linking every selected ticket") is pending host support for batched action context — the live `execute( action, ticket, rule )` signature passes one ticket per invocation, so the "one task linking N tickets" semantic needs a bulk-action registry or a multi-ticket action context that does not yet exist in the host. Optional bulk UI button is also pending the host's bulk-action registry. Single-ticket runs of the existing `createTaskFromTicket` action cover the common case until then.

### Phase 8a: Bidirectional Ticket Integration (Linking + Panels)

- `TaskTicketService@tesserabx-pm` ships the link / unlink / list surface over `pm_task_tickets`. `link(data)` is idempotent via `INSERT ... ON CONFLICT (task_id, ticket_id) DO NOTHING`; `unlink(taskId, ticketId)` is a delete; `setLinkType(taskId, ticketId, linkType)` mutates an existing row. `link_type` is constrained to `related | blocks | fixes`. Linker actor (`linked_by_type` / `linked_by_id`) is recorded for audit-style queries. Organization is auto-resolved from the task when not supplied so accountless ticket links land cleanly.
- Hydration helpers (`ticketsForTaskHydrated`, `tasksForTicketHydrated`) walk the join + delegate to `TicketsService@tickets` / PM's own `TaskService` to return `[ { link, ticket } ]` / `[ { link, task } ]` arrays the UI can render in one pass.
- New CBWire `TaskTicketLink@tesserabx-pm` embedded on the task detail page. Lists currently-linked tickets with subject + status + clickable link-type dropdown + unlink button, plus an inline form for attaching a new ticket by id with a link-type select.
- New ticket panel partial `views/panels/linked_tasks.bxm` registered via the manifest `ticketPanels` array. Lives in the host's ticket detail right column; read-only listing of PM tasks linked to the current ticket (writes happen on the PM task page). Resolves `TaskTicketService` from `application.wirebox` rather than DI because partials are rendered outside a wire/component DI context.
- New DTO `TaskTicketDto@tesserabx-pm` and contract `ITaskTicketService@tesserabx-pm`. ModuleConfig gains the two bindings, the `ticketPanels` entry, and `ticketPanels` appended to `contributesTo`.
- New test bundle `TaskTicketServiceSpec` (6 specs): create + idempotent re-link, unlink leaves the ticket and task alive, invalid link_type rejected, setLinkType updates, symmetric `ticketIdsForTask` / `taskIdsForTicket`, hydration walks to PM tasks. `InstallSpec` adds 3 new probes (TaskTicketService binding, TaskTicketDto binding, `pm.linkedTasks` registered in `TicketPanelRegistry@tickets`). 53 specs total in InstallSpec.
- Deferred to Phase 8b: `CreateTaskFromTicketExecutor` + `TaskFromBulkTicketsExecutor` automation actions; `PmTaskLifecycleListener` close-on-complete prompt; SLA chip on the kanban TaskCard.

### Phase 7: Project Templates

- `TemplateService@tesserabx-pm` ships project template CRUD plus the two big primitives: `snapshotFromProject(projectId)` walks an existing project (statuses, labels, custom fields, tasks with relative date offsets, subtasks) and returns a structured snapshot; `hydrate(data)` applies a template to a freshly-created project, recomputing dates against the new project's `start_date`. Snapshots are persisted as TEXT JSON in `pm_project_templates.structure_json`; the helper `createFromProject(data)` combines snapshot + create in one call for the admin form's primary "create from project" path.
- Snapshot shape (versioned only by convention today; a `version` field can land later if the structure evolves):

  ```jsonc
  { statuses:[...], labels:[...], custom_fields:[...],
    tasks:[ {
        title, description, priority, is_client_visible,
        status_name,                          // matched by name into the destination project's statuses
        start_offset_days, due_offset_days,   // dateDiff from source project_start; null when source had no dates
        estimated_hours, sort_order,
        label_names: [...],                   // re-attached by name into the destination project's labels
        subtasks: [...]
    }, ... ] }
  ```

- Hydration is idempotent per-section: statuses delegate to `ProjectStatusService.hydrateFromTemplate` (Phase 2a guard already skips when present); labels / custom_fields / tasks each skip when the destination project already has any rows for that section. Hydration writes the `tesserabx-pm.template_applied` audit event that Phase 4b's manifest declared but no code fired until now.
- `ProjectService.createProject` switched from `ProjectStatusService.hydrateFromTemplate` (statuses only) to `TemplateService.hydrate` (full hydration). Default template remains the seeded shared "Standard Workflow" so a freshly-created project still ships with the canonical five-column kanban out of the box.
- New CBWires:
  - `TemplateManager@tesserabx-pm` at `/agent/admin/pm/templates`. Inline create (blank or from-project), rename, edit description, toggle shared, delete. The list shows per-template counts (statuses / labels / custom fields / tasks / subtasks) parsed from `structure_json` so the operator can see at a glance what a template will hydrate.
  - `TemplatePicker@tesserabx-pm` embedded inside `views/projects/new.bxm`'s create form. Card-grid selector with a hidden `templateSourceId` input that the existing POST handler picks up unchanged. Defaults to the shared "Standard Workflow" template id so an agent who skips the picker still gets a working board.
- New handler + view + routeClaim: `handlers/admin/Templates.bx`, `views/admin/templates/index.bxm`, and a `routeClaims` entry for `/agent/admin/pm/templates` (PM's `entryPoint = "agent/pm"` cannot reach the admin URL space, so it's claimed via the manifest the same way `/agent/admin/pm` is). `adminPages` manifest gains a `pm.admin.templates` card linked from the admin landing.
- New DTO: `TemplateDto@tesserabx-pm` with `fromTemplate` / `fromTemplateArray` returning snake_case structs and pre-parsed `structure`. New contract: `ITemplateService@tesserabx-pm`.
- New test bundle `TemplateServiceSpec` (6 specs): list returns shared seed, create blank, snapshot captures every section with computed offsets, hydration rebuilds rows + recomputes the due date against the new project's start, audit row lands, hard delete. `InstallSpec` adds 4 new probes: TemplateService binding, TemplateDto binding, `pm.admin.templates` adminPages entry, route claim for `/agent/admin/pm/templates`. 50 specs total in InstallSpec.
- Deferred: live edit of a template's structure (today the JSON snapshot is captured at create-from-project time and the admin edit form only touches name / description / shared flag — a structured edit UX over the JSON tree lands when there's a real need to mutate existing templates rather than re-snapshot from a current project).

### Phase 6b: Per-Project Custom Fields

- `CustomFieldService@tesserabx-pm` ships per-project custom field definitions plus polymorphic value storage over Task / Subtask. Seven field types per BUILD-PLAN §6: `text`, `number`, `date`, `dropdown`, `multiselect`, `checkbox`, `url`. `field_type` is intentionally immutable after create (changing it would silently invalidate stored values; delete-and-recreate is the migration path); name, applies_to, required flag, sort order, and options are mutable.
- Per-type `validateAndSerialize(field, rawValue)` enforces the BUILD-PLAN validation matrix:
  - `text` — passes through as-is.
  - `number` — `isNumeric` guard, stored as a decimal string.
  - `date` — `isDate` guard, normalised to ISO `yyyy-mm-dd`.
  - `checkbox` — coerced to `"true"`/`"false"`.
  - `url` — must start with `http://` or `https://`.
  - `dropdown` — value must be in the field's `options_json` set.
  - `multiselect` — every chosen value must be in `options_json`; stored as a JSON-encoded array of distinct values.
  - Required check fires across every type: an empty value on a required field throws `CustomFieldService.RequiredField`.
- Value storage uses `INSERT ... ON CONFLICT (custom_field_id, valuable_type, valuable_id) DO UPDATE` so `setValue` is idempotent and never produces duplicate rows; `setValue` with an empty value on an optional field clears the row instead. `valuesForValuable(valuableType, valuableId)` returns a decoded map keyed by `custom_field_id` (multiselect → array, checkbox → boolean, everything else → string).
- New CBWires:
  - `CustomFieldBuilder@tesserabx-pm` at `/agent/pm/projects/:projectId/custom-fields`. Inline add (name, type, applies_to, required, options-as-textarea for dropdown/multiselect), edit, delete. Type is locked in the edit view with a note about the migration path.
  - `CustomFieldsForm@tesserabx-pm` embedded on the task and subtask detail pages. Loads applicable fields via `listApplicableForValuable` (union of `applies_to = "both"` and the matching valuable type). Renders one input per field, type-appropriate: native `<input type=text|number|date|url>`, `<select>` for dropdown, button-row toggle for multiselect, switch for checkbox. Single "Save fields" button persists every value through the service's validator so required + format errors surface at the wire level.
- New handler + view + route: `handlers/CustomFields.bx`, `views/customFields/index.bxm`, and `route("projects/:projectId/custom-fields").to("CustomFields.index")` in `config/Router.bx`. Project show page gains a "Manage custom fields" entry-point card alongside the labels card.
- New DTOs: `CustomFieldDto@tesserabx-pm` (parses `options_json` back into an array of strings) and `CustomFieldValueDto@tesserabx-pm` (raw value passthrough). New contract: `ICustomFieldService@tesserabx-pm`.
- New test bundle `CustomFieldServiceSpec` (13 specs covering create, type validation, duplicate-name reject, applies_to filter, every type's value round-trip, required throw, number/dropdown/url format throws, optional clear, upsert no-dup, cascade on field delete, subtask polymorphism). `InstallSpec` adds 3 new probes (CustomFieldService binding, CustomFieldDto binding, CustomFieldValueDto binding). 46 specs total in InstallSpec.
- Deferred to Phase 10 (List / Calendar views): board-level filtering by custom field value. The schema and service already support it; the kanban UI just needs the picker, which is meaningfully more complex than the label chip-row and was de-scoped to keep Phase 6b focused on definitions + value capture.

### Phase 6a: Labels

- `LabelService@tesserabx-pm` ships per-project label CRUD plus task attach/detach. `pm_labels(project_id, name)` is unique so the same name can repeat across projects but never within one. Hard delete on `removeLabel` (no soft-delete column on `pm_labels`); the `pm_task_labels` FK cascade removes attached joins. `attachToTask` uses `INSERT ... ON CONFLICT DO NOTHING` for idempotency; `syncTaskLabels(taskId, labelIds)` reconciles attach + detach in a single call so the picker can save a multi-select with one wire action.
- New CBWires:
  - `LabelManager@tesserabx-pm` at `/agent/pm/projects/:projectId/labels`. Inline add + rename + recolor + delete UI, with the unique-name error surfaced as a wire notice.
  - `LabelPicker@tesserabx-pm` embedded on the task detail page. Chip-style multi-select; clicking a chip toggles attach/detach immediately via `syncTaskLabels`. Each chip uses the label's color when selected. "Manage" link jumps to the project's label admin page.
- `BoardService.buildBoard` and `buildColumn` accept a `labelIds` filter; results narrow to tasks that wear at least one of the supplied labels (OR semantics across the selection). Filtering happens in a single batched query against `pm_task_labels` after the task list is fetched, so the kanban path stays O(tasks-in-project) regardless of label cardinality. The board result also carries a `labelsByTask` map (one batched join, returning `{ id, name, color }` per attached label) so the kanban card template can render label chips inline without N+1.
- Kanban TaskCards render attached labels as a small pill-style row above the metadata line, using each label's color. Hidden when a task has no labels.
- `KanbanBoard` wire gains a `labelIds` array in `data` (queryString-persisted) and a `toggleLabel(labelId)` action; the template renders a chip-row label filter under the search/priority/assignee row, hidden when the project has no labels defined.
- Project show page gains a "Manage labels" entry-point card with a direct link to the project's label admin.
- New handler / view / route: `handlers/Labels.bx`, `views/labels/index.bxm`, and `route("projects/:projectId/labels").to("Labels.index")` in `config/Router.bx`.
- New DTO: `LabelDto@tesserabx-pm` with `fromLabel` / `fromLabelArray`. New contract: `ILabelService@tesserabx-pm`.
- New test bundle `LabelServiceSpec` (8 specs): create, duplicate-name reject (case-insensitive, scoped per project), cross-project name reuse, rename with re-check, hard delete cascades the join, idempotent attach, `syncTaskLabels` add+remove reconciliation, hydrated `labelsForTask`. `InstallSpec` adds 2 new probes (LabelService binding, LabelDto binding). 43 specs total in InstallSpec.
- Deferred to Phase 6b and beyond: inline label assignment from the kanban TaskDetail offcanvas (assignment happens from the task show page picker today).

### Phase 5: Time Tracking

- `TimeTrackingService@tesserabx-pm` ships polymorphic time-log CRUD over Task and Subtask (`loggable_type` + `loggable_id`) and over Agent / Contact (`user_type` + `user_id`). `createTimeLog` enforces the BUILD-PLAN §3.7 per-project opt-in: it walks from the loggable up to the owning project and refuses if `pm_projects.time_tracking_enabled = false`, throwing `TimeTrackingService.TrackingDisabled` so the wire can render a clear message. Soft-delete via `deleted_at`.
- Rollup queries are pure SQL (same workaround as `ProjectEventService` — safe across thread contexts):
  - `totalsForLoggable(loggableType, loggableId)` — direct sum.
  - `totalsForTask(taskId)` — direct task hours plus all of its subtask hours.
  - `totalsForProject(projectId)` — every task and subtask under the project.
- Report queries:
  - `listLogs(filter)` — filter by `organizationId`, `projectId`, `userType`, `userId`, `fromDate`, `toDate`, `isBillable`, `loggableType`; the project filter expands through the task / subtask hierarchy. Capped at 1000 rows.
  - `totalsByUser(filter)` — grouped totals for the by-user report view.
  - `totalsByProject(filter)` — grouped totals via two SQL passes (task-direct + subtask-via-task) merged in BoxLang.
  - `weeklyForAgent(agentId)` — Monday-Sunday window for the dashboard widget.
- New CBWire `TimeLogger@tesserabx-pm` (composer + history + rollup badges). Hides the composer when the project has time tracking off; keeps the read-only history. Embedded on the task detail page below the CommentThread and on the new subtask show page.
- New CBWire `TimeReport@tesserabx-pm` for the standalone reports page at `/agent/pm/time-reports`. Filters (project, user type, user id, from/to date, billable) and a grouping toggle (by user / by project / raw list) all live in `queryString[]` so a shared link preserves the report state. Grand-total summary across the visible rows.
- New CBFM partial `views/widgets/time_this_week.bxm` driven by the `pm.timeThisWeek` dashboard widget. The host's dashboard renderer calls `TimeTrackingService.weeklyForAgent(agentId)` and hands the result to the partial as `data`. The whole card links through to `/agent/pm/time-reports`.
- New handler / view: `handlers/TimeReports.bx` and `views/time/reports.bxm` mount the report wire under the Agent layout.
- New subtask show page at `/agent/pm/subtasks/:id` (handler action `Subtasks.show`, view `views/subtasks/show.bxm`). Embeds the TimeLogger for the subtask alongside its details. The subtask titles in the parent task's subtask list now link through to this page.
- New DTO: `TimeLogDto@tesserabx-pm` with `fromTimeLog` / `fromTimeLogArray` returning snake_case structs. New contract: `ITimeTrackingService@tesserabx-pm`.
- Manifest deltas:
  - `dashboardWidgets` populated with the `pm.timeThisWeek` entry per BUILD-PLAN §9 Phase 5; `contributesTo` extended with `dashboardWidgets`.
  - `navigation` adds `pm.agent.time-reports` (agent surface, main menu, gated on `pm.view`).
- Router gains `GET /subtasks/:id` (handler-bound alongside the existing `POST /subtasks/:id` update) and `GET /time-reports`.
- New test bundle `TimeTrackingServiceSpec` (10 specs covering the disabled-gate, billable/non-billable splits, single-loggable totals, subtask-to-task rollup, project rollup across both kinds, by-user grouping, soft-delete invariants, validation throws). `InstallSpec` adds 4 new probes: `TimeTrackingService` binding, `TimeLogDto` binding, the `pm.timeThisWeek` widget in `DashboardWidgetRegistry@reporting`, and the `pm.agent.time-reports` nav entry. 41 specs total in InstallSpec.
- Deferred to later phases: dedicated permission for who can log time (current code gates on the project's `time_tracking_enabled` flag and the agent firewall; per-user "time-tracker" role lands when the BUILD-PLAN needs it); the cross-project per-agent estimate-vs-actual visualization (Phase 10 reporting lands the chart layer).

### Phase 4b: Project Event Log, Audit Events, Activity Feeds

- `ProjectEventService@tesserabx-pm` writes and reads PM's domain timeline (`pm_project_events`). `record(...)` appends one row with polymorphic subject (`project|task|subtask|comment`) and actor (`agent|contact|system`); `listForProject(projectId, filter)` and `listForSubject(subjectType, subjectId, filter)` return up to 200 newest-first rows with an optional `actorType` filter. INSERTs go through raw `queryExecute` rather than the Quick entity because the announce thread does not initialize Quick's column metadata reliably (per the global CLAUDE.md note on non-request JVM threads).
- `ProjectEventLogger` interceptor (`interceptors/ProjectEventLogger.bx`) listens to every PM lifecycle envelope (`onPmProjectCreated`, `onPmProjectArchived`, `onPmTaskCreated`, `onPmTaskAssigned`, `onPmTaskStatusChanged`, `onPmTaskCompleted`, `onPmSubtaskCreated`, `onPmSubtaskCompleted`, `onPmCommentAdded`) and appends a row to `pm_project_events` derived from the canonical envelope. Subject is resolved from `entity.type` / `entity.id`; the owning `project_id` is looked up by a single indexed read for task/subtask/comment subjects. Comments record against their **commentable** (task/subtask/project), not the comment itself, so `listForSubject("task", taskId)` returns the task's full timeline including comments.
- All PM announces switched to **synchronous** (`async=false`). With the lightweight interceptor (one INSERT per event), keeping announces sync eliminates the cross-thread row-lock deadlock and FK-ordering races that surfaced once `pm_project_events` started carrying live FK references. Heavier downstream listeners (webhook dispatch, AI fan-out) can re-introduce async paths case-by-case when they land.
- `ProjectEventLogger` declares `wirebox` as eager DI but resolves `ProjectEventService` via lazy `wirebox.getInstance()` because ColdBox instantiates module interceptors before the module's `onLoad()` registers per-module bindings.
- ModuleConfig declares the 10 PM custom interception points (`onPmProjectCreated`, `onPmProjectArchived`, `onPmTaskCreated`, `onPmTaskAssigned`, `onPmTaskStatusChanged`, `onPmTaskCompleted`, `onPmSubtaskCreated`, `onPmSubtaskCompleted`, `onPmCommentAdded`, `onPmMentioned`) in `interceptorSettings.customInterceptionPoints` so listeners get auto-registered for them.
- `auditEvents` manifest populated with the five PM compliance types: `project_created`, `project_archived`, `project_deleted` (severity `warning`), `task_assigned_to_contact`, `template_applied` (declared for Phase 7's TemplateService; no PM code fires it yet). `contributesTo` extended with `auditEvents`.
- Inline `AuditService@audit.record(...)` writes from the service layer: `ProjectService.createProject` / `archiveProject` already shipped in Phase 2a; `ProjectService.removeProject` now writes `tesserabx-pm.project_deleted`; `TaskService` adds `auditAssignmentToContact(...)` called from `createTask` and `updateTask` whenever the assignee lands on a Contact. Pattern matches the existing `writeAuditEvent` helper.
- New CBWire components for the activity surface:
  - `ProjectEventFeed@tesserabx-pm` embedded on `views/projects/show.bxm`. Renders a newest-first timeline scoped to the project plus a `wire:model.live` actor filter (`all` / `agent` / `contact` / `system`).
  - `TaskEventFeed@tesserabx-pm` embedded on `views/tasks/show.bxm` alongside the Phase 4a CommentThread. Renders the task-scoped timeline (including its comment events).
- New DTO: `ProjectEventDto@tesserabx-pm` with `fromEvent` / `fromEventArray` returning snake_case structs, parsing `changes_json` back to a struct.
- New test bundles: `ProjectEventServiceSpec` (7 specs), `ProjectEventLoggerSpec` (5 specs covering project / task / subtask / comment paths). `InstallSpec` adds 3 new probes: two service bindings (`ProjectEventService`, `ProjectEventDto`) and an `AuditService.listEventTypes()` probe asserting all 5 PM compliance types surface in the audit search dropdown. 37 specs total in InstallSpec.
- Design call recorded against BUILD-PLAN §9 Phase 4: the spec lists both a `PmEventAnnouncer` interceptor (emits canonical envelopes) and a `ProjectEventLogger` (writes the timeline). Phase 2+ services already build canonical envelopes inline via `EventPayloadBuilder@core` so a separate announcer is redundant; Phase 4b ships only the logger. The decision is recorded so a later phase can revisit if a host module wants to wholesale rewrap PM events.
- Deferred to later phases: `onPmTaskUpdated` (no service site emits it yet, and the granular updates in the current `updateTask` would create noisy timeline rows); `onPmMentioned` (declared as a custom interception point but no service fires it); UI rendering of the `changes_json` per-action (the current feed shows the action name, actor, and timestamp; per-action templates land when the spec firms up).

### Phase 4a: Comments, Mentions, Watchers

- `CommentService@tesserabx-pm` ships polymorphic comment CRUD across Project / Task / Subtask. `listForCommentable(commentableType, commentableId, viewer)` filters `is_internal=true` rows from contact viewers. BUILD-PLAN §3.5 `is_internal` policy enforced at the service layer: agent authors default true (the composer can flip it off); contact authors are always forced false even if the caller passes `isInternal=true`. Soft delete via `deleted_at`. Emits `onPmCommentAdded` async.
- `MentionService@tesserabx-pm` parses `@agent:<token>` and `@contact:<token>` mention forms from a comment body and writes `pm_mentions` rows. Pure-write from the comment perspective: `extractMentions(body)` is the regex-only parser (used by the template's mention-chip renderer), `recordMentions(commentId, organizationId, body)` runs the parser + persists. Dedupes repeated mentions of the same user inside one body.
- `WatcherService@tesserabx-pm` is polymorphic on both sides: watchable (`project|task|subtask`) and watcher (`agent|contact`). `watch` / `unwatch` / `toggle` / `isWatching` / `listForWatchable`. Two auto-add hooks: `autoWatchOnAssignment(...)` and `autoWatchOnComment(...)`. Idempotent — the DB unique constraint dedupes at the row level so re-adding an existing watcher is a no-op.
- Hooks wired:
  - `TaskService.createTask` and `updateTask` call `watcherService.autoWatchOnAssignment(...)` when the assignee column changes.
  - `CommentService.createComment` calls `watcherService.autoWatchOnComment(...)` plus `mentionService.recordMentions(...)` for every successful create.
- New contracts: `ICommentService@tesserabx-pm`, `IWatcherService@tesserabx-pm`.
- New DTO: `CommentDto@tesserabx-pm` with `fromComment` / `fromCommentArray` returning snake_case structs.
- New CBWire component: `CommentThread@tesserabx-pm` (in `wires/CommentThread.bx` + `wires/commentThread.bxm`). Composer + flat chronological thread + agent-side `is_internal` toggle (defaults true; switch off for client-visible replies) + author-only delete button. Mention chips rendered inline via a template-side regex replace so `@agent:alice` shows up as a badge. Embedded on the task detail page (`views/tasks/show.bxm`) with `#wire( name = "CommentThread@tesserabx-pm", params = { commentableType : "task", commentableId : ..., organizationId : ... } )#`.
- Manifest `webhookEvents` populated with 9 lifecycle keys: `project_created` / `project_archived`, `task_created` / `task_assigned` / `task_status_changed` / `task_completed`, `subtask_created` / `subtask_completed`, `comment_added`. Hooks back to the canonical envelopes PM services already emit via `EventPayloadBuilder@core` from Phase 2 onward.
- `contributesTo` extended with `apiResources`, `webhookEvents`, `assets` so the host's admin add-ons page surfaces the full Phase 4a contribution catalog.
- New test bundles: `CommentServiceSpec` (6 specs), `MentionServiceSpec` (5 specs), `WatcherServiceSpec` (5 specs). `InstallSpec` adds 5 new probes: three service bindings, CommentDto binding, and a webhookEvents probe asserting all 9 lifecycle keys land in `WebhookEventRegistry@api`. 34 specs total in InstallSpec.
- Deferred to Phase 4b: `ProjectEventLogger` interceptor (listens for `onPm*` events and writes `pm_project_events` rows); project event feed view + per-task event view; `auditEvents` manifest declarations; audit-log writes when a task assignment crosses to a Contact (BUILD-PLAN §3.11 compliance event `tesserabx-pm.task_assigned_to_contact`).
- Deferred to a later Phase 4 pass: threaded comment display (the schema supports `parent_comment_id`; the v1 UI is flat chronological); the `@agent:slug` / `@contact:slug` autocomplete dropdown in the composer.

### Phase 3b: CBWire Kanban + Drag-and-Drop

- `KanbanBoard@tesserabx-pm` CBWire component replaces the server-rendered board view from Phase 3a. Mounted from `views/tasks/index.bxm` with `#wire( name = "KanbanBoard@tesserabx-pm", params = { projectId : ... } )#`. State (`q`, `priority`, `assigneeType`, `assigneeId`) is URL-persisted via `queryString` so a refreshed board keeps the filter applied. Transient state (`detailTaskId`, `notice`/`noticeKind`) is component-local.
- Live filters via `wire:model.live` (search uses `.debounce.300ms` so each keystroke does not slam the server).
- Quick-add per column via `wire:submit.prevent`: pressing Enter on the column's title input creates a minimal task at the bottom of that column, then clears the input.
- TaskDetail offcanvas: clicking a card sets `data.detailTaskId`, the template conditionally renders a Bootstrap-styled offcanvas with the task's fields, and `wire:submit.prevent="saveDetail(...)"` persists edits through `TaskService.updateTask`.
- Drag-and-drop wired via SortableJS (vendored under `resources/vendor/sortablejs-1.15.6/Sortable.min.js`) + `resources/js/board.js`. The component template emits `data-pm-kanban-column-status` on each column wrapper, `data-pm-kanban-column` on the body (the SortableJS drop zone), and `data-pm-task-id` on each card. The bootstrap script inside the template hooks `livewire:init` + `component.init` with an ID match (per the global CLAUDE.md rule) and calls `tesserabxPmKanban.init(componentId)`. The drag-end callback calls `wire.call("persistReorder", taskId, statusId, slotIndex)`.
- `TaskService@tesserabx-pm` gains `reorderTask(id, targetStatusId, targetIndex, data)`. The implementation is a per-column re-sequence: the moved task is placed at `slotIndex` inside the destination column, all rows in the destination are re-numbered in 10-step gaps, and the source column (if different) is recompacted. Status transitions stamp / clear `completed_at` and emit the same `onPmTaskStatusChanged` + `onPmTaskCompleted` lifecycle events `updateTask` does, with `metadata.source = "drag-drop"` for downstream observability.
- `resources/css/board.css` extracts the inline styles from Phase 3a and adds the SortableJS state classes (`pm-task-card-ghost`, `pm-task-card-chosen`, `pm-task-card-drag`) plus a drop-zone tint via `.pm-column-receiving`.
- `settings.tesserabx.assets` declares the three assets on the agent surface so the host's `AddonAssetService@core` emits the `<link>` and `<script>` tags into the Agent layout: `/modules/tesserabx-pm/resources/css/board.css`, `/modules/tesserabx-pm/resources/vendor/sortablejs-1.15.6/Sortable.min.js`, and `/modules/tesserabx-pm/resources/js/board.js` (deferred).
- `TaskServiceSpec` adds a `reorderTask` describe block: head-of-column re-numbering, cross-column move with `completed_at` toggle, and cross-project status rejection. `InstallSpec` adds three probes: CSS asset registered, both JS assets registered.
- Two integer-binding bugs fixed during local verification: the `reorderTask` `UPDATE`s now `cast( :so as integer )` because the JDBC bind layer defaults numeric parameters to varchar (same flavor as the `estimated_hours` and `deleted_at` NULL workarounds in earlier phases).
- Deferred to Phase 3c: per-project ProjectStatus CRUD UI (rename / recolor / reorder / add custom statuses) accessible from a settings cog on the board header; the `pm.recentActivity` dashboard widget; replacing the paste-a-UUID assignee inputs with a real agent/contact picker.

### Phase 3a: BoardService and the Kanban View

- `BoardService@tesserabx-pm` owns the kanban grouping pipeline. `buildBoard(projectId, filters)` returns `{ statuses, columns, totalTasks, filters }` where `columns` is a struct keyed by `statusId` (plus an empty-string bucket for tasks whose `status_id` is null or refers to a removed row). `buildColumn(projectId, statusId, filters)` returns just one bucket; the Phase 3b CBWire layer will call this for the per-column re-renders that follow a drag-drop or quick-add.
- `handlers/Tasks.bx` `index` action now hands off to `BoardService` and populates `prc.board`. The inline `groupTasksByStatus` helper is gone.
- New action `Tasks.quickAdd` at `POST /agent/pm/projects/:projectId/tasks/quick-add` takes a single `title` field plus the hidden `statusId` from the column form and creates a minimal task, bouncing back to the board.
- `views/tasks/index.bxm` overhauled:
  - Filter card: search (matches title), priority, assignee type.
  - Header summarizes total tasks and column count.
  - Each column is fixed-width with a horizontal-scroll container, so adding more statuses does not collapse the layout.
  - Each column has a quick-add input pinned to the footer (Enter submits; empty titles silently no-op).
  - Task cards show priority badge, assignee chip, due date, client-visible eye, and completed checkmark.
  - Scoped `.pm-board / .pm-column / .pm-task-card` CSS in a `<style>` block; Phase 3b moves this to a real asset and adds SortableJS.
- New `tests/specs/unit/BoardServiceSpec.bx`: 6 specs covering column shape (statuses + empty bucket), status bucketing, search/priority filters, normalized filters echo, and `buildColumn` for the single-column re-render.
- `InstallSpec.bx` gains a `BoardService@tesserabx-pm` WireBox-binding probe. 27 specs total.
- Deferred to Phase 3b: CBWire components (`KanbanBoard`, `TaskCard`, `TaskDetail` flyout), SortableJS drag-and-drop with `sort_order` + `status_id` persistence, status-column management UI accessible from the board, the per-project ProjectStatus CRUD, the dashboard `pm.recentActivity` widget, and the `assets` manifest entries for `board.js` + `board.css`.

### Phase 2c: REST API and `pm.assign-client` Enforcement

- Three new API handlers under `handlers/api/v1/`: `Projects.bx`, `Tasks.bx`, `Subtasks.bx`. Each follows the host's `ensureAgent` JWT-guard pattern (mirrors `modules_app/api/handlers/Tickets.bx`): per-action guard reads the bearer via `JwtService@cbsecurity`, returns 401 when missing/invalid, 403 when the token lacks the `agent` role. Every action returns JSON via `event.renderData( type="json", statusCode=..., data=... )` using the existing `ProjectDto`, `TaskDto`, `SubtaskDto` mappers for serialization. Errors raised by the service layer (UnknownProject, InvalidVisibilityScope, InvalidAssignee, etc.) become 400s with a `{ error : "..." }` body; 404 for missing entities; 204 on soft-delete.
- 16 new `routeClaims` entries in the manifest cover the full CRUD surface. Each `(path, verb)` pair gets its own claim so the host's `AddonRouteClaimsRegistrar` interceptor wires them into ColdBox's main router on `afterAspectsLoad`.
- 16 matching `apiResources` entries register each endpoint with `ApiResourceRegistry@api` so cbswagger and the admin diagnostics surface have a machine-readable catalog of what PM exposes under `/api/v1/pm/*`. Each entry declares `requiredPermission` (`pm.view`/`pm.create`/`pm.edit`/`pm.delete`) for the future per-endpoint authorization layer.
- BUILD-PLAN §3.4 enforcement: both `TaskService` and `SubtaskService` reject a `contact` actor attempting a `contact` assignee, throwing `TaskService.Forbidden` / `SubtaskService.Forbidden`. The check sits in the service layer so the rule holds regardless of the calling surface (HTML agent handler, REST API, future portal handler).
- New tests:
  - `TaskServiceSpec`: +3 specs for `pm.assign-client` enforcement (contact actor forbidden, agent actor allowed, update guard).
  - `InstallSpec`: +3 probes verifying every API endpoint path lands in `RouteClaimsRegistry@core` and every endpoint id lands in `ApiResourceRegistry@api`, plus a shape check on `pm.projects.list`.
- Smoke-tested locally: every `/api/v1/pm/*` URL responds 401 with `{ "error" : "TokenNotFoundException: ..." }` when called without a bearer; route claims wired up cleanly with no false 404s.
- Deferred to Phase 2d (or later): per-project ProjectStatus CRUD UI; `config/cbSecurity.bx` per-action gating in addition to the service-layer guard (the agent firewall already covers `/agent/pm/*` coarsely); handler integration tests; agent/contact assignee picker; an actual end-to-end JWT round trip in the test suite.

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
