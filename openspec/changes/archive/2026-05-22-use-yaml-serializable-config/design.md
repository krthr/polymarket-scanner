## Context

`PolyScan::App::Config.load` currently parses YAML through `YAML.parse` and manually copies every supported key from `YAML::Any` into mutable properties. This keeps the external config format simple, but the parser duplicates defaults, field names, type conversions, nested-section handling, and quoted fixed-point checks in one method.

Crystal 1.20.2 provides `YAML::Serializable` in the standard library. It can generate typed `from_yaml` parsing, honor default property values, map nested objects, and reject unknown keys through `YAML::Serializable::Strict`.

The migration must preserve `Config.load(path)` as the application entrypoint and keep the current accessors used by `Application`, `HttpClient`, detectors, paper trading, dashboard, and Telegram alert setup.

## Goals / Non-Goals

**Goals:**

- Replace hand-written `YAML::Any` config parsing with `YAML::Serializable`.
- Model nested `http`, `paper_trading`, and `telegram` YAML sections as typed serializable config objects.
- Preserve valid config behavior, defaults, environment overrides, validation, and public accessors.
- Reject unknown config keys so typos are visible at startup.
- Keep fixed-point config values as quoted decimal strings and parse them through `PolyScan::Fixed`.

**Non-Goals:**

- Do not change the YAML file layout or option names.
- Do not add new config options.
- Do not change relationship-rule YAML parsing.
- Do not add external shards or runtime dependencies.

## Decisions

### Use `YAML::Serializable::Strict` for config objects

The config contract should fail fast on misspelled or obsolete keys. This is safer for trading-related settings than silently ignoring unknown YAML.

Alternative considered: plain `YAML::Serializable`, which matches the current unknown-key behavior. It avoids a compatibility break, but preserves typo-prone startup behavior. The proposal marks this as a breaking validation change.

### Keep `Config.load` as the boundary

`Config.load(path)` will remain responsible for missing-file defaults, YAML deserialization, environment overrides, and validation. Internally, it will instantiate `Config.new` when the file is absent and `Config.from_yaml(File.read(path))` when present.

Alternative considered: call `Config.from_yaml` directly from application boot. That would leak file-existence behavior and post-load invariants into callers.

### Represent nested sections with dedicated typed objects

Create serializable config types for `http`, `paper_trading`, and `telegram`. `Config` will keep compatibility methods such as `http_timeout_ms`, `paper_trading_enabled`, `telegram_bot_token`, and `telegram_chat_id` so existing runtime code does not need a broad refactor.

Alternative considered: flatten nested YAML into existing top-level properties with custom field keys. That keeps fewer classes but loses the structure that `YAML::Serializable` is meant to provide.

### Make `Fixed::YAMLConverter` compatible with `YAML::Serializable`

Fixed-point config fields should use `@[YAML::Field(converter: Fixed::YAMLConverter)]`. The converter must accept `YAML::ParseContext` and `YAML::Nodes::Node`, assert that the node is a quoted scalar, parse with `Fixed.parse`, and emit quoted decimal scalars.

Alternative considered: add `Fixed.new(ctx, node)` and let fields deserialize without annotations. Field-level converters are clearer because the quoted-decimal rule is a config-format constraint, not necessarily a universal YAML representation for `Fixed`.

## Risks / Trade-offs

- Unknown keys become startup errors -> Document the stricter validation and add tests for typo handling.
- Nested config objects can change internal shape -> Keep existing top-level compatibility accessors and test callers through `Application.boot`.
- Converter changes can affect other YAML uses of `Fixed` -> Scope the behavior to explicit `Fixed::YAMLConverter` usage and keep relationship-rule parsing unchanged.
- YAML parse errors may expose different exception classes/messages -> Test behavior by outcome rather than exact full messages where possible.

## Migration Plan

1. Add/adjust serializable config types while keeping current public methods.
2. Convert `Config.load` to use `Config.from_yaml` for existing files and `Config.new` for missing files.
3. Update `Fixed::YAMLConverter` for `YAML::Serializable` field conversion and quoted scalar enforcement.
4. Add focused config specs and run the existing integration spec.
5. Update README if unknown-key rejection is implemented.

Rollback is straightforward: revert `src/app/config.cr`, the converter adjustment, and the associated tests/documentation.

## Open Questions

- None.
