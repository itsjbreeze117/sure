# Gotchas

## Sync Engine

### Concurrent Sync Race Conditions
- **File**: `app/models/concerns/syncable.rb`
- **Risk**: Two sync requests for the same syncable can create duplicate syncs if not properly guarded
- **Rule**: `sync_later` acquires `with_lock` (pessimistic row lock) and checks `syncs.visible` before creating. Never bypass this by creating Sync records directly.
- **Why**: `visible` scope = incomplete syncs created within last 5 minutes. Stale syncs (>5 min) are assumed lost (e.g., after Sidekiq restart) and a new sync is created.

### Parent-Child Sync Finalization
- **File**: `app/models/sync.rb:finalize_if_all_children_finalized()`
- **Risk**: Parent sync hangs forever if a child sync never finalizes
- **Rule**: `SyncCleanerJob` runs periodically to mark syncs older than 24 hours as `:stale`. Never delete Sync records manually.
- **Why**: `finalize_if_all_children_finalized` uses a transaction with `lock!`. If a child is in limbo, the parent cannot complete until the cleaner marks it stale.

### Sync Window Expansion
- **File**: `app/models/sync.rb:expand_window_if_needed()`
- **Risk**: If a pending sync's window is `nil` (full sync), expanding it does nothing -- it's already as wide as possible. New narrow-window requests silently merge into the full sync.
- **Rule**: Check if the existing sync covers your needed date range before assuming it will.

## Database Schema

### Generated Column: accounts.classification
- **File**: `db/schema.rb`, `app/models/account.rb`
- **Risk**: Setting `account.classification = "asset"` via ActiveRecord silently does nothing. The column is computed from `accountable_type` by a SQL CASE expression.
- **Rule**: Never set `classification` directly. Change `accountable_type` instead. The DB generates the correct value.
- **Why**: This is a `stored: true` virtual column in PostgreSQL.

### UUID Primary Keys Everywhere
- **File**: `db/schema.rb`
- **Risk**: Integer-based queries or assumptions break. IDs are UUIDs (`pgcrypto` extension).
- **Rule**: Always use `uuid` type in migrations. Never assume sequential IDs.

## Delegated Types

### Account delegated_type Must Match TYPES Array
- **File**: `app/models/concerns/accountable.rb`
- **Risk**: Adding a new account type without updating `Accountable::TYPES` silently breaks. The delegated_type won't resolve, and `balance_type` will raise.
- **Rule**: When adding a new account type: (1) Add to `TYPES` array, (2) Create model file, (3) Create migration for new table, (4) Update `balance_type` in `account.rb`, (5) Update `classification` CASE in schema.
- **Why**: `delegated_type :accountable, types: Accountable::TYPES` uses this array as a whitelist.

### Entry delegated_type and Polymorphic Routing
- **File**: `config/routes.rb` (lines 298-304)
- **Risk**: `direct :entry` uses `entry.entryable_name.pluralize` to generate routes. If an entryable model name doesn't match a route, `NoMethodError` at URL generation.
- **Rule**: Every Entryable type must have a matching `resources` declaration in routes.rb.

## Pending Transactions

### Raw SQL in Pending Scopes
- **File**: `app/models/entry.rb`, `app/models/transaction.rb`
- **Risk**: Pending transaction detection uses raw SQL JSONB queries (`transactions.extra -> 'simplefin' ->> 'pending'`). These scopes use `INNER JOIN transactions` which silently excludes non-Transaction entries.
- **Rule**: Never use `Entry.pending` scope on a query that includes Valuations or Trades -- they'll be excluded by the join.

### Stale Pending Auto-Exclusion
- **File**: `app/models/entry.rb:auto_exclude_stale_pending()`
- **Risk**: Pending transactions older than 8 days with no posted match are auto-excluded (hidden). This is irreversible without manual DB intervention.
- **Rule**: The 8-day window is hardcoded. Providers with slower settlement (international wires) may incorrectly exclude valid pending entries.

## Authentication

### Current.user vs current_user
- **File**: `app/models/current.rb`
- **Risk**: Using `current_user` (Rails default) instead of `Current.user` breaks impersonation support and is inconsistent with the codebase.
- **Rule**: Always use `Current.user` and `Current.family`. Never `current_user` or `current_family`.
- **Why**: `Current.user` checks for impersonation sessions. `current_user` would skip this.

## Financial Calculations

### Balance Materializer Strategy
- **File**: `app/models/balance/materializer.rb`
- **Risk**: Linked accounts use `:reverse` strategy (work backwards from current balance). Manual accounts use `:forward` (work from opening balance). Using wrong strategy produces incorrect historical balances.
- **Rule**: `account.linked?` determines strategy. Never force a strategy unless you understand the implications.

### Investment Contributions Category Race Condition
- **File**: `app/models/family.rb:investment_contributions_category()`
- **Risk**: Concurrent requests can create duplicate "Investment Contributions" categories
- **Rule**: Method has `rescue ActiveRecord::RecordNotUnique` handling. It also consolidates legacy duplicates from a locale bug. Don't bypass this method to create the category directly.

## Environment / Config

### Self-Hosted Mode Detection
- **File**: `config/application.rb`
- **Risk**: `SELF_HOSTED` and `SELF_HOSTING_ENABLED` env vars both work, but code checks both. Inconsistent naming.
- **Rule**: Set `SELF_HOSTED=true` (primary). `SELF_HOSTING_ENABLED=true` is the legacy alias.

### Pending Transaction Env Vars Default to ON
- **Files**: `config/initializers/simplefin.rb`, `config/initializers/plaid_config.rb`
- **Risk**: Pending transactions are included by default. Setting `SIMPLEFIN_INCLUDE_PENDING=0` disables them. The "0" string check (not boolean) is a gotcha.
- **Rule**: Only `"0"` disables. Any other value (including empty string) keeps pending enabled.

## Testing

### Fixtures vs Factories
- **Risk**: Using FactoryBot or creating records with `create()` instead of fixtures. The codebase uses fixtures exclusively.
- **Rule**: Use fixtures in `test/fixtures/`. Create edge cases on-the-fly within test context. Never add FactoryBot.

### RSpec is Docs-Only
- **File**: `spec/requests/api/v1/`
- **Risk**: RSpec exists ONLY for OpenAPI documentation via rswag. Adding behavioral assertions in RSpec specs creates a parallel test system.
- **Rule**: Behavioral API tests go in `test/controllers/api/v1/` (Minitest). RSpec specs use `run_test!` only for OpenAPI doc generation.
