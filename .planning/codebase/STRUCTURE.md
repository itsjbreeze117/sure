# Codebase Structure

**Analysis Date:** 2026-03-14

## Directory Layout

```
sure/                              # Rails 7.2 monolith root
├── app/
│   ├── assets/                    # Static assets + Tailwind CSS design system
│   │   └── tailwind/              # Design system tokens (maybe-design-system.css)
│   ├── channels/                  # ActionCable channels (Turbo Streams)
│   ├── components/                # ViewComponents
│   │   ├── DS/                    # Design system primitives (Button, Dialog, Alert, Menu, etc.)
│   │   └── UI/                    # Feature-level UI components (account cards, charts, etc.)
│   ├── controllers/               # Rails controllers
│   │   ├── api/
│   │   │   └── v1/               # External REST API controllers (16 files)
│   │   ├── concerns/             # Controller mixins (Authentication, AutoSync, Localize, etc.)
│   │   ├── admin/                # Super-admin controllers
│   │   ├── import/               # Multi-step import wizard controllers
│   │   ├── settings/             # User/family settings controllers
│   │   ├── transactions/         # Transaction sub-controllers
│   │   └── webhooks/             # Incoming webhooks (Plaid, Stripe)
│   ├── data_migrations/          # Data-only migrations (separate from schema migrations)
│   ├── helpers/                  # View helpers (application_helper.rb has `icon` helper)
│   ├── javascript/
│   │   ├── controllers/          # Stimulus controllers (64 files)
│   │   └── application.js        # JS entry point
│   ├── jobs/                     # Sidekiq background jobs (30+ files)
│   ├── mailers/                  # ActionMailer mailers
│   ├── middleware/               # Rack middleware
│   ├── models/                   # Domain models + business logic (~393 files, ~50 subdirs)
│   │   ├── account/              # Account sub-classes (Syncer, Materializer, etc.)
│   │   ├── balance/              # Balance calculators (Forward, Reverse, Materializer)
│   │   ├── balance_sheet/        # BalanceSheet data aggregators
│   │   ├── {provider}_item/      # Provider connection models (9 providers)
│   │   ├── {provider}_account/   # Provider account mappers
│   │   ├── {provider}_entry/     # Provider entry mappers
│   │   ├── concerns/             # Model mixins (Syncable, Monetizable, Enrichable, etc.)
│   │   ├── import/               # Import processing (Importer, Mapping, Upload)
│   │   ├── provider/             # Provider abstraction layer + Factory
│   │   ├── rule/                 # Rules engine (ConditionFilter, ActionExecutor)
│   │   ├── transaction/          # Transaction sub-classes (AutoCategorizer, Search, etc.)
│   │   └── vector_store/         # AI vector search support
│   ├── policies/                 # Pundit authorization policies
│   ├── services/                 # Minimal (ApiRateLimiter, ProviderLoader — 4 files only)
│   └── views/                    # ERB templates (organized by controller)
├── bin/                          # Binstubs (dev, rails, rubocop, brakeman, setup)
├── charts/                       # Helm charts (Kubernetes deployment)
├── config/
│   ├── initializers/             # Provider initializers (plaid_config.rb, simplefin.rb, etc.)
│   ├── locales/                  # i18n locale files (en.yml + others)
│   └── routes.rb                 # ~507 lines, full route definitions
├── db/
│   ├── migrate/                  # ActiveRecord migrations
│   ├── schema.rb                 # Current DB schema (source of truth)
│   ├── seeds.rb                  # Seed data
│   └── seeds/                    # Seed data files
├── docs/
│   └── atlas/                    # Codebase documentation (repo-map.md, ARCHITECTURE.md, etc.)
├── lib/                          # Library code (rake tasks, etc.)
├── mobile/                       # Mobile app code (React Native or similar)
├── public/                       # Static public files
├── scripts/                      # Utility scripts
├── spec/
│   └── requests/api/v1/          # RSpec + rswag OpenAPI specs (docs only, not behavioral tests)
├── test/                         # Minitest tests
│   ├── controllers/              # Controller tests
│   ├── models/                   # Model tests
│   ├── integration/              # Integration tests
│   ├── system/                   # System (browser) tests
│   ├── fixtures/                 # Test fixtures (minimal, 2-3 per model)
│   └── support/                  # Test helpers and support files
├── vendor/                       # Vendored gems/assets
├── .planning/codebase/           # GSD codebase analysis docs
├── biome.json                    # JS/TS linter + formatter config
├── CLAUDE.md                     # Claude Code guidance (conventions, architecture, rules)
├── Gemfile                       # Ruby dependencies
├── package.json                  # JS dependencies
└── Procfile.dev                  # Development process definitions (Rails, Sidekiq, Tailwind)
```

## Directory Purposes

**`app/models/`:**
- Purpose: All business logic — Rails is "fat models, skinny controllers"
- Contains: Domain models, Syncer classes, financial calculators, provider adapters, PORO helpers
- Key files: `account.rb`, `entry.rb`, `family.rb`, `sync.rb`, `transaction.rb`, `balance_sheet.rb`, `income_statement.rb`
- Convention: Complex models get their own subdirectory (e.g., `app/models/account/syncer.rb`)

**`app/models/concerns/`:**
- Purpose: Shared model behavior via mixins
- Contains: `Syncable`, `Monetizable`, `Enrichable`, `Linkable`, `Anchorable`, `Chartable`, `Accountable`, `Entryable`, plus provider connectable concerns
- Key files: `app/models/concerns/syncable.rb`, `app/models/concerns/accountable.rb`

**`app/models/provider/`:**
- Purpose: Provider abstraction layer — factory, base classes, adapters for each external data provider
- Contains: `base.rb`, `factory.rb`, `configurable.rb`, one file per provider (Coinbase, Plaid, SimpleFIN, etc.)
- Key files: `app/models/provider/factory.rb`, `app/models/provider/base.rb`

**`app/controllers/api/v1/`:**
- Purpose: External REST API endpoints
- Contains: 16 controllers (accounts, transactions, holdings, trades, etc.)
- Key files: `app/controllers/api/v1/base_controller.rb` (auth, rate limiting, scope check)
- Auth pattern: `Api::V1::BaseController` handles both OAuth + API key

**`app/components/DS/`:**
- Purpose: Design system primitive components — reusable across the whole app
- Contains: `Button`, `Dialog`, `Alert`, `Menu`, `MenuItem`, `Link`, `FilledIcon`, `Disclosure`, `Tabs`
- Pattern: Each component has `.rb` class + `.html.erb` template + optional `_controller.js`

**`app/components/UI/`:**
- Purpose: Feature-level UI components (more domain-specific than DS)
- Contains: `Account`, `AccountPage`, and other feature components
- Key file: `app/components/application_component.rb` (base class)

**`app/javascript/controllers/`:**
- Purpose: Stimulus controllers for client-side interactivity
- Contains: 64 controllers (charts, forms, drag-drop, modals, polling, etc.)
- Global controllers live here. Component-scoped controllers live alongside their component

**`app/jobs/`:**
- Purpose: Sidekiq background jobs
- Contains: 30+ jobs. All inherit from `ApplicationJob`
- Key jobs: `SyncJob`, `ImportJob`, `AssistantResponseJob`, `SyncHourlyJob`, `AutoCategorizeJob`, `RuleJob`

**`docs/atlas/`:**
- Purpose: Persistent codebase documentation for AI agents
- Contains: 9 structured docs (architecture, domain model, critical flows, gotchas, test matrix, etc.)
- Key file: `docs/atlas/repo-map.md` (router table mapping tasks to files)

**`spec/requests/api/v1/`:**
- Purpose: OpenAPI documentation specs only (rswag) — NOT behavioral tests
- Contains: RSpec files that generate `docs/api/openapi.yaml`
- Behavioral API tests live in `test/controllers/api/v1/`

## Key File Locations

**Entry Points:**
- `config/routes.rb`: All route definitions (~507 lines)
- `config.ru`: Rack app entry point
- `app/controllers/pages_controller.rb`: Dashboard root action
- `app/controllers/application_controller.rb`: Web base controller with 12+ concern includes
- `app/controllers/api/v1/base_controller.rb`: API base controller with auth/rate-limiting

**Configuration:**
- `config/application.rb`: App mode (`managed` vs `self_hosted`), core config
- `config/initializers/plaid_config.rb`: Plaid provider config
- `config/initializers/simplefin.rb`: SimpleFIN provider config
- `config/locales/en.yml`: All English i18n strings
- `app/assets/tailwind/maybe-design-system.css`: Tailwind design tokens (use these, never raw Tailwind colors)
- `biome.json`: JS/TS linting and formatting rules

**Core Domain Models:**
- `app/models/family.rb`: Top-level tenant; owns everything
- `app/models/account.rb`: Main account model with `delegated_type`
- `app/models/entry.rb`: Journal entry with `delegated_type` (Transaction, Valuation, Trade)
- `app/models/sync.rb`: Sync state machine (AASM)
- `app/models/concerns/syncable.rb`: Sync orchestration mixin
- `app/models/balance_sheet.rb`: Net worth aggregation
- `app/models/income_statement.rb`: Income/expense aggregation
- `app/models/investment_statement.rb`: Investment performance aggregation

**Provider Integration:**
- `app/models/plaid_item.rb` + `app/models/plaid_item/syncer.rb`: Plaid connection
- `app/models/simplefin_item.rb` + `app/models/simplefin_item/syncer.rb`: SimpleFIN connection
- `app/models/provider/factory.rb`: Provider factory (creates correct adapter by type)

**Testing:**
- `test/test_helper.rb`: Minitest base config
- `test/fixtures/`: Test fixture files (keep minimal: 2-3 per model)
- `test/support/`: Shared test helpers and utilities
- `spec/swagger_helper.rb`: rswag schema definitions for OpenAPI docs
- `.rspec`: RSpec config (for OpenAPI specs only)

## Naming Conventions

**Files:**
- Ruby: `snake_case.rb` (e.g., `balance_sheet.rb`, `plaid_item.rb`)
- ERB: `snake_case.html.erb` (e.g., `dashboard.html.erb`)
- Stimulus controllers: `snake_case_controller.js` (e.g., `time_series_chart_controller.js`)
- ViewComponent classes: `PascalCase` in `snake_case.rb` file

**Directories:**
- Model subdirectories match model name: `app/models/account/` for `Account` model sub-classes
- Provider pattern: `{provider}_item/`, `{provider}_account/`, `{provider}_entry/`

**Classes:**
- Controllers: `AccountsController`, `Api::V1::AccountsController`
- Syncer classes: `Account::Syncer`, `PlaidItem::Syncer`, `Family::Syncer`
- ViewComponents: `DS::Button`, `UI::AccountPage`
- Concerns: `Syncable`, `Monetizable`, `PlaidConnectable`

**Rails conventions observed:**
- Plural resource controllers (`AccountsController` not `AccountController`)
- Provider concerns named `{Provider}Connectable` (e.g., `PlaidConnectable`)

## Where to Add New Code

**New Domain Feature:**
- Primary model: `app/models/{feature}.rb`
- If complex: `app/models/{feature}/` subdirectory for `Syncer`, `Calculator`, etc.
- Controller: `app/controllers/{features}_controller.rb`
- Views: `app/views/{features}/`
- Tests: `test/models/{feature}_test.rb`, `test/controllers/{features}_controller_test.rb`

**New Provider Integration:**
- Item model: `app/models/{provider}_item.rb` + `app/models/{provider}_item/syncer.rb`
- Account model: `app/models/{provider}_account.rb`
- Entry model: `app/models/{provider}_entry.rb`
- Connectable concern: `app/models/concerns/{provider}_connectable.rb` (include in `Family`)
- Provider adapter: `app/models/provider/{provider}.rb` + `app/models/provider/{provider}_adapter.rb`
- Config initializer: `config/initializers/{provider}_config.rb`

**New API Endpoint:**
- Controller: `app/controllers/api/v1/{resources}_controller.rb` (inherit from `Api::V1::BaseController`)
- Jbuilder template: `app/views/api/v1/{resources}/index.json.jbuilder`
- OpenAPI spec (docs only): `spec/requests/api/v1/{resources}_spec.rb`
- Behavioral test: `test/controllers/api/v1/{resources}_controller_test.rb`

**New ViewComponent:**
- Use `DS/` for design system primitives; `UI/` for feature components
- Implementation: `app/components/DS/{component_name}.rb` + `app/components/DS/{component_name}.html.erb`
- Stimulus controller (if needed): `app/components/DS/{component_name}_controller.js`
- Preview (Lookbook): `test/components/previews/DS/{component_name}_preview.rb`

**New Stimulus Controller:**
- Global (used across pages): `app/javascript/controllers/{name}_controller.js`
- Component-scoped: Co-locate alongside the component file

**Shared Utilities:**
- Model concerns: `app/models/concerns/{behavior_name}.rb`
- Controller concerns: `app/controllers/concerns/{behavior_name}.rb`
- View helpers: `app/helpers/application_helper.rb` or `app/helpers/{feature}_helper.rb`
- Test helpers: `test/support/{helper_name}.rb`

**i18n Strings:**
- Add to `config/locales/en.yml` under hierarchical key: `{feature}.{view}.{element}`
- Always use `t()` helper in views and components — never hardcode strings

## Special Directories

**`docs/atlas/`:**
- Purpose: AI agent onboarding docs — architecture, domain model, critical flows, gotchas
- Generated: Partially (run `make atlas-generate` after structural changes)
- Committed: Yes — update when architecture changes

**`db/migrate/`:**
- Purpose: ActiveRecord schema migrations
- Generated: Via `rails g migration`
- Committed: Yes

**`db/schema.rb`:**
- Purpose: Authoritative DB schema snapshot
- Generated: Automatically by Rails on migration
- Committed: Yes — never edit manually

**`spec/`:**
- Purpose: RSpec files for OpenAPI documentation only (rswag). Behavioral tests use Minitest in `test/`
- Generated docs: `docs/api/openapi.yaml` (via `rake rswag:specs:swaggerize`)
- Committed: Yes

**`tmp/`:**
- Purpose: Rails temporary files, pids, cache
- Generated: Yes
- Committed: No

**`vendor/`:**
- Purpose: Vendored gems (bundle install with `--path vendor/bundle`)
- Generated: Yes
- Committed: Partially (check `.gitignore`)

---

*Structure analysis: 2026-03-14*
