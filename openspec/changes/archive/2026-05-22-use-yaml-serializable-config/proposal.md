## Why

Configuration parsing is currently a hand-written `YAML::Any` mapper that repeats field names, default handling, and type extraction across every option. Moving to Crystal's `YAML::Serializable` makes the config contract explicit in typed structures while preserving behavior for valid configuration files.

## What Changes

- Replace manual top-level configuration parsing with `YAML::Serializable`.
- Represent nested `http`, `paper_trading`, and `telegram` sections as typed serializable config objects with defaults.
- Preserve current public config accessors used by application, HTTP, detector, paper-trading, dashboard, and alert code.
- Keep environment overrides and validation as post-load steps.
- Update fixed-point YAML conversion so serializable config fields can parse quoted decimal strings safely.
- **BREAKING**: Reject unknown YAML configuration keys instead of silently ignoring them.
- Add tests for default config loading, nested section parsing, environment overrides, unknown key handling, and fixed-point decimal validation.

## Capabilities

### New Capabilities
- `configuration-loading`: Defines how YAML app configuration is loaded, defaulted, validated, and exposed to runtime components.

### Modified Capabilities
- None.

## Impact

- Affected code: `src/app/config.cr`, `src/domain/fixed.cr`, and config-focused specs.
- Affected runtime behavior: application boot continues to use `Config.load(path)` and existing environment overrides.
- Affected documentation: README configuration guidance should note that unknown YAML keys are rejected.
- Dependencies: no new shard dependencies; uses Crystal standard library `YAML::Serializable`.
