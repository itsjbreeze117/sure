# Critical Flows

## Flow 1: Bank Account Sync (Provider -> Sure)

**Trigger**: User clicks "Sync" on an account, or scheduled `SyncHourlyJob` fires.

1. `app/models/concerns/syncable.rb:sync_later()` -- Acquires pessimistic lock, checks for existing visible sync. If none, creates `Sync` record and enqueues `SyncJob`.
2. `app/jobs/sync_job.rb:perform()` -- Calls `sync.perform`
3. `app/models/sync.rb:perform()` -- Guards (state valid? syncable exists? not scheduled for deletion?), transitions to `:syncing`, calls `syncable.perform_sync(self)`
4. `app/models/family/syncer.rb:perform_sync()` (for Family syncs) -- Iterates accounts, calls `account.sync_later(parent_sync: sync)` for each, creating child Sync records
5. `app/models/{provider}_item/syncer.rb:perform_sync()` (for provider syncs) -- Fetches data from provider API, creates/updates `{Provider}Account` and `{Provider}Entry` records, maps to Sure `Account` and `Entry` records
6. `app/models/account/syncer.rb:perform_sync()` -- Calls `import_market_data` (exchange rates, security prices), then `materialize_balances` (forward or reverse strategy based on linked/manual)
7. `app/models/balance/materializer.rb:materialize_balances()` -- Calculates daily balance snapshots from entries, writes `Balance` records
8. `app/models/sync.rb:finalize_if_all_children_finalized()` -- When all children complete, parent transitions to `:completed`, runs `perform_post_sync` (auto-matches transfers), broadcasts Turbo Stream update

**End state**: Account balances updated, Balance records materialized, UI refreshed via Turbo Stream.
**Gotchas**: See `06_GOTCHAS.md` -- concurrent syncs, stale sync cleanup, pending transaction reconciliation.

## Flow 2: Manual Transaction Creation

**Trigger**: User fills out new transaction form and submits.

1. `app/controllers/transactions_controller.rb:create()` -- Builds `Entry` with nested `Transaction` (entryable) attributes
2. `app/models/entry.rb` -- Validates `date`, `name`, `amount`, `currency`. For valuations, enforces date uniqueness per account.
3. `app/models/transaction.rb` -- Sets `kind` (standard by default), associates `category`, `merchant`, `tags`
4. Entry is saved with `accepts_nested_attributes_for :entryable`
5. `entry.sync_account_later` (callback) -- Triggers account re-sync to update balances
6. `app/models/account/syncer.rb:perform_sync()` -- Recalculates balances incorporating the new entry
7. Family's `auto_match_transfers!` runs in post-sync to detect if this is part of a transfer pair

**End state**: New entry created, account balance updated, transfer auto-detected if applicable.
**Gotchas**: `entry.lock_saved_attributes!` locks fields modified by user to prevent provider sync overwrite.

## Flow 3: CSV Import

**Trigger**: User creates a new Import and uploads a CSV file.

1. `app/controllers/imports_controller.rb:create()` -- Creates `Import` record
2. `app/controllers/import/uploads_controller.rb:update()` -- Processes uploaded CSV
3. `app/controllers/import/configurations_controller.rb` -- User maps CSV columns to entry fields
4. `app/controllers/import/cleans_controller.rb` -- User reviews/cleans data
5. `app/controllers/import/confirms_controller.rb` -- User confirms import
6. `app/controllers/imports_controller.rb:publish()` -- Triggers `ImportJob`
7. `app/jobs/import_job.rb:perform()` -- Processes each row, creates `Entry` records with `import_id` set, skipping duplicates by `external_id`
8. Account sync triggered for affected accounts

**End state**: Entries created from CSV, linked to Import record, account balances recalculated.
**Gotchas**: Import can be reverted via `RevertImportJob` which deletes entries with matching `import_id`.

## Flow 4: Dashboard Load

**Trigger**: User navigates to root (`/`), routed to `pages#dashboard`.

1. `app/controllers/pages_controller.rb:dashboard()` -- Loads `Current.family`, builds `BalanceSheet` and `IncomeStatement`
2. `app/models/balance_sheet.rb` -- Aggregates account balances by type (assets vs liabilities), uses `family.build_cache_key` for caching
3. `app/models/income_statement.rb` -- Aggregates transactions by category for the period, excludes `BUDGET_EXCLUDED_KINDS`
4. `app/views/pages/dashboard/` -- Renders Turbo Frames for each dashboard widget (net worth, spending, accounts list, etc.)
5. `app/components/` -- ViewComponents render charts (D3.js), account cards, sparklines
6. Sparklines loaded lazily via `accountable_sparklines_controller.rb` (separate Turbo Frame requests)

**End state**: Dashboard rendered with net worth, income/expense charts, account summaries.
**Gotchas**: Dashboard uses aggressive caching keyed on `latest_sync_completed_at`. Stale cache after sync failure shows old data.

## Flow 5: Rules Engine Execution

**Trigger**: User creates/applies a Rule, or rules auto-run after sync.

1. `app/controllers/rules_controller.rb:apply()` -- Triggers `RuleJob` for a single rule
2. `app/jobs/rule_job.rb:perform()` -- Calls `rule.apply!`
3. `app/models/rule.rb:apply!()` -- Evaluates conditions against entries using `Rule::ConditionFilter`
4. `app/models/rule/condition_filter/` -- Filters entries matching rule conditions (merchant, amount, name patterns, etc.)
5. `app/models/rule/action_executor/` -- Executes actions on matching entries (set category, set tags, set merchant, etc.)
6. Post-execution: `family.auto_categorize_transactions_later()` may trigger AI categorization via `AutoCategorizeJob`

**End state**: Matching entries updated per rule actions, locked attributes set to prevent sync overwrite.
**Gotchas**: `apply_all` runs ALL rules sequentially. Order matters if rules conflict. AI categorization is async and may not reflect immediately.
