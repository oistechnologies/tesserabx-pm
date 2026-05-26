# tesserabx-pm

**Project Management for TesseraBX.**

`tesserabx-pm` is a third-party add-on for the [TesseraBX](https://github.com/oistechnologies/tesserabx) helpdesk and customer support platform. It adds full-featured project management on top of the host: projects, tasks, subtasks, customizable kanban boards, time tracking, templates, per-project custom fields, bidirectional ticket integration, @mentions, watchers, notifications, a client-portal surface, and pgvector-backed AI augmentation through the host's AI middleware.

The add-on installs into a running TesseraBX deployment as a standard ColdBox 8 module at `modules/tesserabx-pm/` and participates in the host's `settings.tesserabx` manifest contract.

## Feature Inventory

| Surface | What lands |
| --- | --- |
| **Agent** | Project list with search / filter / archive; project show + overview report (printable); kanban board with drag-and-drop; list view (sortable, inline edit); calendar view (monthly grid); my-tasks (cross-project assignee + watcher view); per-project status / label / custom-field admin; templates admin with snapshot + duplicate + preview; time reports; task detail with comments / mentions / subtasks / linked tickets / activity feed |
| **Portal** | Client-facing project list scoped to the contact's organization; project detail; task detail with comment composer; self-watch toggle |
| **Admin** | PM admin dashboard (`/agent/admin/pm`) with headline stats, embedding backfill button, per-tenant default-template picker; templates CRUD at `/agent/admin/pm/templates` |
| **AI (gated on `AI_ENABLED`)** | Related-tasks panel (semantic similarity); summarize-thread on any comment thread; suggested assignees on the task edit form; explainable priority score on the "My recommended next task" dashboard widget |
| **API** | REST endpoints for projects, tasks, subtasks (CRUD + archive/restore). See [`docs/API.md`](docs/API.md) for the full catalog |
| **Automation** | One declared action (`tesserabx-pm.createTaskFromTicket`) for the host's automation engine |
| **Notifications** | 23 notification templates across in-app + email × agent + contact for every PM lifecycle event (task assigned, comment added, mentioned, status changed, completed, due soon, overdue) |

## Status

**v1.0.0 release prep.** All 13 phases of the [build plan](docs/BUILD-PLAN.md) are landed and CI is green; this branch is the release candidate. See [`CHANGELOG.md`](CHANGELOG.md) for what each phase added.

## Requirements

PM inherits the TesseraBX host's runtime. There is no separate PM stack.

- TesseraBX host `>= 0.0.1`
- ColdBox 8+
- BoxLang
- PostgreSQL 16 with `pgvector`
- Redis (CacheBox + cbq)

## Install

Once published to ForgeBox:

```bash
box install tesserabx-pm
```

Until then, clone into the host's `modules/` directory:

```bash
git clone https://github.com/oistechnologies/tesserabx-pm.git modules/tesserabx-pm
```

The host's `AddonDiscoveryInterceptor` picks up `tesserabx-pm` on next boot, validates `minCoreVersion` against the running `appVersion`, and upserts a row in the host's `addons` table.

After install, run migrations from the host repo root:

```bash
box run-script migrate:stage
box run-script migrate:up
```

## Configuration

### Per-tenant settings

| Key | Type | Default | Notes |
| --- | --- | --- | --- |
| `pm.default-template-id` | string | `""` | Template applied on new project creation. Blank uses the shared Standard Workflow. Set via `/agent/admin/pm` "Default project template" picker |

Other host-level env vars PM reads (set on the host):

| Env var | Purpose |
| --- | --- |
| `AI_ENABLED` | When `false`, every PM AI surface (Related tasks, Summarize, Suggest, Explain) is invisible and the underlying services short-circuit |
| `AI_EMBEDDING_MODEL` | The embedding dimension must match `pm_tasks.embedding` (1536 by default). Changing this requires a migration to alter the column |
| `SCHEDULER_MODE` | PM's `pm:scan-due-soon` and `pm:scan-overdue` schedulers gate on this so app + worker containers do not double-fire |

### Roles

PM ships six roles via the host's `RoleRegistry`. Grant manually on existing accounts (the host's agent-admin role does not auto-include add-on permissions):

- Agent-side: `pm-admin`, `pm-manager`, `pm-contributor`, `pm-viewer`
- Contact-side: `pm-client-viewer`, `pm-client-contributor`

## Local Development

PM does not run its own server. Develop against the host's dev stack with PM bind-mounted in.

1. **Clone PM next to (not inside) the host repo:**

   ```text
   /Users/you/code/tesserabx/        # host
   /Users/you/code/tesserabx-pm/     # this repo
   ```

2. **Copy `compose.override.yaml.example`** from this repo into the host repo root as `compose.override.yaml`, and update the host path to match your layout.

3. **From the host repo root, bring the stack up:**

   ```bash
   docker compose -f compose.yaml -f compose.dev.yaml -f compose.override.yaml up
   ```

4. **Stage and run migrations** from the host repo root:

   ```bash
   box run-script migrate:stage
   box run-script migrate:up
   ```

5. **Run the test suite.** PM specs are auto-discovered alongside host specs:

   ```bash
   box run-script test:run
   ```

   To scope to PM specs only:

   ```bash
   box testbox run directory=modules.tesserabx-pm.tests.specs
   ```

## Documentation

- [`docs/USAGE.md`](docs/USAGE.md): feature walkthrough by surface
- [`docs/API.md`](docs/API.md): REST endpoint reference
- [`docs/BUILD-PLAN.md`](docs/BUILD-PLAN.md): authoritative build plan, architecture, entity model, phase definitions
- [`docs/CBWIRE-TMP-TRUNCATION-BUG.md`](docs/CBWIRE-TMP-TRUNCATION-BUG.md): documented BoxLang / CBWire parser gotcha and workarounds
- [`CONTRIBUTING.md`](CONTRIBUTING.md): post-v1 contribution + branch workflow
- [`CHANGELOG.md`](CHANGELOG.md): per-phase change history
- Host extension contract: [`docs/EXTENSIONS.md`](https://github.com/oistechnologies/tesserabx/blob/main/docs/EXTENSIONS.md) in the host repo

## License

[Apache 2.0](LICENSE).
