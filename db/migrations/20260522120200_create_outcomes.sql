-- +micrate Up
create table if not exists outcomes (
  id text primary key,
  market_id text not null,
  name text not null,
  yes_token_id text not null,
  no_token_id text,
  p_hat_atoms integer,
  confidence_atoms integer not null,
  raw_json text not null,
  updated_at_unix_ms integer not null
);

-- +micrate Down
drop table if exists outcomes;
