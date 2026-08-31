-- CourtSide — fix Proxy Mode and close remaining spec gaps (UserStory 22).
--
-- The core fix: a minor player with no login had nowhere to exist. Their
-- name lived only in `users` (which they have no row in), and
-- team_members required a user_id — so they could have attendance and
-- RSVP records (both keyed by player_id) while being unable to appear on
-- a roster or even display a name. `players` becomes self-sufficient for
-- identity, and team_members keys off player_id like every other
-- player-activity table already does.
--
-- Tradeoff worth knowing: a player who DOES have an account now carries
-- their name in two places (users + players). `players` is the
-- authoritative source for anything roster/game related; `users` is for
-- the account/profile screen. Keep writes to both in sync in app code.

-- ---------------------------------------------------------------------
-- 1. players: restore identity fields (NOT NULL is safe — table empty)
-- ---------------------------------------------------------------------
alter table players add column first_name text not null;
alter table players add column last_name text not null;
alter table players add column birth_date date;
alter table players add column gender text;
alter table players add column avatar_url text;

-- ---------------------------------------------------------------------
-- 2. team_members: user_id -> player_id (the critical Proxy Mode fix)
-- ---------------------------------------------------------------------
alter table team_members drop constraint if exists team_members_team_user_start_key;
alter table team_members drop column user_id;
alter table team_members add column player_id uuid not null references players (id) on delete cascade;

-- Note: unique on (team_id, player_id) without start_date, so a player
-- can't be added to the same team twice. This also means they can't have
-- two separate stints on the same team row — fine here, since teams are
-- season-scoped (teams.season_id), so next season is a different team row.
alter table team_members add constraint team_members_team_id_player_id_key unique (team_id, player_id);

-- ---------------------------------------------------------------------
-- 3. guardians: distinguish a responsible parent from a view-only
-- relative (spec 4 — "להוסיף בני משפחה (סבא, אח) עם הרשאות צפייה בלו״ז בלבד")
-- ---------------------------------------------------------------------
alter table guardians add column relationship_type text not null default 'parent'
  check (relationship_type in ('parent', 'grandparent', 'sibling', 'other'));
alter table guardians add column is_primary boolean not null default true;

-- ---------------------------------------------------------------------
-- 4. attendance: streak counter for the Rookie Mode gamification
-- (spec 2 — "ספירת רצפי נוכחות")
--
-- Denormalized on purpose: the streak is derivable from attendance
-- history with a window function, but precomputing it keeps the player
-- home screen a single cheap read. It must be written by whatever marks
-- attendance — if it's ever edited directly it can drift from the
-- underlying rows.
-- ---------------------------------------------------------------------
alter table attendance add column streak_count int not null default 0;

-- ---------------------------------------------------------------------
-- 5. teams: which player UI to load (spec 2 — "Rookie Mode & Pro Mode
-- — תלוי גיל")
-- ---------------------------------------------------------------------
alter table teams add column ui_mode text not null default 'rookie'
  check (ui_mode in ('rookie', 'pro'));

-- ---------------------------------------------------------------------
-- 6. clubs: brand colors for per-club theming (logo_url already exists)
-- ---------------------------------------------------------------------
alter table clubs add column primary_color text;
alter table clubs add column secondary_color text;

-- ---------------------------------------------------------------------
-- 7. Indexes on the FK columns the coach/parent screens filter by.
-- Postgres indexes the PK side of an FK automatically, never the
-- referencing column — these are the ones actually used in WHERE clauses.
-- ---------------------------------------------------------------------
create index if not exists events_team_id_idx on events (team_id);
create index if not exists team_members_team_id_idx on team_members (team_id);
create index if not exists team_coaches_team_id_idx on team_coaches (team_id);
create index if not exists event_responses_event_id_idx on event_responses (event_id);
create index if not exists attendance_event_id_idx on attendance (event_id);
create index if not exists guardians_user_id_idx on guardians (user_id);
