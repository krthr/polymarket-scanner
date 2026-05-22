## ADDED Requirements

### Requirement: Production boot uses only real listings
The production application runtime SHALL load market listings only from public Polymarket APIs and MUST NOT load local fixture market or book files during normal boot.

#### Scenario: Default application boot
- **WHEN** the scanner starts with the default production configuration
- **THEN** it fetches listings from Polymarket HTTP APIs
- **THEN** it does not read `spec/fixtures` market or book JSON files

#### Scenario: Fixture config is rejected
- **WHEN** production configuration includes a fixture data source or fixture file paths
- **THEN** configuration validation fails before scanning begins

### Requirement: Listings preserve real Polymarket identity
The system SHALL normalize each scanned market from real Polymarket listing data while preserving the real market slug, question, event metadata when available, CLOB condition id, CLOB token ids, active status, closed status, archived status, and accepting-orders status.

#### Scenario: Real listing with nested event metadata
- **WHEN** a real listing includes nested event metadata
- **THEN** the persisted event and market records use the real Polymarket event and market values
- **THEN** no synthetic `clob-live` event is created for that market

#### Scenario: Listing without required CLOB tokens
- **WHEN** a real listing lacks usable CLOB token ids
- **THEN** the listing is excluded from executable scanning
- **THEN** the system logs or records the exclusion reason without fabricating token ids

### Requirement: Ineligible markets are filtered before scanning
The system SHALL scan only markets that are active, not closed, not archived, accepting orders, and backed by CLOB tokens.

#### Scenario: Closed or archived listing
- **WHEN** a Polymarket listing is closed or archived
- **THEN** the market is not included in detector input

#### Scenario: Listing is not accepting orders
- **WHEN** a Polymarket listing is active but not accepting orders
- **THEN** the market is not included in detector input

### Requirement: CLOB books are fetched for real listing tokens
The system SHALL fetch order books from the public CLOB book endpoint only for token ids discovered from eligible real Polymarket listings.

#### Scenario: Eligible binary listing
- **WHEN** an eligible real binary listing provides YES and NO CLOB token ids
- **THEN** the system fetches books for those token ids
- **THEN** detectors use the fetched order books for executable price and depth checks

#### Scenario: Book fetch fails
- **WHEN** a CLOB book request fails for a token discovered from a real listing
- **THEN** the failure is logged
- **THEN** detectors that require that book do not produce opportunities for the missing book

### Requirement: Fixtures are isolated to tests
Fixture market and book JSON files SHALL remain usable for deterministic tests, but MUST be accessed only through test helpers, parser tests, or an explicitly injected fixture provider.

#### Scenario: Parser test reads captured fixture
- **WHEN** a parser spec loads a captured JSON fixture
- **THEN** the fixture is parsed without requiring live network access

#### Scenario: Production app path cannot select fixture provider
- **WHEN** normal application boot constructs its market data provider
- **THEN** it constructs the real Polymarket provider
- **THEN** it cannot select the fixture provider through production YAML configuration

### Requirement: Runtime remains read-only
The real listing ingestion path SHALL use only unauthenticated read-only public HTTP endpoints and MUST NOT configure wallets, private keys, signatures, order placement, or mutating Polymarket endpoints.

#### Scenario: Real-data scan
- **WHEN** the scanner performs a real-data scan
- **THEN** all Polymarket HTTP requests are GET requests to public listing or book endpoints
- **THEN** no authenticated or mutating trading endpoint is called
