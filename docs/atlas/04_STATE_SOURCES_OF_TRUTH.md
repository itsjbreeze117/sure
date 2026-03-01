# State -- Sources of Truth

## PostgreSQL (Primary Data Store)

- **Location**: `config/database.yml` -> `sure_{development,test,production}`
- **Stores**: All domain data -- families, users, accounts, entries, syncs, categories, tags, rules, imports, provider items/accounts/entries, balances, holdings, securities, exchange rates
- **Written by**: Rails models via ActiveRecord
- **Read by**: All controllers, models, jobs, API endpoints
- **Consistency**: Strong (ACID transactions with pessimistic locking for syncs)
- **Schema**: `db/schema.rb` -- UUIDs everywhere (`pgcrypto`), generated columns, JSONB fields
- **Key tables**: `accounts`, `entries`, `transactions`, `syncs`, `balances`, `holdings`, `families`, `users`
- **Extensions**: `pgcrypto` (UUIDs), `plpgsql`

### Generated Columns (DB-Level Truth)
- `accounts.classification` -- Stored generated column. Computed from `accountable_type` via SQL CASE. Cannot be set via ActiveRecord. Source of truth for asset/liability classification.

### JSONB Fields (Semi-Structured State)
- `transactions.extra` -- Provider-specific metadata. Pending status stored as `extra["simplefin"]["pending"]`, `extra["plaid"]["pending"]`, etc.
- `entries.locked_attributes` -- Field-level locking timestamps. Prevents provider sync from overwriting user edits.
- `accounts.locked_attributes` -- Same pattern for account-level locks.
- `accounts.holdings_snapshot_data` -- Cached holdings snapshot for performance.

## Redis

- **Location**: Configured via `REDIS_URL` env var
- **Stores**: Sidekiq job queues, ActionCable channels, Rails cache, session data (if configured)
- **Written by**: Sidekiq (job enqueue), ActionCable (pub/sub), Rails cache writes
- **Read by**: Sidekiq workers (job dequeue), ActionCable subscribers, cached reads
- **Consistency**: Eventual (jobs may be delayed, cache may be stale)

## Sidekiq Job State

- **Location**: Redis (Sidekiq queues + scheduled sets)
- **Stores**: Pending/scheduled/retry jobs
- **Written by**: `perform_later` calls throughout the app
- **Read by**: Sidekiq server processes
- **Key jobs**: `SyncJob`, `ImportJob`, `AssistantResponseJob`, `SyncHourlyJob`, `SyncCleanerJob`
- **Scheduling**: `sidekiq-cron` for periodic jobs, `sidekiq-unique-jobs` prevents duplicates

## ActiveStorage (File Storage)

- **Location**: Local disk (`storage/`) in dev, S3 in production (`aws-sdk-s3`)
- **Stores**: Account logos, import files, PDF uploads
- **Written by**: File upload controllers, import flow
- **Read by**: Views (via ActiveStorage URL helpers)

## Rails Credentials (Encrypted Secrets)

- **Location**: `config/credentials.yml.enc` (encrypted)
- **Stores**: API keys, encryption keys, provider secrets
- **Read by**: Initializers, provider integration code
- **Key entries**: `active_record_encryption`, provider API keys (Plaid, Stripe, OpenAI)

## Environment Variables (Runtime Config)

- **Location**: `.env` files (local), host environment (production)
- **Stores**: Feature flags, provider config, database URLs
- **Key vars**:
  - `SELF_HOSTED` / `SELF_HOSTING_ENABLED` -- App mode (self-hosted vs managed)
  - `SIMPLEFIN_INCLUDE_PENDING` -- Toggle pending transaction sync (default: on)
  - `PLAID_INCLUDE_PENDING` -- Toggle pending transaction sync (default: on)
  - `SIMPLEFIN_DEBUG_RAW` -- Enable raw payload logging
  - `PLAID_ENV` -- Plaid environment (sandbox/development/production)

## Thread-Local State (Request Context)

- **Location**: `app/models/current.rb`
- **Stores**: Current user, family, session, user_agent, ip_address
- **Written by**: Authentication concern in `ApplicationController`
- **Read by**: Models, controllers, views via `Current.user`, `Current.family`
- **Lifetime**: Single request only. Cleared between requests.
- **Impersonation**: `Current.user` returns impersonated user if active session exists. `Current.true_user` returns the real user.

## Reconciliation Rules

1. **Database wins over cache**: If Redis cache and PostgreSQL disagree, PostgreSQL is truth. Cache is invalidated on sync completion via `family.build_cache_key`.
2. **User edits win over provider sync**: `entry.user_modified?` flag prevents provider from overwriting manual changes. Unlock with `entry.unlock_for_sync!`.
3. **Provider data wins on initial import**: When a provider first syncs an account, provider data populates all fields.
4. **Locked attributes are immutable during sync**: `entry.locked_attributes` stores timestamps of field-level locks. Syncer skips locked fields.
5. **Posted transactions win over pending**: `Entry.reconcile_pending_duplicates` excludes pending entries when matching posted versions arrive.
6. **Family sync waits for all children**: Parent `Sync` only completes when all child syncs finalize. One failure = parent failure.
