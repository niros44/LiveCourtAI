-- CourtSide — columns the spec needs but the schema never got, plus the
-- away-game fix (UserStory 22).

-- ---------------------------------------------------------------------
-- 1. team_coaches.role — head / assistant / fitness coach.
--
-- 0019 created team_coaches deliberately without player-only fields,
-- but also without any professional role, so every coach attached to a
-- team is indistinguishable from every other. Spec 3 and 8 both assume
-- the distinction ("מאמן ראשי, עוזר מאמן", inviting coaches and
-- assigning them to teams).
--
-- No "one head coach per team" constraint on purpose: the spec notes a
-- coach can go on reserve duty and be replaced mid-season, and some
-- teams run more than one coach — an overlap during a handover is a
-- real state, not an error.
-- ---------------------------------------------------------------------
alter table team_coaches add column if not exists role text not null default 'head_coach';
alter table team_coaches drop constraint if exists team_coaches_role_check;
alter table team_coaches add constraint team_coaches_role_check
  check (role in ('head_coach', 'assistant_coach', 'fitness_coach'));

-- ---------------------------------------------------------------------
-- 2. player_feedback.team_id — 0015 added event_id but never this, so
-- feedback could not be filtered by team or season. A player who moves
-- up an age group carries every past note into the new team's view.
-- SET NULL rather than CASCADE: the feedback outlives the team.
-- ---------------------------------------------------------------------
alter table player_feedback add column if not exists team_id uuid;
alter table player_feedback drop constraint if exists player_feedback_team_id_fkey;
alter table player_feedback add constraint player_feedback_team_id_fkey
  foreign key (team_id) references teams (id) on delete set null;

-- ---------------------------------------------------------------------
-- 3. game_events_log.quarter.
--
-- games_live_session.quarter holds only the quarter being played right
-- now; it is overwritten as the game moves on. Without a per-row
-- snapshot the log cannot be grouped by quarter, which blocks both the
-- box score breakdown (spec 7) and team fouls per quarter (spec 6).
--
-- Same idea as game_clock_snapshot, which 0024 already got right — this
-- column was simply missed. The cockpit must write the live quarter on
-- every tap; the default of 1 exists only so the column can be NOT NULL
-- and grouping never has to cope with a NULL.
--
-- No points_value column: it is derivable from event_type
-- (points_2 -> 2, points_3 -> 3, free_throw -> 1), and storing it
-- separately just creates a value that can contradict the type.
-- ---------------------------------------------------------------------
alter table game_events_log add column if not exists quarter int not null default 1;
alter table game_events_log drop constraint if exists game_events_log_quarter_check;
alter table game_events_log add constraint game_events_log_quarter_check
  check (quarter between 1 and 10);   -- 1-4 plus overtimes

-- ---------------------------------------------------------------------
-- 4. performance_reviews.is_anonymous (spec 2 — the automatic anonymous
-- end-of-year coach rating).
--
-- Worth being honest about what this does and does not give: the row
-- still stores reviewer_user_id, so this is a display flag, not real
-- anonymity. A player rating their coach under a promise of anonymity
-- needs the reviewer link not to be stored at all. Enough for the MVP,
-- but do not promise players more than the schema delivers.
-- ---------------------------------------------------------------------
alter table performance_reviews add column if not exists is_anonymous boolean not null default false;

-- ---------------------------------------------------------------------
-- 5. guardians.notification_channel (spec 1 — the Fallback case, a
-- parent who never installs the app and needs cancellations by SMS).
-- ---------------------------------------------------------------------
alter table guardians add column if not exists notification_channel text not null default 'app';
alter table guardians drop constraint if exists guardians_notification_channel_check;
alter table guardians add constraint guardians_notification_channel_check
  check (notification_channel in ('app', 'sms_only'));

-- ---------------------------------------------------------------------
-- 6. Away games had nowhere to be recorded.
--
-- 0027 dropped events.location in favour of facility_id, but 0020 had
-- created facilities with club_id NOT NULL — so every venue must belong
-- to one of your own clubs. An opposing team's hall fits neither: it
-- cannot be a facility, and the free-text fallback was gone. Exactly
-- the case where parents most need the navigation link (spec 4).
--
-- Making club_id nullable lets a shared or opposing venue exist as a
-- real, reusable facility with real coordinates. A club's own facility
-- list is a `where club_id = $1` query either way, so club-less rows
-- stay out of the admin Gantt board on their own.
-- ---------------------------------------------------------------------
alter table facilities alter column club_id drop not null;

-- While in facilities: the navigation link belongs on the venue rather
-- than being retyped into events.location_url for every single event,
-- and courts_count is what half-court scheduling will divide (spec 8).
alter table facilities add column if not exists location_url text;
alter table facilities add column if not exists courts_count int not null default 1;
alter table facilities drop constraint if exists facilities_courts_count_check;
alter table facilities add constraint facilities_courts_count_check
  check (courts_count >= 1);
