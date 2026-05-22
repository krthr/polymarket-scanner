-- +micrate Up
create table if not exists alerts (
  id text primary key,
  channel text not null,
  status text not null,
  opportunity_id text,
  raw_json text not null,
  created_at_unix_ms integer not null
);

-- +micrate Down
drop table if exists alerts;
