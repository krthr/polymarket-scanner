-- +micrate Up
create table if not exists signals (
  id text primary key,
  detector text not null,
  market_id text,
  status text not null,
  edge_net_atoms integer not null,
  score_atoms integer not null,
  confidence_atoms integer not null,
  raw_json text not null,
  created_at_unix_ms integer not null
);

-- +micrate Down
drop table if exists signals;
