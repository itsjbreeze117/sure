# Coding Conventions

**Analysis Date:** 2026-03-14

## Naming Patterns

**Files:**
- Ruby: `snake_case.rb` — e.g., `balance_forward_calculator.rb`, `current_balance_manager.rb`
- JavaScript controllers: `snake_case_controller.js` — e.g., `time_series_chart_controller.js`, `chat_controller.js`
- ViewComponents: `snake_case_component.rb` + matching `.html.erb` — e.g., `alert.rb`, `button.rb`
- ERB templates: `snake_case.html.erb`
- Test files: mirrored path with `_test.rb` suffix — e.g., `test/models/account/current_balance_manager_test.rb`

**Classes:**
- PascalCase Ruby classes — e.g., `Account`, `Balance::ForwardCalculator`, `Account::CurrentBalanceManager`
- Namespaced with `::` for sub-domains — e.g., `Api::V1::AccountsController`, `Provider::Stripe`, `DS::Button`
- ViewComponent classes inherit from `ApplicationComponent` (general) or `DesignSystemComponent` (DS primitives)

**Methods:**
- `snake_case` for all Ruby methods
- Predicate methods end in `?` — e.g., `syncing?`, `linked?`, `active?`, `supports_trades?`
- Bang methods for state-changing operations — e.g., `mark_for_deletion!`, `activate!`, `disable!`
- Private methods use 4-space indented `private` block with double-indented methods

**Variables:**
- `snake_case` for Ruby locals and instance variables
- `camelCase` for JavaScript variables
- JavaScript: `_prefixed` for "memo/cache" fields — e.g., `_d3SvgMemo`, `_normalDataPoints`
- JavaScript: `#prefixed` for private class methods — e.g., `#configureAutoScroll`, `#scrollToBottom`

**Constants:**
- `SCREAMING_SNAKE_CASE` — e.g., `DATE_FORMATS`, `MONIKERS`, `ASSISTANT_TYPES`
- Frozen after definition: `[...].freeze`

**i18n Keys:**
- Hierarchical dot notation by feature: `accounts.index.title`, `components.transaction_details.show_details`
- Descriptive key names indicating purpose, never generic: `show_details` not `button`

## Code Style

**Ruby Formatting:**
- Tool: RuboCop via `rubocop-rails-omakase` gem (`.rubocop.yml`)
- 2-space indentation (enforced via `Layout/IndentationWidth`)
- `frozen_string_literal: true` at top of API/controller files
- Run: `bin/rubocop`

**JavaScript Formatting:**
- Tool: Biome (`biome.json`) — applies to `app/javascript/**/*.js`
- Double quotes for strings (`"quoteStyle": "double"`)
- Recommended lint rules enabled; `noForEach` is off
- Run: `npm run lint` / `npm run format`

**ERB Linting:**
- Tool: `erb_lint` — `bundle exec erb_lint ./app/**/*.erb -a`

## Import Organization

**Ruby:**
- `require "test_helper"` first in test files
- Module/class open, then `include` statements at top
- No explicit import ordering enforced beyond RuboCop defaults

**JavaScript (Stimulus controllers):**
1. `@hotwired/stimulus` import
2. External library imports (e.g., `d3`)
3. Module-level constants
4. `export default class extends Controller { ... }`

## Architecture Conventions (Critical)

**Fat Models, Skinny Controllers:**
- Business logic belongs in `app/models/`, NOT `app/services/`
- Models answer questions about themselves: `account.balance_series` not `AccountService.new(account).call`
- Use Rails Concerns (`ActiveSupport::Concern`) and POROs for organization

**Authentication Context:**
- Use `Current.user` — NEVER `current_user`
- Use `Current.family` — NEVER `current_family`

**Concerns Pattern:**
```ruby
module Syncable
  extend ActiveSupport::Concern

  included do
    has_many :syncs, as: :syncable, dependent: :destroy
  end

  def syncing?
    syncs.visible.any?
  end
end
```
Location: `app/models/concerns/`

**PORO Sub-objects:**
- Namespaced under parent model — e.g., `Account::CurrentBalanceManager`, `Balance::ForwardCalculator`
- Located in directory matching namespace — e.g., `app/models/account/current_balance_manager.rb`

**State Machines:**
- Use AASM gem with `aasm column: :status, timestamps: true` block
- States: `active`, `draft`, `disabled`, `pending_deletion` (common pattern)
- Events use `may_*?` guards before transitioning

**Dependency Philosophy:**
- Minimize external gems — push Rails to its limits first
- Strong technical/business reason required for any new dependency

## ViewComponent Conventions

**Base Classes:**
- General components: inherit `ApplicationComponent < ViewComponent::Base` (`app/components/application_component.rb`)
- Design system primitives: inherit `DesignSystemComponent < ViewComponent::Base` (`app/components/design_system_component.rb`) in `app/components/DS/`

**When to use ViewComponent vs partials:**
- ViewComponent: complex logic, reused across contexts, variants/sizes, needs Stimulus, needs ARIA
- Partial: static HTML, single-context use, no variants

**Component structure:**
```ruby
class DS::Alert < DesignSystemComponent
  def initialize(message:, variant: :info)
    @message = message
    @variant = variant
  end

  private
    attr_reader :message, :variant

    def container_classes
      # compute Tailwind classes
    end
end
```

## Stimulus Controller Conventions

**File location:**
- Component-specific controllers: co-located with component in `app/components/`
- Global controllers: `app/javascript/controllers/`

**Structure pattern:**
```javascript
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["messages", "form"];
  static values = { data: Object };

  connect() { /* setup */ }
  disconnect() { /* teardown */ }

  // Public action methods (called from HTML data-action)
  publicAction() { }

  // Private methods prefixed with # (ES2022 private fields)
  #privateMethod() { }
}
```

**Rules:**
- Keep controllers lightweight — fewer than 7 targets
- Pass data via `data-*-value` attributes, not inline JavaScript
- Single responsibility per controller
- Always declare `connect()` and `disconnect()` for cleanup

## Hotwire-First Frontend

- Prefer `<dialog>` for modals, `<details><summary>` for disclosures (native HTML)
- Use Turbo Frames for partial page sections
- Query params for state over localStorage/sessions
- Server-side formatting for currencies, numbers, dates
- Always use `icon` helper in `application_helper.rb` — NEVER `lucide_icon` directly
- Use Tailwind functional tokens: `text-primary` not `text-white`, `bg-container` not `bg-white`
- Never create new styles in `app/assets/tailwind/maybe-design-system.css` without explicit approval

## Error Handling

**Ruby/Rails:**
- `rescue_from` at controller level for common error types — maps to JSON error objects in API controllers
- Bang methods (`save!`, `create!`, `update!`) in tests and internal code; returns in controllers
- Background jobs log errors via `Rails.logger.warn/error` before re-raising or swallowing
- `destroy` override pattern for recovery: catch error, transition state, re-raise
- API controllers use `render_json` helper consistently with standard error keys: `error`, `message`, `details`

**JavaScript:**
- Guard against invalid dimensions/state before DOM operations (early return pattern)
- Use optional chaining: `adapter.metadata?.provider_name`

## Logging

**Framework:** Rails.logger

**Patterns:**
- `Rails.logger.info` for normal API access and informational events
- `Rails.logger.warn` for auth failures, rate limit violations, expected-but-notable events
- `Rails.logger.error` + backtrace for unexpected exceptions in controllers
- Log user/family context in API logs: `"User: #{email} (Family: #{family_id})"`

## Comments

**When to comment:**
- Comment section headers in long files using dashes: `# --------------------------------`
- Explain non-obvious business rules or edge cases (e.g., why a scope uses `visible` instead of `incomplete`)
- Comment TODOs with linked issue/reason: `# TODO: Remove max version constraint when fixed`
- RDoc-style comments on public interfaces in test support modules

**When NOT to comment:**
- Self-explanatory validations, associations, or standard Rails patterns

## Function Design

**Ruby:**
- Short focused methods; business logic split into private helpers
- Methods answering domain questions: `account.balance_type`, `account.supports_trades?`
- `private` block with 4-space indent at class level, methods double-indented
- `attr_reader` for exposing private ivars cleanly

**JavaScript:**
- Short focused methods (< 30 lines typical)
- Public methods declared first, private `#methods` at bottom
- Arrow functions for callbacks to preserve `this`: `_reinstall = () => { ... }`

## Module Design

**Ruby Exports:**
- Constants defined at class level before methods
- Class methods via `class << self` block or `def self.method_name`
- Modules use `extend ActiveSupport::Concern` with `included do` block for AR hooks

**JavaScript:**
- Single `export default class extends Controller` per Stimulus controller file
- Utility modules not common — logic lives in controllers or Rails helpers

---

*Convention analysis: 2026-03-14*
