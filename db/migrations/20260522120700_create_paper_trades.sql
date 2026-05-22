-- +micrate Up
create table if not exists paper_trades (
  id text primary key,
  opportunity_id text not null,
  status text not null,
  total_cost_atoms integer not null,
  expected_payout_atoms integer not null,
  raw_json text not null,
  created_at_unix_ms integer not null
);

-- +micrate Down
drop table if exists paper_trades;
