-- +micrate Up
create table if not exists book_snapshots (
  id integer primary key autoincrement,
  token_id text not null,
  market_id text,
  raw_json text not null,
  reason text not null,
  fetched_at_unix_ms integer not null,
  created_at_unix_ms integer not null
);

-- +micrate Down
drop table if exists book_snapshots;
