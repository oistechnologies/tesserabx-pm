# Changelog

All notable changes to `tesserabx-pm` are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Pre-1.0 development happens directly on `main`. Phases are tracked here as `[Unreleased]` sections until v1.0.0 is tagged, at which point post-v1 work moves to feature branches per the BUILD-PLAN §4.3.

## [Unreleased]

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
