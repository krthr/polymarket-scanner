-- +micrate Up
alter table markets add column gamma_id text;
alter table markets add column condition_id text;
alter table markets add column question_id text;
alter table markets add column closed integer not null default 0;
alter table markets add column archived integer not null default 0;
alter table markets add column accepting_orders integer not null default 1;

-- +micrate Down
alter table markets drop column accepting_orders;
alter table markets drop column archived;
alter table markets drop column closed;
alter table markets drop column question_id;
alter table markets drop column condition_id;
alter table markets drop column gamma_id;
