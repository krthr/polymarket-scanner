## 1. Provider Boundary

- [x] 1.1 Add a market-data result type that carries events, markets, books, and skipped-listing diagnostics.
- [x] 1.2 Add a `MarketDataProvider` interface or equivalent abstraction for application boot.
- [x] 1.3 Update `Application.boot` to construct and use the real Polymarket provider instead of branching on fixture data source.
- [x] 1.4 Move fixture loading behind test helpers or an explicitly named fixture provider that is not selectable from production YAML.

## 2. Real Listing Parsing

- [x] 2.1 Add Gamma market listing fetch support using `/markets` or `/markets/keyset` with pagination and configurable limits.
- [x] 2.2 Parse real listing fields including market id, condition id, question id, slug, question, category, end date, active, closed, archived, accepting orders, outcomes, CLOB token ids, and nested events.
- [x] 2.3 Filter out listings that are closed, archived, inactive, not accepting orders, or missing usable CLOB token ids.
- [x] 2.4 Preserve real event metadata when present and avoid creating synthetic `clob-live` events.

## 3. Domain And Storage

- [x] 3.1 Extend market domain models to represent explicit real identifiers such as Gamma id, condition id, question id, and accepting-orders status.
- [x] 3.2 Update JSON serialization specs for the extended domain fields.
- [x] 3.3 Update SQLite migrations or storage serialization so persisted markets retain the real Polymarket identifiers needed for reconciliation.
- [x] 3.4 Ensure existing detectors continue to use token ids and market ids without relying on fixture-specific identifiers.

## 4. CLOB Book Enrichment

- [x] 4.1 Fetch CLOB books only for token ids discovered from eligible real listings.
- [x] 4.2 Validate fetched books and insert usable books into `OrderBookCache`.
- [x] 4.3 Log structured skip/failure reasons when listing validation or book fetching fails.
- [x] 4.4 Ensure detectors do not fabricate opportunities when required real books are missing.

## 5. Configuration And Documentation

- [x] 5.1 Remove production support for `data_source: fixtures`, `gamma_fixture_path`, and `clob_books_path`.
- [x] 5.2 Update `config/app.example.yml` so the default example uses real read-only Polymarket data.
- [x] 5.3 Remove, replace, or clearly repurpose `config/live.example.yml` to avoid duplicate runtime modes.
- [x] 5.4 Update README run instructions, configuration tables, and safety notes to describe real-listing-only runtime behavior.
- [x] 5.5 Update relationship-rule documentation to explain that production rules must reference loaded real tokens or resolved live market/outcome references.

## 6. Tests And Verification

- [x] 6.1 Add parser tests using captured real Gamma listing samples and CLOB book samples.
- [x] 6.2 Add config validation tests proving fixture runtime configuration is rejected.
- [x] 6.3 Convert app integration tests to inject fixture data through test-only provider/helpers instead of production config.
- [x] 6.4 Add provider tests for filtering inactive, closed, archived, not-accepting-orders, and missing-token listings.
- [x] 6.5 Add provider tests for book fetch failures and skip diagnostics.
- [x] 6.6 Run `shards install` if dependencies are missing, then run `crystal spec`.
- [x] 6.7 Run a small real-data one-shot scan and verify persisted markets come from real Polymarket listings with no fixture market IDs.
