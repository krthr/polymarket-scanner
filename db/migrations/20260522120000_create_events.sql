-- +micrate Up
create table if not exists events (
  id text primary key,
  slug text not null,
  title text not null,
  category text not null,
  raw_json text not null,
  updated_at_unix_ms integer not null
);

-- +micrate Down
drop table if exists events;
