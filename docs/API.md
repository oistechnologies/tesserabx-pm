# tesserabx-pm: REST API Reference

All PM endpoints are version-prefixed at `/api/v1/pm/` and routed through the host's API surface. Every endpoint is gated by the host's API authentication layer and a PM permission per the host's `cbSecurity` rules; the `requiredPermission` column below maps directly to the `permissions` PM declares in its manifest.

The endpoint catalog is registered with the host's `ApiResourceRegistry@api`, so it surfaces in the host's OpenAPI / swagger output without any add-on-specific config.

## Conventions

- **Auth.** The host's API firewall covers every `/api/v1/*` path. Authenticate per the host's documented mechanism.
- **Tenancy.** Projects (and everything attached to them) are tenant-scoped through `TenantScope@contacts`. The auth context determines the visible org; cross-tenant lookups by an agent with `pm.view` succeed, but contact-side callers see only their organization.
- **Content type.** Requests with bodies should send `Content-Type: application/json`. Responses are JSON.
- **Errors.** Service-layer exceptions (e.g. `ProjectService.MissingField`, `TaskService.InvalidStatus`) surface as `4xx` with a `{ error : "..." }` payload.
- **Pagination.** List endpoints return up to 500 rows by default. Pass `?limit=N` to narrow; `?offset=N` to page.
- **Soft delete.** `DELETE` endpoints soft-delete (`deleted_at = now()`). Restore endpoints flip it back.

## Projects

| Method | Path | Permission | Notes |
| --- | --- | --- | --- |
| `GET` | `/api/v1/pm/projects` | `pm.view` | List projects visible to the auth context. Filters: `q` (name search), `organizationId`, `lifecycleStatus`, `includeArchived` |
| `POST` | `/api/v1/pm/projects` | `pm.create` | Body: `{ organizationId, name, description?, visibilityScope?, startDate?, endDate?, timeTrackingEnabled?, templateSourceId? }` |
| `GET` | `/api/v1/pm/projects/:id` | `pm.view` | Single project by id |
| `PATCH` | `/api/v1/pm/projects/:id` | `pm.edit` | Body: subset of create fields |
| `DELETE` | `/api/v1/pm/projects/:id` | `pm.delete` | Soft-delete |
| `POST` | `/api/v1/pm/projects/:id/archive` | `pm.edit` | Flip `lifecycle_status` to `archived` (NOT a delete) |
| `POST` | `/api/v1/pm/projects/:id/restore` | `pm.edit` | Restore from archive or soft-delete |

## Tasks

| Method | Path | Permission | Notes |
| --- | --- | --- | --- |
| `GET` | `/api/v1/pm/projects/:projectId/tasks` | `pm.view` | List tasks in a project. Filters: `statusId`, `assigneeType`, `assigneeId`, `priority`, `search`, `labelIds[]` |
| `POST` | `/api/v1/pm/projects/:projectId/tasks` | `pm.create` | Body: `{ title, description?, statusId?, priority?, assigneeType?, assigneeId?, startDate?, dueDate?, estimatedHours?, isClientVisible?, sortOrder? }` |
| `GET` | `/api/v1/pm/tasks/:id` | `pm.view` | Single task |
| `PATCH` | `/api/v1/pm/tasks/:id` | `pm.edit` | Body: subset of create fields. Status transitions auto-fill / clear `completed_at` based on the target status's `is_completed` flag |
| `DELETE` | `/api/v1/pm/tasks/:id` | `pm.delete` | Soft-delete |

## Subtasks

| Method | Path | Permission | Notes |
| --- | --- | --- | --- |
| `GET` | `/api/v1/pm/tasks/:taskId/subtasks` | `pm.view` | List subtasks in a task |
| `POST` | `/api/v1/pm/tasks/:taskId/subtasks` | `pm.create` | Body: `{ title, description?, assigneeType?, assigneeId?, dueDate?, estimatedHours?, sortOrder? }` |
| `PATCH` | `/api/v1/pm/subtasks/:id` | `pm.edit` | Body: subset of create fields, plus `isCompleted` for the inline completion toggle |
| `DELETE` | `/api/v1/pm/subtasks/:id` | `pm.delete` | Soft-delete |

## Webhooks

PM announces canonical event envelopes through the host's `EventPayloadBuilder@core`. Every PM lifecycle event is also a registered webhook event key so external subscribers can react.

| Event key | Fired by | Includes |
| --- | --- | --- |
| `tesserabx-pm.project_created` | `ProjectService.createProject` | `{ entity, actor }` |
| `tesserabx-pm.project_archived` | `ProjectService.archiveProject` | `{ entity, actor }` |
| `tesserabx-pm.task_created` | `TaskService.createTask` | `{ entity, actor }` |
| `tesserabx-pm.task_assigned` | `TaskService.updateTask` when assignee changes | `{ entity, actor, previousAssignee }` |
| `tesserabx-pm.task_status_changed` | `TaskService.updateTask` when status changes | `{ entity, actor, previousStatus }` |
| `tesserabx-pm.task_completed` | `TaskService.updateTask` on transition into a completed status | `{ entity, actor }` |
| `tesserabx-pm.subtask_created` | `SubtaskService.createSubtask` | `{ entity, actor }` |
| `tesserabx-pm.subtask_completed` | `SubtaskService.complete` | `{ entity, actor }` |
| `tesserabx-pm.comment_added` | `CommentService.createComment` | `{ entity, actor, commentable }` |
| `tesserabx-pm.mentioned` | `MentionService.recordMentions` per parsed mention | `{ comment, actor, mentioned }` |
| `tesserabx-pm.ticket_linked` | `TaskTicketService.link` | `{ task, ticket, linkType }` |
| `tesserabx-pm.ticket_unlinked` | `TaskTicketService.unlink` | `{ task, ticket }` |
| `tesserabx-pm.task_due_soon` | `PmTaskDueScanService.scanDueSoon` (scheduled) | `{ task }` |
| `tesserabx-pm.task_overdue` | `PmTaskDueScanService.scanOverdue` (scheduled) | `{ task }` |

Configure subscribers through the host's webhook subscription admin.

## Admin endpoints (agent surface, not under `/api/v1/`)

These are operator endpoints behind the agent firewall; not part of the public REST API.

| Method | Path | Notes |
| --- | --- | --- |
| `POST` | `/agent/admin/pm/embed-backlog` | Returns the embedding-scheduler report as JSON. Useful from scripts |
| `POST` | `/agent/admin/pm/embed-backlog-ui` | Same sweep, but messageboxes the report and relocates to the admin landing |
| `POST` | `/agent/admin/pm/default-template` | Saves the per-tenant `pm.default-template-id` setting via `SettingsRegistry@core` |

## Permissions reference

| Permission id | Default-included in roles | What it gates |
| --- | --- | --- |
| `pm.view` | every PM role | Read PM data |
| `pm.create` | pm-admin, pm-manager, pm-contributor | Create projects + tasks + subtasks |
| `pm.edit` | pm-admin, pm-manager, pm-contributor, pm-client-contributor | Update entities, comments, labels, custom field values |
| `pm.delete` | pm-admin, pm-manager | Soft-delete projects + tasks + subtasks |
| `pm.assign-client` | pm-admin, pm-manager | Assign tasks to contacts (not just agents) |
| `pm.admin` | pm-admin | Templates, project-status sets, per-project custom fields, per-tenant PM settings |
