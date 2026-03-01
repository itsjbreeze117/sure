# Architecture

## Overview

Sure is a monolithic Rails 7.2 application for personal finance management. Users connect bank accounts
via multiple providers (Plaid, SimpleFIN, Enable Banking, Lunchflow, Coinbase, CoinStats, SnapTrade,
Mercury, Indexa Capital), sync transactions/balances automatically, and view dashboards with net worth,
income/expense breakdowns, budgets, and investment performance.

The app runs in two modes: **self-hosted** (Docker Compose, `SELF_HOSTED=true`) and **managed**
(team-operated servers with Stripe billing). Mode is determined at boot via
`config/application.rb` -> `config.app_mode`.

## Component Diagram

```
Browser (Hotwire/Turbo/Stimulus)
    |
    v
Rails 7.2 (Puma)
    |
    +--- Controllers (app/controllers/)
    |       +--- Web UI controllers (Turbo responses)
    |       +--- API v1 controllers (JSON/Jbuilder)
    |       +--- Webhooks (Plaid, Stripe)
    |
    +--- Models (app/models/)  <-- business logic lives here
    |       +--- Domain models (Account, Entry, Family, Transaction, etc.)
    |       +--- Provider models ({Provider}Item, {Provider}Account, {Provider}Entry)
    |       +--- Sync engine (Sync, Syncable concern, {Model}::Syncer classes)
    |       +--- Financial calculators (BalanceSheet, IncomeStatement, InvestmentStatement)
    |
    +--- Views (app/views/ + app/components/)
    |       +--- ERB templates with Turbo Frames
    |       +--- ViewComponents (DS/ for design system, UI/ for features)
    |
    +--- Background Jobs (app/jobs/ -> Sidekiq)
            +--- SyncJob, ImportJob, AssistantResponseJob, etc.
            +--- Scheduled via sidekiq-cron

PostgreSQL (primary data store, UUIDs, pgcrypto)
Redis (Sidekiq queues, ActionCable, caching)
```

## Components

### Web Layer (`app/controllers/`)
- **Purpose**: Handle HTTP requests, authentication, authorization, render responses
- **Location**: `app/controllers/` (web), `app/controllers/api/v1/` (REST API)
- **Key patterns**: `ApplicationController` mixes in 12+ concerns (Authentication, AutoSync, Localize, etc.)
- **Auth**: Session-based for web, Doorkeeper OAuth + API keys for API

### Domain Models (`app/models/`)
- **Purpose**: All business logic, validations, calculations, sync orchestration
- **Location**: `app/models/` (393 files across ~50 subdirectories)
- **Key patterns**: `delegated_type` for polymorphism, AASM state machines, Concerns for shared behavior
- **Convention**: "Skinny controllers, fat models" -- no `app/services/` layer (just one file there)

### Provider Integration Layer (`app/models/{provider}_item/`)
- **Purpose**: Bank sync provider adapters (Plaid, SimpleFIN, etc.)
- **Location**: Each provider has `{Provider}Item`, `{Provider}Account`, `{Provider}Entry` models + `Syncer` class
- **Pattern**: Provider Items are the "connection", Accounts map to Sure Accounts, Entries map to Sure Entries
- **Family Connectables**: `Family` includes `{Provider}Connectable` concerns (9 of them)

### Sync Engine (`app/models/sync.rb` + `concerns/syncable.rb`)
- **Purpose**: Orchestrate data sync from providers to Sure's domain models
- **Pattern**: AASM state machine (pending -> syncing -> completed/failed/stale)
- **Hierarchy**: Family sync spawns Account syncs (parent-child relationship)
- **Deduplication**: `sync_later` checks for existing visible syncs before creating new ones

### Frontend (`app/views/` + `app/components/` + `app/javascript/`)
- **Purpose**: Server-rendered HTML with Hotwire interactivity
- **Stack**: Turbo Frames/Streams, Stimulus controllers, Tailwind CSS v4
- **Components**: `app/components/DS/` (design system primitives), `app/components/UI/` (feature components)
- **Charts**: D3.js for financial visualizations

### Background Processing (`app/jobs/` + Sidekiq)
- **Purpose**: Async work -- syncs, imports, AI responses, data cleanup
- **Key jobs**: `SyncJob`, `ImportJob`, `AssistantResponseJob`, `SyncHourlyJob`
- **Scheduling**: `sidekiq-cron` for periodic tasks, `sidekiq-unique-jobs` for dedup

## Communication Patterns

- **Web -> Models**: Direct method calls via controllers
- **Models -> Jobs**: `perform_later` for async work
- **Jobs -> Models**: Call `Syncer#perform_sync` via `Sync#perform`
- **Server -> Browser**: Turbo Streams (broadcast via ActionCable/Redis)
- **Providers -> App**: Webhooks (Plaid, Stripe) + polling via scheduled syncs
- **API Clients -> App**: REST API at `/api/v1/` with Doorkeeper OAuth or API key auth

## Key Design Decisions

- **delegated_type over STI**: Account and Entry use `delegated_type` for polymorphism. Each accountable/entryable type gets its own table. Tradeoff: more tables but cleaner separation.
- **No services layer**: Business logic stays in models and concerns, not in a separate services directory. Tradeoff: models can get large but behavior is discoverable.
- **Multi-provider sync via Syncer pattern**: Each provider implements a `Syncer` class that conforms to the same interface. Family sync creates child syncs for each account.
- **Generated columns in DB**: `accounts.classification` is a stored generated column computed from `accountable_type`. Cannot be set via ActiveRecord.
- **Self-hosted first**: `SELF_HOSTED=true` is the primary deployment mode. Managed mode adds Stripe billing and invite codes.
