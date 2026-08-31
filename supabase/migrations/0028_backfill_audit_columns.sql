-- CourtSide — backfill created_at/updated_at/is_active wherever a table
-- was missing one (UserStory 22). Audited every table across 0001-0027
-- and verified live against the DB (not just the migration files) before
-- writing this.
--
-- game_events_log is a note-worthy case: it's an immutable play-by-play
-- log (each row is one historical tap, never edited) — is_active/
-- updated_at don't really mean anything for a row like that. Adding them
-- anyway per your blanket instruction, but flagging that they're
-- unlikely to ever be used there.

-- events: had created_at only.
alter table events add column updated_at timestamptz;
alter table events add column is_active boolean not null default true;

-- rsvps: had none of the three.
alter table rsvps add column created_at timestamptz not null default now();
alter table rsvps add column updated_at timestamptz;
alter table rsvps add column is_active boolean not null default true;

-- team_media_reactions: had created_at only.
alter table team_media_reactions add column updated_at timestamptz;
alter table team_media_reactions add column is_active boolean not null default true;

-- games_live_session: had is_active only.
alter table games_live_session add column created_at timestamptz not null default now();
alter table games_live_session add column updated_at timestamptz;

-- game_events_log: had created_at only (see note above).
alter table game_events_log add column updated_at timestamptz;
alter table game_events_log add column is_active boolean not null default true;
