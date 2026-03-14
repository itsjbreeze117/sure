# Architecture

**Analysis Date:** 2026-03-14

## Pattern Overview

**Overall:** Monolithic Rails 7.2 MVC with domain-heavy models

**Key Characteristics:**
- "Skinny controllers, fat models" — all business logic lives in `app/models/`, not `app/services/`
- `delegated_type` for Account and Entry polymorphism (one table per subtype, not STI)
- AASM state machines for Account lifecycle and Sync lifecycle
- Concerns-heavy composition: models mix in 5-12 concerns each for shared behavior
- Two deployment modes: self-hosted (`SELF_HOSTED=true`) and managed (Stripe billing, invite codes)

## Layers

**Web Layer:**
- Purpose: Handle HTTP, session auth, CSRF, authorization, render Turbo responses
- Location: `app/controllers/`
- Contains: 50+ controllers, organized by domain and provider. Controller concerns in `app/controllers/concerns/`
- Depends on: Domain models, ViewComponents, Pundit policies
- Used by: Browser via Hotwire (Turbo Frames/Streams)
- Auth: Session-based via `Authentication` concern. `Current.user` and `Current.family` — never `current_user`

**API Layer:**
- Purpose: REST API for third-party apps and external clients
- Location: `app/controllers/api/v1/`
- Contains: 16 controllers inheriting from `Api::V1::BaseController`
- Depends on: Same domain models as web layer, Doorkeeper, `ApiKey`
- Auth: Dual-mode — OAuth2 (Doorkeeper, `Authorization: Bearer`) or API key (`X-Api-Key` header). Rate limiting via `ApiRateLimiter`

**Domain Model Layer:**
- Purpose: All business logic, validations, calculations, sync orchestration
- Location: `app/models/` (~393 files across ~50 subdirectories)
- Contains: Domain models, per-model `Syncer` classes, financial calculators, provider adapters
- Depends on: PostgreSQL (via ActiveRecord), Redis (via Sidekiq for job enqueueing)
- Convention: Models answer questions about themselves (`account.balance_series`, not `AccountSeries.new(account).call`)

**Provider Integration Layer:**
- Purpose: Bank/brokerage sync adapters
- Location: `app/models/{provider}_item/`, `app/models/{provider}_account/`, `app/models/{provider}_entry/`
- Contains: 9 providers: Plaid, SimpleFIN, Enable Banking, Lunchflow, Coinbase, CoinStats, SnapTrade, Mercury, Indexa Capital
- Pattern: Each provider has `{Provider}Item` (connection), `{Provider}Account` (mapped account), `{Provider}Entry` (mapped transaction), and a `Syncer` class
- Family includes 9x `{Provider}Connectable` concerns

**Background Jobs Layer:**
- Purpose: Async work — syncs, imports, AI, scheduled cleanup
- Location: `app/jobs/`
- Contains: 30+ Sidekiq jobs. Key: `SyncJob`, `ImportJob`, `AssistantResponseJob`, `SyncHourlyJob`, `AutoCategorizeJob`
- Scheduling: `sidekiq-cron` for periodic tasks, `sidekiq-unique-jobs` for deduplication

**View Layer:**
- Purpose: Server-rendered HTML with Hotwire interactivity
- Location: `app/views/`, `app/components/`
- Contains: ERB templates with Turbo Frames. ViewComponents split into `DS/` (design system primitives) and `UI/` (feature components). 64 Stimulus controllers in `app/javascript/controllers/`
- Charts: D3.js via `time_series_chart_controller.js`, `donut_chart_controller.js`, `sankey_chart_controller.js`

## Data Flow

**Bank Sync Flow:**

1. `Syncable#sync_later` — acquires pessimistic lock, creates `Sync` record, enqueues `SyncJob`
2. `SyncJob#perform` — calls `sync.perform`
3. `Sync#perform` — validates state, transitions to `:syncing`, calls `syncable.perform_sync(self)`
4. `Family::Syncer#perform_sync` — iterates accounts, creates child `Sync` records per account
5. `{Provider}Item::Syncer#perform_sync` — fetches from provider API, upserts `{Provider}Account` and `{Provider}Entry`, maps to `Account`/`Entry`
6. `Account::Syncer#perform_sync` — calls `import_market_data`, then `materialize_balances`
7. `Balance::Materializer#materialize_balances` — calculates daily `Balance` snapshots from entries
8. `Sync#finalize_if_all_children_finalized` — when all children complete, parent → `:completed`, broadcasts Turbo Stream

**API Request Flow:**

1. Request hits `Api::V1::BaseController` before_actions: `force_json_format`, `authenticate_request!`, `check_api_key_rate_limit`, `log_api_access`
2. `authenticate_request!` tries OAuth first, then API key
3. `setup_current_context_for_api` — sets `Current.session` (finds or builds session for the user)
4. Controller method queries domain models scoped to `current_resource_owner.family`
5. Response rendered via Jbuilder `.json.jbuilder` templates

**Transaction Creation Flow:**

1. `TransactionsController#create` — builds `Entry` with nested `Transaction` (entryable) attributes
2. `Entry` saved via `accepts_nested_attributes_for :entryable`
3. `entry.sync_account_later` callback — triggers balance recalculation
4. `Account::Syncer#perform_sync` — recalculates balances
5. `Family#auto_match_transfers!` runs in post-sync to detect transfer pairs

**Dashboard Load Flow:**

1. `PagesController#dashboard` — builds `BalanceSheet` and `IncomeStatement` for `Current.family`
2. `BalanceSheet` aggregates account balances by type, uses `family.build_cache_key` for caching
3. `IncomeStatement` aggregates transactions by category for the period
4. Views render Turbo Frames per widget; sparklines loaded lazily via separate Turbo Frame requests

**State Management:**
- Server-side: `Current` object (Rails thread-local) for user/family/session
- Client-side: Query params for UI state (not localStorage/sessions)
- Real-time updates: ActionCable via Redis, Turbo Streams broadcast after sync completion

## Key Abstractions

**delegated_type (Account):**
- Purpose: Polymorphic account types without STI
- Files: `app/models/account.rb`, `app/models/concerns/accountable.rb`
- Types (9): `Depository`, `Investment`, `Crypto`, `Property`, `Vehicle`, `OtherAsset`, `CreditCard`, `Loan`, `OtherLiability`
- Pattern: `account.accountable` returns the subtype record. `account.delegated_type :accountable`

**delegated_type (Entry):**
- Purpose: Polymorphic journal entry types
- Files: `app/models/entry.rb`, `app/models/entryable.rb`
- Types (3): `Transaction`, `Valuation`, `Trade`
- Pattern: `entry.entryable` returns the subtype. `entry.transaction?`, `entry.trade?` etc.

**Syncable Concern:**
- Purpose: Shared sync orchestration for any model that syncs (Family, Account, PlaidItem, etc.)
- File: `app/models/concerns/syncable.rb`
- Pattern: `model.sync_later` → creates `Sync` record + enqueues `SyncJob`. `{Model}::Syncer.new(model).perform_sync(sync)` does the work

**Syncer Pattern:**
- Purpose: Encapsulate sync logic per model type
- Files: `app/models/account/syncer.rb`, `app/models/family/syncer.rb`, `app/models/{provider}_item/syncer.rb`
- Pattern: Each syncer class implements `perform_sync(sync)` and `perform_post_sync`

**Financial Calculators:**
- Purpose: Aggregate financial data for reporting
- Files: `app/models/balance_sheet.rb`, `app/models/income_statement.rb`, `app/models/investment_statement.rb`
- Pattern: Instantiated with a `Family`, return structured data for views

**ViewComponents (DS + UI split):**
- Purpose: Reusable UI with logic separated from ERB
- Files: `app/components/DS/` (design system primitives: Button, Dialog, Alert, Menu, etc.), `app/components/UI/` (feature components: account cards, charts, etc.)
- Pattern: Component class in `.rb`, template in `.html.erb`, Stimulus controller co-located as `_controller.js`

## Entry Points

**Web Dashboard:**
- Location: `app/controllers/pages_controller.rb`
- Triggers: `GET /` (root)
- Responsibilities: Loads balance sheet, income statement, renders dashboard with Turbo Frames

**API Base:**
- Location: `app/controllers/api/v1/base_controller.rb`
- Triggers: Any `GET|POST|PATCH|DELETE /api/v1/*` request
- Responsibilities: Authentication (OAuth or API key), rate limiting, scope authorization, `Current` context setup

**Sync Entry:**
- Location: `app/models/concerns/syncable.rb` → `app/jobs/sync_job.rb`
- Triggers: User clicks sync, scheduled `SyncHourlyJob`, post-transaction callback
- Responsibilities: Dedup check, `Sync` record creation, job enqueue

**Webhook Entry:**
- Location: `app/controllers/webhooks/` (Plaid, Stripe)
- Triggers: `POST /webhooks/plaid`, `POST /webhooks/stripe`
- Responsibilities: Validate signature, process event, enqueue jobs

**MCP Entry:**
- Location: `app/controllers/mcp_controller.rb`
- Triggers: `POST /mcp`
- Responsibilities: JSON-RPC 2.0 handler for external AI assistants

**Application Boot:**
- Location: `config/application.rb`, `config/environment.rb`, `config.ru`
- Key configs: `Rails.application.config.app_mode` (`managed` or `self_hosted`), provider initializers in `config/initializers/`

## Error Handling

**Strategy:** Rescue at the controller boundary for API; let Rails default error pages handle web errors. Sync errors captured on `Sync#error` field.

**Patterns:**
- `Api::V1::BaseController`: `rescue_from ActiveRecord::RecordNotFound`, `Doorkeeper::Errors::DoorkeeperError`, `ActionController::ParameterMissing` → JSON error responses
- `Sync` model: captures exceptions into `sync.error`, transitions state to `:failed`
- Provider syncers: log errors, re-raise or capture per sync record
- Validation errors: returned via `422 Unprocessable Entity` with `model.errors`

## Cross-Cutting Concerns

**Authentication:** `Authentication` concern in `app/controllers/concerns/authentication.rb` (web). Dual OAuth + API key in `Api::V1::BaseController`.

**Authorization:** Pundit policies in `app/policies/`. `pundit_user` returns `Current.user`. Family-scoped data access enforced in controllers.

**Current Context:** `Current` (Rails `ActiveSupport::CurrentAttributes`) holds `user`, `family`, `session`. All controllers set this before use. API controllers set it via `setup_current_context_for_api`.

**Internationalization:** All user-facing strings via `t()` helper. Locale files in `config/locales/en.yml`. Keys organized by feature: `accounts.index.title`.

**Multi-Currency:** `Monetizable` concern wraps money fields with `Money` objects. Historical exchange rates stored in `ExchangeRate` model for accurate reporting.

**Logging:** `Rails.logger` throughout. API layer logs all requests with user, family, auth method, and path.

---

*Architecture analysis: 2026-03-14*
