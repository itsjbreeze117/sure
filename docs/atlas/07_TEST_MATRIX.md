# Test Matrix

## Running Tests

```bash
# Run all tests
bin/rails test

# Run all tests with database reset
bin/rails test:db

# Run specific test file
bin/rails test test/models/account_test.rb

# Run specific test at line number
bin/rails test test/models/account_test.rb:42

# Run system tests (slow -- use sparingly)
bin/rails test:system

# Run with coverage report
COVERAGE=true bin/rails test

# Disable parallelization (debugging)
DISABLE_PARALLELIZATION=true bin/rails test

# Run OpenAPI spec generation (RSpec -- docs only)
RAILS_ENV=test bundle exec rake rswag:specs:swaggerize
```

## Test Structure

| Directory | What It Tests | Framework |
|-----------|--------------|-----------|
| `test/models/` | Model logic, validations, state machines, calculations | Minitest |
| `test/controllers/` | Controller actions, auth, params, responses | Minitest |
| `test/controllers/api/v1/` | API endpoint behavior (auth, CRUD, error codes) | Minitest |
| `test/jobs/` | Background job execution | Minitest |
| `test/system/` | Full browser flows (Capybara + Selenium) | Minitest + Capybara |
| `test/helpers/` | View helper methods | Minitest |
| `test/mailers/` | Email delivery and content | Minitest |
| `test/integration/` | Multi-request flows | Minitest |
| `test/interfaces/` | Shared interface compliance tests | Minitest |
| `test/components/` | ViewComponent rendering | Minitest |
| `test/lib/` | Library code (Money, etc.) | Minitest |
| `test/services/` | Service object tests | Minitest |
| `test/policies/` | Pundit authorization policies | Minitest |
| `test/data_migrations/` | Data migration correctness | Minitest |
| `spec/requests/api/v1/` | API OpenAPI documentation generation | RSpec + rswag (docs only) |

## Test Tooling

| Tool | Purpose | Config |
|------|---------|--------|
| Minitest | Primary test framework | `test/test_helper.rb` |
| Mocha | Stubs and mocks | `require "mocha/minitest"` in test_helper |
| VCR | HTTP request recording/playback | `test/vcr_cassettes/`, configured in test_helper |
| WebMock | HTTP request stubbing | `require "webmock/minitest"` |
| Capybara | Browser automation for system tests | `test/application_system_test_case.rb` |
| Selenium | WebDriver for system tests | Via `selenium-webdriver` gem |
| ClimateControl | Environment variable overrides | `with_env_overrides()` helper |
| SimpleCov | Coverage reporting | `COVERAGE=true` env var |
| AASM Minitest | State machine testing helpers | `require "aasm/minitest"` |

## Fixtures

- **Location**: `test/fixtures/`
- **Convention**: 2-3 fixtures per model for base cases
- **Edge cases**: Created on-the-fly within test methods
- **Special files**: `test/fixtures/files/imports/` -- sample CSV files for import tests

## Key Test Helpers

Defined in `test/test_helper.rb`:

```ruby
# Sign in a user for controller tests
sign_in(user)

# Override environment variables
with_env_overrides(SELF_HOSTED: "true") { ... }

# Test self-hosted mode
with_self_hosting { ... }

# Standard test password
user_password_test  # => "maybetestpassword817983172"

# Ensure Investment Contributions category exists
ensure_investment_contributions_category(family)
```

## Coverage Gaps

- **System tests are sparse**: Only critical flows have system tests. Most UI behavior tested via controller tests.
- **Provider sync integration**: VCR cassettes cover some provider responses. Live provider testing requires real API keys.
- **Multi-currency edge cases**: Exchange rate scenarios not exhaustively tested.
- **Concurrent sync behavior**: Race conditions in sync engine are hard to test deterministically.
- **Mobile API**: Flutter mobile client tests are separate (in `mobile/` directory).

## Adding Tests

1. **Model test**: Create `test/models/{model}_test.rb`. Use `fixtures :all` (loaded automatically). Test business logic, not ActiveRecord CRUD.
2. **Controller test**: Create `test/controllers/{controller}_test.rb`. Use `sign_in(users(:family_admin))` for auth. Test response codes and side effects.
3. **API test**: Two files needed:
   - `test/controllers/api/v1/{resource}_controller_test.rb` -- Behavioral tests (Minitest)
   - `spec/requests/api/v1/{resource}_spec.rb` -- OpenAPI docs (RSpec + rswag, `run_test!` only)
4. **System test**: Create `test/system/{feature}_test.rb`. Extend `ApplicationSystemTestCase`. Use sparingly.

## Pre-PR Checklist

```bash
# All required before opening a PR:
bin/rails test                           # All unit/controller tests
bin/rubocop -f github -a                 # Ruby linting with auto-fix
bundle exec erb_lint ./app/**/*.erb -a   # ERB linting with auto-fix
bin/brakeman --no-pager                  # Security analysis

# Only when applicable:
bin/rails test:system                    # System tests (if UI changes)
RAILS_ENV=test bundle exec rake rswag:specs:swaggerize  # If API changes
```
