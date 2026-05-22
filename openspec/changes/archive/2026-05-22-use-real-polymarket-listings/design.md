## Context

The application currently supports two runtime data paths. `fixtures` loads local Gamma and CLOB JSON files, while `live` loads CLOB sampling markets and wraps them in one synthetic `clob-live` event. The default example configuration still selects fixtures, and relationship rules reference fixture token IDs.

Polymarket exposes richer real listing data through Gamma market endpoints and executable book data through CLOB book endpoints. The scanner should treat Gamma market listings as the canonical source for real market/event metadata, then use CLOB only for token-level order-book data and optional eligibility checks.

## Goals / Non-Goals

**Goals:**

- Make production application boot use only public, current Polymarket listings.
- Preserve fixture parsing for tests without exposing fixtures as a normal runtime data source.
- Normalize real Gamma market/event fields into domain models without synthetic live event wrappers.
- Fetch CLOB books only for tokens discovered from real listings and only scan markets with usable books.
- Keep the scanner read-only and unauthenticated.

**Non-Goals:**

- No trading, order placement, wallet configuration, signing, or authenticated API support.
- No automatic inference of logical relationships between unrelated markets.
- No guarantee that every Polymarket market is scanned in one run; limits and pagination remain configurable.
- No replacement for manually curated or externally sourced model probabilities.

## Decisions

1. Introduce a `MarketDataProvider` boundary for app boot.

   Production boot will depend on a provider that returns `events`, `markets`, and `books` together. A `RealPolymarketProvider` will fetch real listings and enrich books. A fixture provider or parser helpers can exist under specs for deterministic tests.

   Alternative considered: keep `data_source` branching in `Application`. That leaves fixture selection as a production concern and keeps the current accidental-use risk.

2. Use Gamma market listings as the canonical listing source.

   The provider will fetch Gamma `/markets` or `/markets/keyset` pages, filter to active, not closed, not archived, accepting-orders markets, and parse `clobTokenIds` plus outcome names. Nested event metadata, when present, will become real `Event` records. Markets without usable CLOB tokens will be skipped before book fetching.

   Alternative considered: continue using CLOB `/sampling-markets`. That endpoint is useful for market sampling and books, but it omits or weakens listing/event metadata and currently forces synthetic event modeling.

3. Enrich listings with CLOB order books by token ID.

   For each eligible token discovered from Gamma listings, the provider will fetch CLOB `/book?token_id=...`, validate the returned book, and insert it into `OrderBookCache`. Book fetch failures will be logged and will cause that token/market to be skipped by detectors that require executable depth.

   Alternative considered: use token prices embedded in simplified market responses. The current code intentionally avoids using token prices as trading-critical values; executable scanning should continue to use order books and fixed-point parsing.

4. Make fixture use explicit and test-scoped.

   Runtime config will remove `data_source: fixtures`, `gamma_fixture_path`, and `clob_books_path`. Specs can still parse captured JSON files directly or through a clearly named fixture helper. `config/app.example.yml` becomes the real-data example, and `config/live.example.yml` can be removed or reduced to an alias/example if still useful.

   Alternative considered: keep fixture config but default to live. That still allows accidental synthetic runtime scans and weakens the contract of this change.

5. Separate real identifiers in the domain model.

   `Market.id` is currently overloaded between Gamma ids and CLOB condition ids. The implementation should preserve compatibility where practical, but add explicit fields or a source mapping for Gamma id, condition id, question id, and accepting-orders status so storage and book matching are unambiguous.

   Alternative considered: continue storing only one id. That makes it difficult to reconcile Gamma markets with CLOB books and relationship rules safely.

## Risks / Trade-offs

- Gamma and CLOB schemas can drift -> keep parser tests with captured real-response samples and fail closed when required identifiers are missing.
- Live API calls make app boot slower and less deterministic -> retain limits, pagination controls, retries, throttling, and deterministic parser tests.
- Removing fixture runtime config is breaking -> update examples and tests in the same change, and keep fixture helpers available for local parser testing.
- Some real markets may have partial metadata or book failures -> skip incomplete markets and log structured reasons instead of fabricating placeholders.
- Existing relationship examples reference fixture tokens -> provide a real-token rule example or document that relationship rules must reference loaded real tokens/slugs.

## Migration Plan

1. Add the provider abstraction and wire production boot to the real provider.
2. Implement Gamma market pagination/parsing and CLOB book enrichment.
3. Update domain models, storage serialization, and tests for explicit real identifiers.
4. Remove fixture runtime config fields and update example YAML/docs.
5. Convert app integration tests to use an injected fixture provider instead of production fixture config.

Rollback is straightforward before deployment: restore the old `data_source` branch and fixture config fields. After deployment, rollback requires restoring removed config fields or using the test fixture provider only in local test code.

## Open Questions

- Should relationship rules reference live markets by token ID only, or support stable `market_slug` plus outcome labels resolved at startup?
- Should `/markets` or `/markets/keyset` be the default Gamma listing endpoint for the first implementation?
