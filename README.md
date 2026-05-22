# Polymarket Inefficiency Scanner

Private, read-only Crystal scanner for fixture-backed Polymarket market-relationship analysis.

## Safety Defaults

- No real order placement.
- No wallet or private-key configuration.
- No authenticated trading endpoints.
- Dashboard/API binds to `127.0.0.1` by default.
- Live HTTP clients are GET-only scaffolds; the example app path uses fixtures.
- Trading-critical values use `PolyScan::Fixed` fixed-point integer math.

## Run

```sh
shards install
crystal spec
crystal build src/poly_scan.cr
./poly_scan --config config/app.example.yml --once
./poly_scan --config config/app.example.yml --serve
```

Then open:

- `http://127.0.0.1:8765/`
- `http://127.0.0.1:8765/api/health`
- `http://127.0.0.1:8765/api/opportunities`
- `http://127.0.0.1:8765/api/paper-trades`

## Relationship Rules

Manual relationship rules live in `config/relationships.example.yml` and support:

- `implication`
- `mutually_exclusive`
- `exhaustive_group`
- `complement`
- `correlated_group`

The scanner does not infer exhaustiveness from market titles. Use `verified_exhaustive: true` only for manually checked exactly-one groups.
