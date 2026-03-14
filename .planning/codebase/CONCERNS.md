# Codebase Concerns

**Analysis Date:** 2026-03-14

---

## Tech Debt

**VectorStore::Pgvector — Entirely Unimplemented:**
- Issue: The pgvector adapter stub raises `VectorStore::Error, "Pgvector adapter is not yet implemented"` for every method. No schema migration exists for the `vector_store_chunks` table.
- Files: `app/models/vector_store/pgvector.rb`
- Impact: Any code path that resolves to the pgvector adapter will blow up at runtime. It is quietly registered in the system.
- Fix approach: Either implement (add `neighbor` gem, write migration, implement chunking + embedding) or gate behind a feature flag so it is never selected at runtime.

**Mercury Provider — Skeletal Implementation:**
- Issue: Core methods (`import_latest_mercury_data`, `process_accounts`, `schedule_account_syncs`, `sync_status_summary`, `connected_institutions`, `institution_summary`) contain `TODO` comments pointing at sibling providers as examples. The importer stub exists but the actual API integration is not built.
- Files: `app/models/mercury_item.rb`, `app/models/mercury_item/importer.rb` (if it exists)
- Impact: Mercury items are importable via the UI but produce no data. Silently fails with a logger error.
- Fix approach: Implement importer following the `SimplefinItem::Importer` or `EnableBankingItem::Importer` pattern.

**Indexa Capital Connection Cleanup — API Delete Not Implemented:**
- Issue: `IndexaCapitalConnectionCleanupJob#delete_connection` has a `TODO` and returns `nil` instead of calling the provider API.
- Files: `app/jobs/indexa_capital_connection_cleanup_job.rb`
- Impact: Deleted Indexa Capital connections are NOT revoked at the provider API — OAuth authorizations accumulate until manually purged.
- Fix approach: Implement the `provider.delete_connection(authorization_id:, **credentials)` call once the provider client exposes it.

**Indexa Capital Activities Processor — Field Names Are Placeholders:**
- Issue: `ActivitiesProcessor` has 6 `TODO` comments marking field name customizations (`activity type field name`, `ticker extraction`, `date field names`, `amount field names`). The ACTIVITY_TYPE_TO_LABEL map exists but the actual field extraction is not confirmed against the real API payload.
- Files: `app/models/indexa_capital_account/activities_processor.rb`
- Impact: Activity import silently processes zero trades/transactions if field names do not match real API.
- Fix approach: Test against a live Indexa Capital API response and harden field name extraction.

**Temporary Assertions in Test Helper — Migration In Progress:**
- Issue: `test/support/ledger_testing_helper.rb` (line 279) contains assertions marked `TODO: Remove these assertions after migration is complete` for a balance component migration.
- Files: `test/support/ledger_testing_helper.rb`
- Impact: Test suite carries migration-era overhead. These assertions may mask genuine failures if the migration finalized but assertions were not removed.
- Fix approach: Confirm balance migration is complete and remove the temporary assertion block.

**Preferences Store — Schemaless JSONB Sprawl:**
- Issue: `User#preferences` is a JSONB column used as a catch-all for dashboard, reports, and transactions section preferences. Three separate update methods exist (`update_dashboard_preferences`, `update_reports_preferences`, `update_transactions_preferences`), all performing the same pessimistic lock + deep merge pattern.
- Files: `app/models/user.rb` (lines 238–316)
- Impact: Adding new preference scopes requires copy-pasting the lock pattern. No schema enforces valid preference keys.
- Fix approach: Extract the lock-and-merge logic into a single private method. Consider a typed preferences object or at least a constants hash of valid keys.

**Localization Tests — All Skipped:**
- Issue: `test/i18n_test.rb` skips all four i18n tests (`missing keys`, `unused keys`, `file normalization`, `inconsistent interpolations`). Comment references a GitHub issue (#1225) for future resolution.
- Files: `test/i18n_test.rb`
- Impact: Untranslated strings and orphaned keys accumulate silently. New features regularly add strings without verifying locale coverage.
- Fix approach: Incrementally re-enable tests starting with `test_no_missing_keys` once the English locale is cleaned up.

**`SELF_HOSTED` / `SELF_HOSTING_ENABLED` Dual Env Var:**
- Issue: `config/application.rb` line 30 checks both `SELF_HOSTED` and `SELF_HOSTING_ENABLED`. The atlas GOTCHAS doc notes this as an inconsistency.
- Files: `config/application.rb`
- Impact: Deployment docs and scripts that use only one var silently pick the wrong mode if both are set to conflicting values.
- Fix approach: Deprecate `SELF_HOSTING_ENABLED`, keep only `SELF_HOSTED`. Add a startup warning if the legacy var is set.

---

## Security Considerations

**AR Encryption Optional at Runtime — Plaintext Fallback:**
- Risk: The `Encryptable` concern only applies `encrypts` if `encryption_ready?` is true. If encryption keys are not configured (they are not required for self-hosted instances), `email`, `first_name`, `last_name`, `otp_secret`, and provider tokens (`MercuryItem#token`, etc.) are stored in plaintext.
- Files: `app/models/concerns/encryptable.rb`, `app/models/user.rb`, `app/models/mercury_item.rb`, `config/initializers/active_record_encryption.rb`
- Current mitigation: Self-hosted mode auto-derives keys from `SECRET_KEY_BASE` if no explicit keys provided. Managed mode requires explicit keys.
- Recommendations: Surface a startup warning when encryption is not configured. Consider making encryption mandatory for production environments. Document clearly in setup guides that plaintext storage is a security risk.

**MFA Backup Codes Stored in Plaintext PostgreSQL Array:**
- Risk: `otp_backup_codes` is a PostgreSQL array column. User.rb comment notes this column cannot be encrypted with AR encryption as-is. Backup codes are hex strings readable in a DB dump.
- Files: `app/models/user.rb` (lines 10–13, 392–406)
- Current mitigation: None — the comment acknowledges the gap.
- Recommendations: Migrate `otp_backup_codes` to a `text`/`jsonb` column to enable AR encryption, or hash the backup codes at storage (compare hash at verify time).

**API Scope Test Skipped:**
- Risk: The test for API scope checking (`should require read_accounts scope`) is explicitly skipped with `skip "Scope checking temporarily disabled - needs configuration fix"`.
- Files: `test/controllers/api/v1/accounts_controller_test.rb` (line 28)
- Current mitigation: Rack Attack rate limiting still applies. Other scope guards exist.
- Recommendations: Fix the underlying test configuration issue and re-enable the scope test to prevent scope bypass regressions.

**Bare `rescue` Blocks Swallowing All Exceptions:**
- Risk: Multiple bare `rescue` (no exception class) in hot paths catch and silently ignore any exception including `SignalException`, `NoMemoryError`, etc.
- Files: `app/models/simplefin_item/importer.rb` (lines 143, 173, 434, 521, 565), `app/models/rule_import.rb` (line 321), `app/models/transaction.rb` (line 84), `app/controllers/simplefin_items_controller.rb` (line 160)
- Current mitigation: Outer rescue blocks catch and log at higher levels.
- Recommendations: Replace bare `rescue` with specific exception classes. At minimum, use `rescue StandardError`.

**API Controllers Leak Internal Error Messages:**
- Risk: Every API controller action in `app/controllers/api/v1/` returns `"Error: #{e.message}"` in the JSON body on `rescue => e`. Exception messages may include SQL fragments, file paths, or internal model state.
- Files: `app/controllers/api/v1/transactions_controller.rb`, `app/controllers/api/v1/trades_controller.rb`, `app/controllers/api/v1/accounts_controller.rb` (and others)
- Current mitigation: Error is logged server-side with full backtrace.
- Recommendations: Return a generic `"An internal error occurred"` message in the JSON response body. Keep detail in server logs only.

---

## Performance Bottlenecks

**Reports Controller — 1,026 Lines, Complex Query Composition:**
- Problem: `ReportsController` assembles multiple financial aggregations in a single controller class. Building monthly breakdowns, trend data, and section ordering all happens inline.
- Files: `app/controllers/reports_controller.rb`
- Cause: Business logic accumulated in controller rather than being delegated to model query objects.
- Improvement path: Extract `build_monthly_breakdown_for_export`, `setup_report_data`, and `build_reports_sections` to domain query objects in `app/models/` per the "skinny controllers, fat models" convention.

**Pending Transaction Detection — Raw JSONB SQL in Scopes:**
- Problem: `Entry.pending`, `Entry.excluding_pending`, and `Entry.stale_pending` use raw INNER JOIN SQL on the `transactions` table and JSONB operator queries. These scopes silently drop Valuations and Trades from results and are not covered by standard AR query optimizations.
- Files: `app/models/entry.rb` (lines 40–69), `app/models/transaction.rb` (lines 79–86)
- Cause: Pending detection is stored in `transactions.extra` JSONB with no dedicated column, requiring runtime JSONB parsing.
- Improvement path: Add a generated or materialized boolean column `transactions.pending` to enable index-based queries, or at least add a GIN index on `transactions.extra`.

**SimpleFIN Importer — 1,331 Lines:**
- Problem: `SimplefinItem::Importer` is the largest file in the codebase at 1,331 lines, handling chunked history, regular sync, rate limiting, pending reconciliation, and stats recording.
- Files: `app/models/simplefin_item/importer.rb`
- Cause: Complex provider sync logic accumulated in a single class.
- Improvement path: Extract `import_with_chunked_history`, `import_regular_sync`, and `reconcile_pending` into collaborator classes similar to how `Account::ProviderImportAdapter` was extracted.

---

## Fragile Areas

**Sync Engine — Parent Sync Hangs on Zombie Children:**
- Files: `app/models/concerns/syncable.rb`, `app/models/sync.rb`
- Why fragile: If a child sync job is killed mid-flight (Sidekiq restart, OOM), its Sync record never finalizes. Parent sync remains `started` indefinitely until `SyncCleanerJob` marks it stale after 24 hours.
- Safe modification: Never create Sync records directly. Always use `sync_later` which acquires a pessimistic row lock. Do not bypass `SyncCleanerJob` scheduling.
- Test coverage: Covered conceptually in `docs/atlas/06_GOTCHAS.md` but integration test for the hang scenario is not present in `test/`.

**`accounts.classification` Generated Column:**
- Files: `db/schema.rb`, `app/models/account.rb`
- Why fragile: The column is a PostgreSQL stored generated column computed from `accountable_type`. ActiveRecord silently ignores assignments to it. New developers who set `account.classification = "asset"` see no error but no effect.
- Safe modification: Change `accountable_type` instead. Never set `classification` directly.
- Test coverage: No specific test guards against the silent no-op.

**Investment Contributions Category — Race Condition at Create:**
- Files: `app/models/family.rb` (lines 126–154)
- Why fragile: `investment_contributions_category` can create duplicate categories under concurrent requests. It handles this with a `rescue ActiveRecord::RecordNotUnique` and a legacy de-duplication pass, but the consolidation uses `update_all` and `delete_all` without a transaction, leaving a window for orphaned budget categories.
- Safe modification: Always use `Family#investment_contributions_category` — never create the category directly.
- Test coverage: Low — race condition path not explicitly tested.

**Auto-Exclusion of Stale Pending — Irreversible:**
- Files: `app/models/entry.rb` (lines 81–91)
- Why fragile: `auto_exclude_stale_pending` calls `update_all(excluded: true)` on entries older than 8 days with no matching posted transaction. This is irreversible without direct DB intervention. Providers with slow settlement (international wires, ACH) may have legitimate pending entries older than 8 days.
- Safe modification: The 8-day window is hardcoded. International payment flows need a longer window.
- Test coverage: Unit tested for the exclusion logic but not for the settlement time edge case.

**`Entry.pending` Scope Silently Drops Non-Transaction Entries:**
- Files: `app/models/entry.rb` (lines 40–47)
- Why fragile: The pending scope uses `INNER JOIN transactions` which excludes Valuations and Trades. Callers expecting all entries may get a truncated result.
- Safe modification: Never call `Entry.pending` on a scope that includes Valuations or Trades. Document this at the call site.

---

## Scaling Limits

**Yahoo Finance — Unofficial API with Cookie/Crumb Auth:**
- Current capacity: Rate-limited at 0.5s minimum interval between requests (`MIN_REQUEST_INTERVAL`). User-agent rotation partially mitigates fingerprinting.
- Limit: Yahoo Finance is an unofficial API. Auth mechanism requires rotating cookies/crumbs (`MAX_CRUMB_CACHE_DURATION = 1.hour`). Estimated daily limit is 2,000 requests (hardcoded mock in `usage` method).
- Scaling path: Switch to `Twelve Data` (already integrated) as primary securities provider, or subscribe to a verified Yahoo Finance commercial API.
- Files: `app/models/provider/yahoo_finance.rb`

**Rack Attack — Managed Mode API Limit at 100 req/hour per Token:**
- Current capacity: 100 requests/hour per Bearer token in managed mode, 200 req/hour per IP.
- Limit: Legitimate integrations (e.g., Google Sheets export) hitting `/reports/export_transactions` on a schedule can trip the 100 req/hour ceiling quickly.
- Scaling path: Introduce tiered API key limits (implemented in `app/services/api_rate_limiter.rb` but not connected to Rack Attack throttle).
- Files: `config/initializers/rack_attack.rb`, `app/services/api_rate_limiter.rb`

---

## Dependencies at Risk

**Yahoo Finance Unofficial API:**
- Risk: Not a sanctioned API. Can be blocked or restructured at any time without notice.
- Impact: Security price fetching fails for all investment accounts using Yahoo Finance as securities provider.
- Migration plan: `Twelve Data` is already integrated (`app/models/provider/twelve_data.rb`). Consider making it the default with Yahoo Finance as a fallback.

**`sidekiq-unique-jobs` and `aasm` — Pinned to "latest":**
- Risk: Gemfile specifies `latest` (no version constraint) for several critical gems including `sidekiq`, `sidekiq-cron`, `sidekiq-unique-jobs`, `aasm`, and multiple Hotwire gems.
- Impact: A breaking change in any of these on next `bundle update` can silently break job deduplication, sync state machines, or frontend reactivity.
- Migration plan: Pin major versions in Gemfile. Run `bundle outdated` and resolve pin candidates.
- Files: `Gemfile`

---

## Missing Critical Features

**Auto-Sync Tests Disabled:**
- Problem: `AutoSyncTest` skips both positive auto-sync tests with `"AutoSync functionality temporarily disabled"`.
- Files: `test/controllers/concerns/auto_sync_test.rb`
- Blocks: Cannot verify that auto-sync on login correctly triggers without running end-to-end manually.

**Messages Controller Retry Test Skipped:**
- Problem: `test/controllers/api/v1/messages_controller_test.rb` skips a retry test with `"Retry functionality needs debugging"`.
- Files: `test/controllers/api/v1/messages_controller_test.rb`
- Blocks: Chat message retry behavior is untested at the controller level.

**OpenAPI Spec Missing for Several Endpoints:**
- Problem: `spec/requests/api/v1/` has no spec for `holdings_controller`, `sync_controller`, `usage_controller`, or `messages_controller` API endpoints. CLAUDE.md mandates OpenAPI specs for all `api/v1/` controllers.
- Files: Missing `spec/requests/api/v1/holdings_spec.rb`, `sync_spec.rb`, `usage_spec.rb`, `messages_spec.rb`
- Blocks: `docs/api/openapi.yaml` is incomplete. Third-party integrators cannot discover these endpoints from generated docs.

---

## Test Coverage Gaps

**Scope Checking for API Authorization:**
- What's not tested: The OAuth scope enforcement for API read/write operations. The only scope test is explicitly skipped.
- Files: `test/controllers/api/v1/accounts_controller_test.rb` (line 28)
- Risk: A misconfigured Doorkeeper scope could allow read-only tokens to perform write operations undetected.
- Priority: High

**Auto-Sync on Login Flow:**
- What's not tested: Two of four `AutoSyncTest` cases are skipped. The feature itself may still work, but regressions would not be caught.
- Files: `test/controllers/concerns/auto_sync_test.rb`
- Risk: Degraded sync user experience goes undetected until user reports.
- Priority: Medium

**Mercury Provider Integration:**
- What's not tested: Mercury importer has no test coverage because the implementation is a stub.
- Files: No `test/models/mercury_item/importer_test.rb` exists.
- Risk: Any Mercury account sync silently fails without alerting CI.
- Priority: High (blocked by implementation)

**Indexa Capital Activities Processor Field Mapping:**
- What's not tested: Whether the TODO-filled field extraction correctly maps to real API payloads.
- Files: `app/models/indexa_capital_account/activities_processor.rb`
- Risk: Zero activities imported for Indexa Capital users; hard to distinguish from an empty account.
- Priority: High (blocked by implementation)

**Bare `rescue` in SimpleFIN Importer:**
- What's not tested: Whether the bare `rescue` blocks in `SimplefinItem::Importer` mask genuine programming errors during sync.
- Files: `app/models/simplefin_item/importer.rb`
- Risk: A bug in inner processing logic is swallowed and logged, but the sync reports success.
- Priority: Medium

---

*Concerns audit: 2026-03-14*
