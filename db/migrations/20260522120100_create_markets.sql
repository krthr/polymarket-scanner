-- +micrate Up
create table if not exists markets (
  id text primary key,
  event_id text not null,
  slug text not null,
  question text not null,
  category text not null,
  end_time text,
  active integer not null,
  raw_json text not null,
  updated_at_unix_ms integer not null
);

-- +micrate Down
drop table if exists markets;
