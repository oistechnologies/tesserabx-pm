# tesserabx-pm

**Project Management for TesseraBX.**

`tesserabx-pm` is a third-party add-on for the [TesseraBX](https://github.com/oistechnologies/tesserabx) helpdesk and customer support platform. It adds full-featured project management: projects, tasks, subtasks, customizable kanban boards, time tracking, templates, per-project custom fields, bidirectional ticket integration, @mentions, watchers, notifications, a client-portal surface, and pgvector-backed AI augmentation through the host's AI middleware.

The add-on installs into a running TesseraBX deployment as a standard ColdBox 8 module at `modules/tesserabx-pm/` and participates in the host's `settings.tesserabx` manifest contract.

## Status

Pre-1.0, scaffold in place. See [`CHANGELOG.md`](CHANGELOG.md) for the current phase. The full build plan lives in [`docs/BUILD-PLAN.md`](docs/BUILD-PLAN.md).

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

## Local Development

PM does not run its own server. Develop against the host's dev stack with PM bind-mounted in.

**1. Clone PM next to (not inside) the host repo:**

```text
/Users/you/code/tesserabx/        # host
/Users/you/code/tesserabx-pm/     # this repo
```

**2. Copy `compose.override.yaml.example`** from this repo into the host repo root as `compose.override.yaml`, and update the host path to match your layout.

**3. From the host repo root, bring the stack up:**

```bash
docker compose -f compose.yaml -f compose.dev.yaml -f compose.override.yaml up
```

**4. Stage and run migrations** from the host repo root:

```bash
box run-script migrate:stage
box run-script migrate:up
```

**5. Run PM specs.** They run as part of the host TestBox suite. The host's `tests/runner.bxm` auto-discovers `modules/<addon>/tests/specs/` for any folder whose `ModuleConfig.bx` declares `settings.tesserabx`, so PM specs are picked up by `box run-script test:run` along with the host's own:

```bash
box run-script test:run
```

To scope a run to just PM's specs during a tight feedback loop, target the directory explicitly:

```bash
box testbox run directory=modules.tesserabx-pm.tests.specs
```

## Documentation

- [`docs/BUILD-PLAN.md`](docs/BUILD-PLAN.md): authoritative build plan, architecture, entity model, phase definitions.
- [`CLAUDE.md`](CLAUDE.md): instructions for Claude Code working in this repo.
- Host extension contract: [`docs/EXTENSIONS.md`](https://github.com/oistechnologies/tesserabx/blob/main/docs/EXTENSIONS.md) in the host repo.
- Host reference add-on (the source of every PM convention): [`sample-addons/example-sync/`](https://github.com/oistechnologies/tesserabx/tree/main/sample-addons/example-sync) in the host repo.

## License

[Apache 2.0](LICENSE).
