-- CourtSide — make updated_at real, and clean up the index set
-- (UserStory 22).
--
-- ---------------------------------------------------------------------
-- 1. updated_at was a dead column on all 23 tables.
--
-- Every table got an updated_at somewhere along 0003-0028, explicitly
-- for client sync ("חובה לתחזוקת נתונים וסנכרון שינויים מול ה-Client").
-- But a live-schema audit found all 23 of them nullable, with no
-- default, and exactly one trigger in the entire database — none of
-- them for this. Nothing has ever written to any of these columns, and
-- nothing ever would have.
--
-- They are made NOT NULL DEFAULT now() rather than left nullable
-- because of how they are meant to be read: a delta query
-- (`where updated_at > $since`) skips every row whose updated_at is
-- NULL, so a never-edited row would be invisible to sync forever.
-- Starting them equal to created_at is the usual convention and closes
-- that hole.
--
-- The DO block walks information_schema rather than naming 23 tables,
-- so a table added later picks this up by re-running the block.
-- ---------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $fn$
begin
  new.updated_at := now();
  return new;
end;
$fn$;

do $do$
declare t record;
begin
  for t in
    select c.table_name
    from information_schema.columns c
    join information_schema.tables tb
      on tb.table_schema = c.table_schema and tb.table_name = c.table_name
    where c.table_schema = 'public'
      and c.column_name = 'updated_at'
      and tb.table_type = 'BASE TABLE'
    order by c.table_name
  loop
    execute format(
      'update %I set updated_at = coalesce(updated_at, created_at, now()) where updated_at is null',
      t.table_name);
    execute format('alter table %I alter column updated_at set default now()', t.table_name);
    execute format('alter table %I alter column updated_at set not null', t.table_name);
    execute format('drop trigger if exists set_updated_at on %I', t.table_name);
    execute format(
      'create trigger set_updated_at before update on %I
         for each row execute function public.set_updated_at()',
      t.table_name);
    raise notice 'updated_at wired on %', t.table_name;
  end loop;
end $do$;

-- ---------------------------------------------------------------------
-- 2. Drop indexes that a UNIQUE constraint already covers.
--
-- 0039 added six FK indexes on the reasoning that Postgres never
-- indexes the referencing side of a foreign key. True in general, but
-- four of the six duplicated the leading column of a UNIQUE constraint
-- that was already there — and a multi-column index already serves
-- lookups on its prefix. They cost write time on every insert and
-- bought nothing on read.
--
-- events_team_id_idx is dropped for a different reason: the composite
-- index created in section 3 supersedes it entirely.
-- ---------------------------------------------------------------------
drop index if exists attendance_event_id_idx;        -- unique (event_id, player_id)
drop index if exists event_responses_event_id_idx;   -- unique (event_id, player_id)
drop index if exists team_members_team_id_idx;       -- unique (team_id, player_id)
drop index if exists team_coaches_team_id_idx;       -- unique (team_id, user_id, start_date)
drop index if exists events_team_id_idx;             -- superseded below

-- guardians_user_id_idx is deliberately kept: guardians' unique is
-- (player_id, user_id), so user_id is not a prefix of it and the
-- "which children does this parent have" lookup has no other index.

-- ---------------------------------------------------------------------
-- 3. Indexes the actual screens need.
--
-- Each one is here because a specific screen in the spec drives it,
-- not because the column happens to be a foreign key.
-- ---------------------------------------------------------------------

-- Team calendar — the most-opened screen in the app.
create index if not exists events_team_starts_idx      on events (team_id, starts_at desc);

-- Admin Gantt board and its conflict detection (spec 8).
create index if not exists events_facility_starts_idx  on events (facility_id, starts_at);

-- Attendance streak counter (spec 2 — "ספירת רצפי נוכחות").
create index if not exists attendance_player_time_idx  on attendance (player_id, created_at desc);

-- Player file: feedback history, newest first.
create index if not exists player_feedback_player_idx  on player_feedback (player_id, created_at desc);

-- A player's own RSVP history.
create index if not exists event_responses_player_idx  on event_responses (player_id);

-- person -> player resolution, on nearly every authenticated request.
create index if not exists players_user_id_idx         on players (user_id);

-- Permission lookup, on nearly every authenticated request. The only
-- existing index on user_roles.user_id is partial (club_id is null),
-- so it cannot serve the general case.
create index if not exists user_roles_user_id_idx      on user_roles (user_id);

-- Coach dashboard: every team this coach is assigned to (spec 3).
create index if not exists team_coaches_user_id_idx    on team_coaches (user_id);

-- The team a player is currently on. Partial, because the roster
-- history rows (end_date set) are never the ones being asked for here.
create index if not exists team_members_current_idx
  on team_members (player_id) where end_date is null;

-- Team feed (spec 2), which only ever renders approved media.
create index if not exists team_media_feed_idx
  on team_media (team_id, created_at desc) where status = 'approved';
