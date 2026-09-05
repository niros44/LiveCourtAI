-- =====================================================================
-- CourtSide / LiveCourtAI — full database schema, one script.
--
-- Regenerated VERBATIM from a live-DB audit (pg_catalog / information_schema)
-- after the 13-point findings review. Every object below is reproduced as
-- it exists in production, not hand-edited.
--
-- Run once on an EMPTY database. No DROP preamble by design.
--
-- Layout: extensions -> tables -> constraints -> foreign keys -> indexes
-- -> functions -> triggers -> views -> RLS + policies -> view grants
-- -> seed data.
-- =====================================================================


-- ============================ EXTENSIONS ============================
create extension if not exists btree_gist;   -- venue-overlap EXCLUDE constraint
-- (plpgsql / pgcrypto / uuid-ossp / pg_stat_statements / supabase_vault
--  are provisioned by Supabase and are not created here.)


-- ============================== TABLES ==============================
create table clubs (
  id uuid not null default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now(),
  is_active boolean not null default true,
  updated_at timestamptz not null default now(),
  logo_url text,
  city text,
  primary_color text,
  secondary_color text
);

create table seasons (
  season_id uuid not null default gen_random_uuid(),
  season_name text,
  start_date date,
  end_date date,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table age_group (
  agegroup_id uuid not null default gen_random_uuid(),
  agegroup_name text,
  is_active boolean not null default true,
  comment text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table roles (
  role_id integer not null generated always as identity,
  name text not null,
  hierarchy_depth integer not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  requires_club boolean not null default true,
  can_manage_club boolean not null default false
);

create table review_periods (
  review_period_id integer not null generated always as identity,
  name text not null,
  display_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table feedback_type (
  feedback_id integer not null generated always as identity,
  feedback_name text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table permissions (
  id text not null,
  name text not null,
  description text,
  category text not null default 'general'::text,
  created_at timestamptz not null default now()
);

create table users (
  id uuid not null default gen_random_uuid(),
  email text,
  cellphone text,
  gender text,
  city text,
  address text,
  country text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  first_name text not null,
  last_name text not null,
  updated_at timestamptz not null default now(),
  avatar_url text,
  birth_date date,
  auth_user_id uuid
);

create table user_roles (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null,
  created_at timestamptz not null default now(),
  club_id uuid,
  is_active boolean not null default true,
  updated_at timestamptz not null default now(),
  role_id integer not null
);

create table role_permissions (
  role_id integer not null,
  permission_id text not null,
  created_at timestamptz not null default now()
);

create table teams (
  id uuid not null default gen_random_uuid(),
  club_id uuid not null,
  name text not null,
  color text,
  created_at timestamptz not null default now(),
  is_active boolean not null default true,
  updated_at timestamptz not null default now(),
  season_id uuid,
  agegroup_id uuid,
  ui_mode text not null default 'rookie'::text
);

create table players (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null,
  id_number text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_active boolean not null default true,
  first_name text,
  last_name text,
  birth_date date,
  gender text
);

create table player_measurements (
  id uuid not null default gen_random_uuid(),
  player_id uuid not null,
  measured_on date not null default CURRENT_DATE,
  height_cm numeric(5,2),
  wingspan_cm numeric(5,2),
  weight_kg numeric(5,2),
  vertical_jump_cm numeric(5,2),
  recorded_by uuid,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  valid_from timestamptz not null default now(),
  valid_to timestamptz,
  is_current boolean not null default true
);

create table facilities (
  id uuid not null default gen_random_uuid(),
  club_id uuid,
  name text not null,
  address text,
  latitude numeric,
  longitude numeric,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  location_url text,
  courts_count integer not null default 1
);

create table team_members (
  id uuid not null default gen_random_uuid(),
  team_id uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_active boolean not null default true,
  jersey_number integer,
  court_position text,
  start_date date,
  end_date date,
  status text not null default 'active'::text,
  player_id uuid not null
);

create table team_coaches (
  id uuid not null default gen_random_uuid(),
  team_id uuid not null,
  user_id uuid not null,
  start_date date,
  end_date date,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  role text not null default 'head_coach'::text
);

create table guardians (
  id uuid not null default gen_random_uuid(),
  player_id uuid not null,
  user_id uuid not null,
  can_rsvp boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_active boolean not null default true,
  relationship_type text not null default 'parent'::text,
  is_primary boolean not null default false,
  notification_channel text not null default 'app'::text
);

create table invitations (
  id uuid not null default gen_random_uuid(),
  club_id uuid not null,
  team_id uuid,
  role_id integer not null,
  inviter_id uuid not null,
  email text,
  cellphone text,
  target_name text,
  token text not null default encode(gen_random_bytes(24), 'hex'::text),
  status text not null default 'pending'::text,
  expires_at timestamptz not null default (now() + '7 days'::interval),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table announcements (
  id uuid not null default gen_random_uuid(),
  club_id uuid not null,
  team_id uuid,
  author_id uuid not null,
  title text not null,
  content text not null,
  is_urgent boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table club_blackout_dates (
  id uuid not null default gen_random_uuid(),
  club_id uuid not null,
  title text not null,
  starts_at date not null,
  ends_at date not null,
  cancel_events boolean not null default true,
  created_at timestamptz not null default now()
);

create table knowledge_base (
  id uuid not null default gen_random_uuid(),
  club_id uuid,
  title text not null,
  content text not null,
  category text not null default 'rules'::text,
  target_ui_mode text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table events (
  id uuid not null default gen_random_uuid(),
  team_id uuid not null,
  type text not null,
  title text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  notes text,
  created_by uuid,
  created_at timestamptz not null default now(),
  facility_id uuid,
  opponent_name text,
  is_home_game boolean,
  location_url text,
  coach_note text,
  coach_id uuid,
  status text not null default 'scheduled'::text,
  recurrence_group_id uuid,
  updated_at timestamptz not null default now(),
  is_active boolean not null default true,
  court_number integer default 1,
  court_portion text default 'full'::text,
  court_range int4range generated always as (CASE court_portion
    WHEN 'full'::text THEN int4range(0, 2)
    WHEN 'half_a'::text THEN int4range(0, 1)
    WHEN 'half_b'::text THEN int4range(1, 2)
    ELSE int4range(0, 2)
END) stored
);

create table event_responses (
  id uuid not null default gen_random_uuid(),
  event_id uuid not null,
  player_id uuid not null,
  status text not null default 'undecided'::text,
  decline_reason text,
  responded_by uuid,
  responded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_active boolean not null default true,
  response_source text
);

create table attendance (
  id uuid not null default gen_random_uuid(),
  event_id uuid not null,
  player_id uuid not null,
  status text not null,
  marked_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_active boolean not null default true,
  comments text,
  streak_count integer not null default 0
);

create table player_feedback (
  id uuid not null default gen_random_uuid(),
  player_id uuid not null,
  coach_id uuid not null,
  note text,
  video_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_active boolean not null default true,
  event_id uuid,
  feedback_id integer,
  team_id uuid
);

create table team_media (
  id uuid not null default gen_random_uuid(),
  team_id uuid not null,
  uploaded_by uuid not null,
  event_id uuid,
  media_url text not null,
  media_type text not null,
  caption text,
  status text not null default 'pending'::text,
  reviewed_by uuid,
  reviewed_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table team_media_reactions (
  id uuid not null default gen_random_uuid(),
  media_id uuid not null,
  user_id uuid not null,
  emoji text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_active boolean not null default true
);

create table games_live_session (
  id uuid not null default gen_random_uuid(),
  event_id uuid not null,
  quarter integer not null default 1,
  game_clock_seconds integer not null default 600,
  home_score integer not null default 0,
  away_score integer not null default 0,
  is_active boolean not null default true,
  started_at timestamptz,
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  home_lineup uuid[] default '{}'::uuid[],
  away_lineup uuid[] default '{}'::uuid[]
);

create table game_events_log (
  id uuid not null default gen_random_uuid(),
  game_session_id uuid not null,
  player_id uuid not null,
  team_id uuid not null,
  event_type text not null,
  is_success boolean not null default true,
  pos_x numeric(5,2),
  pos_y numeric(5,2),
  game_clock_snapshot integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_active boolean not null default true,
  quarter integer not null default 1
);

create table performance_reviews (
  id uuid not null default gen_random_uuid(),
  review_type text not null,
  player_id uuid,
  reviewee_user_id uuid,
  team_id uuid,
  club_id uuid,
  season_id uuid not null,
  self_rating integer,
  self_comments text,
  self_submitted_at timestamptz,
  reviewer_rating integer,
  reviewer_comments text,
  reviewer_user_id uuid,
  status text not null default 'pending_self_rating'::text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  review_period_id integer not null,
  is_anonymous boolean not null default false
);

create table playbooks (
  id uuid not null default gen_random_uuid(),
  club_id uuid not null,
  author_id uuid not null,
  team_id uuid,
  title text not null,
  description text,
  category text default 'offense'::text,
  is_shared_with_club boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table plays (
  id uuid not null default gen_random_uuid(),
  playbook_id uuid not null,
  title text not null,
  canvas_data jsonb not null default '{}'::jsonb,
  video_url text,
  notes text,
  display_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table play_views (
  id uuid not null default gen_random_uuid(),
  play_id uuid not null,
  player_id uuid not null,
  viewed_at timestamptz not null default now(),
  view_duration_seconds integer default 0,
  updated_at timestamptz not null default now()
);

create table depth_charts (
  id uuid not null default gen_random_uuid(),
  team_id uuid not null,
  player_id uuid not null,
  court_position text not null,
  depth_order integer not null default 1,
  week_date date not null default CURRENT_DATE,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table team_weekly_focus (
  id uuid not null default gen_random_uuid(),
  team_id uuid not null,
  week_start_date date not null,
  focus_title text not null,
  description text,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);


-- ===================== CONSTRAINTS (pk / unique / check / exclude) =====================

-- primary keys, unique, check, exclusion
alter table clubs add constraint clubs_pkey PRIMARY KEY (id);
alter table seasons add constraint seasons_pkey PRIMARY KEY (season_id);
alter table age_group add constraint age_group_pkey PRIMARY KEY (agegroup_id);
alter table roles add constraint roles_hierarchy_depth_key UNIQUE (hierarchy_depth);
alter table roles add constraint roles_name_key UNIQUE (name);
alter table roles add constraint roles_pkey PRIMARY KEY (role_id);
alter table review_periods add constraint review_periods_name_key UNIQUE (name);
alter table review_periods add constraint review_periods_pkey PRIMARY KEY (review_period_id);
alter table feedback_type add constraint feedback_type_name_key UNIQUE (feedback_name);
alter table feedback_type add constraint feedback_type_pkey PRIMARY KEY (feedback_id);
alter table permissions add constraint permissions_pkey PRIMARY KEY (id);
alter table users add constraint user_pkey PRIMARY KEY (id);
alter table users add constraint users_auth_user_id_key UNIQUE (auth_user_id);
alter table users add constraint users_cellphone_key UNIQUE (cellphone);
alter table users add constraint users_email_key UNIQUE (email);
alter table user_roles add constraint user_roles_pkey PRIMARY KEY (id);
alter table role_permissions add constraint role_permissions_pkey PRIMARY KEY (role_id, permission_id);
alter table teams add constraint teams_pkey PRIMARY KEY (id);
alter table teams add constraint teams_ui_mode_check CHECK ((ui_mode = ANY (ARRAY['rookie'::text, 'pro'::text])));
alter table players add constraint players_id_number_key UNIQUE (id_number);
alter table players add constraint players_pkey PRIMARY KEY (id);
alter table player_measurements add constraint player_measurements_pkey PRIMARY KEY (id);
alter table facilities add constraint facilities_courts_count_check CHECK ((courts_count >= 1));
alter table facilities add constraint facilities_pkey PRIMARY KEY (id);
alter table team_members add constraint team_members_pkey PRIMARY KEY (id);
alter table team_members add constraint team_members_status_check CHECK ((status = ANY (ARRAY['active'::text, 'injured'::text, 'pending_approval'::text, 'inactive'::text])));
alter table team_members add constraint team_members_team_id_player_id_key UNIQUE (team_id, player_id);
alter table team_coaches add constraint team_coaches_pkey PRIMARY KEY (id);
alter table team_coaches add constraint team_coaches_role_check CHECK ((role = ANY (ARRAY['head_coach'::text, 'assistant_coach'::text, 'fitness_coach'::text, 'other'::text])));
alter table team_coaches add constraint unique_team_coach_role UNIQUE (team_id, user_id, role);
alter table guardians add constraint guardians_notification_channel_check CHECK ((notification_channel = ANY (ARRAY['app'::text, 'sms_only'::text])));
alter table guardians add constraint guardians_pkey PRIMARY KEY (id);
alter table guardians add constraint guardians_player_id_profile_id_key UNIQUE (player_id, user_id);
alter table guardians add constraint guardians_relationship_type_check CHECK ((relationship_type = ANY (ARRAY['parent'::text, 'grandparent'::text, 'sibling'::text, 'other'::text])));
alter table invitations add constraint invitations_pkey PRIMARY KEY (id);
alter table invitations add constraint invitations_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'accepted'::text, 'expired'::text, 'cancelled'::text])));
alter table invitations add constraint invitations_token_key UNIQUE (token);
alter table announcements add constraint announcements_pkey PRIMARY KEY (id);
alter table club_blackout_dates add constraint club_blackout_dates_pkey PRIMARY KEY (id);
alter table knowledge_base add constraint knowledge_base_category_check CHECK ((category = ANY (ARRAY['onboarding'::text, 'rules'::text, 'technique'::text, 'nutrition'::text, 'mentality'::text])));
alter table knowledge_base add constraint knowledge_base_pkey PRIMARY KEY (id);
alter table knowledge_base add constraint knowledge_base_target_ui_mode_check CHECK ((target_ui_mode = ANY (ARRAY['rookie'::text, 'pro'::text, 'all'::text])));
alter table events add constraint events_court_portion_check CHECK ((court_portion = ANY (ARRAY['full'::text, 'half_a'::text, 'half_b'::text])));
alter table events add constraint events_ends_after_starts CHECK ((ends_at > starts_at));
alter table events add constraint events_no_venue_overlap EXCLUDE USING gist (facility_id WITH =, court_number WITH =, court_range WITH &&, tstzrange(starts_at, ends_at) WITH &&) WHERE (((status <> 'cancelled'::text) AND (facility_id IS NOT NULL) AND is_active));
alter table events add constraint events_opponent_required_for_games CHECK (((type <> 'game'::text) OR (opponent_name IS NOT NULL)));
alter table events add constraint events_pkey PRIMARY KEY (id);
alter table events add constraint events_status_check CHECK ((status = ANY (ARRAY['scheduled'::text, 'cancelled'::text, 'completed'::text])));
alter table events add constraint events_type_check CHECK ((type = ANY (ARRAY['practice'::text, 'game'::text, 'meeting'::text, 'other'::text])));
alter table event_responses add constraint rsvps_event_id_player_id_key UNIQUE (event_id, player_id);
alter table event_responses add constraint rsvps_pkey PRIMARY KEY (id);
alter table event_responses add constraint rsvps_response_source_check CHECK ((response_source = ANY (ARRAY['player'::text, 'guardian'::text])));
alter table event_responses add constraint rsvps_status_check CHECK ((status = ANY (ARRAY['attending'::text, 'not_attending'::text, 'undecided'::text, 'injured'::text])));
alter table attendance add constraint attendance_pkey PRIMARY KEY (id);
alter table attendance add constraint attendance_status_check CHECK ((status = ANY (ARRAY['present'::text, 'late'::text, 'absent'::text])));
alter table attendance add constraint unique_event_player_attendance UNIQUE (event_id, player_id);
alter table player_feedback add constraint player_feedback_pkey PRIMARY KEY (id);
alter table team_media add constraint team_media_media_type_check CHECK ((media_type = ANY (ARRAY['image'::text, 'video'::text])));
alter table team_media add constraint team_media_pkey PRIMARY KEY (id);
alter table team_media add constraint team_media_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])));
alter table team_media_reactions add constraint team_media_reactions_emoji_check CHECK ((emoji = ANY (ARRAY['👍'::text, '❤️'::text, '🔥'::text, '💪'::text, '🏀'::text, '😂'::text, '👏'::text, '🎯'::text, '⭐'::text, '🙌'::text])));
alter table team_media_reactions add constraint team_media_reactions_media_id_user_id_key UNIQUE (media_id, user_id);
alter table team_media_reactions add constraint team_media_reactions_pkey PRIMARY KEY (id);
alter table games_live_session add constraint games_live_session_pkey PRIMARY KEY (id);
alter table game_events_log add constraint game_events_log_event_type_check CHECK ((event_type = ANY (ARRAY['points_2'::text, 'points_3'::text, 'free_throw'::text, 'foul'::text, 'rebound'::text, 'assist'::text, 'turnover'::text, 'steal'::text, 'sub_in'::text, 'sub_out'::text])));
alter table game_events_log add constraint game_events_log_pkey PRIMARY KEY (id);
alter table game_events_log add constraint game_events_log_quarter_check CHECK (((quarter >= 1) AND (quarter <= 10)));
alter table performance_reviews add constraint performance_reviews_check CHECK ((((review_type = 'player_review'::text) AND (player_id IS NOT NULL) AND (reviewee_user_id IS NULL)) OR ((review_type = 'coach_review'::text) AND (reviewee_user_id IS NOT NULL) AND (player_id IS NULL))));
alter table performance_reviews add constraint performance_reviews_pkey PRIMARY KEY (id);
alter table performance_reviews add constraint performance_reviews_review_type_check CHECK ((review_type = ANY (ARRAY['player_review'::text, 'coach_review'::text])));
alter table performance_reviews add constraint performance_reviews_reviewer_rating_check CHECK (((reviewer_rating >= 1) AND (reviewer_rating <= 5)));
alter table performance_reviews add constraint performance_reviews_self_rating_check CHECK (((self_rating >= 1) AND (self_rating <= 5)));
alter table performance_reviews add constraint performance_reviews_status_check CHECK ((status = ANY (ARRAY['pending_self_rating'::text, 'awaiting_reviewer'::text, 'completed'::text])));
alter table playbooks add constraint playbooks_category_check CHECK ((category = ANY (ARRAY['offense'::text, 'defense'::text, 'inbound'::text, 'drill'::text, 'special'::text])));
alter table playbooks add constraint playbooks_pkey PRIMARY KEY (id);
alter table plays add constraint plays_pkey PRIMARY KEY (id);
alter table play_views add constraint play_views_pkey PRIMARY KEY (id);
alter table play_views add constraint play_views_play_id_player_id_key UNIQUE (play_id, player_id);
alter table depth_charts add constraint depth_charts_pkey PRIMARY KEY (id);
alter table depth_charts add constraint depth_charts_team_id_court_position_depth_order_week_date_key UNIQUE (team_id, court_position, depth_order, week_date);
alter table team_weekly_focus add constraint team_weekly_focus_pkey PRIMARY KEY (id);
alter table team_weekly_focus add constraint team_weekly_focus_team_id_week_start_date_key UNIQUE (team_id, week_start_date);


-- ========================= FOREIGN KEYS =========================
alter table users add constraint users_auth_user_id_fkey FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table user_roles add constraint user_roles_club_id_fkey FOREIGN KEY (club_id) REFERENCES clubs(id) ON DELETE CASCADE;
alter table user_roles add constraint user_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES roles(role_id);
alter table user_roles add constraint user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
alter table role_permissions add constraint role_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE CASCADE;
alter table role_permissions add constraint role_permissions_role_id_fkey FOREIGN KEY (role_id) REFERENCES roles(role_id) ON DELETE CASCADE;
alter table teams add constraint teams_agegroup_id_fkey FOREIGN KEY (agegroup_id) REFERENCES age_group(agegroup_id) ON DELETE SET NULL;
alter table teams add constraint teams_club_id_fkey FOREIGN KEY (club_id) REFERENCES clubs(id) ON DELETE CASCADE;
alter table teams add constraint teams_season_id_fkey FOREIGN KEY (season_id) REFERENCES seasons(season_id) ON DELETE SET NULL;
alter table players add constraint players_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT;
alter table player_measurements add constraint player_measurements_player_id_fkey FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE RESTRICT;
alter table player_measurements add constraint player_measurements_recorded_by_fkey FOREIGN KEY (recorded_by) REFERENCES users(id) ON DELETE SET NULL;
alter table facilities add constraint facilities_club_id_fkey FOREIGN KEY (club_id) REFERENCES clubs(id) ON DELETE CASCADE;
alter table team_members add constraint team_members_player_id_fkey FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE RESTRICT;
alter table team_members add constraint team_members_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE;
alter table team_coaches add constraint team_coaches_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE;
alter table team_coaches add constraint team_coaches_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT;
alter table guardians add constraint guardians_player_id_fkey FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE;
alter table guardians add constraint guardians_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
alter table invitations add constraint invitations_club_id_fkey FOREIGN KEY (club_id) REFERENCES clubs(id) ON DELETE CASCADE;
alter table invitations add constraint invitations_inviter_id_fkey FOREIGN KEY (inviter_id) REFERENCES users(id) ON DELETE RESTRICT;
alter table invitations add constraint invitations_role_id_fkey FOREIGN KEY (role_id) REFERENCES roles(role_id);
alter table invitations add constraint invitations_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE;
alter table announcements add constraint announcements_author_id_fkey FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE RESTRICT;
alter table announcements add constraint announcements_club_id_fkey FOREIGN KEY (club_id) REFERENCES clubs(id) ON DELETE CASCADE;
alter table announcements add constraint announcements_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE;
alter table club_blackout_dates add constraint club_blackout_dates_club_id_fkey FOREIGN KEY (club_id) REFERENCES clubs(id) ON DELETE CASCADE;
alter table knowledge_base add constraint knowledge_base_club_id_fkey FOREIGN KEY (club_id) REFERENCES clubs(id) ON DELETE CASCADE;
alter table events add constraint events_coach_id_fkey FOREIGN KEY (coach_id) REFERENCES users(id) ON DELETE SET NULL;
alter table events add constraint events_created_by_user_fkey FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL;
alter table events add constraint events_facility_id_fkey FOREIGN KEY (facility_id) REFERENCES facilities(id) ON DELETE SET NULL;
alter table events add constraint events_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE;
alter table event_responses add constraint event_responses_player_id_fkey FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE RESTRICT;
alter table event_responses add constraint rsvps_event_id_fkey FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE;
alter table event_responses add constraint rsvps_responded_by_user_fkey FOREIGN KEY (responded_by) REFERENCES users(id) ON DELETE SET NULL;
alter table attendance add constraint attendance_event_id_fkey FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE;
alter table attendance add constraint attendance_marked_by_user_fkey FOREIGN KEY (marked_by) REFERENCES users(id) ON DELETE SET NULL;
alter table attendance add constraint attendance_player_id_fkey FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE RESTRICT;
alter table player_feedback add constraint player_feedback_coach_id_fkey FOREIGN KEY (coach_id) REFERENCES users(id) ON DELETE RESTRICT;
alter table player_feedback add constraint player_feedback_event_id_fkey FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE SET NULL;
alter table player_feedback add constraint player_feedback_feedback_id_fkey FOREIGN KEY (feedback_id) REFERENCES feedback_type(feedback_id) ON DELETE SET NULL;
alter table player_feedback add constraint player_feedback_player_id_fkey FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE RESTRICT;
alter table player_feedback add constraint player_feedback_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE SET NULL;
alter table team_media add constraint team_media_event_id_fkey FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE SET NULL;
alter table team_media add constraint team_media_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES users(id) ON DELETE SET NULL;
alter table team_media add constraint team_media_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE;
alter table team_media add constraint team_media_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table team_media_reactions add constraint team_media_reactions_media_id_fkey FOREIGN KEY (media_id) REFERENCES team_media(id) ON DELETE CASCADE;
alter table team_media_reactions add constraint team_media_reactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
alter table games_live_session add constraint games_live_session_event_id_fkey FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE;
alter table game_events_log add constraint game_events_log_game_session_id_fkey FOREIGN KEY (game_session_id) REFERENCES games_live_session(id) ON DELETE CASCADE;
alter table game_events_log add constraint game_events_log_player_id_fkey FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE RESTRICT;
alter table game_events_log add constraint game_events_log_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE;
alter table performance_reviews add constraint performance_reviews_club_id_fkey FOREIGN KEY (club_id) REFERENCES clubs(id) ON DELETE SET NULL;
alter table performance_reviews add constraint performance_reviews_player_id_fkey FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE RESTRICT;
alter table performance_reviews add constraint performance_reviews_review_period_id_fkey FOREIGN KEY (review_period_id) REFERENCES review_periods(review_period_id);
alter table performance_reviews add constraint performance_reviews_reviewee_user_id_fkey FOREIGN KEY (reviewee_user_id) REFERENCES users(id) ON DELETE RESTRICT;
alter table performance_reviews add constraint performance_reviews_reviewer_user_id_fkey FOREIGN KEY (reviewer_user_id) REFERENCES users(id) ON DELETE SET NULL;
alter table performance_reviews add constraint performance_reviews_season_id_fkey FOREIGN KEY (season_id) REFERENCES seasons(season_id) ON DELETE CASCADE;
alter table performance_reviews add constraint performance_reviews_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE SET NULL;
alter table playbooks add constraint playbooks_author_id_fkey FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE RESTRICT;
alter table playbooks add constraint playbooks_club_id_fkey FOREIGN KEY (club_id) REFERENCES clubs(id) ON DELETE CASCADE;
alter table playbooks add constraint playbooks_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE SET NULL;
alter table plays add constraint plays_playbook_id_fkey FOREIGN KEY (playbook_id) REFERENCES playbooks(id) ON DELETE CASCADE;
alter table play_views add constraint play_views_play_id_fkey FOREIGN KEY (play_id) REFERENCES plays(id) ON DELETE CASCADE;
alter table play_views add constraint play_views_player_id_fkey FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE;
alter table depth_charts add constraint depth_charts_player_id_fkey FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE;
alter table depth_charts add constraint depth_charts_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE;
alter table team_weekly_focus add constraint team_weekly_focus_created_by_fkey FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL;
alter table team_weekly_focus add constraint team_weekly_focus_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE;


-- ============================= INDEXES =============================
-- (primary-key / unique / exclusion indexes are created by their
--  constraints above and are not repeated here.)
CREATE INDEX idx_user_roles_club_id ON public.user_roles USING btree (club_id);
CREATE INDEX idx_user_roles_role_id ON public.user_roles USING btree (role_id);
CREATE UNIQUE INDEX user_roles_one_clubless_role_per_user ON public.user_roles USING btree (user_id, role_id) WHERE (club_id IS NULL);
CREATE INDEX user_roles_user_id_idx ON public.user_roles USING btree (user_id);
CREATE INDEX idx_role_permissions_permission_id ON public.role_permissions USING btree (permission_id);
CREATE INDEX idx_teams_agegroup_id ON public.teams USING btree (agegroup_id);
CREATE INDEX idx_teams_club_id ON public.teams USING btree (club_id);
CREATE INDEX idx_teams_season_id ON public.teams USING btree (season_id);
CREATE INDEX players_user_id_idx ON public.players USING btree (user_id);
CREATE INDEX idx_player_measurements_recorded_by ON public.player_measurements USING btree (recorded_by);
CREATE INDEX player_measurements_player_date_idx ON public.player_measurements USING btree (player_id, measured_on DESC);
CREATE INDEX player_measurements_scd_idx ON public.player_measurements USING btree (player_id, valid_from, valid_to);
CREATE UNIQUE INDEX player_measurements_single_active_idx ON public.player_measurements USING btree (player_id) WHERE (is_current = true);
CREATE INDEX idx_facilities_club_id ON public.facilities USING btree (club_id);
CREATE INDEX team_members_current_idx ON public.team_members USING btree (player_id) WHERE (end_date IS NULL);
CREATE INDEX team_coaches_user_id_idx ON public.team_coaches USING btree (user_id);
CREATE UNIQUE INDEX guardians_one_primary_per_player ON public.guardians USING btree (player_id) WHERE is_primary;
CREATE INDEX guardians_user_id_idx ON public.guardians USING btree (user_id);
CREATE INDEX idx_invitations_club_id ON public.invitations USING btree (club_id);
CREATE INDEX idx_invitations_inviter_id ON public.invitations USING btree (inviter_id);
CREATE INDEX idx_invitations_role_id ON public.invitations USING btree (role_id);
CREATE INDEX idx_invitations_team_id ON public.invitations USING btree (team_id);
CREATE INDEX announcements_team_idx ON public.announcements USING btree (team_id, created_at DESC);
CREATE INDEX idx_announcements_author_id ON public.announcements USING btree (author_id);
CREATE INDEX idx_announcements_club_id ON public.announcements USING btree (club_id);
CREATE INDEX idx_club_blackout_dates_club_id ON public.club_blackout_dates USING btree (club_id);
CREATE INDEX idx_knowledge_base_club_id ON public.knowledge_base USING btree (club_id);
CREATE INDEX events_facility_starts_idx ON public.events USING btree (facility_id, starts_at);
CREATE INDEX events_team_starts_idx ON public.events USING btree (team_id, starts_at DESC);
CREATE INDEX idx_events_coach_id ON public.events USING btree (coach_id);
CREATE INDEX idx_events_created_by ON public.events USING btree (created_by);
CREATE INDEX event_responses_player_idx ON public.event_responses USING btree (player_id);
CREATE INDEX idx_event_responses_responded_by ON public.event_responses USING btree (responded_by);
CREATE INDEX attendance_player_time_idx ON public.attendance USING btree (player_id, created_at DESC);
CREATE INDEX idx_attendance_marked_by ON public.attendance USING btree (marked_by);
CREATE INDEX idx_player_feedback_coach_id ON public.player_feedback USING btree (coach_id);
CREATE INDEX idx_player_feedback_event_id ON public.player_feedback USING btree (event_id);
CREATE INDEX idx_player_feedback_feedback_id ON public.player_feedback USING btree (feedback_id);
CREATE INDEX idx_player_feedback_team_id ON public.player_feedback USING btree (team_id);
CREATE INDEX player_feedback_player_idx ON public.player_feedback USING btree (player_id, created_at DESC);
CREATE INDEX idx_team_media_event_id ON public.team_media USING btree (event_id);
CREATE INDEX idx_team_media_reviewed_by ON public.team_media USING btree (reviewed_by);
CREATE INDEX idx_team_media_uploaded_by ON public.team_media USING btree (uploaded_by);
CREATE INDEX team_media_feed_idx ON public.team_media USING btree (team_id, created_at DESC) WHERE (status = 'approved'::text);
CREATE INDEX idx_team_media_reactions_user_id ON public.team_media_reactions USING btree (user_id);
CREATE UNIQUE INDEX active_live_session_per_event ON public.games_live_session USING btree (event_id) WHERE (is_active = true);
CREATE INDEX game_events_log_player_idx ON public.game_events_log USING btree (player_id);
CREATE INDEX game_events_log_session_idx ON public.game_events_log USING btree (game_session_id);
CREATE INDEX game_events_player_summary_idx ON public.game_events_log USING btree (player_id, event_type, is_success);
CREATE INDEX idx_game_events_log_team_id ON public.game_events_log USING btree (team_id);
CREATE INDEX idx_performance_reviews_club_id ON public.performance_reviews USING btree (club_id);
CREATE INDEX idx_performance_reviews_review_period_id ON public.performance_reviews USING btree (review_period_id);
CREATE INDEX idx_performance_reviews_reviewer_user_id ON public.performance_reviews USING btree (reviewer_user_id);
CREATE INDEX idx_performance_reviews_season_id ON public.performance_reviews USING btree (season_id);
CREATE INDEX idx_performance_reviews_team_id ON public.performance_reviews USING btree (team_id);
CREATE UNIQUE INDEX performance_reviews_one_coach_review ON public.performance_reviews USING btree (reviewee_user_id, season_id, review_period_id) WHERE (review_type = 'coach_review'::text);
CREATE UNIQUE INDEX performance_reviews_one_player_review ON public.performance_reviews USING btree (player_id, season_id, review_period_id) WHERE (review_type = 'player_review'::text);
CREATE INDEX idx_playbooks_author_id ON public.playbooks USING btree (author_id);
CREATE INDEX idx_playbooks_club_id ON public.playbooks USING btree (club_id);
CREATE INDEX idx_playbooks_team_id ON public.playbooks USING btree (team_id);
CREATE INDEX idx_plays_playbook_id ON public.plays USING btree (playbook_id);
CREATE INDEX play_views_player_idx ON public.play_views USING btree (player_id);
CREATE INDEX depth_charts_team_idx ON public.depth_charts USING btree (team_id, week_date);
CREATE INDEX idx_depth_charts_player_id ON public.depth_charts USING btree (player_id);
CREATE INDEX idx_team_weekly_focus_created_by ON public.team_weekly_focus USING btree (created_by);


-- ============================ FUNCTIONS ============================
-- Application functions only; btree_gist's support functions are omitted.
CREATE OR REPLACE FUNCTION public.close_previous_measurement()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  update player_measurements
     set is_current = false, valid_to = now()
   where player_id = new.player_id
     and is_current = true;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.current_person_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select id from users where auth_user_id = auth.uid()
$function$;

CREATE OR REPLACE FUNCTION public.current_user_club_ids()
 RETURNS SETOF uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select ur.club_id from user_roles ur
    join roles r on r.role_id = ur.role_id
   where ur.user_id = public.current_person_id()
     and ur.is_active and r.can_manage_club and ur.club_id is not null
$function$;

CREATE OR REPLACE FUNCTION public.current_user_is_staff()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1 from team_coaches tc
     where tc.user_id = public.current_person_id() and tc.is_active
       and (tc.end_date is null or tc.end_date >= current_date)
  ) or exists (select 1 from public.current_user_club_ids())
$function$;

CREATE OR REPLACE FUNCTION public.current_user_managed_event_ids()
 RETURNS SETOF uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select e.id from events e
   where e.team_id in (select public.current_user_managed_team_ids())
$function$;

CREATE OR REPLACE FUNCTION public.current_user_managed_session_ids()
 RETURNS SETOF uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select s.id from games_live_session s
   where s.event_id in (select public.current_user_managed_event_ids())
$function$;

CREATE OR REPLACE FUNCTION public.current_user_managed_team_ids()
 RETURNS SETOF uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select tc.team_id from team_coaches tc
   where tc.user_id = public.current_person_id() and tc.is_active
     and (tc.end_date is null or tc.end_date >= current_date)
  union
  select t.id from teams t where t.club_id in (select public.current_user_club_ids())
$function$;

CREATE OR REPLACE FUNCTION public.current_user_own_player_ids()
 RETURNS SETOF uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select p.id from players p
   where p.user_id = public.current_person_id()
  union
  select g.player_id from guardians g
   where g.user_id = public.current_person_id() and g.is_active
$function$;

CREATE OR REPLACE FUNCTION public.current_user_player_ids()
 RETURNS SETOF uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select public.current_user_own_player_ids()
  union
  select tm.player_id from team_members tm
   where tm.team_id in (select public.current_user_team_ids())
$function$;

CREATE OR REPLACE FUNCTION public.current_user_primary_player_ids()
 RETURNS SETOF uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select g.player_id from guardians g
   where g.user_id = public.current_person_id() and g.is_primary and g.is_active
$function$;

CREATE OR REPLACE FUNCTION public.current_user_rsvp_player_ids()
 RETURNS SETOF uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select p.id from players p where p.user_id = public.current_person_id()
  union
  select g.player_id from guardians g
   where g.user_id = public.current_person_id() and g.is_active and g.can_rsvp
$function$;

CREATE OR REPLACE FUNCTION public.current_user_team_ids()
 RETURNS SETOF uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.current_user_visible_club_ids()
 RETURNS SETOF uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select ur.club_id from user_roles ur
   where ur.user_id = public.current_person_id()
     and ur.is_active and ur.club_id is not null
  union
  select t.club_id from teams t
   where t.id in (select public.current_user_team_ids())
$function$;

CREATE OR REPLACE FUNCTION public.current_user_visible_media_ids()
 RETURNS SETOF uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select m.id from team_media m
   where m.team_id in (select public.current_user_team_ids())
$function$;

CREATE OR REPLACE FUNCTION public.current_user_visible_person_ids()
 RETURNS SETOF uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.current_user_visible_session_ids()
 RETURNS SETOF uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select s.id from games_live_session s
    join events e on e.id = s.event_id
   where e.team_id in (select public.current_user_team_ids())
$function$;

CREATE OR REPLACE FUNCTION public.enforce_user_role_club_scope()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.protect_pii_updates()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  -- הקשרים מהימנים (service_role, SQL editor, מיגרציות) — אין להם
  -- auth.uid(). מעבירים אותם כדי שאדמין יוכל לתקן נתונים.
  if auth.uid() is null then
    return new;
  end if;

  -- סשן משתמש-קצה: שדות הזהות ניתנים לשינוי רק ל-staff.
  if (new.id_number, new.first_name, new.last_name, new.birth_date, new.gender)
       is distinct from
     (old.id_number, old.first_name, old.last_name, old.birth_date, old.gender)
     and not public.current_user_is_staff()
  then
    raise exception
      'Only staff may change player identity fields (id_number, first_name, last_name, birth_date, gender)';
  end if;

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  new.updated_at := now();
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.validate_measurement_date()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  if new.measured_on > current_date then
    raise exception 'measured_on (%) is in the future', new.measured_on;
  end if;
  return new;
end;
$function$;


-- ============================ TRIGGERS ============================
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.age_group FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.attendance FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.clubs FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.event_responses FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.events FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.facilities FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.feedback_type FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.game_events_log FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.games_live_session FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.guardians FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.performance_reviews FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_play_views_updated_at BEFORE UPDATE ON public.play_views FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.player_feedback FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER close_previous_measurement BEFORE INSERT ON public.player_measurements FOR EACH ROW EXECUTE FUNCTION close_previous_measurement();
CREATE TRIGGER validate_measurement_date BEFORE INSERT OR UPDATE ON public.player_measurements FOR EACH ROW EXECUTE FUNCTION validate_measurement_date();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.players FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trigger_protect_pii BEFORE UPDATE ON public.players FOR EACH ROW EXECUTE FUNCTION protect_pii_updates();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.review_periods FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.roles FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.seasons FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.team_coaches FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.team_media FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.team_media_reactions FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.team_members FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.teams FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.user_roles FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER user_roles_club_scope_check BEFORE INSERT OR UPDATE ON public.user_roles FOR EACH ROW EXECUTE FUNCTION enforce_user_role_club_scope();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION set_updated_at();


-- ============================== VIEWS ==============================
create view safe_players as
SELECT id,
    first_name,
    last_name,
    birth_date,
    gender,
    created_at
   FROM players;
alter view safe_players set (security_invoker = true);

create view safe_users as
SELECT id,
    first_name,
    last_name,
    avatar_url,
    city,
    gender,
    is_active
   FROM users;
alter view safe_users set (security_invoker = true);


-- ==================== ROW LEVEL SECURITY ====================
alter table clubs enable row level security;
alter table seasons enable row level security;
alter table age_group enable row level security;
alter table roles enable row level security;
alter table review_periods enable row level security;
alter table feedback_type enable row level security;
alter table permissions enable row level security;
alter table users enable row level security;
alter table user_roles enable row level security;
alter table role_permissions enable row level security;
alter table teams enable row level security;
alter table players enable row level security;
alter table player_measurements enable row level security;
alter table facilities enable row level security;
alter table team_members enable row level security;
alter table team_coaches enable row level security;
alter table guardians enable row level security;
alter table invitations enable row level security;
alter table announcements enable row level security;
alter table club_blackout_dates enable row level security;
alter table knowledge_base enable row level security;
alter table events enable row level security;
alter table event_responses enable row level security;
alter table attendance enable row level security;
alter table player_feedback enable row level security;
alter table team_media enable row level security;
alter table team_media_reactions enable row level security;
alter table games_live_session enable row level security;
alter table game_events_log enable row level security;
alter table performance_reviews enable row level security;
alter table playbooks enable row level security;
alter table plays enable row level security;
alter table play_views enable row level security;
alter table depth_charts enable row level security;
alter table team_weekly_focus enable row level security;

-- clubs
create policy "read visible clubs" on clubs for select to authenticated
  using ((id IN ( SELECT current_user_visible_club_ids() AS current_user_visible_club_ids)));
create policy "managers update their club" on clubs for update to authenticated
  using ((id IN ( SELECT current_user_club_ids() AS current_user_club_ids)))
  with check ((id IN ( SELECT current_user_club_ids() AS current_user_club_ids)));

-- seasons
create policy "read seasons" on seasons for select to authenticated
  using (true);

-- age_group
create policy "read age_group" on age_group for select to authenticated
  using (true);

-- roles
create policy "read roles" on roles for select to authenticated
  using (true);

-- review_periods
create policy "read review_periods" on review_periods for select to authenticated
  using (true);

-- feedback_type
create policy "read feedback_type" on feedback_type for select to authenticated
  using (true);

-- permissions
create policy "read permissions" on permissions for select to authenticated
  using (true);

-- users
create policy "create person rows" on users for insert to authenticated
  with check (((auth_user_id = ( SELECT auth.uid() AS uid)) OR ((auth_user_id IS NULL) AND current_user_is_staff())));
create policy "read visible people" on users for select to authenticated
  using ((id IN ( SELECT current_user_visible_person_ids() AS current_user_visible_person_ids)));
create policy "update person rows" on users for update to authenticated
  using (((auth_user_id = ( SELECT auth.uid() AS uid)) OR ((auth_user_id IS NULL) AND current_user_is_staff() AND (id IN ( SELECT current_user_visible_person_ids() AS current_user_visible_person_ids)))))
  with check (((auth_user_id = ( SELECT auth.uid() AS uid)) OR ((auth_user_id IS NULL) AND current_user_is_staff())));

-- user_roles
create policy "read own roles" on user_roles for select to authenticated
  using ((user_id = current_person_id()));

-- role_permissions
create policy "read role_permissions" on role_permissions for select to authenticated
  using (true);

-- teams
create policy "managers write teams" on teams for insert to authenticated
  with check ((club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids)));
create policy "read visible teams" on teams for select to authenticated
  using ((id IN ( SELECT current_user_team_ids() AS current_user_team_ids)));
create policy "managers update teams" on teams for update to authenticated
  using ((club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids)))
  with check ((club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids)));

-- players
create policy "staff create players" on players for insert to authenticated
  with check (current_user_is_staff());
create policy "read visible players" on players for select to authenticated
  using ((id IN ( SELECT current_user_player_ids() AS current_user_player_ids)));
create policy "update own players" on players for update to authenticated
  using (((id IN ( SELECT current_user_player_ids() AS current_user_player_ids)) AND (current_user_is_staff() OR (id IN ( SELECT current_user_own_player_ids() AS current_user_own_player_ids)))))
  with check ((id IN ( SELECT current_user_player_ids() AS current_user_player_ids)));

-- player_measurements
create policy "staff record measurements" on player_measurements for insert to authenticated
  with check ((current_user_is_staff() AND (player_id IN ( SELECT current_user_player_ids() AS current_user_player_ids))));
create policy "read visible measurements" on player_measurements for select to authenticated
  using ((player_id IN ( SELECT current_user_player_ids() AS current_user_player_ids)));
create policy "staff update measurements" on player_measurements for update to authenticated
  using ((current_user_is_staff() AND (player_id IN ( SELECT current_user_player_ids() AS current_user_player_ids))))
  with check ((current_user_is_staff() AND (player_id IN ( SELECT current_user_player_ids() AS current_user_player_ids))));

-- facilities
create policy "staff write facilities" on facilities for insert to authenticated
  with check ((((club_id IS NULL) AND current_user_is_staff()) OR (club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids))));
create policy "read visible facilities" on facilities for select to authenticated
  using (((club_id IS NULL) OR (club_id IN ( SELECT current_user_visible_club_ids() AS current_user_visible_club_ids))));
create policy "staff update facilities" on facilities for update to authenticated
  using ((((club_id IS NULL) AND current_user_is_staff()) OR (club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids))))
  with check ((((club_id IS NULL) AND current_user_is_staff()) OR (club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids))));

-- team_members
create policy "staff write roster" on team_members for insert to authenticated
  with check ((team_id IN ( SELECT current_user_managed_team_ids() AS current_user_managed_team_ids)));
create policy "read visible roster" on team_members for select to authenticated
  using ((team_id IN ( SELECT current_user_team_ids() AS current_user_team_ids)));
create policy "staff update roster" on team_members for update to authenticated
  using ((team_id IN ( SELECT current_user_managed_team_ids() AS current_user_managed_team_ids)))
  with check ((team_id IN ( SELECT current_user_managed_team_ids() AS current_user_managed_team_ids)));

-- team_coaches
create policy "managers assign coaches" on team_coaches for insert to authenticated
  with check ((team_id IN ( SELECT t.id
   FROM teams t
  WHERE (t.club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids)))));
create policy "read visible coaches" on team_coaches for select to authenticated
  using ((team_id IN ( SELECT current_user_team_ids() AS current_user_team_ids)));
create policy "managers update coaches" on team_coaches for update to authenticated
  using ((team_id IN ( SELECT t.id
   FROM teams t
  WHERE (t.club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids)))))
  with check ((team_id IN ( SELECT t.id
   FROM teams t
  WHERE (t.club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids)))));

-- guardians
create policy "primary guardian invites" on guardians for insert to authenticated
  with check (((player_id IN ( SELECT current_user_primary_player_ids() AS current_user_primary_player_ids)) OR current_user_is_staff()));
create policy "read own family links" on guardians for select to authenticated
  using (((user_id = current_person_id()) OR (player_id IN ( SELECT current_user_player_ids() AS current_user_player_ids))));
create policy "primary guardian updates" on guardians for update to authenticated
  using (((player_id IN ( SELECT current_user_primary_player_ids() AS current_user_primary_player_ids)) OR current_user_is_staff()))
  with check (((player_id IN ( SELECT current_user_primary_player_ids() AS current_user_primary_player_ids)) OR current_user_is_staff()));

-- invitations
create policy "staff create invitations" on invitations for insert to authenticated
  with check (((inviter_id = current_person_id()) AND (club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids))));
create policy "staff read invitations" on invitations for select to authenticated
  using ((club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids)));
create policy "staff update invitations" on invitations for update to authenticated
  using ((club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids)))
  with check ((club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids)));

-- announcements
create policy "staff post announcements" on announcements for insert to authenticated
  with check (((author_id = current_person_id()) AND ((club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids)) OR (team_id IN ( SELECT current_user_managed_team_ids() AS current_user_managed_team_ids)))));
create policy "read announcements" on announcements for select to authenticated
  using (((club_id IN ( SELECT current_user_visible_club_ids() AS current_user_visible_club_ids)) OR (team_id IN ( SELECT current_user_team_ids() AS current_user_team_ids))));
create policy "staff update announcements" on announcements for update to authenticated
  using (((author_id = current_person_id()) OR (club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids))))
  with check (((author_id = current_person_id()) OR (club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids))));

-- club_blackout_dates
create policy "manage club_blackout_dates" on club_blackout_dates for all to authenticated
  using ((club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids)))
  with check ((club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids)));
create policy "read club_blackout_dates" on club_blackout_dates for select to authenticated
  using ((club_id IN ( SELECT current_user_visible_club_ids() AS current_user_visible_club_ids)));

-- knowledge_base
create policy "managers write knowledge_base" on knowledge_base for insert to authenticated
  with check ((club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids)));
create policy "read knowledge_base" on knowledge_base for select to authenticated
  using (((club_id IS NULL) OR (club_id IN ( SELECT current_user_visible_club_ids() AS current_user_visible_club_ids))));
create policy "managers update knowledge_base" on knowledge_base for update to authenticated
  using ((club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids)))
  with check ((club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids)));

-- events
create policy "staff create events" on events for insert to authenticated
  with check ((team_id IN ( SELECT current_user_managed_team_ids() AS current_user_managed_team_ids)));
create policy "read visible events" on events for select to authenticated
  using ((team_id IN ( SELECT current_user_team_ids() AS current_user_team_ids)));
create policy "staff update events" on events for update to authenticated
  using ((team_id IN ( SELECT current_user_managed_team_ids() AS current_user_managed_team_ids)))
  with check ((team_id IN ( SELECT current_user_managed_team_ids() AS current_user_managed_team_ids)));

-- event_responses
create policy "respond for own players" on event_responses for insert to authenticated
  with check (((player_id IN ( SELECT current_user_rsvp_player_ids() AS current_user_rsvp_player_ids)) OR (event_id IN ( SELECT current_user_managed_event_ids() AS current_user_managed_event_ids))));
create policy "read visible responses" on event_responses for select to authenticated
  using ((player_id IN ( SELECT current_user_player_ids() AS current_user_player_ids)));
create policy "update own responses" on event_responses for update to authenticated
  using (((player_id IN ( SELECT current_user_rsvp_player_ids() AS current_user_rsvp_player_ids)) OR (event_id IN ( SELECT current_user_managed_event_ids() AS current_user_managed_event_ids))))
  with check (((player_id IN ( SELECT current_user_rsvp_player_ids() AS current_user_rsvp_player_ids)) OR (event_id IN ( SELECT current_user_managed_event_ids() AS current_user_managed_event_ids))));

-- attendance
create policy "staff mark attendance" on attendance for insert to authenticated
  with check ((event_id IN ( SELECT current_user_managed_event_ids() AS current_user_managed_event_ids)));
create policy "read visible attendance" on attendance for select to authenticated
  using ((player_id IN ( SELECT current_user_player_ids() AS current_user_player_ids)));
create policy "staff update attendance" on attendance for update to authenticated
  using ((event_id IN ( SELECT current_user_managed_event_ids() AS current_user_managed_event_ids)))
  with check ((event_id IN ( SELECT current_user_managed_event_ids() AS current_user_managed_event_ids)));

-- player_feedback
create policy "coaches write feedback" on player_feedback for insert to authenticated
  with check ((current_user_is_staff() AND (coach_id = current_person_id()) AND (player_id IN ( SELECT current_user_player_ids() AS current_user_player_ids))));
create policy "read visible feedback" on player_feedback for select to authenticated
  using ((player_id IN ( SELECT current_user_player_ids() AS current_user_player_ids)));
create policy "coaches edit own feedback" on player_feedback for update to authenticated
  using ((coach_id = current_person_id()))
  with check ((coach_id = current_person_id()));

-- team_media
create policy "upload own media" on team_media for insert to authenticated
  with check (((team_id IN ( SELECT current_user_team_ids() AS current_user_team_ids)) AND (uploaded_by = current_person_id())));
create policy "read approved media" on team_media for select to authenticated
  using (((team_id IN ( SELECT current_user_team_ids() AS current_user_team_ids)) AND ((status = 'approved'::text) OR (uploaded_by = current_person_id()) OR (team_id IN ( SELECT current_user_managed_team_ids() AS current_user_managed_team_ids)))));
create policy "moderate media" on team_media for update to authenticated
  using (((uploaded_by = current_person_id()) OR (team_id IN ( SELECT current_user_managed_team_ids() AS current_user_managed_team_ids))))
  with check (((uploaded_by = current_person_id()) OR (team_id IN ( SELECT current_user_managed_team_ids() AS current_user_managed_team_ids))));

-- team_media_reactions
create policy "react as self" on team_media_reactions for insert to authenticated
  with check (((user_id = current_person_id()) AND (media_id IN ( SELECT current_user_visible_media_ids() AS current_user_visible_media_ids))));
create policy "read visible reactions" on team_media_reactions for select to authenticated
  using ((media_id IN ( SELECT current_user_visible_media_ids() AS current_user_visible_media_ids)));
create policy "change own reaction" on team_media_reactions for update to authenticated
  using ((user_id = current_person_id()))
  with check ((user_id = current_person_id()));

-- games_live_session
create policy "staff open session" on games_live_session for insert to authenticated
  with check ((event_id IN ( SELECT current_user_managed_event_ids() AS current_user_managed_event_ids)));
create policy "read visible sessions" on games_live_session for select to authenticated
  using ((event_id IN ( SELECT e.id
   FROM events e
  WHERE (e.team_id IN ( SELECT current_user_team_ids() AS current_user_team_ids)))));
create policy "staff run session" on games_live_session for update to authenticated
  using ((event_id IN ( SELECT current_user_managed_event_ids() AS current_user_managed_event_ids)))
  with check ((event_id IN ( SELECT current_user_managed_event_ids() AS current_user_managed_event_ids)));

-- game_events_log
create policy "staff log game events" on game_events_log for insert to authenticated
  with check ((game_session_id IN ( SELECT current_user_managed_session_ids() AS current_user_managed_session_ids)));
create policy "read visible game log" on game_events_log for select to authenticated
  using ((game_session_id IN ( SELECT current_user_visible_session_ids() AS current_user_visible_session_ids)));
create policy "staff fix game log" on game_events_log for update to authenticated
  using ((game_session_id IN ( SELECT current_user_managed_session_ids() AS current_user_managed_session_ids)))
  with check ((game_session_id IN ( SELECT current_user_managed_session_ids() AS current_user_managed_session_ids)));

-- performance_reviews
create policy "staff create reviews" on performance_reviews for insert to authenticated
  with check (current_user_is_staff());
create policy "read visible reviews" on performance_reviews for select to authenticated
  using (((player_id IN ( SELECT current_user_player_ids() AS current_user_player_ids)) OR ((reviewee_user_id = current_person_id()) AND (NOT is_anonymous)) OR (reviewer_user_id = current_person_id()) OR (club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids))));
create policy "participants update reviews" on performance_reviews for update to authenticated
  using (((reviewer_user_id = current_person_id()) OR (reviewee_user_id = current_person_id()) OR (player_id IN ( SELECT current_user_own_player_ids() AS current_user_own_player_ids)) OR (club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids))))
  with check (((reviewer_user_id = current_person_id()) OR (reviewee_user_id = current_person_id()) OR (player_id IN ( SELECT current_user_own_player_ids() AS current_user_own_player_ids)) OR (club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids))));

-- playbooks
create policy "staff create playbooks" on playbooks for insert to authenticated
  with check (((author_id = current_person_id()) AND current_user_is_staff() AND ((club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids)) OR (team_id IN ( SELECT current_user_managed_team_ids() AS current_user_managed_team_ids)))));
create policy "read visible playbooks" on playbooks for select to authenticated
  using (((author_id = current_person_id()) OR (team_id IN ( SELECT current_user_team_ids() AS current_user_team_ids)) OR (is_shared_with_club AND (club_id IN ( SELECT current_user_visible_club_ids() AS current_user_visible_club_ids)))));
create policy "author or mgr update playbooks" on playbooks for update to authenticated
  using (((author_id = current_person_id()) OR (club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids))))
  with check (((author_id = current_person_id()) OR (club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids))));

-- plays
create policy "write plays" on plays for insert to authenticated
  with check ((playbook_id IN ( SELECT playbooks.id
   FROM playbooks
  WHERE ((playbooks.author_id = current_person_id()) OR (playbooks.club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids))))));
create policy "read plays" on plays for select to authenticated
  using ((playbook_id IN ( SELECT playbooks.id
   FROM playbooks)));
create policy "update plays" on plays for update to authenticated
  using ((playbook_id IN ( SELECT playbooks.id
   FROM playbooks
  WHERE ((playbooks.author_id = current_person_id()) OR (playbooks.club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids))))))
  with check ((playbook_id IN ( SELECT playbooks.id
   FROM playbooks
  WHERE ((playbooks.author_id = current_person_id()) OR (playbooks.club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids))))));

-- play_views
create policy "log own play_views" on play_views for insert to authenticated
  with check (((player_id IN ( SELECT current_user_own_player_ids() AS current_user_own_player_ids)) OR current_user_is_staff()));
create policy "read play_views" on play_views for select to authenticated
  using ((player_id IN ( SELECT current_user_player_ids() AS current_user_player_ids)));
create policy "update own play_views" on play_views for update to authenticated
  using (((player_id IN ( SELECT current_user_own_player_ids() AS current_user_own_player_ids)) OR current_user_is_staff()))
  with check (((player_id IN ( SELECT current_user_own_player_ids() AS current_user_own_player_ids)) OR current_user_is_staff()));

-- depth_charts
create policy "staff write depth_charts" on depth_charts for insert to authenticated
  with check ((team_id IN ( SELECT current_user_managed_team_ids() AS current_user_managed_team_ids)));
create policy "read depth_charts" on depth_charts for select to authenticated
  using ((team_id IN ( SELECT current_user_team_ids() AS current_user_team_ids)));
create policy "staff update depth_charts" on depth_charts for update to authenticated
  using ((team_id IN ( SELECT current_user_managed_team_ids() AS current_user_managed_team_ids)))
  with check ((team_id IN ( SELECT current_user_managed_team_ids() AS current_user_managed_team_ids)));

-- team_weekly_focus
create policy "staff write team_weekly_focus" on team_weekly_focus for insert to authenticated
  with check ((team_id IN ( SELECT current_user_managed_team_ids() AS current_user_managed_team_ids)));
create policy "read team_weekly_focus" on team_weekly_focus for select to authenticated
  using ((team_id IN ( SELECT current_user_team_ids() AS current_user_team_ids)));
create policy "staff update team_weekly_focus" on team_weekly_focus for update to authenticated
  using ((team_id IN ( SELECT current_user_managed_team_ids() AS current_user_managed_team_ids)))
  with check ((team_id IN ( SELECT current_user_managed_team_ids() AS current_user_managed_team_ids)));


-- ==================== VIEW GRANTS ====================
-- safe_* views are read-only for client roles (finding #13); the default
-- Supabase grant of ALL is narrowed to what the live DB actually has.
revoke insert, update, delete, truncate on safe_players from anon, authenticated;
revoke insert, update, delete, truncate on safe_users from anon, authenticated;


-- ============================ SEED DATA ============================
-- Lookup tables only. user_roles.role_id is NOT NULL with an FK to roles,
-- so no role can be assigned to anyone until this runs.

insert into roles (name, hierarchy_depth, requires_club, can_manage_club) values
  ('Management', 1, true,  true),
  ('Coach',      2, true,  false),
  ('Player',     3, true,  false),
  ('Parent',     4, false, false);

insert into review_periods (name, display_order) values
  ('שיחת אמצע עונה', 1),
  ('שיחת סוף עונה',  2);

insert into feedback_type (feedback_name) values
  ('אימון נהדר'),
  ('אימון טוב'),
  ('דורש שיפור'),
  ('אימון חלש');

-- permissions / role_permissions are created empty; the admin permission
-- matrix screen defines and grants them.
