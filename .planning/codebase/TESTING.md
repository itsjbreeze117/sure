# Testing Patterns

**Analysis Date:** 2026-03-14

## Test Framework

**Primary Runner (Behavioral Tests):**
- Minitest (Rails built-in) — all functional/behavioral tests
- Config: `test/test_helper.rb`
- Parallel execution enabled by default: `parallelize(workers: :number_of_processors)`

**Secondary Runner (API Documentation Only):**
- RSpec + rswag — used exclusively in `spec/requests/api/v1/` to generate OpenAPI docs
- Config: `spec/rails_helper.rb`, `spec/swagger_helper.rb`
- NOT used for behavioral assertions — only for generating `docs/api/openapi.yaml`

**Assertion Library:**
- Minitest built-in assertions
- `mocha` gem for stubs/mocks
- `aasm/minitest` for state machine assertions

**Coverage:**
- SimpleCov (opt-in): `COVERAGE=true bin/rails test`
- Branch coverage enabled when active

**Run Commands:**
```bash
bin/rails test                                  # Run all Minitest tests
bin/rails test:db                               # Run tests with database reset
bin/rails test:system                           # System tests only (use sparingly)
bin/rails test test/models/account_test.rb      # Single file
bin/rails test test/models/account_test.rb:42  # Single test at line
COVERAGE=true bin/rails test                    # With coverage report
DISABLE_PARALLELIZATION=true bin/rails test     # Single-threaded (for debugging)
RAILS_ENV=test bundle exec rake rswag:specs:swaggerize  # Regenerate OpenAPI docs
```

## Test File Organization

**Location:** Separate `test/` directory mirroring `app/` structure

**Minitest file structure:**
```
test/
├── test_helper.rb              # Global test setup
├── application_system_test_case.rb  # System test base
├── models/
│   ├── account.rb              # Flat model tests
│   └── account/                # Subdirectory for account sub-objects
│       ├── current_balance_manager_test.rb
│       ├── activity_feed_data_test.rb
│       └── provider_import_adapter_test.rb
├── controllers/
│   ├── accounts_controller_test.rb
│   └── api/v1/
│       └── accounts_controller_test.rb
├── jobs/
│   └── sync_job_test.rb
├── system/
│   └── accounts_test.rb
├── support/                    # Shared test helpers
│   ├── balance_test_helper.rb
│   ├── entries_test_helper.rb
│   ├── ledger_testing_helper.rb
│   ├── provider_test_helper.rb
│   ├── provider_adapter_test_interface.rb
│   └── securities_test_helper.rb
├── interfaces/                 # Shared interface contract tests
│   ├── security_provider_interface_test.rb
│   └── exchange_rate_provider_interface_test.rb
├── fixtures/                   # YAML fixture files
│   ├── accounts.yml
│   ├── entries.yml
│   └── ...
└── vcr_cassettes/              # Recorded HTTP responses
    ├── openai/
    ├── plaid/
    ├── stripe/
    └── git_repository_provider/

spec/                           # RSpec — OpenAPI docs ONLY
└── requests/api/v1/
    └── accounts_spec.rb        # run_test! only, no expect/assert
```

**Naming:**
- `*_test.rb` suffix for all Minitest files
- Class name mirrors file path: `test/models/account/current_balance_manager_test.rb` → `Account::CurrentBalanceManagerTest`
- System test classes inherit `ApplicationSystemTestCase`, not `ActiveSupport::TestCase`

## Test Structure

**Suite Organization:**
```ruby
require "test_helper"

class Account::CurrentBalanceManagerTest < ActiveSupport::TestCase
  include EntriesTestHelper  # include helper modules after class declaration

  setup do
    @family = families(:empty)
    @account = accounts(:depository)
  end

  # Section comments with dashes for grouping related tests
  # ------------------------------------------------------------------------------------------------
  # Manual account current balance management
  # ------------------------------------------------------------------------------------------------

  test "when one or more reconciliations exist, append new reconciliation" do
    manager = Account::CurrentBalanceManager.new(@account)
    assert_difference "@account.valuations.count", 1 do
      manager.set_current_balance(1400)
    end
    assert_equal 1400, @account.balance
  end
end
```

**Key patterns:**
- `setup do` block for shared fixtures per test class
- Inline object creation for edge cases (not extracted to fixtures)
- Descriptive test names as plain English sentences
- `assert_difference` for count assertions with blocks
- Multi-lambda `assert_difference` for multiple counts:
  ```ruby
  assert_difference -> { @account.entries.count } => 1,
                   -> { @account.valuations.count } => 1 do
    result = manager.set_opening_balance(balance: 1000, date: 1.year.ago.to_date)
    assert result.success?
  end
  ```

**Controller tests:**
```ruby
class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
    @account = accounts(:depository)
  end

  test "should get index" do
    get accounts_url
    assert_response :success
  end

  test "destroys account" do
    delete account_url(@account)
    assert_redirected_to accounts_path
    assert_enqueued_with job: DestroyJob
    assert_equal "...", flash[:notice]
  end
end
```

**Job tests:**
```ruby
class SyncJobTest < ActiveJob::TestCase
  test "sync is performed" do
    sync = accounts(:depository).syncs.create!(window_start_date: 2.days.ago.to_date)
    sync.expects(:perform).once
    SyncJob.perform_now(sync)
  end
end
```

## Mocking

**Framework:** mocha gem (`require "mocha/minitest"` in `test_helper.rb`)

**Instance mock pattern (most common):**
```ruby
Account.any_instance.expects(:syncing?).returns(false)
Account.any_instance.expects(:sync_later).once

PlaidItem.any_instance.expects(:sync_later).once
```

**Stub Rails config:**
```ruby
Rails.configuration.stubs(:app_mode).returns("self_hosted".inquiry)
```

**Method expectation with arguments:**
```ruby
@entry.account.expects(:sync_later).with(window_start_date: prior_date)
```

**Provider/external service mocking:**
- Use `OpenStruct` for lightweight mock instances when response structure is simple
- `ProviderTestHelper` provides `provider_success_response(data)` and `provider_error_response(error)`:
  ```ruby
  def provider_success_response(data)
    Provider::Response.new(success?: true, data: data, error: nil)
  end
  ```
  Location: `test/support/provider_test_helper.rb`

**What to mock:**
- External HTTP calls (use VCR cassettes or WebMock)
- Sidekiq job enqueuing when testing triggers (`expects(:sync_later).once`)
- Provider responses when testing data processing logic
- State machine transitions when testing one layer in isolation

**What NOT to mock:**
- ActiveRecord operations when testing domain logic
- Rails built-in functionality (validations, associations)
- Implementation details of classes under test

## Fixtures and Factories

**Fixtures ONLY — no FactoryBot:**
- All fixtures in `test/fixtures/*.yml`
- Load: `fixtures :all` (global in `test_helper.rb`)
- Access: `accounts(:depository)`, `families(:empty)`, `users(:family_admin)`

**Fixture philosophy:**
- Keep minimal: 2-3 records per model for base cases
- Named semantically: `depository`, `connected`, `credit_card`, `investment`, `empty`
- Create edge cases on-the-fly within test context using `create!`:
  ```ruby
  account = @family.accounts.create!(
    name: "Test",
    balance: 1000,
    currency: "USD",
    accountable: Depository.new
  )
  ```

**Helper modules for complex object creation:**
Location: `test/support/`

- `EntriesTestHelper` — `create_transaction`, `create_valuation`, `create_trade`, `create_transfer`
- `BalanceTestHelper` — `create_balance`, `create_balance_with_flows`
- `LedgerTestingHelper` — `create_account_with_ledger(account:, entries:, exchange_rates:, ...)`
- `ProviderTestHelper` — `provider_success_response`, `provider_error_response`

**Include helpers at class level:**
```ruby
class EntryTest < ActiveSupport::TestCase
  include EntriesTestHelper
  # ...
end
```

## VCR for External HTTP

**Framework:** VCR gem with WebMock (`require "webmock/minitest"` in `test_helper.rb`)

**Cassette location:** `test/vcr_cassettes/{provider}/{operation}.yml`
- Examples: `test/vcr_cassettes/plaid/link_token.yml`, `test/vcr_cassettes/stripe/create_checkout_session.yml`

**Usage pattern:**
```ruby
VCR.use_cassette("stripe/create_checkout_session") do
  result = @stripe.create_checkout_session(...)
  assert result.url.present?
end
```

**VCR config in `test_helper.rb`:**
- Sensitive data filtered: `<OPENAI_ACCESS_TOKEN>`, `<PLAID_CLIENT_ID>`, `<STRIPE_SECRET_KEY>`, etc.
- ERB enabled in cassettes for template substitution
- `ignore_localhost = true`

**Interface tests (shared provider contracts):**
```ruby
module SecurityProviderInterfaceTest
  extend ActiveSupport::Testing::Declarative

  test "fetches security price" do
    VCR.use_cassette("#{vcr_key_prefix}/security_price") do
      response = @subject.fetch_security_price(...)
      assert response.success?
    end
  end

  private
    def vcr_key_prefix
      @subject.class.name.demodulize.underscore
    end
end
```
Location: `test/interfaces/`

## Coverage

**Requirements:** Not formally enforced with a threshold; opt-in via `COVERAGE=true`

**View Coverage:**
```bash
COVERAGE=true bin/rails test
# SimpleCov report generated in coverage/ directory
```

**Branch coverage enabled** when SimpleCov is active.

## Test Types

**Unit Tests (Models):**
- Scope: individual model methods, business logic, validations, state machines
- Inherits: `ActiveSupport::TestCase`
- Location: `test/models/**/*_test.rb`
- Do NOT test ActiveRecord itself (saves, associations) — only domain logic

**Integration Tests (Controllers):**
- Scope: HTTP responses, redirects, flash messages, job enqueuing, auth
- Inherits: `ActionDispatch::IntegrationTest`
- Location: `test/controllers/**/*_test.rb`
- Use `sign_in @user = users(:family_admin)` in setup

**Job Tests:**
- Scope: job performs, side effects triggered
- Inherits: `ActiveJob::TestCase`
- Location: `test/jobs/**/*_test.rb`

**System Tests (E2E):**
- Use **sparingly** — slow, require Selenium
- Driven by: Selenium Chrome (headless in CI via `ENV["CI"]`)
- Inherits: `ApplicationSystemTestCase` (`test/application_system_test_case.rb`)
- Location: `test/system/**/*_test.rb`
- Capybara default wait: 5 seconds
- Use `within_testid("...")` helper for `data-testid` selectors

**API Documentation (rswag):**
- NOT behavioral tests — documentation only
- Location: `spec/requests/api/v1/*_spec.rb`
- Use `run_test!` only — no `expect(...)` or `assert_*` assertions
- All requests use API key auth via `X-Api-Key` header and `ApiKey.generate_secure_key`

## Common Patterns

**Sign in helper (defined in `test_helper.rb`):**
```ruby
def sign_in(user)
  post sessions_path, params: { email: user.email, password: user_password_test }
end
```

**Environment override:**
```ruby
def with_env_overrides(overrides = {}, &block)
  ClimateControl.modify(**overrides, &block)
end
# Usage:
with_env_overrides(PLAID_ENV: "sandbox") { ... }
```

**Self-hosting mode:**
```ruby
def with_self_hosting
  Rails.configuration.stubs(:app_mode).returns("self_hosted".inquiry)
  yield
end
```

**Async Testing:**
```ruby
test "sync is performed" do
  sync = accounts(:depository).syncs.create!(...)
  sync.expects(:perform).once
  SyncJob.perform_now(sync)
end
```

**Error/Invalid Testing:**
```ruby
test "entry cannot be older than 10 years ago" do
  assert_raises ActiveRecord::RecordInvalid do
    @entry.update! date: 50.years.ago.to_date
  end
end

test "valuation cannot duplicate" do
  new_valuation = Entry.new(...)
  assert new_valuation.invalid?
end
```

**Shared Provider Interface Contracts:**
```ruby
# Define contract module in test/interfaces/
module SecurityProviderInterfaceTest
  extend ActiveSupport::Testing::Declarative
  test "fetches security price" { ... }
end

# Include in concrete provider test
class Provider::FinancialDatasetsTest < ActiveSupport::TestCase
  include SecurityProviderInterfaceTest
  setup { @subject = Provider::FinancialDatasets.new(...) }
end
```

**Reusable Adapter Interface:**
```ruby
# test/support/provider_adapter_test_interface.rb
module ProviderAdapterTestInterface
  extend ActiveSupport::Concern
  class_methods do
    def test_provider_adapter_interface
      test "adapter implements provider_name" { ... }
    end
  end
  def adapter; raise NotImplementedError; end
end
```

## Pre-PR CI Checklist

Run in this order before opening a pull request:
```bash
bin/rails test                         # All unit/integration tests (required)
bin/rails test:system                  # System tests (only when applicable)
bin/rubocop -f github -a               # Ruby linting with auto-correct
bundle exec erb_lint ./app/**/*.erb -a # ERB linting with auto-correct
bin/brakeman --no-pager                # Security analysis
```

---

*Testing analysis: 2026-03-14*
