# Contributing to tesserabx-pm

Thanks for considering a contribution. This doc captures the workflow that takes effect at `v1.0.0`. The pre-1.0 direct-to-`main` workflow described in BUILD-PLAN §4.3 ended with the v1.0.0 tag.

## Workflow at a glance

1. Open an issue describing the change.
2. Branch from `main` using a `feature/<slug>` or `fix/<slug>` name.
3. Implement + test locally.
4. Push the branch + open a Pull Request.
5. Wait for CI green + one approving review.
6. Squash-merge into `main`.

## Branch policy

`main` is protected. Direct pushes are rejected. Every change lands through a PR that:

- Has a green CI run (`box run-script test:run` against the host stack).
- Has at least one approving review from a maintainer.
- Has a `CHANGELOG.md` entry describing the change.

## Local development

PM does not run its own server. Develop against the host's dev stack with PM bind-mounted in. See the [README](README.md#local-development) for the docker compose setup.

The whole-suite local check:

```bash
docker compose exec app box run-script test:run
```

To scope to PM specs during a tight feedback loop:

```bash
docker compose exec app box testbox run directory=modules.tesserabx-pm.tests.specs
```

## Commit messages

Conventional Commits. Common prefixes:

- `feat:` — new feature or surface
- `fix:` — bug fix
- `test:` — test-only change
- `docs:` — docs-only change
- `refactor:` — refactor with no behavior change
- `chore:` — tooling / build / housekeeping

## Adding a new feature

PM is structured as a host add-on; every feature touches one or more of these contracts (full reference in the host's [`docs/EXTENSIONS.md`](https://github.com/oistechnologies/tesserabx/blob/main/docs/EXTENSIONS.md)):

- **Manifest** in `ModuleConfig.bx` under `settings.tesserabx` — declare any new permission / role / nav / admin-page / route claim / API resource / webhook event / audit event / ticket panel / dashboard widget / automation action / notification template / per-tenant setting / AI feature / embedding consumer / asset / help section / help page contributions.
- **Migrations** under `migrations/` — schema changes go through the host's `migrate:stage` + `migrate:up` flow. The stager prefixes each PM migration with `_addon_tesserabx-pm_` automatically.
- **InstallSpec** at `tests/specs/InstallSpec.bx` — every manifest contribution gets a probe asserting the host registered it correctly. CI gate.
- **Per-service tests** at `tests/specs/unit/` — one spec bundle per service, with org-scoped fixtures and `afterEach` cleanup.

## Reviewing a PR

Reviewers should verify:

1. **InstallSpec covers every new manifest contribution.** If a PR adds a route claim, an admin page, or a widget, there must be a new probe.
2. **Migrations are reversible.** Both `up` and `down` should run cleanly against the test DB.
3. **AI surfaces are gated.** Any new UI that calls AI must contribute through a `requiresAi : true` registry path so the AI-off invariant holds (BUILD-PLAN §3.10).
4. **No `bx-ai` imports.** PM is forbidden from importing `bx-ai` directly. All AI calls go through `AiMiddleware@ai` (BUILD-PLAN §3.9, CLAUDE.md non-negotiable rule 2).
5. **Tenant scope.** New tenant-scoped entities must apply `TenantScope@contacts` from their first migration; hand-written qb queries that bypass it must use `TenancyGuard@contacts` (BUILD-PLAN §3.4).
6. **No em dashes.** Inherited from the host's style rule; check copy in code, comments, docs, commit messages, and UI strings.
7. **CHANGELOG entry.** Group the PR's changes under `[Unreleased]` until a tagged release.

## Releasing

Maintainers only.

1. Pick a target version per [SemVer](https://semver.org/).
2. Move the `[Unreleased]` section in `CHANGELOG.md` to `[X.Y.Z] — YYYY-MM-DD`.
3. Bump `version` in `box.json` and `this.version` + the `settings.tesserabx.version` in `ModuleConfig.bx`.
4. Commit on `main` (after PR merge), tag `vX.Y.Z`, push the tag.
5. Publish to ForgeBox: `box publish` from the repo root.
6. Cut a GitHub release with the CHANGELOG entry as the release notes body.

## Known parser gotchas

PM has hit a couple of BoxLang / CBWire parser issues that are worth knowing about:

- **`##` adjacent to a `#expression#`** inside a `<bx:output>` HTML attribute (typically `data-bs-target="#id"` for Bootstrap collapse toggles) can produce an "Unclosed output tag on line 1" parse error. Use `#char(35)#` for the literal `#` instead. Full writeup in [`docs/CBWIRE-TMP-TRUNCATION-BUG.md`](docs/CBWIRE-TMP-TRUNCATION-BUG.md).
- **Deeply nested templates** with a top-of-file `<bx:script>` block + `<bx:loop>` + nested `<bx:if>` inside an HTML attribute can trigger a different variant of the same bug (the CBWire tmp file gets truncated mid-write). Workaround: flatten the template, move the conditional into a precomputed local. Same doc covers both.

## Code style

- Module is `.bx` and `.bxm` end-to-end. No `.cfc` / `.cfm` files except CommandBox task scripts (CommandBox's task runner hard-codes `.cfc`).
- Two spaces for indentation in `.bx` / `.bxm`; tabs in `.bxm` view templates (matches the host's style).
- Don't use em dashes (—) anywhere. Use commas, parentheses, or sentence breaks.
- Comments should explain WHY, not WHAT. Skip the obvious.

## Filing bugs

Open a GitHub issue with:

- TesseraBX host version (`docker compose exec app cat box.json | grep version`).
- PM version (`cat box.json | grep version` in this repo).
- Reproduction steps.
- Expected vs actual behavior.
- Relevant log excerpts from `/app/.engine/boxlang/WEB-INF/boxlang/logs/`.
