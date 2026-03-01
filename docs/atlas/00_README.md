# Atlas -- Sure Finance

## What Is This?

The `docs/atlas/` folder is a persistent context system -- structured documentation
that helps engineers and LLM coding agents understand this codebase quickly without
grep-searching hundreds of files.

Sure is a Rails 7.2 personal finance app (forked from Maybe Finance via we-promise/sure).
~1,300 Ruby files, 393 model files, 9 account types, 8+ bank sync providers,
Hotwire/Stimulus frontend, PostgreSQL + Redis + Sidekiq backend.

## Files

| File | Purpose | Auto-generated? |
|------|---------|----------------|
| `00_README.md` | This file -- how to use the atlas | No |
| `01_ARCHITECTURE.md` | System overview, layers, components | No |
| `02_DOMAIN_MODEL.md` | Core entities, delegated types, state machines | No |
| `03_CRITICAL_FLOWS.md` | Happy-path call chains for top flows | No |
| `04_STATE_SOURCES_OF_TRUTH.md` | Where state lives + reconciliation rules | No |
| `05_EXTERNAL_DEPENDENCIES.md` | Gems, APIs, external services | No |
| `06_GOTCHAS.md` | Known traps, race conditions, fragile zones | No |
| `07_TEST_MATRIX.md` | Test structure + how to prove correctness | No |
| `08_CHANGELOG_LAST_14_DAYS.md` | Recent changes summary | Yes |
| `repo-map.md` | Directory tree, router table, entrypoints, danger zones | Partially |

## How to Use

1. Start with `repo-map.md` to orient yourself -- use the Router Table to find where to start
2. Read the domain-specific atlas doc for your task area
3. Check `06_GOTCHAS.md` before modifying fragile areas (sync engine, balance calculations, delegated types)
4. Only then dive into source files

## Key Conventions

- **Use `Current.user` and `Current.family`** -- never `current_user` or `current_family`
- **Minitest + fixtures for tests** -- never RSpec or factories (RSpec exists only for API OpenAPI doc generation)
- **Models are fat, controllers are skinny** -- business logic lives in `app/models/`, not `app/services/`
- **Hotwire-first frontend** -- Turbo Frames/Streams + Stimulus, minimal custom JS
- **`delegated_type` is everywhere** -- Account -> Accountable (9 types), Entry -> Entryable (3 types)

## Maintenance

- Run `make atlas-generate` after structural changes (new dirs, new entrypoints)
- Update manual docs when architecture, flows, or state management changes
- `make atlas-check` to verify auto-generated files are current
