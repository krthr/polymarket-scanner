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

## Configuration

The app loads YAML from `--config PATH`, or from `POLY_SCAN_CONFIG` when no `--config` argument is provided. If neither is set, it uses `config/app.example.yml`.

Trading-critical decimal values must be quoted strings with up to six decimal places, for example `"0.005000"`. They are parsed into fixed-point integer atoms by `PolyScan::Fixed`; do not write these values as YAML floats.

Top-level options:

| Option | Default | Description |
| --- | --- | --- |
| `bind_host` | `"127.0.0.1"` | Dashboard/API bind host. Non-loopback binds are rejected unless `POLY_SCAN_ALLOW_PUBLIC_BIND=true` is set. |
| `port` | `8765` | Dashboard/API TCP port. |
| `database_path` | `"data/poly_scan.db"` | SQLite database file path. Parent directories are created automatically. |
| `gamma_base_url` | `"https://gamma-api.polymarket.com"` | Base URL for the read-only Gamma discovery client. The default app flow still uses fixtures. |
| `clob_base_url` | `"https://clob.polymarket.com"` | Base URL for the read-only CLOB book client. The default app flow still uses fixtures. |
| `gamma_fixture_path` | `"spec/fixtures/gamma_event.json"` | Fixture file used to load events, markets, and outcomes. |
| `clob_books_path` | `"spec/fixtures/books"` | Directory containing CLOB order-book JSON fixtures. |
| `relationships_path` | `"config/relationships.example.yml"` | Manual relationship-rule YAML file. |
| `scan_size` | `"1.000000"` | Fixed-point size used for executable VWAP checks and paper-trade legs. Must be positive. |
| `taker_fee_bps` | `0` | Taker fee in basis points. Fee is computed on `min(price, 1-price) * size`. |
| `max_book_age_ms` | `300000` | Maximum book age before stale-book risk and stale penalties apply. |
| `max_spread` | `"0.080000"` | Spread threshold for wide-spread risk and `SpreadAnomaly` signals. |
| `min_depth` | `"1.000000"` | Minimum ask depth used by spread anomaly checks. |
| `slippage_buffer` | `"0.005000"` | Fixed-point buffer subtracted from gross edge. |
| `uncertainty_penalty` | `"0.003000"` | Fixed-point penalty subtracted from gross edge. |
| `resolution_penalty` | `"0.002000"` | Fixed-point resolution-risk penalty subtracted from gross edge. |
| `stale_book_penalty` | `"0.010000"` | Fixed-point penalty applied when a book is stale. |
| `low_confidence_threshold` | `"0.600000"` | Confidence below this threshold adds the low-confidence risk flag. |
| `high_fee_threshold` | `"0.010000"` | Per-leg fee at or above this threshold adds the high-fees risk flag. |
| `imbalance_ratio` | `"3.000000"` | Depth ratio threshold for `BookImbalance` supporting signals. |

HTTP options under `http`:

| Option | Default | Description |
| --- | --- | --- |
| `timeout_ms` | `5000` | Connect, read, and write timeout for read-only HTTP calls. |
| `max_retries` | `2` | Number of retries after the first HTTP attempt. |
| `retry_backoff_ms` | `250` | Base exponential backoff delay. |
| `retry_jitter_ms` | `125` | Random jitter added to retry backoff. |
| `rate_limit_per_minute` | `60` | Conservative per-client request pacing. Must be positive. |

Paper trading options under `paper_trading`:

| Option | Default | Description |
| --- | --- | --- |
| `enabled` | `true` | Creates local paper trades from generated opportunities. This never places real orders. |

Telegram options under `telegram`:

| Option | Default | Description |
| --- | --- | --- |
| `enabled` | `false` | Enables the alert scaffold. Current implementation logs readiness/skips and does not send network alerts. |
| `bot_token_env` | `"POLY_SCAN_TELEGRAM_BOT_TOKEN"` | Name of the environment variable containing the bot token. The token itself is not stored in YAML. |
| `chat_id_env` | `"POLY_SCAN_TELEGRAM_CHAT_ID"` | Name of the environment variable containing the chat ID. The chat ID itself is not stored in YAML. |

Environment overrides:

| Variable | Description |
| --- | --- |
| `POLY_SCAN_CONFIG` | Config file path used when `--config` is not provided. |
| `POLY_SCAN_BIND_HOST` | Overrides `bind_host`. Public binds still require `POLY_SCAN_ALLOW_PUBLIC_BIND=true`. |
| `POLY_SCAN_PORT` | Overrides `port`. |
| `POLY_SCAN_DATABASE_PATH` | Overrides `database_path`. |
| `POLY_SCAN_RELATIONSHIPS_PATH` | Overrides `relationships_path`. |
| `POLY_SCAN_ALLOW_PUBLIC_BIND` | Set to `true` to permit a non-`127.0.0.1` bind. Leave unset for private local use. |

Example:

```sh
POLY_SCAN_DATABASE_PATH=tmp/dev.db \
POLY_SCAN_RELATIONSHIPS_PATH=config/relationships.example.yml \
./poly_scan --config config/app.example.yml --serve
```

## Relationship Rules

Manual relationship rules live in `config/relationships.example.yml` and support:

- `implication`
- `mutually_exclusive`
- `exhaustive_group`
- `complement`
- `correlated_group`

The scanner does not infer exhaustiveness from market titles. Use `verified_exhaustive: true` only for manually checked exactly-one groups.

Rule fields:

| Field | Required | Applies To | Description |
| --- | --- | --- | --- |
| `id` | Yes | All rules | Stable unique rule ID. Used in opportunity IDs and storage. |
| `type` | Yes | All rules | One of the supported relationship types above. |
| `description` | No | All rules | Human-readable note explaining the manual rule source or reasoning. |
| `from_token_id` | Yes | `implication` | Antecedent YES token. In `A implies B`, this is `A`. |
| `to_token_id` | Yes | `implication` | Consequent YES token. In `A implies B`, this is `B`. |
| `token_ids` | Type-dependent | Group rules | YES token IDs for `mutually_exclusive`, `exhaustive_group`, `complement`, and `correlated_group`. |
| `confidence` | No | All rules | Quoted fixed-point confidence factor. Defaults to `"0.500000"`. |
| `quality` | No | All rules | Quoted fixed-point rule-quality factor. Defaults to `"0.500000"`. |
| `verified_exhaustive` | No | `exhaustive_group` | Set `true` only after manual exactly-one verification. Defaults to `false`. |
