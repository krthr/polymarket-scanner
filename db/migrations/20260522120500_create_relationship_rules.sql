-- +micrate Up
create table if not exists relationship_rules (
  id text primary key,
  type text not null,
  raw_json text not null,
  updated_at_unix_ms integer not null
);

-- +micrate Down
drop table if exists relationship_rules;
