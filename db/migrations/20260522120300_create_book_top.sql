-- +micrate Up
create table if not exists book_top (
  token_id text primary key,
  market_id text,
  bid_price_atoms integer,
  bid_size_atoms integer,
  ask_price_atoms integer,
  ask_size_atoms integer,
  fetched_at_unix_ms integer not null,
  updated_at_unix_ms integer not null
);

-- +micrate Down
drop table if exists book_top;
