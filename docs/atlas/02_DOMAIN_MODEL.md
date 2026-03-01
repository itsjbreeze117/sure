# Domain Model

## Core Entities

### Family
- **Defined in**: `app/models/family.rb`
- **Key fields**: `currency`, `locale`, `date_format`, `country`, `month_start_day`, `moniker`, `assistant_type`
- **Role**: Top-level tenant/owner. All accounts, entries, categories, tags belong to a Family.
- **Includes**: `Syncable`, `Subscribeable`, 9x `{Provider}Connectable` concerns
- **Key methods**: `balance_sheet`, `income_statement`, `investment_statement`, `auto_categorize_transactions_later`

### User
- **Defined in**: `app/models/user.rb`
- **Key fields**: `email`, `password_digest`, `role`, `family_id`
- **Role**: A person within a Family. Multiple users can share one Family.
- **Auth**: bcrypt passwords, optional MFA (ROTP), SSO via OmniAuth

### Account (delegated_type)
- **Defined in**: `app/models/account.rb`
- **Key fields**: `name`, `balance`, `cash_balance`, `currency`, `status`, `classification` (generated column), `accountable_type`, `accountable_id`
- **Lifecycle**: `active` (initial) -> `draft` | `disabled` -> `pending_deletion` (AASM)
- **delegated_type**: `accountable` -> one of 9 Accountable types
- **Includes**: `AASM`, `Syncable`, `Monetizable`, `Chartable`, `Linkable`, `Enrichable`

### Entry (delegated_type)
- **Defined in**: `app/models/entry.rb`
- **Key fields**: `date`, `name`, `amount`, `currency`, `account_id`, `entryable_type`, `entryable_id`, `excluded`, `user_modified`, `import_locked`, `locked_attributes`
- **delegated_type**: `entryable` -> one of 3 Entryable types
- **Protection**: `protected_from_sync?` checks `excluded`, `user_modified`, `import_locked`

### Sync
- **Defined in**: `app/models/sync.rb`
- **Key fields**: `syncable_type`, `syncable_id`, `status`, `parent_id`, `window_start_date`, `window_end_date`, `error`
- **Lifecycle**: `pending` -> `syncing` -> `completed` | `failed` | `stale` (AASM)

## Accountable Types (9)

Defined in `app/models/concerns/accountable.rb`:

```ruby
TYPES = %w[Depository Investment Crypto Property Vehicle OtherAsset CreditCard Loan OtherLiability]
```

| Type | File | Classification | Balance Type |
|------|------|---------------|-------------|
| `Depository` | `app/models/depository.rb` | asset | cash |
| `Investment` | `app/models/investment.rb` | asset | investment |
| `Crypto` | `app/models/crypto.rb` | asset | investment |
| `Property` | `app/models/property.rb` | asset | non_cash |
| `Vehicle` | `app/models/vehicle.rb` | asset | non_cash |
| `OtherAsset` | `app/models/other_asset.rb` | asset | non_cash |
| `CreditCard` | `app/models/credit_card.rb` | liability | cash |
| `Loan` | `app/models/loan.rb` | liability | non_cash |
| `OtherLiability` | `app/models/other_liability.rb` | liability | non_cash |

## Entryable Types (3)

Defined in `app/models/entryable.rb`:

```ruby
TYPES = %w[Valuation Transaction Trade]
```

| Type | File | Purpose |
|------|------|---------|
| `Transaction` | `app/models/transaction.rb` | Income/expense entries. Has `kind` enum, `category`, `merchant`, `tags` |
| `Valuation` | `app/models/valuation.rb` | Point-in-time account value snapshots (e.g., property appraisals) |
| `Trade` | `app/models/trade.rb` | Buy/sell of securities. Links to `Security` via `security_id` |

## Transaction Kinds

```ruby
enum :kind, {
  standard: "standard",              # Regular transaction, included in budgets
  funds_movement: "funds_movement",  # Internal transfer, excluded from budgets
  cc_payment: "cc_payment",          # Credit card payment, excluded from budgets
  loan_payment: "loan_payment",      # Loan payment, treated as expense in budgets
  one_time: "one_time",              # One-time, excluded from budgets
  investment_contribution: "investment_contribution"  # Investment transfer, expense in budgets
}
```

## Vocabulary

| Term | Meaning | Where Used |
|------|---------|-----------|
| Family | Top-level tenant, owns all accounts and data | `app/models/family.rb` |
| Accountable | The type-specific model behind a delegated Account | `app/models/concerns/accountable.rb` |
| Entryable | The type-specific model behind a delegated Entry | `app/models/entryable.rb` |
| Provider Item | A bank connection (e.g., `PlaidItem`, `SimplefinItem`) | `app/models/{provider}_item.rb` |
| Provider Account | A bank account within a connection | `app/models/{provider}_account.rb` |
| Syncer | Class that performs sync logic for a model | `app/models/{model}/syncer.rb` |
| Linkable | Account linked to a provider (has `external_id`) | `app/models/concerns/linkable.rb` |
| Enrichable | Model that can be enriched with AI data | `app/models/concerns/enrichable.rb` |
| Monetizable | Model with money fields (uses `Money` objects) | `app/models/concerns/monetizable.rb` |
| Balance Type | Whether account tracks cash, non-cash, or investment balance | `app/models/account.rb#balance_type` |

## State Machines

### Account Lifecycle (AASM)
```
[active] <--enable-- [disabled]
   |                     ^
   +---disable----------+
   |
   +---mark_for_deletion--> [pending_deletion] --> DestroyJob
   ^
   |
[draft] --activate--> [active]
```

### Sync Lifecycle (AASM)
```
[pending] --start--> [syncing] --complete--> [completed]
                         |
                         +---fail--> [failed]

[pending|syncing] --mark_stale--> [stale]  (after 24 hours)
```

### Sync Hierarchy
```
Family Sync (parent)
  +-- Account Sync (child 1)
  +-- Account Sync (child 2)
  +-- Account Sync (child N)

Parent completes only when ALL children finalize.
If any child fails, parent fails.
```

## Key Relationships

```
Family
  |-- has_many Users
  |-- has_many Accounts
  |     |-- delegated_type Accountable (9 types)
  |     |-- has_many Entries
  |     |     |-- delegated_type Entryable (Transaction, Valuation, Trade)
  |     |-- has_many Holdings
  |     |-- has_many Balances
  |     |-- has_many Syncs (via Syncable)
  |-- has_many Categories
  |-- has_many Tags
  |-- has_many FamilyMerchants
  |-- has_many Budgets -> BudgetCategories
  |-- has_many Rules -> Actions, Conditions
  |-- has_many Imports
  |-- has_many {Provider}Items (via Connectable concerns)
```
