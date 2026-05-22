## Why

The scanner can still boot against local fixture markets by default, which makes it too easy to inspect, persist, or reason about synthetic listings as if they were current Polymarket data. We need a production path that only ingests real Polymarket listings and uses fixtures strictly for tests.

## What Changes

- Add a production market-data path that loads real Polymarket market listings from the public Gamma market APIs and enriches them with public CLOB order books.
- Replace the current synthetic live event wrapper with normalized real event and market metadata from Polymarket listings.
- Validate live market eligibility before scanning: active, not closed, not archived, accepting orders, has CLOB token IDs, and has usable order-book data.
- Move fixture loading behind test-only or explicitly named fixture-provider code so normal app configuration cannot accidentally select fixture data.
- Update configuration and documentation so the default runtime uses live read-only public Polymarket data.
- Keep all trading safety defaults: no wallet, private key, authentication, order placement, or mutating endpoints.
- **BREAKING**: `data_source: fixtures`, `gamma_fixture_path`, and `clob_books_path` will no longer be supported in production app configuration.

## Capabilities

### New Capabilities

- `real-polymarket-listings`: Production scans use only current public Polymarket listings and CLOB books; fixture data is isolated to tests.

### Modified Capabilities

- None.

## Impact

- Affected code: `src/app/application.cr`, `src/app/config.cr`, `src/clients/gamma_client.cr`, `src/clients/clob_client.cr`, domain market models, storage serialization, specs, and documentation.
- Affected config: `config/app.example.yml`, `config/live.example.yml`, and environment overrides for data-source selection.
- Affected tests: fixture-based tests should remain, but should exercise fixture providers/parsers directly instead of the default app boot path.
- External systems: read-only public Polymarket Gamma and CLOB HTTP APIs only.
