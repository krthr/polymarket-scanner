# configuration-loading Specification

## Purpose
Defines how application YAML configuration is loaded, defaulted, validated, and exposed to runtime components.

## Requirements
### Requirement: Configuration load entrypoint
The system SHALL load application configuration through `PolyScan::App::Config.load(path)` and return a validated `Config` object.

#### Scenario: Missing config file uses defaults
- **WHEN** `Config.load(path)` is called with a path that does not exist
- **THEN** the returned config uses built-in defaults, applies supported environment overrides, and passes validation

#### Scenario: Existing config file is deserialized
- **WHEN** `Config.load(path)` is called with an existing YAML config file
- **THEN** the returned config reflects YAML values, built-in defaults for omitted values, supported environment overrides, and validation results

### Requirement: Typed YAML deserialization
The system SHALL deserialize app configuration with Crystal `YAML::Serializable` types instead of manual `YAML::Any` field extraction.

#### Scenario: Nested HTTP settings load from YAML
- **WHEN** the YAML file contains an `http` mapping with timeout, retry, jitter, and rate-limit values
- **THEN** the returned config exposes those values through the existing HTTP accessor methods

#### Scenario: Nested paper trading settings load from YAML
- **WHEN** the YAML file contains `paper_trading.enabled`
- **THEN** the returned config exposes the value through the existing paper-trading accessor

#### Scenario: Nested Telegram settings resolve secrets from environment names
- **WHEN** the YAML file contains Telegram environment-variable names and those environment variables are set
- **THEN** the returned config exposes the resolved Telegram token and chat ID values without requiring secrets in YAML

### Requirement: Existing config API compatibility
The system SHALL preserve the public config methods currently used by runtime components.

#### Scenario: Existing callers read top-level config methods
- **WHEN** application, HTTP client, detector, paper trading, dashboard, or alert code reads existing config methods
- **THEN** those methods compile and return the same values they returned for equivalent valid YAML before this change

### Requirement: Fixed-point config values
The system SHALL parse trading-critical fixed-point config values from quoted YAML decimal strings through `PolyScan::Fixed`.

#### Scenario: Quoted fixed-point decimal parses
- **WHEN** the YAML file contains a fixed-point setting such as `scan_size: "1.000000"`
- **THEN** the returned config contains the corresponding `PolyScan::Fixed` value

#### Scenario: Unquoted fixed-point decimal is rejected
- **WHEN** the YAML file contains an unquoted fixed-point setting such as `scan_size: 1.000000`
- **THEN** config loading fails with an error that identifies the value as an invalid fixed-point config scalar

### Requirement: Strict config key validation
The system SHALL reject unknown YAML keys in app configuration.

#### Scenario: Unknown top-level key fails
- **WHEN** the YAML file contains a top-level key that is not part of the supported app config schema
- **THEN** config loading fails instead of silently ignoring the key

#### Scenario: Unknown nested key fails
- **WHEN** the YAML file contains an unsupported key inside a nested config section
- **THEN** config loading fails instead of silently ignoring the key

### Requirement: Post-load validation
The system SHALL run environment overrides and existing semantic validation after YAML deserialization.

#### Scenario: Environment override is applied before validation
- **WHEN** a supported `POLY_SCAN_*` environment override is set
- **THEN** the override is reflected in the returned config before validation completes

#### Scenario: Invalid semantic value is rejected
- **WHEN** the YAML file or environment overrides produce an invalid semantic value such as a non-positive scan size, non-positive rate limit, or unsupported data source
- **THEN** config loading fails with a validation error
