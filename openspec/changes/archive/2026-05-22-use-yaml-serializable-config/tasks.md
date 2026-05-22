## 1. Config Model Refactor

- [x] 1.1 Update `PolyScan::App::Config` to include `YAML::Serializable` and `YAML::Serializable::Strict`.
- [x] 1.2 Add typed serializable nested config types for `http`, `paper_trading`, and `telegram` with current default values.
- [x] 1.3 Annotate fixed-point config fields with `Fixed::YAMLConverter`.
- [x] 1.4 Preserve current public config accessors used by existing runtime callers.

## 2. Loading, Overrides, and Validation

- [x] 2.1 Replace manual `YAML::Any` parsing in `Config.load` with `Config.from_yaml` for existing files and `Config.new` for missing files.
- [x] 2.2 Keep environment overrides applied after file loading and before validation.
- [x] 2.3 Preserve current semantic validation for bind host, data source, scan size, rate limit, live market limit, and live book limit.
- [x] 2.4 Ensure unknown top-level and nested YAML keys fail during config loading.

## 3. Fixed-Point YAML Conversion

- [x] 3.1 Update `Fixed::YAMLConverter.from_yaml` to accept `YAML::ParseContext` and `YAML::Nodes::Node` safely for `YAML::Serializable` fields.
- [x] 3.2 Reject unquoted fixed-point config scalars with a clear parse error.
- [x] 3.3 Emit fixed-point YAML values as quoted decimal scalars.

## 4. Tests and Documentation

- [x] 4.1 Add focused config specs for defaults, nested YAML sections, environment overrides, Telegram env resolution, and compatibility accessors.
- [x] 4.2 Add config specs for unknown top-level keys, unknown nested keys, unquoted fixed-point values, and invalid semantic values.
- [x] 4.3 Update README configuration docs to state that unknown YAML config keys are rejected.
- [x] 4.4 Run the Crystal spec suite and fix any regressions.
