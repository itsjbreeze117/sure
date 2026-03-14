# External Integrations

**Analysis Date:** 2026-03-14

## APIs & External Services

**Bank Account Sync:**
- Plaid (US) - Real-time bank/credit account sync, pending transactions
  - SDK/Client: `plaid` gem + `Provider::Plaid` (`app/models/provider/plaid.rb`, `app/models/provider/plaid_adapter.rb`)
  - Auth env vars: `PLAID_CLIENT_ID`, `PLAID_SECRET`
  - Config: `config/initializers/plaid_config.rb`
  - Webhook: `POST /webhooks/plaid` handled by `WebhooksController#plaid`
  - Supports US (`Provider::PlaidAdapter`) and EU (`Provider::PlaidEuAdapter`) regions

- SimpleFIN - Open banking account sync alternative to Plaid
  - SDK/Client: Custom Faraday client in `Provider::Simplefin` (`app/models/provider/simplefin.rb`)
  - Auth env vars: Token-based (configured via settings DB)
  - Config: `config/initializers/simplefin.rb`
  - Feature flags: `SIMPLEFIN_INCLUDE_PENDING`, `SIMPLEFIN_DEBUG_RAW`

- Lunchflow - Additional bank sync provider
  - SDK/Client: Custom adapter in `Provider::Lunchflow` (`app/models/provider/lunchflow.rb`, `app/models/provider/lunchflow_adapter.rb`)
  - Config: `config/initializers/lunchflow.rb`
  - Feature flags: `LUNCHFLOW_INCLUDE_PENDING`, `LUNCHFLOW_DEBUG_RAW`

- Enable Banking - EU open banking provider
  - SDK/Client: Custom adapter in `Provider::EnableBanking` (`app/models/provider/enable_banking.rb`, `app/models/provider/enable_banking_adapter.rb`)
  - Auth: Configured via settings DB

**Brokerage / Investment Sync:**
- SnapTrade ~2.0 - Brokerage account aggregation (stocks, ETFs)
  - SDK/Client: `snaptrade` gem + `Provider::Snaptrade` (`app/models/provider/snaptrade.rb`, `app/models/provider/snaptrade_adapter.rb`)
  - Auth env vars: Configured via settings DB

- Coinbase CDP - Crypto portfolio sync
  - SDK/Client: `ed25519` gem for request signing in `Provider::Coinbase` (`app/models/provider/coinbase.rb`, `app/models/provider/coinbase_adapter.rb`)
  - Auth: ED25519 key-based CDP API authentication

- CoinStats - Crypto portfolio aggregation
  - SDK/Client: Custom adapter in `Provider::Coinstats` (`app/models/provider/coinstats.rb`, `app/models/provider/coinstats_adapter.rb`)

- Mercury - Business banking integration
  - SDK/Client: Custom adapter in `Provider::Mercury` (`app/models/provider/mercury.rb`, `app/models/provider/mercury_adapter.rb`)

- Indexa Capital - Spanish robo-advisor integration
  - SDK/Client: Custom adapter in `Provider::IndexaCapital` (`app/models/provider/indexa_capital.rb`, `app/models/provider/indexa_capital_adapter.rb`)

**Market Data:**
- Twelve Data - Exchange rates and security prices (primary market data)
  - SDK/Client: Custom Faraday client in `Provider::TwelveData` (`app/models/provider/twelve_data.rb`)
  - Auth env vars: `TWELVE_DATA_API_KEY` (or set via admin settings page)
  - Selected via: `EXCHANGE_RATE_PROVIDER=twelve_data`, `SECURITIES_PROVIDER=twelve_data`

- Yahoo Finance - Free fallback for exchange rates and security prices
  - SDK/Client: Custom Faraday client in `Provider::YahooFinance` (`app/models/provider/yahoo_finance.rb`)
  - Auth: No API key required; uses cookie/crumb auth for some endpoints
  - Selected via: `EXCHANGE_RATE_PROVIDER=yahoo_finance`, `SECURITIES_PROVIDER=yahoo_finance`

**AI / LLM:**
- OpenAI (or compatible) - AI financial assistant
  - SDK/Client: `ruby-openai` gem + `Provider::Openai` (`app/models/provider/openai.rb`)
  - Auth env vars: `OPENAI_ACCESS_TOKEN`
  - Config env vars: `OPENAI_MODEL` (default: `gpt-4.1`), `OPENAI_URI_BASE` (for compatible endpoints), `OPENAI_REQUEST_TIMEOUT`
  - Default model: `gpt-4.1`; supports any OpenAI-compatible endpoint (e.g., LM Studio, Ollama)

- Langfuse - LLM observability and tracing
  - SDK/Client: `langfuse-ruby` ~0.1.4
  - Auth env vars: `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY`
  - Config: `LANGFUSE_HOST` (default: `https://cloud.langfuse.com`)
  - Config file: `config/initializers/langfuse.rb`

**Billing:**
- Stripe - Subscription management (managed mode only)
  - SDK/Client: `stripe` gem + `Provider::Stripe` (`app/models/provider/stripe.rb`)
  - Auth env vars: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`
  - Webhook: `POST /webhooks/stripe` handled by `WebhooksController#stripe`
  - Handles: customer subscriptions, checkout sessions

**Brand & Merchant Data:**
- Brandfetch - Bank/merchant logo fetching
  - Auth env vars: `BRAND_FETCH_CLIENT_ID`
  - Setting: `Setting.brand_fetch_client_id` (`app/models/setting.rb`)

**Version/Release:**
- GitHub (Octokit) - Fetches latest release notes for display in app
  - SDK/Client: `octokit` gem + `Provider::Github` (`app/models/provider/github.rb`)
  - Auth: Public API (no token required for public repo)

## Data Storage

**Databases:**
- PostgreSQL (primary)
  - Adapter: `pg` gem via ActiveRecord
  - Connection env vars: `DB_HOST`, `DB_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`
  - Config: `config/database.yml`
  - Pool size: `RAILS_MAX_THREADS` (default: 3)

**Caching:**
- Redis - Production cache store and ActionCable adapter
  - Connection env var: `REDIS_URL` (default: `redis://localhost:6379`)
  - HA mode: `REDIS_SENTINEL_HOSTS`, `REDIS_SENTINEL_MASTER`, `REDIS_PASSWORD`
  - Config: `config/initializers/sidekiq.rb`, `config/cable.yml`, `config/environments/production.rb`
  - Rails cache: `:redis_cache_store` in production

**File Storage:**
- Active Storage with multiple backends:
  - Local disk (default, development/test): `storage/` directory
  - Amazon S3: env vars `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`, `S3_REGION`, `S3_BUCKET`
  - Cloudflare R2: env vars `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_ACCESS_KEY_ID`, `CLOUDFLARE_SECRET_ACCESS_KEY`, `CLOUDFLARE_BUCKET`
  - Generic S3-compatible: `GENERIC_S3_*` env vars
  - Selected via: `ACTIVE_STORAGE_SERVICE` env var
  - Config: `config/storage.yml`

## Authentication & Identity

**Session Auth (Web):**
- Custom session-based auth via `Session` model and signed `session_token` cookie
- `Current.user` / `Current.family` for request context (not `current_user`)
- `bcrypt` for password hashing

**API Auth (External API):**
- OAuth 2.0 via Doorkeeper (`/oauth/` routes, `config/initializers/doorkeeper.rb`)
- API keys with JWT tokens for direct API access (`app/models/api_key.rb`)
- Config: `config/initializers/doorkeeper.rb`

**SSO / OAuth Login:**
- OmniAuth 2.1 with CSRF protection
- Supported providers (configured via `config/auth.yml` or database):
  - OpenID Connect (OIDC): `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET`, `OIDC_ISSUER`, `OIDC_REDIRECT_URI`
  - Google OAuth2: `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET`
  - GitHub: `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`
  - SAML 2.0: IdP metadata URL or manual IdP configuration
- Config: `config/initializers/omniauth.rb`

**2FA:**
- TOTP via `rotp` ~6.3
- QR code generation via `rqrcode` ~3.0

## Monitoring & Observability

**Error Tracking:**
- Sentry (`sentry-ruby`, `sentry-rails`, `sentry-sidekiq`)
  - Auth env var: `SENTRY_DSN`
  - Enabled only in production; traces at 25% sample rate
  - Config: `config/initializers/sentry.rb`

**Product Analytics:**
- PostHog
  - Auth env vars: `POSTHOG_KEY`, `POSTHOG_HOST` (default: `https://us.i.posthog.com`)
  - Config: `config/initializers/posthog.rb`

**Logging:**
- BetterStack (Logtail) - Structured log ingestion in production
  - Auth env vars: `LOGTAIL_API_KEY`, `LOGTAIL_INGESTING_HOST`
  - Falls back to STDOUT if not configured
  - Config: `config/environments/production.rb`

**Performance:**
- Skylight - APM for production (gem group `:production`)
- rack-mini-profiler - Request profiling in development
- Vernier - Ruby CPU profiler integrated with Sentry

## Email

**SMTP:**
- Generic SMTP delivery (e.g., Resend, SendGrid, Postmark)
- Auth env vars: `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_TLS_ENABLED`
- Sender: `EMAIL_SENDER`
- Config: `config/environments/production.rb`
- Development: Letter Opener (preview in browser, no actual sending)

## CI/CD & Deployment

**Hosting:**
- Docker (primary deployment method)
  - `Dockerfile` - Multi-stage Ruby 3.4.7-slim build
  - `compose.example.yml`, `compose.example.ai.yml`, `compose.example.pipelock.yml` - Compose templates

**CI Pipeline:**
- GitHub Actions (`.github/workflows/ci.yml`)

## Environment Configuration

**Required env vars (self-hosted minimum):**
- `SECRET_KEY_BASE` - Rails secret key
- `SELF_HOSTED=true` - Enable self-hosted mode
- `DB_HOST`, `POSTGRES_USER`, `POSTGRES_PASSWORD` - Database connection
- `REDIS_URL` - Redis connection

**Optional high-value vars:**
- `OPENAI_ACCESS_TOKEN` - Enables AI assistant
- `TWELVE_DATA_API_KEY` or `YAHOO_FINANCE` config - Market data
- `PLAID_CLIENT_ID` + `PLAID_SECRET` - Bank sync
- `STRIPE_SECRET_KEY` + `STRIPE_WEBHOOK_SECRET` - Billing (managed mode)
- `SENTRY_DSN` - Error tracking
- `POSTHOG_KEY` - Analytics
- `LOGTAIL_API_KEY` + `LOGTAIL_INGESTING_HOST` - Structured logging
- `ACTIVE_STORAGE_SERVICE` + corresponding S3/R2 vars - Cloud file storage
- `SMTP_*` vars - Email delivery

**Secrets location:**
- Local development: `.env` file (gitignored), template at `.env.local.example`
- Self-hosting: `.env` file, documented in `.env.example`
- Production credentials: Rails encrypted credentials (`config/credentials.yml.enc`)

## Webhooks & Callbacks

**Incoming webhooks:**
- `POST /webhooks/plaid` - Plaid US transaction/account update events
- `POST /webhooks/plaid_eu` - Plaid EU transaction/account update events
- `POST /webhooks/stripe` - Stripe subscription lifecycle events
- All webhook endpoints in `app/controllers/webhooks_controller.rb`

**Outgoing:**
- None detected (all provider integrations are polling-based via background jobs)

---

*Integration audit: 2026-03-14*
