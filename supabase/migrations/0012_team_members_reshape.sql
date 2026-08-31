-- CourtSide — reshape team_members into team-roster membership
-- (UserStory 22): drop role/player_id, rename joined_at, add tenure
-- dates and per-team player attributes. jersey_number/court_position
-- move here from players (dropped there in 0011) since a player can
-- hold a different squad number/position on different teams.
--
-- Dropping player_id removes the old "exactly one of user_id/player_id"
-- CHECK (team_members_one_subject) via CASCADE, since it can no longer
-- apply. That also means team_members is now always keyed by user_id, so
-- user_id becomes NOT NULL too — a row with neither column would no
-- longer identify anyone.

alter table team_members drop column role;
alter table team_members drop column player_id cascade;
alter table team_members alter column user_id set not null;

alter table team_members rename column joined_at to created_at;
alter table team_members add column updated_at timestamptz;
alter table team_members add column is_active boolean not null default true;
alter table team_members add column jersey_number int;
alter table team_members add column court_position text;
alter table team_members add column start_date date;
alter table team_members add column end_date date;

alter table team_members add constraint team_members_team_user_start_key unique (team_id, user_id, start_date);
