# Technology Stack

**Analysis Date:** 2026-03-14

## Languages

**Primary:**
- Ruby 3.4.7 - Rails backend, all business logic, background jobs
- Dart/Flutter (SDK >=3.0.0 <4.0.0, Flutter >=3.27.0) - Mobile app (`mobile/`)

**Secondary:**
- JavaScript (ES modules via importmap) - Frontend interactivity via Stimulus controllers
- Python 3 - Atlas doc generation scripts (`scripts/atlas/generate_atlas.py`)
- ERB / HTML - Server-rendered templates

## Runtime

**Environment:**
- MRI Ruby 3.4.7 with YJIT enabled (`config/initializers/enable_yjit.rb`)
- YJIT enabled via `enable_yjit.rb` initializer for production performance

**Package Manager:**
- Bundler - Ruby gems (`Gemfile.lock` present)
- npm (package-lock.json present) - JavaScript devDependencies only (Biome)
- Flutter pub - Mobile app dependencies (`mobile/pubspec.lock`)

## Frameworks

**Core:**
- Rails 7.2.2 - Full-stack web framework
- Hotwire (Turbo + Stimulus) - Frontend reactivity without heavy JavaScript
- ViewComponent - Reusable server-rendered UI components (`app/components/`)

**Background Jobs:**
- Sidekiq - Job processing with Redis backend
- sidekiq-cron - Scheduled recurring jobs (`config/schedule.yml`)
- sidekiq-unique-jobs - Job deduplication

**Frontend:**
- D3.js 7.9.0 (via importmap) - Financial charts (time series, donut, sankey)
- Tailwind CSS v4.x - Utility-first CSS with custom design system (`app/assets/tailwind/maybe-design-system.css`)
- @floating-ui/dom 1.7.0 - Tooltip/dropdown positioning
- @simonwep/pickr 1.9.1 - Color picker
- @github/hotkey 3.1.1 - Keyboard shortcut handling
- Propshaft - Asset pipeline (replaces Sprockets)
- importmap-rails - JavaScript module imports without bundler

**Mobile (Flutter):**
- provider 6.1.1 - State management
- flutter_secure_storage 10.0.0 - Secure credential storage
- sqflite 2.4.2 - Local SQLite database
- http 1.1.0 - HTTP client
- app_links 6.4.0 - Deep linking
- shared_preferences 2.2.2 - Local key-value storage

**Testing:**
- Minitest - Primary test framework (Rails built-in)
- RSpec + rswag - OpenAPI spec generation only (`spec/requests/api/`)
- Capybara + Selenium - System tests
- VCR + WebMock - HTTP interaction recording/stubbing
- mocha - Mocking library
- simplecov - Code coverage
- Faker - Test data generation (development only)

**Build/Dev:**
- Biome 1.9.3 - JavaScript linting and formatting
- RuboCop (rubocop-rails-omakase) - Ruby linting
- ERB Lint - ERB template linting
- Brakeman - Ruby security scanning
- Lookbook 2.3.11 - ViewComponent development UI
- Foreman - Multi-process dev server
- Letter Opener - Email preview in development

## Key Dependencies

**Critical:**
- `pg` ~1.5 - PostgreSQL adapter for ActiveRecord
- `redis` ~5.4 - Cache store, ActionCable adapter, Sidekiq backend
- `puma` >=5.0 - Web server (production and development)
- `doorkeeper` - OAuth 2.0 provider for external API auth
- `pundit` - Authorization policy framework
- `aasm` - State machine for accounts and syncs
- `bcrypt` ~3.1 - Password hashing
- `jwt` - JWT token generation/verification
- `faraday` + `faraday-retry` + `faraday-multipart` - HTTP client for all provider integrations
- `activerecord-import` - Bulk insert for import performance

**Infrastructure:**
- `sidekiq` - Background job processing
- `rack-attack` ~6.6 - API rate limiting
- `rack-cors` - Cross-origin request handling
- `bootsnap` - Boot time optimization
- `aws-sdk-s3` ~1.208.0 - Active Storage S3/R2 backend

**AI & Observability:**
- `ruby-openai` - OpenAI API client
- `langfuse-ruby` ~0.1.4 - LLM observability/tracing
- `sentry-ruby` + `sentry-rails` + `sentry-sidekiq` - Error tracking
- `posthog-ruby` - Product analytics
- `logtail-rails` - Structured logging (BetterStack)
- `skylight` - Performance profiling (production only)
- `vernier` - Ruby profiler (Sentry integration)
- `rack-mini-profiler` - Request profiling

**Financial Domain:**
- `stripe` - Subscription billing
- `plaid` - Bank account sync (US/EU)
- `snaptrade` ~2.0 - Brokerage account sync
- `ed25519` - Coinbase CDP API authentication
- `rotp` ~6.3 - TOTP two-factor authentication
- `rqrcode` ~3.0 - QR code generation
- `pagy` - Pagination
- `pdf-reader` ~2.12 - PDF import parsing
- `redcarpet` - Markdown rendering

**Auth:**
- `omniauth` ~2.1 - Multi-provider SSO
- `omniauth-google-oauth2` - Google OAuth
- `omniauth-github` - GitHub OAuth
- `omniauth_openid_connect` - OIDC support
- `omniauth-saml` ~2.1 - SAML 2.0 SSO

## Configuration

**Environment:**
- `.env` files via `dotenv-rails` (development/test)
- `.env.example` documents all self-hosting variables
- `.env.local.example` documents all local development variables
- `SELF_HOSTED=true` or `SELF_HOSTING_ENABLED=true` switches to self-hosted mode
- `RAILS_ENV` controls environment (development/test/production)

**Build:**
- `config/application.rb` - Application config and middleware
- `config/database.yml` - PostgreSQL config (all from ENV vars)
- `config/importmap.rb` - JavaScript module pinning
- `Dockerfile` - Multi-stage Docker build (Ruby 3.4.7-slim base)
- `Procfile.dev` - Local dev process definitions

## Platform Requirements

**Development:**
- Ruby 3.4.7 (enforced by `.ruby-version`)
- PostgreSQL (adapter: postgresql, default port 5432)
- Redis (default `redis://localhost:6379`)
- libvips (image processing for Active Storage)

**Production:**
- Docker (Dockerfile provided, compose examples in `compose.example*.yml`)
- PostgreSQL
- Redis (supports Redis Sentinel for HA via `REDIS_SENTINEL_HOSTS`)
- SMTP server for email delivery
- Optional: S3-compatible object storage for Active Storage

---

*Stack analysis: 2026-03-14*
