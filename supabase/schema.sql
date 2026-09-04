-- =====================================================================
-- CourtSide / LiveCourtAI — complete database schema.
--
-- One script, run once, on an EMPTY database. It creates everything:
-- 35 tables + 2 views, their constraints and indexes, 20 functions, the
-- triggers, row-level security, and the lookup seed data.
--
-- Built from a live audit of the production database
-- (pg_constraint / pg_indexes / pg_policies / pg_proc /
-- information_schema), not from the migration files it replaces.
--
-- Structure: SECTION 1 is the core (24 tables); SECTION 1b is the
-- feature tables added afterwards (11 tables); SECTION 6b holds two
-- views added later.
--
-- !!! KNOWN ISSUES carried over from the live DB (this regen does not
-- fix them — it makes them visible):
--   1. sync_player_latest_measurements() still writes to
--      players.height_cm et al., which were dropped from players. Every
--      write to player_measurements now errors. (SECTION 3)
--   2. The 7 "Cross-validated" / "Management and Coaches" RLS policies
--      are dead: wrong role-name spelling ('MANAGMENT'/'COACH') and
--      auth.uid() compared to users.id instead of auth_user_id.
--      (SECTION 6, end)
--   3. Duplicate UNIQUE constraints on attendance, event_responses,
--      team_members, and user_roles (three on user_roles).
--   4. team_coaches.role_id -> roles cannot express head / assistant /
--      fitness coach; roles only holds the four app roles.
--   5. protect_pii_updates() body and the two view bodies could not be
--      captured by the audit — reproduced as placeholders. (SECTIONS 3, 6b)
--   6. player_measurements carries both measured_on and the new SCD
--      columns (valid_from / valid_to / is_current) at once.
--
-- Deliberately NOT here: any DROP SCHEMA or DROP TABLE preamble. A
-- script that can erase a schema is a loaded gun sitting next to
-- production. Run this against an empty database only.
--
-- Constraint names are preserved exactly as they exist in production,
-- including a few that read oddly for historical reasons:
--   * users' primary key is user_pkey  — the table was once "user"
--   * event_responses' constraints are named rsvps_*  — its old name
--   * guardians_player_id_profile_id_key  — profile_id became user_id
-- Renaming them would look tidier but would make a freshly built
-- database differ from production, and silent drift between
-- environments is the exact problem this file exists to end.
-- =====================================================================


-- =====================================================================
-- SECTION 1 — TABLES
-- Ordered so every foreign key target exists before it is referenced.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Organisation: the tenant, its seasons and its age groups.
--
-- seasons and age_group are intentionally global rather than per-club.
-- Israeli basketball runs one national calendar (September to June) and
-- national age categories, so a per-club copy of each would be the same
-- rows repeated. If a club ever needs its own season boundaries this
-- becomes a structural change, not a configuration one.
-- ---------------------------------------------------------------------
create table clubs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  city text,
  logo_url text,
  primary_color text,                       -- club theming, e.g. '#1D4ED8'
  secondary_color text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table seasons (
  season_id uuid primary key default gen_random_uuid(),
  season_name text,
  start_date date,
  end_date date,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table age_group (
  agegroup_id uuid primary key default gen_random_uuid(),
  agegroup_name text,
  comment text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Lookups.
--
-- All three use an integer identity primary key rather than a uuid: they
-- are short, human-meaningful lists, and a numeric foreign key reads
-- better in the tables that point at them.
--
-- roles carries its two rules as DATA, not as hardcoded ids:
--   requires_club    — must this role be scoped to a club?
--   can_manage_club  — does this role administer the club?
-- Both were literals in earlier versions. The roles table was dropped
-- and reseeded several times during design and the ids moved each time,
-- so any code holding "role_id = 1" silently pointed at whichever role
-- had landed there. As columns, adding a new administrative role (a club
-- secretary, say) is an UPDATE rather than a schema change.
-- ---------------------------------------------------------------------
create table roles (
  role_id int generated always as identity,
  name text not null,
  hierarchy_depth int not null,             -- 1 is most senior
  requires_club boolean not null default true,
  can_manage_club boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint roles_pkey primary key (role_id),
  constraint roles_name_key unique (name),
  constraint roles_hierarchy_depth_key unique (hierarchy_depth)
);

create table review_periods (
  review_period_id int generated always as identity,
  name text not null,
  display_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint review_periods_pkey primary key (review_period_id),
  constraint review_periods_name_key unique (name)
);

-- The coach's overall verdict on a session, seeded best-to-worst so
-- feedback_id doubles as the scale order and the UI needs no extra sort
-- column. Hebrew here, unlike roles, because these strings are content
-- the coach picks and the player reads, not structural identifiers.
create table feedback_type (
  feedback_id int generated always as identity,
  feedback_name text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint feedback_type_pkey primary key (feedback_id),
  constraint feedback_type_name_key unique (feedback_name)
);

-- ---------------------------------------------------------------------
-- users — a PERSON, not an account.
--
-- This distinction is the backbone of the whole schema. Everyone gets a
-- row here: the coach, the parent, and the nine-year-old with no phone.
-- auth_user_id is the LOGIN, and it is nullable — set only for people
-- who can actually sign in.
--
-- That nullable column is what makes Proxy Mode possible. A minor with
-- no account is a person with a name, a roster spot, attendance and
-- statistics, who simply cannot log in. Before this split their name had
-- nowhere to live at all.
--
-- Consequence for every RLS policy in section 6: auth.uid() equals
-- users.auth_user_id, never users.id. Comparing it to users.id matches
-- nothing and fails silently.
--
-- first_name/last_name are NOT NULL because this is the only place a
-- name exists anywhere in the schema. A nameless row is a person no
-- screen — roster, feed, cockpit, review — can render.
-- ---------------------------------------------------------------------
create table users (
  id uuid default gen_random_uuid(),
  auth_user_id uuid,                        -- the login; null = no account
  first_name text not null,
  last_name text not null,
  email text,
  cellphone text,
  gender text,
  birth_date date,
  avatar_url text,
  city text,
  address text,
  country text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_pkey primary key (id),
  constraint users_auth_user_id_key unique (auth_user_id),
  -- email and cellphone stay nullable (not everyone has both channels).
  -- Postgres treats NULLs as non-conflicting in a UNIQUE, so these block
  -- real duplicates without requiring a value. They also back the OTP
  -- lookup by email or phone.
  constraint users_email_key unique (email),
  constraint users_cellphone_key unique (cellphone),
  constraint users_auth_user_id_fkey foreign key (auth_user_id)
    references auth.users (id) on delete set null
);

-- ---------------------------------------------------------------------
-- user_roles — which role a person holds, in which club.
--
-- club_id is nullable because the rule is per-role, not per-column: a
-- Parent is club-less (their link to a club runs through their child),
-- while a Coach or Management must be scoped to one. That rule lives in
-- roles.requires_club and is enforced by a trigger (section 5), because
-- a CHECK cannot contain a subquery and would have to hardcode a role id.
-- ---------------------------------------------------------------------
create table user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  role_id int not null,
  club_id uuid,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- DUPLICATE unique constraints added on the live DB — both cover the
  -- same three columns as the existing partial index and each other,
  -- just in a different column order.
  constraint unique_user_club_role unique (user_id, club_id, role_id),
  constraint unique_user_role_in_club unique (user_id, role_id, club_id),
  constraint user_roles_user_id_fkey foreign key (user_id)
    references users (id) on delete cascade,
  constraint user_roles_role_id_fkey foreign key (role_id)
    references roles (role_id),
  constraint user_roles_club_id_fkey foreign key (club_id)
    references clubs (id) on delete cascade
);

-- ---------------------------------------------------------------------
-- teams
--
-- A team belongs to a season: the under-11s of 2026/27 are not the same
-- team as the under-11s of 2027/28, even under the same name.
--
-- ui_mode decides which player interface loads — the playful Rookie Mode
-- or the fuller Pro Mode. It sits on the team rather than the player
-- because it follows the age group.
-- ---------------------------------------------------------------------
create table teams (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null,
  season_id uuid,
  agegroup_id uuid,
  name text not null,
  color text,
  ui_mode text not null default 'rookie',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint teams_ui_mode_check check (ui_mode in ('rookie', 'pro')),
  constraint teams_club_id_fkey foreign key (club_id)
    references clubs (id) on delete cascade,
  constraint teams_season_id_fkey foreign key (season_id)
    references seasons (season_id) on delete set null,
  constraint teams_agegroup_id_fkey foreign key (agegroup_id)
    references age_group (agegroup_id) on delete set null
);

-- ---------------------------------------------------------------------
-- players — the ATHLETIC dimension of a person.
--
-- user_id is NOT NULL: every player is first a person, and their name
-- comes from users. id_number (the national ID) is the permanent anchor
-- that follows them across teams and clubs for their whole career, so it
-- is UNIQUE — two registrations of the same child would split their
-- entire history in two.
--
-- The four measurement columns are a CACHE of the latest reading, not
-- the source of truth. player_measurements holds the history and a
-- trigger keeps these in step. They exist because the roster, the player
-- card and the cockpit all want height inline, and without them each of
-- those becomes a latest-measurement-per-player subquery.
-- Application code must write measurements to player_measurements;
-- writing here is overwritten by the next reading.
--
-- Notably absent: jersey_number, court_position and fitness status.
-- Those belong to a team membership, not to a career — a child can wear
-- 7 for their school team and 12 for the regional squad in the same
-- season. They live on team_members.
-- ---------------------------------------------------------------------
-- CHANGED on the live DB (fix-schema regen): the four measurement cache
-- columns (height_cm / wingspan_cm / weight_kg / vertical_jump_cm) were
-- DROPPED from players, and first_name / last_name / birth_date / gender
-- were added back. This reverses the 0040 person/account split — a
-- person's name now lives in BOTH users and players again.
--
-- KNOWN ISSUE: the sync_player_latest_measurements() trigger (SECTION 5)
-- still writes to players.height_cm et al. Those columns no longer
-- exist here, so every INSERT/UPDATE/DELETE on player_measurements will
-- raise "column height_cm of relation players does not exist" until that
-- function is rewritten or the columns are restored.
create table players (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  id_number text not null,
  first_name text,
  last_name text,
  birth_date date,
  gender text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint players_id_number_key unique (id_number),
  -- RESTRICT, not CASCADE or SET NULL: a person who is a player cannot
  -- be deleted, only deactivated.
  constraint players_user_id_fkey foreign key (user_id)
    references users (id) on delete restrict
);

-- ---------------------------------------------------------------------
-- player_measurements — the growth chart.
--
-- One row per player per measurement day. This is the source of truth
-- for every physical metric; players.* caches the latest of each.
-- Without it, each new height simply overwrote the last and a growth
-- line could not be drawn at all.
-- ---------------------------------------------------------------------
-- CHANGED on the live DB (fix-schema regen): moved toward a Slowly
-- Changing Dimension (SCD Type 2) model — valid_from / valid_to /
-- is_current were added and the one-per-day unique was dropped. The
-- measured_on column is still present, so the table now carries both
-- shapes at once.
create table player_measurements (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null,
  measured_on date not null default current_date,
  height_cm numeric(5,2),
  wingspan_cm numeric(5,2),
  weight_kg numeric(5,2),
  vertical_jump_cm numeric(5,2),
  recorded_by uuid,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  valid_from timestamptz not null default now(),  -- SCD Type 2 window start
  valid_to timestamptz,                           -- null while current
  is_current boolean not null default true,       -- the live version of the row
  constraint player_measurements_player_id_fkey foreign key (player_id)
    references players (id) on delete restrict,
  constraint player_measurements_recorded_by_fkey foreign key (recorded_by)
    references users (id) on delete set null
);
-- The "not in the future" rule is a trigger (section 5), never a
-- CHECK (measured_on <= CURRENT_DATE): CURRENT_DATE is not IMMUTABLE.
-- Postgres accepts such a CHECK without complaint and then breaks
-- pg_restore and every table-rewriting ALTER — a failure that only
-- surfaces the day you try to restore a backup.

-- ---------------------------------------------------------------------
-- facilities — halls and courts.
--
-- club_id is NULLABLE, and that is load-bearing. A null club means a
-- shared or opposing team's venue, which is the only way an away game
-- can be recorded at all: an opponent's hall belongs to no club of
-- yours. A club's own facility list is a `where club_id = $1` query, so
-- these club-less rows stay out of the admin scheduling board on their
-- own.
--
-- courts_count is what half-court scheduling divides.
-- ---------------------------------------------------------------------
create table facilities (
  id uuid primary key default gen_random_uuid(),
  club_id uuid,                             -- null = shared / away venue
  name text not null,
  address text,
  location_url text,                        -- Waze / Google Maps link
  latitude numeric,
  longitude numeric,
  courts_count int not null default 1,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint facilities_courts_count_check check (courts_count >= 1),
  constraint facilities_club_id_fkey foreign key (club_id)
    references clubs (id) on delete cascade
);

-- ---------------------------------------------------------------------
-- team_members — the player roster.
--
-- Keyed by player_id, never user_id, so a Proxy Mode child with no login
-- still appears on a roster. Carries the attributes that are true of a
-- membership rather than of a career: squad number, position, fitness.
--
-- start_date/end_date implement "no hard deletes" for transfers: a
-- player moving on gets an end_date, so last season's attendance and
-- statistics stay attached to the right team.
-- ---------------------------------------------------------------------
create table team_members (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null,
  player_id uuid not null,
  jersey_number int,
  court_position text,                      -- PG, SG, SF, PF, C
  status text not null default 'active',
  start_date date,
  end_date date,                            -- null while still on the squad
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- pending_approval is the onboarding waiting room: a child registered
  -- through an invitation but not yet confirmed onto the squad by a coach.
  -- inactive is a roster spot kept for history without an end_date yet.
  constraint team_members_status_check
    check (status in ('active', 'injured', 'pending_approval', 'inactive')),
  -- Unique on the pair without start_date: teams are season-scoped, so
  -- next season is a different team row and a second stint on the same
  -- row is not a case that arises.
  constraint team_members_team_id_player_id_key unique (team_id, player_id),
  -- DUPLICATE added on the live DB — same columns as the line above.
  constraint unique_player_in_team unique (team_id, player_id),
  constraint team_members_team_id_fkey foreign key (team_id)
    references teams (id) on delete cascade,
  constraint team_members_player_id_fkey foreign key (player_id)
    references players (id) on delete restrict
);

-- ---------------------------------------------------------------------
-- team_coaches — the professional staff.
--
-- CHANGED on the live DB (fix-schema regen): the role column changed
-- from a text enum (head_coach / assistant_coach / fitness_coach) to
-- role_id, a nullable FK to roles. The unique key moved from
-- (team_id, user_id, start_date) to (team_id, user_id, role_id).
--
-- KNOWN ISSUE: roles only holds Management / Coach / Player / Parent, so
-- role_id cannot express head vs assistant vs fitness coach — that
-- distinction (spec 3 / 8) is lost under this shape.
-- ---------------------------------------------------------------------
create table team_coaches (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null,
  user_id uuid not null,
  role_id int,
  start_date date,
  end_date date,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint unique_team_coach_role unique (team_id, user_id, role_id),
  constraint team_coaches_role_id_fkey foreign key (role_id)
    references roles (role_id),
  constraint team_coaches_team_id_fkey foreign key (team_id)
    references teams (id) on delete cascade,
  constraint team_coaches_user_id_fkey foreign key (user_id)
    references users (id) on delete restrict
);

-- ---------------------------------------------------------------------
-- guardians — the family layer.
--
-- is_primary defaults to FALSE deliberately. It once defaulted to true,
-- which quietly made every grandparent and sibling added to a child a
-- primary guardian — and the primary guardian is the one allowed to
-- invite further family members. Application code must set it explicitly
-- for the registering parent during onboarding.
--
-- can_rsvp is what makes view-only delegation real: a grandparent can be
-- given the schedule without the ability to answer for the child.
--
-- notification_channel covers the parent who never installs the app and
-- needs cancellations by SMS.
-- ---------------------------------------------------------------------
create table guardians (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null,
  user_id uuid not null,
  relationship_type text not null default 'parent',
  is_primary boolean not null default false,
  can_rsvp boolean not null default true,
  notification_channel text not null default 'app',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint guardians_relationship_type_check
    check (relationship_type in ('parent', 'grandparent', 'sibling', 'other')),
  constraint guardians_notification_channel_check
    check (notification_channel in ('app', 'sms_only')),
  -- Named for the column profile_id that became user_id long ago.
  constraint guardians_player_id_profile_id_key unique (player_id, user_id),
  constraint guardians_player_id_fkey foreign key (player_id)
    references players (id) on delete cascade,
  constraint guardians_user_id_fkey foreign key (user_id)
    references users (id) on delete cascade
);

-- ---------------------------------------------------------------------
-- events — practices, games and everything else on the calendar.
--
-- There is no free-text location column: the venue is facility_id, and
-- away venues are facilities with a null club_id. location_url remains
-- for a one-off navigation link.
--
-- recurrence_group_id has no foreign key target by design. It is a value
-- shared across the rows of one recurring series (every Monday and
-- Wednesday practice, say), which is what lets a coach edit or cancel a
-- whole series, not a reference to a separate series table.
--
-- Cancelling is status = 'cancelled', never a delete: that is what draws
-- the strikethrough in the calendar and fires the notification. A
-- deleted event would simply vanish.
-- ---------------------------------------------------------------------
create table events (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null,
  facility_id uuid,
  type text not null,
  title text not null,
  starts_at timestamptz not null,
  ends_at timestamptz,
  location_url text,
  opponent_name text,
  is_home_game boolean,
  coach_note text,                          -- the sticky note players see
  coach_id uuid,                            -- who actually runs it
  notes text,
  status text not null default 'scheduled',
  recurrence_group_id uuid,                 -- shared across one series
  -- Which court in the facility, and which portion of it. court_portion
  -- is what the scheduling board reads to allow two teams into one hall
  -- at once: half_a and half_b do not clash with each other, full clashes
  -- with both. Held on the event itself rather than in a separate
  -- bookings table.
  court_number int default 1,
  court_portion text default 'full',
  created_by uuid,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint events_type_check
    check (type in ('practice', 'game', 'meeting', 'other')),
  constraint events_status_check
    check (status in ('scheduled', 'cancelled', 'completed')),
  constraint events_court_portion_check
    check (court_portion in ('full', 'half_a', 'half_b')),
  -- A game card without the opponent is unreadable to a child.
  constraint events_opponent_required_for_games
    check (type <> 'game' or opponent_name is not null),
  constraint events_team_id_fkey foreign key (team_id)
    references teams (id) on delete cascade,
  constraint events_facility_id_fkey foreign key (facility_id)
    references facilities (id) on delete set null,
  constraint events_coach_id_fkey foreign key (coach_id)
    references users (id) on delete set null,
  constraint events_created_by_user_fkey foreign key (created_by)
    references users (id) on delete set null
);

-- ---------------------------------------------------------------------
-- event_responses — RSVP, the intention stated in advance.
--
-- Kept separate from attendance on purpose: comparing "said they would
-- come" against "actually came" is a question the coach asks, and
-- merging the two would overwrite the child's own answer.
--
-- responded_by is the acting person; response_source says whether that
-- was the player or a guardian, so the coach can tell a child who
-- answered for themselves from a parent who answered for them.
--
-- Table and constraint names disagree: it was renamed from rsvps, and
-- its constraints kept their original names.
-- ---------------------------------------------------------------------
create table event_responses (
  id uuid default gen_random_uuid(),
  event_id uuid not null,
  player_id uuid not null,
  status text not null default 'undecided',
  decline_reason text,
  responded_by uuid,
  response_source text,
  responded_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint rsvps_pkey primary key (id),
  constraint rsvps_status_check
    check (status in ('attending', 'not_attending', 'undecided', 'injured')),
  constraint rsvps_response_source_check
    check (response_source in ('player', 'guardian')),
  -- One answer per player per event; changing it is an UPDATE.
  constraint rsvps_event_id_player_id_key unique (event_id, player_id),
  -- DUPLICATE added on the live DB — same columns as the line above.
  constraint unique_rsvp_per_event unique (event_id, player_id),
  constraint rsvps_event_id_fkey foreign key (event_id)
    references events (id) on delete cascade,
  -- This one FK does carry the corrected name; the rest of this table's
  -- constraints kept their rsvps_* originals.
  constraint event_responses_player_id_fkey foreign key (player_id)
    references players (id) on delete restrict,
  constraint rsvps_responded_by_user_fkey foreign key (responded_by)
    references users (id) on delete set null
);

-- ---------------------------------------------------------------------
-- attendance — the roll call, taken in the hall.
--
-- streak_count is denormalised on purpose: the streak is derivable from
-- history with a window function, but precomputing it keeps the player
-- home screen a single cheap read. Whatever marks attendance must
-- maintain it.
-- ---------------------------------------------------------------------
create table attendance (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null,
  player_id uuid not null,
  status text not null,
  comments text,
  streak_count int not null default 0,
  marked_by uuid,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint attendance_status_check
    check (status in ('present', 'late', 'absent')),
  constraint unique_event_player_attendance unique (event_id, player_id),
  -- DUPLICATE added on the live DB — same columns as the line above.
  constraint unique_attendance_per_event unique (event_id, player_id),
  constraint attendance_event_id_fkey foreign key (event_id)
    references events (id) on delete cascade,
  constraint attendance_player_id_fkey foreign key (player_id)
    references players (id) on delete restrict,
  constraint attendance_marked_by_user_fkey foreign key (marked_by)
    references users (id) on delete set null
);

-- ---------------------------------------------------------------------
-- player_feedback — the coach's note or video to a player's file.
--
-- team_id scopes it so a player moving up an age group does not carry
-- every past note into the new team's view.
-- ---------------------------------------------------------------------
create table player_feedback (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null,
  coach_id uuid not null,
  team_id uuid,
  event_id uuid,
  feedback_id int,                          -- the coach's overall verdict
  note text,
  video_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- RESTRICT on coach_id: a coach leaving the club must not take the
  -- feedback they wrote with them.
  constraint player_feedback_coach_id_fkey foreign key (coach_id)
    references users (id) on delete restrict,
  constraint player_feedback_player_id_fkey foreign key (player_id)
    references players (id) on delete restrict,
  constraint player_feedback_team_id_fkey foreign key (team_id)
    references teams (id) on delete set null,
  constraint player_feedback_event_id_fkey foreign key (event_id)
    references events (id) on delete set null,
  constraint player_feedback_feedback_id_fkey foreign key (feedback_id)
    references feedback_type (feedback_id) on delete set null
);

-- ---------------------------------------------------------------------
-- team_media — the closed team feed.
--
-- The anti-bullying rule is enforced by the schema, not by the UI: there
-- is no text-comment column anywhere in this feature. Reactions are
-- emoji only, one per person per item.
-- ---------------------------------------------------------------------
create table team_media (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null,
  uploaded_by uuid not null,
  event_id uuid,
  media_url text not null,
  media_type text not null,
  caption text,
  status text not null default 'pending',
  reviewed_by uuid,
  reviewed_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint team_media_media_type_check check (media_type in ('image', 'video')),
  constraint team_media_status_check
    check (status in ('pending', 'approved', 'rejected')),
  constraint team_media_team_id_fkey foreign key (team_id)
    references teams (id) on delete cascade,
  constraint team_media_uploaded_by_fkey foreign key (uploaded_by)
    references users (id) on delete restrict,
  constraint team_media_event_id_fkey foreign key (event_id)
    references events (id) on delete set null,
  constraint team_media_reviewed_by_fkey foreign key (reviewed_by)
    references users (id) on delete set null
);

-- Emoji only. There is no text column here by design. The unique pair
-- means one reaction per person per item, so changing or clearing a
-- reaction is an UPDATE and is_active carries the "un-reacted" state.
create table team_media_reactions (
  id uuid primary key default gen_random_uuid(),
  media_id uuid not null,
  user_id uuid not null,
  emoji text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint team_media_reactions_media_id_user_id_key unique (media_id, user_id),
  constraint team_media_reactions_media_id_fkey foreign key (media_id)
    references team_media (id) on delete cascade,
  constraint team_media_reactions_user_id_fkey foreign key (user_id)
    references users (id) on delete cascade
);

-- ---------------------------------------------------------------------
-- Live game cockpit.
--
-- games_live_session holds the state of the game happening right now.
-- game_events_log receives every tap and is the raw material for the box
-- score, shooting percentages and heat maps.
--
-- quarter appears on BOTH: the session's is the quarter being played and
-- is overwritten as the game moves on, while the log's is a per-row
-- snapshot. Without the snapshot the log cannot be grouped by quarter,
-- which is what a quarter-by-quarter box score and a team-foul count
-- both need.
--
-- No points_value column: it follows from event_type (points_2 -> 2,
-- points_3 -> 3, free_throw -> 1), and storing it separately only
-- creates a number that can contradict the type.
-- ---------------------------------------------------------------------
create table games_live_session (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null,
  quarter int not null default 1,
  game_clock_seconds int not null default 600,
  home_score int not null default 0,
  away_score int not null default 0,
  -- The five players on court right now, per side, as an array of
  -- player ids. This is the "who is playing" state the cockpit needs for
  -- substitutions; the durable per-stint history still comes from the
  -- sub_in / sub_out rows in game_events_log.
  home_lineup uuid[] default '{}',
  away_lineup uuid[] default '{}',
  is_active boolean not null default true,
  started_at timestamptz,
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- CHANGED on the live DB: the plain UNIQUE(event_id) was replaced with
  -- a PARTIAL unique index active_live_session_per_event (SECTION 2),
  -- WHERE is_active — so a finished session can coexist with a new one
  -- for the same event.
  constraint games_live_session_event_id_fkey foreign key (event_id)
    references events (id) on delete cascade
);

create table game_events_log (
  id uuid primary key default gen_random_uuid(),
  game_session_id uuid not null,
  player_id uuid not null,
  team_id uuid not null,
  event_type text not null,
  is_success boolean not null default true, -- made or missed
  quarter int not null default 1,           -- snapshot, see note above
  pos_x numeric(5,2),                       -- 0-100% of court width
  pos_y numeric(5,2),                       -- 0-100% of court length
  game_clock_snapshot int,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint game_events_log_event_type_check check (event_type in (
    'points_2', 'points_3', 'free_throw', 'foul', 'rebound',
    'assist', 'turnover', 'steal', 'sub_in', 'sub_out'
  )),
  constraint game_events_log_quarter_check check (quarter between 1 and 10),
  constraint game_events_log_game_session_id_fkey foreign key (game_session_id)
    references games_live_session (id) on delete cascade,
  constraint game_events_log_player_id_fkey foreign key (player_id)
    references players (id) on delete restrict,
  constraint game_events_log_team_id_fkey foreign key (team_id)
    references teams (id) on delete cascade
);

-- ---------------------------------------------------------------------
-- performance_reviews — the structured mid-season and end-of-season
-- conversation.
--
-- Covers two cases with one table: a coach reviewing a player, and
-- management reviewing a coach. Field names are generic (self_*,
-- reviewer_*) rather than player_*/coach_* so both fit.
--
-- Exactly one of player_id / reviewee_user_id is set, matching
-- review_type — enforced by the CHECK below.
--
-- is_anonymous is a display flag, and it is worth being precise about
-- what it does not do: reviewer_user_id is still stored, so club
-- management can still see who rated whom. Genuine anonymity means not
-- storing that link at all. Do not promise players more than this.
-- ---------------------------------------------------------------------
create table performance_reviews (
  id uuid primary key default gen_random_uuid(),
  review_type text not null,
  player_id uuid,                           -- set for player_review
  reviewee_user_id uuid,                    -- set for coach_review
  team_id uuid,
  club_id uuid,
  season_id uuid not null,
  review_period_id int not null,
  self_rating int,
  self_comments text,
  self_submitted_at timestamptz,
  reviewer_rating int,
  reviewer_comments text,
  reviewer_user_id uuid,
  is_anonymous boolean not null default false,
  status text not null default 'pending_self_rating',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint performance_reviews_review_type_check
    check (review_type in ('player_review', 'coach_review')),
  constraint performance_reviews_self_rating_check
    check (self_rating between 1 and 5),
  constraint performance_reviews_reviewer_rating_check
    check (reviewer_rating between 1 and 5),
  constraint performance_reviews_status_check
    check (status in ('pending_self_rating', 'awaiting_reviewer', 'completed')),
  constraint performance_reviews_check check (
    (review_type = 'player_review' and player_id is not null and reviewee_user_id is null)
    or
    (review_type = 'coach_review' and reviewee_user_id is not null and player_id is null)
  ),
  constraint performance_reviews_player_id_fkey foreign key (player_id)
    references players (id) on delete restrict,
  constraint performance_reviews_reviewee_user_id_fkey foreign key (reviewee_user_id)
    references users (id) on delete restrict,
  constraint performance_reviews_reviewer_user_id_fkey foreign key (reviewer_user_id)
    references users (id) on delete set null,
  constraint performance_reviews_team_id_fkey foreign key (team_id)
    references teams (id) on delete set null,
  constraint performance_reviews_club_id_fkey foreign key (club_id)
    references clubs (id) on delete set null,
  constraint performance_reviews_season_id_fkey foreign key (season_id)
    references seasons (season_id) on delete cascade,
  constraint performance_reviews_review_period_id_fkey foreign key (review_period_id)
    references review_periods (review_period_id)
);


-- =====================================================================
-- SECTION 1b — FEATURE TABLES
--
-- Added after the core was in place: onboarding, the permission matrix,
-- club-wide messaging and blackout dates, the playbook, the depth chart
-- and the weekly training focus. Every one of these traces to a spec
-- feature the core schema had no home for.
--
-- Note: these tables have RLS enabled (SECTION 6) but no policies yet,
-- which denies all client access until their access rules are written.
-- =====================================================================

-- ---------------------------------------------------------------------
-- permissions + role_permissions — the configurable permission matrix
-- (spec 1 "מסך הרשאות מפורט", spec 8 "מטריצת הרשאות").
--
-- permissions.id is a text slug ('reports.financial', 'schedule.global')
-- rather than a uuid: these are referenced by name in app code and read
-- better as a handle than a random id. role_permissions is the join,
-- keyed by the pair so a permission is granted to a role at most once.
-- ---------------------------------------------------------------------
create table permissions (
  id text primary key,
  name text not null,
  description text,
  category text not null default 'general',
  created_at timestamptz not null default now()
);

create table role_permissions (
  role_id int not null,
  permission_id text not null,
  created_at timestamptz not null default now(),
  constraint role_permissions_pkey primary key (role_id, permission_id),
  constraint role_permissions_role_id_fkey foreign key (role_id)
    references roles (role_id) on delete cascade,
  constraint role_permissions_permission_id_fkey foreign key (permission_id)
    references permissions (id) on delete cascade
);

-- ---------------------------------------------------------------------
-- invitations — the onboarding flow (spec 1, spec 8 "הזמנת מאמנים
-- חדשים... הזנת שם ואימייל/טלפון").
--
-- One row per person being brought in — a coach, or a player's parent.
-- token defaults to 24 random bytes hex-encoded and is UNIQUE, so the
-- invite link carries it directly. expires_at defaults to seven days
-- out. The OTP itself is handled by Supabase Auth, not stored here.
--
-- inviter_id is RESTRICT: an invitation records who extended it, and
-- that attribution should survive the inviter leaving.
-- ---------------------------------------------------------------------
create table invitations (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null,
  team_id uuid,
  role_id int not null,
  inviter_id uuid not null,
  target_name text,
  email text,
  cellphone text,
  token text not null default encode(gen_random_bytes(24), 'hex'),
  status text not null default 'pending',
  expires_at timestamptz not null default (now() + interval '7 days'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint invitations_status_check
    check (status in ('pending', 'accepted', 'expired', 'cancelled')),
  constraint invitations_token_key unique (token),
  constraint invitations_club_id_fkey foreign key (club_id)
    references clubs (id) on delete cascade,
  constraint invitations_team_id_fkey foreign key (team_id)
    references teams (id) on delete cascade,
  constraint invitations_role_id_fkey foreign key (role_id)
    references roles (role_id),
  constraint invitations_inviter_id_fkey foreign key (inviter_id)
    references users (id) on delete restrict
);

-- ---------------------------------------------------------------------
-- announcements — coach and club messaging (spec 2 "תזכורות והודעות
-- מאמן / מועדון").
--
-- team_id nullable: a null means a club-wide announcement, a value means
-- it is scoped to one team. is_urgent drives the push priority.
-- ---------------------------------------------------------------------
create table announcements (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null,
  team_id uuid,                             -- null = whole club
  author_id uuid not null,
  title text not null,
  content text not null,
  is_urgent boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint announcements_club_id_fkey foreign key (club_id)
    references clubs (id) on delete cascade,
  constraint announcements_team_id_fkey foreign key (team_id)
    references teams (id) on delete cascade,
  constraint announcements_author_id_fkey foreign key (author_id)
    references users (id) on delete restrict
);

-- ---------------------------------------------------------------------
-- club_blackout_dates — holidays and mass cancellations (spec 8
-- "ניהול כל הליגה, חגים, ביטול כל האימונים ביום אחד").
--
-- A date range per club. cancel_events says whether events inside the
-- range are auto-cancelled (and notifications fired) or the range is
-- just shown as a marker on the calendar.
-- ---------------------------------------------------------------------
create table club_blackout_dates (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null,
  title text not null,
  starts_at date not null,
  ends_at date not null,
  cancel_events boolean not null default true,
  created_at timestamptz not null default now(),
  constraint club_blackout_dates_club_id_fkey foreign key (club_id)
    references clubs (id) on delete cascade
);

-- ---------------------------------------------------------------------
-- playbooks / plays / play_views — the Play Designer and its analytics
-- (spec 2 "Playbook - צפייה בתרגילים", spec 3 "Play Designer" +
-- "Playbook Analytics המציג למאמן אילו שחקנים צפו").
--
--   playbooks   a named collection, owned by a coach, optionally shared
--               club-wide (is_shared_with_club).
--   plays       one drill or set piece. canvas_data holds the animated
--               diagram as jsonb; video_url an optional clip.
--   play_views  one row per player per play — "has this player studied
--               it", not a log of every open. view_duration_seconds is
--               updated in place.
-- ---------------------------------------------------------------------
create table playbooks (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null,
  team_id uuid,
  author_id uuid not null,
  title text not null,
  description text,
  category text default 'offense',
  is_shared_with_club boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint playbooks_category_check
    check (category in ('offense', 'defense', 'inbound', 'drill', 'special')),
  constraint playbooks_club_id_fkey foreign key (club_id)
    references clubs (id) on delete cascade,
  constraint playbooks_team_id_fkey foreign key (team_id)
    references teams (id) on delete set null,
  constraint playbooks_author_id_fkey foreign key (author_id)
    references users (id) on delete restrict
);

create table plays (
  id uuid primary key default gen_random_uuid(),
  playbook_id uuid not null,
  title text not null,
  notes text,
  canvas_data jsonb not null default '{}',
  video_url text,
  display_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint plays_playbook_id_fkey foreign key (playbook_id)
    references playbooks (id) on delete cascade
);

create table play_views (
  id uuid primary key default gen_random_uuid(),
  play_id uuid not null,
  player_id uuid not null,
  view_duration_seconds int default 0,
  viewed_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),  -- added on the live DB
  constraint play_views_play_id_player_id_key unique (play_id, player_id),
  constraint play_views_play_id_fkey foreign key (play_id)
    references plays (id) on delete cascade,
  constraint play_views_player_id_fkey foreign key (player_id)
    references players (id) on delete cascade
);

-- ---------------------------------------------------------------------
-- depth_charts — the starting five and rotation order (spec 3 "טבלת
-- עומק / Depth Chart... המתבסס על דירוג האימונים לאותו שבוע").
--
-- One row per (team, position, slot, week). depth_order 1 is the
-- starter at that position; the unique key stops two players being put
-- in the same slot for the same week.
-- ---------------------------------------------------------------------
create table depth_charts (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null,
  player_id uuid not null,
  court_position text not null,             -- PG, SG, SF, PF, C
  depth_order int not null default 1,       -- 1 = starter
  week_date date not null default current_date,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint depth_charts_team_id_court_position_depth_order_week_date_key
    unique (team_id, court_position, depth_order, week_date),
  constraint depth_charts_team_id_fkey foreign key (team_id)
    references teams (id) on delete cascade,
  constraint depth_charts_player_id_fkey foreign key (player_id)
    references players (id) on delete cascade
);

-- ---------------------------------------------------------------------
-- team_weekly_focus — "במה מתרכזים השבוע באימונים" (spec 2).
--
-- One focus per team per week (unique on the pair). This is the
-- team-level counterpart to events.coach_note, which is per-event.
-- ---------------------------------------------------------------------
create table team_weekly_focus (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null,
  week_start_date date not null,
  focus_title text not null,
  description text,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint team_weekly_focus_team_id_week_start_date_key
    unique (team_id, week_start_date),
  constraint team_weekly_focus_team_id_fkey foreign key (team_id)
    references teams (id) on delete cascade,
  constraint team_weekly_focus_created_by_fkey foreign key (created_by)
    references users (id) on delete set null
);

-- ---------------------------------------------------------------------
-- knowledge_base — onboarding notes, rules, technique pointers (spec 3
-- "Knowledge Base - דגשים לשחקן החדש שמצטרף, דגשים בעולם הכדורסל,
-- חוקים").
--
-- club_id nullable: a null row is platform-wide content, a value scopes
-- it to one club. target_ui_mode aims an entry at Rookie or Pro mode,
-- or 'all'.
-- ---------------------------------------------------------------------
create table knowledge_base (
  id uuid primary key default gen_random_uuid(),
  club_id uuid,                             -- null = platform-wide
  title text not null,
  content text not null,
  category text not null default 'rules',
  target_ui_mode text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint knowledge_base_category_check
    check (category in ('onboarding', 'rules', 'technique', 'nutrition', 'mentality')),
  constraint knowledge_base_target_ui_mode_check
    check (target_ui_mode in ('rookie', 'pro', 'all')),
  constraint knowledge_base_club_id_fkey foreign key (club_id)
    references clubs (id) on delete cascade
);


-- =====================================================================
-- SECTION 2 — INDEXES
--
-- Only what a real screen asks for. Postgres already indexes every
-- primary key and unique constraint, and a multi-column index serves
-- lookups on its leading columns, so a plain index on a foreign key that
-- is already the first column of a unique constraint would cost write
-- time and buy nothing.
-- =====================================================================

-- Partial unique indexes: rules a UNIQUE constraint cannot express,
-- because Postgres treats each NULL as distinct.

-- At most one primary guardian per child.
create unique index guardians_one_primary_per_player
  on guardians (player_id) where is_primary;

-- UNIQUE(user_id, role_id, club_id) does not catch duplicates when
-- club_id is null. This closes that hole for any club-less role without
-- naming one.
create unique index user_roles_one_clubless_role_per_user
  on user_roles (user_id, role_id) where club_id is null;

-- One review per subject per season per period. Split in two because
-- each review_type uses a different subject column, and NULLs would
-- never conflict in a single constraint.
create unique index performance_reviews_one_player_review
  on performance_reviews (player_id, season_id, review_period_id)
  where review_type = 'player_review';

create unique index performance_reviews_one_coach_review
  on performance_reviews (reviewee_user_id, season_id, review_period_id)
  where review_type = 'coach_review';

-- Lookup indexes, each driven by a specific screen.

-- Team calendar: the most-opened screen in the app.
create index events_team_starts_idx on events (team_id, starts_at desc);

-- Admin scheduling board and its conflict detection.
create index events_facility_starts_idx on events (facility_id, starts_at);

-- Attendance streak counter on the player home screen.
create index attendance_player_time_idx on attendance (player_id, created_at desc);

-- Player file: feedback history, newest first.
create index player_feedback_player_idx on player_feedback (player_id, created_at desc);

-- The growth chart.
create index player_measurements_player_date_idx
  on player_measurements (player_id, measured_on desc);

-- Added on the live DB with the SCD Type 2 change: range lookups over
-- the validity window, and "exactly one current row per player".
create index player_measurements_scd_idx
  on player_measurements (player_id, valid_from, valid_to);
create unique index player_measurements_single_active_idx
  on player_measurements (player_id) where is_current = true;

-- Added on the live DB: replaces games_live_session's plain UNIQUE(event_id)
-- so a finished session no longer blocks starting a new one.
create unique index active_live_session_per_event
  on games_live_session (event_id) where is_active = true;

-- A player's own RSVP history.
create index event_responses_player_idx on event_responses (player_id);

-- person -> player resolution, on nearly every authenticated request.
create index players_user_id_idx on players (user_id);

-- Permission lookup, on nearly every authenticated request. The partial
-- index above cannot serve this, since it only covers club-less rows.
create index user_roles_user_id_idx on user_roles (user_id);

-- Coach dashboard: every team this coach is assigned to.
create index team_coaches_user_id_idx on team_coaches (user_id);

-- Which children does this parent have. guardians' unique is
-- (player_id, user_id), so user_id is not a prefix of it.
create index guardians_user_id_idx on guardians (user_id);

-- The team a player is currently on. Partial: the history rows, the ones
-- with an end_date, are never what this question is about.
create index team_members_current_idx on team_members (player_id)
  where end_date is null;

-- Team feed, which only ever renders approved media.
create index team_media_feed_idx on team_media (team_id, created_at desc)
  where status = 'approved';

-- The cockpit is both write-heavy (every tap) and read-heavy (box score,
-- heat maps), and neither column is covered by a constraint.
create index game_events_log_session_idx on game_events_log (game_session_id);
create index game_events_log_player_idx  on game_events_log (player_id);

-- The player box score: sum makes and misses by event type for one
-- player. Covers the WHERE and the GROUP BY in one index.
create index game_events_player_summary_idx
  on game_events_log (player_id, event_type, is_success);

-- Feature-table indexes.

-- Announcement feed for a team, newest first.
create index announcements_team_idx on announcements (team_id, created_at desc);

-- The depth chart for a team in a given week.
create index depth_charts_team_idx on depth_charts (team_id, week_date);

-- Playbook analytics: which plays has this player studied.
create index play_views_player_idx on play_views (player_id);


-- =====================================================================
-- SECTION 3 — TRIGGER FUNCTIONS
-- =====================================================================

-- ---------------------------------------------------------------------
-- Keep updated_at honest.
--
-- Every table has updated_at NOT NULL DEFAULT now() rather than a
-- nullable column, because of how it is meant to be read: a delta query
-- (where updated_at > $since) skips rows whose value is NULL, so a
-- never-edited row would stay invisible to client sync forever.
-- ---------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $fn$
begin
  new.updated_at := now();
  return new;
end;
$fn$;

-- ---------------------------------------------------------------------
-- Enforce the club-scoping rule held in roles.requires_club.
--
-- A trigger rather than a CHECK because a CHECK cannot contain a
-- subquery and would have to hardcode a role id — brittle, since the
-- roles table was reseeded several times during design and the ids moved
-- each time. SECURITY DEFINER so the lookup into roles works whatever
-- the caller can see.
-- ---------------------------------------------------------------------
create or replace function public.enforce_user_role_club_scope()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_requires_club boolean;
  v_role_name text;
begin
  select requires_club, name into v_requires_club, v_role_name
  from roles where role_id = new.role_id;

  if v_requires_club and new.club_id is null then
    raise exception 'Role "%" is club-scoped — club_id is required', v_role_name;
  end if;

  if not v_requires_club and new.club_id is not null then
    raise exception 'Role "%" is not club-scoped — club_id must be null', v_role_name;
  end if;

  return new;
end;
$fn$;

-- ---------------------------------------------------------------------
-- Reject a measurement dated in the future. See the note on
-- player_measurements for why this is not a CHECK.
-- ---------------------------------------------------------------------
create or replace function public.validate_measurement_date()
returns trigger language plpgsql as $fn$
begin
  if new.measured_on > current_date then
    raise exception 'measured_on (%) is in the future', new.measured_on;
  end if;
  return new;
end;
$fn$;

-- ---------------------------------------------------------------------
-- Keep players.* holding the latest reading of each metric.
--
-- !!! BROKEN AGAINST THIS SCHEMA !!!
-- This is the body as it stood before the live-DB change, reproduced
-- here because the audit could not capture the current function body.
-- players.height_cm / wingspan_cm / weight_kg / vertical_jump_cm were
-- DROPPED from players on the live DB, so this UPDATE now fails and
-- every write to player_measurements errors. It must be rewritten (to
-- target the SCD columns, or a projection) or the players columns
-- restored. Left here so the drift is visible, not hidden.
-- ---------------------------------------------------------------------
create or replace function public.sync_player_latest_measurements()
returns trigger language plpgsql as $fn$
declare
  v_player uuid := coalesce(new.player_id, old.player_id);
begin
  update players p set
    height_cm = (select m.height_cm from player_measurements m
                 where m.player_id = v_player and m.is_active and m.height_cm is not null
                 order by m.measured_on desc, m.created_at desc limit 1),
    wingspan_cm = (select m.wingspan_cm from player_measurements m
                 where m.player_id = v_player and m.is_active and m.wingspan_cm is not null
                 order by m.measured_on desc, m.created_at desc limit 1),
    weight_kg = (select m.weight_kg from player_measurements m
                 where m.player_id = v_player and m.is_active and m.weight_kg is not null
                 order by m.measured_on desc, m.created_at desc limit 1),
    vertical_jump_cm = (select m.vertical_jump_cm from player_measurements m
                 where m.player_id = v_player and m.is_active and m.vertical_jump_cm is not null
                 order by m.measured_on desc, m.created_at desc limit 1)
  where p.id = v_player;
  return null;
end;
$fn$;

-- ---------------------------------------------------------------------
-- protect_pii_updates — added on the live DB.
--
-- PLACEHOLDER: the audit could not capture this function's body. It is
-- SECURITY DEFINER and fires BEFORE UPDATE on players (trigger
-- trigger_protect_pii, SECTION 5), so it almost certainly guards or
-- rejects changes to the PII columns (first_name / last_name /
-- birth_date / gender). This no-op version keeps the script runnable;
-- replace it with the real body before relying on this file.
-- ---------------------------------------------------------------------
create or replace function public.protect_pii_updates()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  -- TODO: real guard logic not captured by the audit.
  return new;
end;
$fn$;


-- =====================================================================
-- SECTION 4 — RLS HELPER FUNCTIONS
--
-- The access rules live here once instead of being re-written inside 59
-- policies, where one subtly wrong copy would be a silent leak rather
-- than an error.
--
-- SECURITY DEFINER is a requirement, not a convenience. A policy on
-- players that reads guardians would fire guardians' policy, which reads
-- players, which fires players' policy — infinite recursion. Running the
-- lookups as the definer bypasses RLS and breaks the cycle. The base
-- function below is kept free of team logic for the same reason, so the
-- chain runs own players -> teams -> all players and never loops back.
-- =====================================================================

-- Maps the caller's login to their person row. Since users.id is no
-- longer auth.users' id, every policy needs this indirection.
create or replace function public.current_person_id()
returns uuid language sql stable security definer set search_path = public as $$
  select id from users where auth_user_id = auth.uid()
$$;

-- BASE: players the caller is personally attached to — the player row
-- that is them, and any child they actively guard.
create or replace function public.current_user_own_player_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select p.id from players p
   where p.user_id = public.current_person_id()
  union
  select g.player_id from guardians g
   where g.user_id = public.current_person_id() and g.is_active
$$;

-- Clubs the caller manages.
create or replace function public.current_user_club_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select ur.club_id from user_roles ur
    join roles r on r.role_id = ur.role_id
   where ur.user_id = public.current_person_id()
     and ur.is_active and r.can_manage_club and ur.club_id is not null
$$;

-- Teams the caller may SEE: teams they currently coach, teams their own
-- players are on, and every team in a club they manage. The end_date
-- check matters — a coach who has handed a team over stops seeing it.
create or replace function public.current_user_team_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select tc.team_id from team_coaches tc
   where tc.user_id = public.current_person_id()
     and tc.is_active and (tc.end_date is null or tc.end_date >= current_date)
  union
  select tm.team_id from team_members tm
   where tm.is_active
     and tm.player_id in (select public.current_user_own_player_ids())
  union
  select t.id from teams t
   where t.club_id in (select public.current_user_club_ids())
$$;

-- Every player the caller may see: their own, plus everyone on a team
-- they have access to.
create or replace function public.current_user_player_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select public.current_user_own_player_ids()
  union
  select tm.player_id from team_members tm
   where tm.team_id in (select public.current_user_team_ids())
$$;

-- Clubs the caller can SEE, broader than the ones they manage: any club
-- they hold an active role in, plus the club behind any visible team.
--
-- The second half is not redundant. Parent is a club-less role, so a
-- parent has no club_id anywhere in user_roles — their access to the
-- club's name, logo and colours has to resolve through their child's
-- team, or no screen can be branded for them.
create or replace function public.current_user_visible_club_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select ur.club_id from user_roles ur
   where ur.user_id = public.current_person_id()
     and ur.is_active and ur.club_id is not null
  union
  select t.club_id from teams t
   where t.id in (select public.current_user_team_ids())
$$;

-- Staff = anyone currently coaching a team or managing a club.
create or replace function public.current_user_is_staff()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from team_coaches tc
     where tc.user_id = public.current_person_id() and tc.is_active
       and (tc.end_date is null or tc.end_date >= current_date)
  ) or exists (select 1 from public.current_user_club_ids())
$$;

-- People the caller may see: themselves, the person behind any visible
-- player, the coaches of their teams, and the guardians of their players
-- — that last one being the coach's need to reach a parent.
create or replace function public.current_user_visible_person_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select u.id from users u where u.auth_user_id = auth.uid()
  union
  select p.user_id from players p
   where p.id in (select public.current_user_player_ids())
  union
  select tc.user_id from team_coaches tc
   where tc.is_active and tc.team_id in (select public.current_user_team_ids())
  union
  select g.user_id from guardians g
   where g.is_active and g.player_id in (select public.current_user_player_ids())
$$;

-- Teams the caller may CHANGE. Narrower than the teams they can see, on
-- purpose: a parent can see the team their child plays on, but must not
-- be able to edit its roster.
create or replace function public.current_user_managed_team_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select tc.team_id from team_coaches tc
   where tc.user_id = public.current_person_id() and tc.is_active
     and (tc.end_date is null or tc.end_date >= current_date)
  union
  select t.id from teams t where t.club_id in (select public.current_user_club_ids())
$$;

-- Players the caller is the PRIMARY guardian of. Only they may invite
-- further family members — which is what makes the is_primary default of
-- false load-bearing rather than cosmetic.
create or replace function public.current_user_primary_player_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select g.player_id from guardians g
   where g.user_id = public.current_person_id() and g.is_primary and g.is_active
$$;

-- Players the caller may RESPOND for. Narrower than own_player_ids,
-- which ignores can_rsvp: seeing a child and answering on their behalf
-- are different rights, and a view-only relative has the first without
-- the second.
create or replace function public.current_user_rsvp_player_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select p.id from players p where p.user_id = public.current_person_id()
  union
  select g.player_id from guardians g
   where g.user_id = public.current_person_id() and g.is_active and g.can_rsvp
$$;

-- Events on a team the caller runs, so a coach can act on a whole event
-- at once rather than row by row.
create or replace function public.current_user_managed_event_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select e.id from events e
   where e.team_id in (select public.current_user_managed_team_ids())
$$;

create or replace function public.current_user_visible_media_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select m.id from team_media m
   where m.team_id in (select public.current_user_team_ids())
$$;

create or replace function public.current_user_visible_session_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select s.id from games_live_session s
    join events e on e.id = s.event_id
   where e.team_id in (select public.current_user_team_ids())
$$;

create or replace function public.current_user_managed_session_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select s.id from games_live_session s
   where s.event_id in (select public.current_user_managed_event_ids())
$$;

grant execute on function public.current_person_id()                  to authenticated;
grant execute on function public.current_user_own_player_ids()        to authenticated;
grant execute on function public.current_user_club_ids()              to authenticated;
grant execute on function public.current_user_team_ids()              to authenticated;
grant execute on function public.current_user_player_ids()            to authenticated;
grant execute on function public.current_user_visible_club_ids()      to authenticated;
grant execute on function public.current_user_is_staff()              to authenticated;
grant execute on function public.current_user_visible_person_ids()    to authenticated;
grant execute on function public.current_user_managed_team_ids()      to authenticated;
grant execute on function public.current_user_primary_player_ids()    to authenticated;
grant execute on function public.current_user_rsvp_player_ids()       to authenticated;
grant execute on function public.current_user_managed_event_ids()     to authenticated;
grant execute on function public.current_user_visible_media_ids()     to authenticated;
grant execute on function public.current_user_visible_session_ids()   to authenticated;
grant execute on function public.current_user_managed_session_ids()   to authenticated;


-- =====================================================================
-- SECTION 5 — TRIGGERS
-- =====================================================================

-- One set_updated_at trigger per table. The loop walks
-- information_schema rather than naming every table, so it picks up any
-- table with an updated_at column — including the SECTION 1b feature
-- tables (announcements, depth_charts, invitations, knowledge_base,
-- playbooks, plays, team_weekly_focus).
--
-- Drift note: the live database this file was regenerated from is
-- missing these seven triggers — the feature tables were added without
-- running this block. A fresh build from this file is correct; to sync
-- the existing database, run this DO block against it once.
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
    execute format('drop trigger if exists set_updated_at on %I', t.table_name);
    execute format(
      'create trigger set_updated_at before update on %I
         for each row execute function public.set_updated_at()',
      t.table_name);
  end loop;
end $do$;

create trigger user_roles_club_scope_check
  before insert or update on user_roles
  for each row execute function public.enforce_user_role_club_scope();

create trigger validate_measurement_date
  before insert or update on player_measurements
  for each row execute function public.validate_measurement_date();

create trigger sync_player_measurements
  after insert or update or delete on player_measurements
  for each row execute function public.sync_player_latest_measurements();

-- Added on the live DB.
create trigger trigger_protect_pii
  before update on players
  for each row execute function public.protect_pii_updates();

create trigger set_play_views_updated_at
  before update on play_views
  for each row execute function public.set_updated_at();


-- =====================================================================
-- SECTION 6 — ROW LEVEL SECURITY
--
-- The rule throughout: a parent sees only their own children, a coach
-- only their teams, management only their club.
--
-- No table has a DELETE policy. "No hard deletes" is the rule of this
-- system — every table carries is_active, transfers close with an
-- end_date, cancelled events keep their row — and the foreign keys back
-- it up with ON DELETE RESTRICT wherever history hangs off a row. The
-- absence of a DELETE policy is what enforces it at the client edge.
--
-- The SQL Editor and the service_role key bypass RLS entirely, which is
-- where administrative data entry belongs.
-- =====================================================================

alter table clubs                enable row level security;
alter table seasons              enable row level security;
alter table age_group            enable row level security;
alter table roles                enable row level security;
alter table review_periods       enable row level security;
alter table feedback_type        enable row level security;
alter table users                enable row level security;
alter table user_roles           enable row level security;
alter table teams                enable row level security;
alter table players              enable row level security;
alter table player_measurements  enable row level security;
alter table facilities           enable row level security;
alter table team_members         enable row level security;
alter table team_coaches         enable row level security;
alter table guardians            enable row level security;
alter table events               enable row level security;
alter table event_responses      enable row level security;
alter table attendance           enable row level security;
alter table player_feedback      enable row level security;
alter table team_media           enable row level security;
alter table team_media_reactions enable row level security;
alter table games_live_session   enable row level security;
alter table game_events_log      enable row level security;
alter table performance_reviews  enable row level security;

-- SECTION 1b feature tables. RLS is on, and there are deliberately no
-- policies for them yet — every one of these denies all client access
-- until its access rules are written. The SQL Editor and service_role
-- key still reach them. Their policies belong in a follow-up, alongside
-- the screens that use them.
alter table permissions          enable row level security;
alter table role_permissions     enable row level security;
alter table invitations          enable row level security;
alter table announcements        enable row level security;
alter table club_blackout_dates  enable row level security;
alter table playbooks            enable row level security;
alter table plays                enable row level security;
alter table play_views           enable row level security;
alter table depth_charts         enable row level security;
alter table team_weekly_focus    enable row level security;
alter table knowledge_base       enable row level security;

-- ---------------------------------------------------------------------
-- System lookups: everyone signed in reads, nobody writes through the
-- client. Editing a lookup list belongs in the SQL Editor.
-- ---------------------------------------------------------------------
create policy "read roles"          on roles          for select to authenticated using (true);
create policy "read review_periods" on review_periods for select to authenticated using (true);
create policy "read feedback_type"  on feedback_type  for select to authenticated using (true);
create policy "read seasons"        on seasons        for select to authenticated using (true);
create policy "read age_group"      on age_group      for select to authenticated using (true);

-- ---------------------------------------------------------------------
-- clubs. No INSERT or DELETE policy: creating or removing a tenant is a
-- system-admin action performed with the service_role key.
-- ---------------------------------------------------------------------
create policy "read visible clubs" on clubs for select to authenticated
  using (id in (select public.current_user_visible_club_ids()));

create policy "managers update their club" on clubs for update to authenticated
  using      (id in (select public.current_user_club_ids()))
  with check (id in (select public.current_user_club_ids()));

-- ---------------------------------------------------------------------
-- facilities. Club-less rows are the shared and away venues: readable by
-- everyone, since a shared venue directory is pointless otherwise, and
-- writable by staff, who are the people actually standing in an
-- opponent's hall.
-- ---------------------------------------------------------------------
create policy "read visible facilities" on facilities for select to authenticated
  using (club_id is null or club_id in (select public.current_user_visible_club_ids()));

create policy "staff write facilities" on facilities for insert to authenticated
  with check ((club_id is null and public.current_user_is_staff())
              or club_id in (select public.current_user_club_ids()));

create policy "staff update facilities" on facilities for update to authenticated
  using      ((club_id is null and public.current_user_is_staff())
              or club_id in (select public.current_user_club_ids()))
  with check ((club_id is null and public.current_user_is_staff())
              or club_id in (select public.current_user_club_ids()));

-- ---------------------------------------------------------------------
-- users. Reading other people's rows is not a convenience: it is how any
-- name reaches any screen, because users is the only place names live.
--
-- Two insert cases: signing yourself up, and staff creating the shadow
-- person row for a child with no login.
--
-- Known edge: updating a shadow row that has no players row yet is
-- denied, since nothing makes it visible. The normal onboarding flow
-- writes users and players together, so this should not surface — but it
-- is the first thing to check if onboarding throws an odd error.
-- ---------------------------------------------------------------------
create policy "read visible people" on users for select to authenticated
  using (id in (select public.current_user_visible_person_ids()));

create policy "create person rows" on users for insert to authenticated
  with check (auth_user_id = auth.uid()
              or (auth_user_id is null and public.current_user_is_staff()));

create policy "update person rows" on users for update to authenticated
  using      (auth_user_id = auth.uid()
              or (auth_user_id is null and public.current_user_is_staff()
                  and id in (select public.current_user_visible_person_ids())))
  with check (auth_user_id = auth.uid()
              or (auth_user_id is null and public.current_user_is_staff()));

-- ---------------------------------------------------------------------
-- user_roles is read-only through the client. Assigning roles is an
-- administrative act; the console that does it will need write policies
-- of its own, and granting them before that console exists would be
-- opening a door onto an empty room.
-- ---------------------------------------------------------------------
create policy "read own roles" on user_roles for select to authenticated
  using (user_id = public.current_person_id());

-- ---------------------------------------------------------------------
-- players
-- ---------------------------------------------------------------------
create policy "read visible players" on players for select to authenticated
  using (id in (select public.current_user_player_ids()));

create policy "staff create players" on players for insert to authenticated
  with check (public.current_user_is_staff());

create policy "update own players" on players for update to authenticated
  using (id in (select public.current_user_player_ids())
         and (public.current_user_is_staff()
              or id in (select public.current_user_own_player_ids())))
  with check (id in (select public.current_user_player_ids()));

-- ---------------------------------------------------------------------
-- teams
-- ---------------------------------------------------------------------
create policy "read visible teams" on teams for select to authenticated
  using (id in (select public.current_user_team_ids()));

create policy "managers write teams" on teams for insert to authenticated
  with check (club_id in (select public.current_user_club_ids()));

create policy "managers update teams" on teams for update to authenticated
  using      (club_id in (select public.current_user_club_ids()))
  with check (club_id in (select public.current_user_club_ids()));

-- ---------------------------------------------------------------------
-- team_members (the roster)
-- ---------------------------------------------------------------------
create policy "read visible roster" on team_members for select to authenticated
  using (team_id in (select public.current_user_team_ids()));

create policy "staff write roster" on team_members for insert to authenticated
  with check (team_id in (select public.current_user_managed_team_ids()));

create policy "staff update roster" on team_members for update to authenticated
  using      (team_id in (select public.current_user_managed_team_ids()))
  with check (team_id in (select public.current_user_managed_team_ids()));

-- ---------------------------------------------------------------------
-- team_coaches. Assigning coaches is a management action, not something
-- a coach does for the team they already coach.
-- ---------------------------------------------------------------------
create policy "read visible coaches" on team_coaches for select to authenticated
  using (team_id in (select public.current_user_team_ids()));

create policy "managers assign coaches" on team_coaches for insert to authenticated
  with check (team_id in (select t.id from teams t
                          where t.club_id in (select public.current_user_club_ids())));

create policy "managers update coaches" on team_coaches for update to authenticated
  using      (team_id in (select t.id from teams t
                          where t.club_id in (select public.current_user_club_ids())))
  with check (team_id in (select t.id from teams t
                          where t.club_id in (select public.current_user_club_ids())));

-- ---------------------------------------------------------------------
-- guardians. Only the primary guardian may invite further family.
-- ---------------------------------------------------------------------
create policy "read own family links" on guardians for select to authenticated
  using (user_id = public.current_person_id()
         or player_id in (select public.current_user_player_ids()));

create policy "primary guardian invites" on guardians for insert to authenticated
  with check (player_id in (select public.current_user_primary_player_ids())
              or public.current_user_is_staff());

create policy "primary guardian updates" on guardians for update to authenticated
  using      (player_id in (select public.current_user_primary_player_ids())
              or public.current_user_is_staff())
  with check (player_id in (select public.current_user_primary_player_ids())
              or public.current_user_is_staff());

-- ---------------------------------------------------------------------
-- events
-- ---------------------------------------------------------------------
create policy "read visible events" on events for select to authenticated
  using (team_id in (select public.current_user_team_ids()));

create policy "staff create events" on events for insert to authenticated
  with check (team_id in (select public.current_user_managed_team_ids()));

create policy "staff update events" on events for update to authenticated
  using      (team_id in (select public.current_user_managed_team_ids()))
  with check (team_id in (select public.current_user_managed_team_ids()));

-- ---------------------------------------------------------------------
-- event_responses. A coach sees the whole team's intentions; a parent
-- sees their own children. Both fall out of the same helper.
-- ---------------------------------------------------------------------
create policy "read visible responses" on event_responses for select to authenticated
  using (player_id in (select public.current_user_player_ids()));

create policy "respond for own players" on event_responses for insert to authenticated
  with check (player_id in (select public.current_user_rsvp_player_ids())
              or event_id in (select public.current_user_managed_event_ids()));

create policy "update own responses" on event_responses for update to authenticated
  using      (player_id in (select public.current_user_rsvp_player_ids())
              or event_id in (select public.current_user_managed_event_ids()))
  with check (player_id in (select public.current_user_rsvp_player_ids())
              or event_id in (select public.current_user_managed_event_ids()));

-- ---------------------------------------------------------------------
-- attendance. Read by players and parents, since it feeds the streak
-- counter. Written only by the coach: a streak a child can set for
-- themselves is not a streak.
-- ---------------------------------------------------------------------
create policy "read visible attendance" on attendance for select to authenticated
  using (player_id in (select public.current_user_player_ids()));

create policy "staff mark attendance" on attendance for insert to authenticated
  with check (event_id in (select public.current_user_managed_event_ids()));

create policy "staff update attendance" on attendance for update to authenticated
  using      (event_id in (select public.current_user_managed_event_ids()))
  with check (event_id in (select public.current_user_managed_event_ids()));

-- ---------------------------------------------------------------------
-- player_feedback. coach_id must be the caller: the player reads
-- feedback attributed, and a coach filing under a colleague's name would
-- be a lie the schema allowed.
-- ---------------------------------------------------------------------
create policy "read visible feedback" on player_feedback for select to authenticated
  using (player_id in (select public.current_user_player_ids()));

create policy "coaches write feedback" on player_feedback for insert to authenticated
  with check (public.current_user_is_staff()
              and coach_id = public.current_person_id()
              and player_id in (select public.current_user_player_ids()));

create policy "coaches edit own feedback" on player_feedback for update to authenticated
  using      (coach_id = public.current_person_id())
  with check (coach_id = public.current_person_id());

-- ---------------------------------------------------------------------
-- player_measurements
-- ---------------------------------------------------------------------
create policy "read visible measurements" on player_measurements for select to authenticated
  using (player_id in (select public.current_user_player_ids()));

create policy "staff record measurements" on player_measurements for insert to authenticated
  with check (public.current_user_is_staff()
              and player_id in (select public.current_user_player_ids()));

create policy "staff update measurements" on player_measurements for update to authenticated
  using      (public.current_user_is_staff()
              and player_id in (select public.current_user_player_ids()))
  with check (public.current_user_is_staff()
              and player_id in (select public.current_user_player_ids()));

-- ---------------------------------------------------------------------
-- team_media. Pending media is visible only to whoever uploaded it and
-- to the team's coaches, who are the moderators.
--
-- Moderation is scoped to the media's own team. An earlier design put it
-- at age-group level, where any coach sharing the age group could
-- approve; the narrower grant is the safer default.
-- ---------------------------------------------------------------------
create policy "read approved media" on team_media for select to authenticated
  using (team_id in (select public.current_user_team_ids())
         and (status = 'approved'
              or uploaded_by = public.current_person_id()
              or team_id in (select public.current_user_managed_team_ids())));

create policy "upload own media" on team_media for insert to authenticated
  with check (team_id in (select public.current_user_team_ids())
              and uploaded_by = public.current_person_id());

create policy "moderate media" on team_media for update to authenticated
  using      (uploaded_by = public.current_person_id()
              or team_id in (select public.current_user_managed_team_ids()))
  with check (uploaded_by = public.current_person_id()
              or team_id in (select public.current_user_managed_team_ids()));

create policy "read visible reactions" on team_media_reactions for select to authenticated
  using (media_id in (select public.current_user_visible_media_ids()));

create policy "react as self" on team_media_reactions for insert to authenticated
  with check (user_id = public.current_person_id()
              and media_id in (select public.current_user_visible_media_ids()));

create policy "change own reaction" on team_media_reactions for update to authenticated
  using      (user_id = public.current_person_id())
  with check (user_id = public.current_person_id());

-- ---------------------------------------------------------------------
-- The live cockpit stays staff-only.
--
-- The product spec describes a bench player being able to run it, but
-- handing the cockpit to a player needs an explicit delegation mechanism
-- that does not exist in this schema, and inventing one inside an RLS
-- policy would be the wrong place for it.
-- ---------------------------------------------------------------------
create policy "read visible sessions" on games_live_session for select to authenticated
  using (event_id in (select e.id from events e
                      where e.team_id in (select public.current_user_team_ids())));

create policy "staff open session" on games_live_session for insert to authenticated
  with check (event_id in (select public.current_user_managed_event_ids()));

create policy "staff run session" on games_live_session for update to authenticated
  using      (event_id in (select public.current_user_managed_event_ids()))
  with check (event_id in (select public.current_user_managed_event_ids()));

create policy "read visible game log" on game_events_log for select to authenticated
  using (game_session_id in (select public.current_user_visible_session_ids()));

create policy "staff log game events" on game_events_log for insert to authenticated
  with check (game_session_id in (select public.current_user_managed_session_ids()));

create policy "staff fix game log" on game_events_log for update to authenticated
  using      (game_session_id in (select public.current_user_managed_session_ids()))
  with check (game_session_id in (select public.current_user_managed_session_ids()));

-- ---------------------------------------------------------------------
-- performance_reviews.
--
-- An anonymous review is hidden at row level from the person it is
-- about. Both sides of the conversation can write: the reviewer fills
-- their half, the subject fills self_rating and self_comments before the
-- meeting.
--
-- Known limit: RLS is row-level, not column-level, so nothing here stops
-- a player who may update the row from also overwriting
-- reviewer_comments. Closing that properly needs column-level
-- GRANT UPDATE (col, ...).
-- ---------------------------------------------------------------------
create policy "read visible reviews" on performance_reviews for select to authenticated
  using (player_id in (select public.current_user_player_ids())
         or (reviewee_user_id = public.current_person_id() and not is_anonymous)
         or reviewer_user_id = public.current_person_id()
         or club_id in (select public.current_user_club_ids()));

create policy "staff create reviews" on performance_reviews for insert to authenticated
  with check (public.current_user_is_staff());

create policy "participants update reviews" on performance_reviews for update to authenticated
  using      (reviewer_user_id = public.current_person_id()
              or reviewee_user_id = public.current_person_id()
              or player_id in (select public.current_user_own_player_ids())
              or club_id in (select public.current_user_club_ids()))
  with check (reviewer_user_id = public.current_person_id()
              or reviewee_user_id = public.current_person_id()
              or player_id in (select public.current_user_own_player_ids())
              or club_id in (select public.current_user_club_ids()));

-- ---------------------------------------------------------------------
-- Policies added on the live DB (fix-schema regen), reproduced verbatim.
--
-- !!! ALL SEVEN ARE DEAD as written — they never grant anything:
--   * they compare r.name to 'MANAGMENT' / 'COACH'. The seeded values
--     are 'Management' / 'Coach' (SECTION 7), so the ANY(...) never
--     matches.
--   * they compare ur.user_id / users.id to auth.uid(). Since the
--     person/account split, auth.uid() equals users.auth_user_id, not
--     users.id — so these joins match nothing either.
--   * they are granted TO public, not TO authenticated, unlike every
--     other policy in this file.
-- They sit ON TOP of the policies above; RLS OR-combines per command,
-- so the working policies still govern and these add no real access.
-- Kept here for fidelity to the live DB, not because they function.
-- ---------------------------------------------------------------------
create policy "Cross-validated: Staff can insert attendance for their team pla"
  on attendance for insert to public
  with check (exists (
    select 1 from events e
      join team_members tm on e.team_id = tm.team_id
      join teams t on t.id = e.team_id
      join user_roles ur on ur.club_id = t.club_id
      join roles r on r.role_id = ur.role_id
    where e.id = attendance.event_id and tm.player_id = attendance.player_id
      and ur.user_id = auth.uid()
      and r.name = any (array['MANAGMENT', 'COACH'])));

create policy "Cross-validated: event_responses only allowed for valid team me"
  on event_responses for insert to public
  with check (exists (
    select 1 from events e
      join team_members tm on e.team_id = tm.team_id
    where e.id = event_responses.event_id and tm.player_id = event_responses.player_id)
  and exists (
    select 1 from guardians g
    where g.player_id = event_responses.player_id and g.user_id = auth.uid()));

create policy "Cross-validated: Game events restricted to actual team roster"
  on game_events_log for insert to public
  with check (exists (
    select 1 from games_live_session gls
      join events e on gls.event_id = e.id
      join team_members tm on e.team_id = tm.team_id
    where gls.id = game_events_log.game_session_id
      and tm.player_id = game_events_log.player_id));

create policy "Management and Coaches can insert guardians only for their club"
  on guardians for insert to public
  with check (exists (
    select 1 from team_members tm
      join teams t on tm.team_id = t.id
      join user_roles ur on t.club_id = ur.club_id
      join roles r on r.role_id = ur.role_id
    where tm.player_id = guardians.player_id and ur.user_id = auth.uid()
      and r.name = any (array['MANAGMENT', 'COACH'])));

create policy "Management and Coaches can update guardians only for their club"
  on guardians for update to public
  using (exists (
    select 1 from team_members tm
      join teams t on tm.team_id = t.id
      join user_roles ur on t.club_id = ur.club_id
      join roles r on r.role_id = ur.role_id
    where tm.player_id = guardians.player_id and ur.user_id = auth.uid()
      and r.name = any (array['MANAGMENT', 'COACH'])))
  with check (exists (
    select 1 from team_members tm
      join teams t on tm.team_id = t.id
      join user_roles ur on t.club_id = ur.club_id
      join roles r on r.role_id = ur.role_id
    where tm.player_id = guardians.player_id and ur.user_id = auth.uid()
      and r.name = any (array['MANAGMENT', 'COACH'])));

create policy "Guardians and Staff can view full player data"
  on players for select to public
  using (exists (
      select 1 from guardians g
      where g.player_id = players.id and g.user_id = auth.uid())
    or exists (
      select 1 from team_members tm
        join teams t on tm.team_id = t.id
        join user_roles ur on t.club_id = ur.club_id
        join roles r on r.role_id = ur.role_id
      where tm.player_id = players.id and ur.user_id = auth.uid()
        and r.name = any (array['MANAGMENT', 'COACH'])));

create policy "Users can view own data, Staff can view club users"
  on users for select to public
  using (id = auth.uid()
    or exists (
      select 1 from guardians g
        join team_members tm on g.player_id = tm.player_id
        join teams t on tm.team_id = t.id
        join user_roles ur on t.club_id = ur.club_id
        join roles r on r.role_id = ur.role_id
      where g.user_id = users.id and ur.user_id = auth.uid()
        and r.name = any (array['MANAGMENT', 'COACH']))
    or exists (
      select 1 from user_roles target_ur
        join user_roles staff_ur on target_ur.club_id = staff_ur.club_id
        join roles r on r.role_id = staff_ur.role_id
      where target_ur.user_id = users.id and staff_ur.user_id = auth.uid()
        and r.name = any (array['MANAGMENT', 'COACH'])));


-- =====================================================================
-- SECTION 6b — VIEWS (added on the live DB)
--
-- PII-limited projections. RECONSTRUCTED from the view columns only —
-- the audit did not capture the view bodies, so any WHERE clause,
-- security_barrier / security_invoker setting, or column expression is
-- not reflected here. Verify against pg_get_viewdef before relying on
-- this file.
-- =====================================================================
create view safe_players as
  select id, first_name, last_name, birth_date, gender, created_at
  from players;

create view safe_users as
  select id, first_name, last_name, avatar_url, city, gender, is_active
  from users;


-- =====================================================================
-- SECTION 7 — SEED DATA
--
-- Only the lookup tables. Nothing here is optional: user_roles.role_id
-- is NOT NULL with a foreign key to roles, so no role can be assigned to
-- anyone while that table is empty.
-- =====================================================================

-- hierarchy_depth reads as actual depth: 1 is closest to the root.
-- Parent is the one club-less role — a parent's link to a club runs
-- through their child, not through a direct assignment.
insert into roles (name, hierarchy_depth, requires_club, can_manage_club) values
  ('Management', 1, true,  true),
  ('Coach',      2, true,  false),
  ('Player',     3, true,  false),
  ('Parent',     4, false, false);

insert into review_periods (name, display_order) values
  ('שיחת אמצע עונה', 1),
  ('שיחת סוף עונה',  2);

-- Best to worst, so feedback_id doubles as the scale order.
insert into feedback_type (feedback_name) values
  ('אימון נהדר'),
  ('אימון טוב'),
  ('דורש שיפור'),
  ('אימון חלש');

-- ---------------------------------------------------------------------
-- permissions / role_permissions
--
-- These tables were created empty in the live database, and their rows
-- are not visible to the audit (RLS on, no policy). The permission
-- matrix screen (spec 8) is what defines and grants these, so the seed
-- is left to that work rather than guessed here. Until then the two
-- tables are structurally present but carry no grants.
-- ---------------------------------------------------------------------
