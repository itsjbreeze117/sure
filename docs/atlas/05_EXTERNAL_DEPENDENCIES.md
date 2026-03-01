# External Dependencies

## Core Framework

| Package | Purpose | Version |
|---------|---------|---------|
| `rails` | Web framework | ~> 7.2.2 |
| `pg` | PostgreSQL adapter | ~> 1.5 |
| `redis` | Redis client (Sidekiq, ActionCable, cache) | ~> 5.4 |
| `puma` | HTTP server | >= 5.0 |
| `sidekiq` | Background job processor | latest |
| `sidekiq-cron` | Scheduled/recurring jobs | latest |
| `sidekiq-unique-jobs` | Job deduplication | latest |

## Frontend

| Package | Purpose | Version |
|---------|---------|---------|
| `turbo-rails` | Turbo Frames/Streams (Hotwire) | latest |
| `stimulus-rails` | Stimulus JS controllers | latest |
| `tailwindcss-rails` | Tailwind CSS compilation | latest |
| `view_component` | Reusable UI components | latest |
| `lookbook` | Component preview/development | 2.3.11 |
| `importmap-rails` | JS module imports without bundler | latest |
| `propshaft` | Asset pipeline | latest |
| `lucide-rails` | Icon library | latest |
| `hotwire_combobox` | Autocomplete component | latest |

## Authentication & Authorization

| Package | Purpose | Version |
|---------|---------|---------|
| `bcrypt` | Password hashing | ~> 3.1 |
| `doorkeeper` | OAuth2 provider for API | latest |
| `pundit` | Authorization policies | latest |
| `rack-attack` | Rate limiting | ~> 6.6 |
| `omniauth` | SSO authentication | ~> 2.1 |
| `omniauth_openid_connect` | OpenID Connect SSO | latest |
| `omniauth-google-oauth2` | Google SSO | latest |
| `omniauth-github` | GitHub SSO | latest |
| `omniauth-saml` | SAML SSO | ~> 2.1 |
| `rotp` | MFA TOTP codes | ~> 6.3 |
| `jwt` | JSON Web Tokens for API auth | latest |

## State Machines

| Package | Purpose | Version |
|---------|---------|---------|
| `aasm` | State machines for Sync, Account | latest |
| `after_commit_everywhere` | after_commit outside ActiveRecord | ~> 1.0 |

## External Services

### Plaid (Bank Sync - US/CA)
- **Used for**: Bank account connection, transaction sync, investment data
- **Integration point**: `app/models/plaid_item/`, `app/models/plaid_account/`, `config/initializers/plaid_config.rb`
- **Gem**: `plaid`
- **If unavailable**: Accounts show last-synced data. Syncs fail with error stored on Sync record. UI shows sync error state.

### SimpleFIN (Bank Sync - Aggregator)
- **Used for**: Alternative bank connection via SimpleFIN Bridge
- **Integration point**: `app/models/simplefin_item/`, `app/models/simplefin_account/`, `config/initializers/simplefin.rb`, `lib/simplefin/`
- **If unavailable**: Same as Plaid -- graceful degradation to last-synced data.

### Enable Banking (Bank Sync - EU)
- **Used for**: European bank connections
- **Integration point**: `app/models/enable_banking_item/`, `app/models/enable_banking_account/`
- **If unavailable**: EU accounts show last-synced data.

### Lunchflow (Bank Sync)
- **Used for**: Additional bank sync provider
- **Integration point**: `app/models/lunchflow_item/`, `app/models/lunchflow_account/`, `config/initializers/lunchflow.rb`

### Coinbase (Crypto)
- **Used for**: Coinbase exchange account sync
- **Integration point**: `app/models/coinbase_item/`, `app/models/coinbase_account/`
- **Gem**: Uses `ed25519` for CDP API auth

### CoinStats (Crypto)
- **Used for**: Crypto wallet/exchange tracking
- **Integration point**: `app/models/coinstats_item/`, `app/models/coinstats_account/`

### SnapTrade (Investments)
- **Used for**: Investment account sync
- **Integration point**: `app/models/snaptrade_item/`, `app/models/snaptrade_account/`
- **Gem**: `snaptrade` ~> 2.0

### Mercury (Banking)
- **Used for**: Mercury bank account sync
- **Integration point**: `app/models/mercury_item/`, `app/models/mercury_account/`

### Indexa Capital (Investments)
- **Used for**: Indexa Capital investment sync
- **Integration point**: `app/models/indexa_capital_item/`, `app/models/indexa_capital_account/`

### Stripe (Billing)
- **Used for**: Subscription billing (managed mode only)
- **Integration point**: `config/initializers/stripe.rb`, `app/controllers/subscriptions_controller.rb`, webhooks at `/webhooks/stripe`
- **Gem**: `stripe`
- **If unavailable**: Billing page fails. Self-hosted mode unaffected.

### OpenAI (AI Features)
- **Used for**: AI chat assistant, auto-categorization, merchant detection, rule suggestions
- **Integration point**: `app/models/assistant/`, `app/models/provider/openai/`
- **Gem**: `ruby-openai`
- **If unavailable**: AI features disabled. Manual categorization still works.

### Langfuse (AI Observability)
- **Used for**: LLM usage tracking, eval metrics
- **Integration point**: `config/initializers/langfuse.rb`, `app/models/eval/`
- **Gem**: `langfuse-ruby` ~> 0.1.4

### Sentry (Error Monitoring)
- **Used for**: Error tracking, sync failure alerts
- **Integration point**: `config/initializers/sentry.rb`, error reporting throughout sync engine
- **Gems**: `sentry-ruby`, `sentry-rails`, `sentry-sidekiq`

### PostHog (Analytics)
- **Used for**: Product analytics
- **Integration point**: `config/initializers/posthog.rb`
- **Gem**: `posthog-ruby`

## Data Provider Dependencies

| Provider | Gem/Library | What Happens If Down |
|----------|-------------|---------------------|
| Plaid | `plaid` gem | Bank syncs fail, last data preserved |
| SimpleFIN | `lib/simplefin/` (custom) | Bank syncs fail, last data preserved |
| Stripe | `stripe` gem | Billing fails (self-hosted unaffected) |
| OpenAI | `ruby-openai` gem | AI features disabled, manual flow works |
| Coinbase | `ed25519` + custom | Crypto syncs fail |
| SnapTrade | `snaptrade` gem | Investment syncs fail |
