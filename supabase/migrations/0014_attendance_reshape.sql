-- CourtSide — attendance: track by user_id instead of player_id
-- (UserStory 22), same shift already made on team_members. Drops the old
-- auto-named FK/unique constraints on player_id (standard Postgres naming
-- for unnamed inline constraints) before repointing them.

alter table attendance drop constraint if exists attendance_event_id_player_id_key;
alter table attendance drop constraint if exists attendance_player_id_fkey;

alter table attendance rename column player_id to user_id;
alter table attendance add constraint attendance_user_id_fkey foreign key (user_id) references users (id) on delete cascade;

alter table attendance rename column marked_at to created_at;
alter table attendance add column updated_at timestamptz;
alter table attendance add column is_active boolean not null default true;
alter table attendance add column comments text;

alter table attendance add constraint unique_event_player_attendance unique (event_id, user_id);
