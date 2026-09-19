-- =====================================================================
-- CourtSide / LiveCourtAI — full database schema, one script.
--
-- Regenerated VERBATIM from a live-DB audit (pg_catalog / information_schema).
-- Every object below is reproduced as it exists in production, not hand-edited.
--
-- Run once on an EMPTY database. No DROP preamble by design.
--
-- Layout: extensions -> types -> tables -> constraints -> foreign keys
-- -> indexes -> functions -> triggers -> views -> RLS + policies -> grants
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
  secondary_color text,
  company_id text,
  status text not null default 'provisioning'::text,
  created_by uuid,
  updated_by uuid
);

create table seasons (
  id uuid not null default gen_random_uuid(),
  season_name text,
  start_date date,
  end_date date,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table age_group (
  id uuid not null default gen_random_uuid(),
  agegroup_name text,
  is_active boolean not null default true,
  comment text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table roles (
  id integer not null generated always as identity,
  name text not null,
  hierarchy_depth integer not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  requires_club boolean not null default true,
  can_manage_club boolean not null default false
);

create table review_periods (
  id integer not null generated always as identity,
  name text not null,
  display_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table feedback_type (
  id integer not null generated always as identity,
  feedback_name text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_positive boolean not null default false
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
  auth_user_id uuid,
  phone_verified_at timestamptz,
  email_verified_at timestamptz
);

create table user_roles (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null,
  created_at timestamptz not null default now(),
  club_id uuid,
  is_active boolean not null default true,
  updated_at timestamptz not null default now(),
  role_id integer not null,
  ended_at timestamptz,
  ended_reason text,
  created_by uuid,
  updated_by uuid
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
  created_by uuid,
  updated_by uuid
);

create table players (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_active boolean not null default true,
  first_name text,
  last_name text,
  birth_date date,
  gender text,
  parent_confirmed_at timestamptz,
  parent_confirmed_by uuid,
  coach_confirmed_at timestamptz,
  coach_confirmed_by uuid,
  merged_into_player_id uuid,
  merged_at timestamptz,
  id_number_encrypted bytea,
  id_number_hash text,
  created_by uuid,
  updated_by uuid
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
  courts_count integer not null default 1,
  created_by uuid,
  updated_by uuid
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
  player_id uuid not null,
  created_by uuid,
  updated_by uuid
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
  role text not null default 'head_coach'::text,
  created_by uuid,
  updated_by uuid
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
  notification_channel text not null default 'app'::text,
  ended_at timestamptz,
  ended_reason text,
  created_by uuid,
  updated_by uuid
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
  status text not null default 'pending'::text,
  expires_at timestamptz not null default (now() + '7 days'::interval),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  token_hash text not null,
  player_id uuid,
  claimed_by_user_id uuid,
  claimed_at timestamptz,
  claimed_ip inet,
  target_user_id uuid
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
  updated_at timestamptz not null default now(),
  updated_by uuid
);

create table club_blackout_dates (
  id uuid not null default gen_random_uuid(),
  club_id uuid not null,
  title text not null,
  starts_at date not null,
  ends_at date not null,
  cancel_events boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid
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
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid
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
END) stored,
  updated_by uuid
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
  feedback_type_id integer,
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
  away_lineup uuid[] default '{}'::uuid[],
  created_by uuid,
  updated_by uuid
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
  quarter integer not null default 1,
  created_by uuid,
  updated_by uuid
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
  is_anonymous boolean not null default false,
  created_by uuid,
  updated_by uuid
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
  updated_at timestamptz not null default now(),
  updated_by uuid
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
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid
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
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid
);

create table team_weekly_focus (
  id uuid not null default gen_random_uuid(),
  team_id uuid not null,
  week_start_date date not null,
  focus_title text not null,
  description text,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid
);

create table audit_log (
  id bigint not null generated always as identity,
  table_name text not null,
  row_id uuid not null,
  action text not null,
  old_row jsonb,
  new_row jsonb,
  changed_columns text[],
  changed_by uuid,
  changed_by_auth uuid,
  changed_at timestamptz not null default now()
);

create table consents (
  id uuid not null default gen_random_uuid(),
  player_id uuid not null,
  granted_by uuid not null,
  consent_type text not null,
  policy_version text not null,
  method text not null,
  evidence jsonb,
  granted_at timestamptz not null default now(),
  revoked_at timestamptz
);

create table idempotency_keys (
  auth_user_id uuid not null,
  key text not null,
  operation text not null,
  result jsonb,
  created_at timestamptz not null default now()
);

create table policy_versions (
  consent_type text not null,
  current_version text not null,
  updated_at timestamptz not null default now()
);

create table rate_counters (
  actor_key text not null,
  bucket text not null,
  window_start timestamptz not null,
  hits integer not null default 0
);

create table team_join_requests (
  id uuid not null default gen_random_uuid(),
  club_id uuid not null,
  team_id uuid not null,
  player_id uuid not null,
  requested_by uuid not null,
  status text not null default 'pending'::text,
  rejection_reason text,
  reviewed_by uuid,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table user_identities (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null,
  provider text not null,
  provider_subject text not null,
  verified_at timestamptz,
  created_at timestamptz not null default now()
);


-- ===================== CONSTRAINTS (pk / unique / check / exclude) =====================

-- primary keys, unique, check, exclusion
alter table clubs add constraint clubs_pkey PRIMARY KEY (id);
alter table clubs add constraint clubs_status_check CHECK ((status = ANY (ARRAY['provisioning'::text, 'active'::text, 'closed'::text])));
alter table seasons add constraint seasons_pkey PRIMARY KEY (id);
alter table age_group add constraint age_group_pkey PRIMARY KEY (id);
alter table roles add constraint roles_hierarchy_depth_key UNIQUE (hierarchy_depth);
alter table roles add constraint roles_name_key UNIQUE (name);
alter table roles add constraint roles_pkey PRIMARY KEY (id);
alter table review_periods add constraint review_periods_name_key UNIQUE (name);
alter table review_periods add constraint review_periods_pkey PRIMARY KEY (id);
alter table feedback_type add constraint feedback_type_name_key UNIQUE (feedback_name);
alter table feedback_type add constraint feedback_type_pkey PRIMARY KEY (id);
alter table permissions add constraint permissions_pkey PRIMARY KEY (id);
alter table users add constraint shadow_person_has_no_contact CHECK (((auth_user_id IS NOT NULL) OR ((cellphone IS NULL) AND (email IS NULL))));
alter table users add constraint user_pkey PRIMARY KEY (id);
alter table users add constraint users_auth_user_id_key UNIQUE (auth_user_id);
alter table users add constraint users_cellphone_key UNIQUE (cellphone);
alter table users add constraint users_email_key UNIQUE (email);
alter table user_roles add constraint user_roles_pkey PRIMARY KEY (id);
alter table role_permissions add constraint role_permissions_pkey PRIMARY KEY (role_id, permission_id);
alter table teams add constraint teams_pkey PRIMARY KEY (id);
alter table players add constraint players_pkey PRIMARY KEY (id);
alter table player_measurements add constraint player_measurements_pkey PRIMARY KEY (id);
alter table facilities add constraint facilities_courts_count_check CHECK ((courts_count >= 1));
alter table facilities add constraint facilities_pkey PRIMARY KEY (id);
alter table team_members add constraint team_members_pkey PRIMARY KEY (id);
alter table team_members add constraint team_members_status_check CHECK ((status = ANY (ARRAY['active'::text, 'injured'::text, 'inactive'::text])));
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
alter table invitations add constraint invitations_token_hash_key UNIQUE (token_hash);
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
alter table audit_log add constraint audit_log_action_check CHECK ((action = ANY (ARRAY['INSERT'::text, 'UPDATE'::text, 'DELETE'::text])));
alter table audit_log add constraint audit_log_pkey PRIMARY KEY (id);
alter table consents add constraint consents_consent_type_check CHECK ((consent_type = ANY (ARRAY['app_use'::text, 'media'::text, 'measurements'::text, 'data_processing'::text])));
alter table consents add constraint consents_method_check CHECK ((method = ANY (ARRAY['otp'::text, 'in_app'::text, 'signed_form'::text])));
alter table consents add constraint consents_pkey PRIMARY KEY (id);
alter table idempotency_keys add constraint idempotency_keys_pkey PRIMARY KEY (auth_user_id, key);
alter table policy_versions add constraint policy_versions_consent_type_check CHECK ((consent_type = ANY (ARRAY['app_use'::text, 'media'::text, 'measurements'::text, 'data_processing'::text])));
alter table policy_versions add constraint policy_versions_pkey PRIMARY KEY (consent_type);
alter table rate_counters add constraint rate_counters_pkey PRIMARY KEY (actor_key, bucket, window_start);
alter table team_join_requests add constraint team_join_requests_pkey PRIMARY KEY (id);
alter table team_join_requests add constraint team_join_requests_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text, 'cancelled'::text, 'expired'::text])));
alter table user_identities add constraint uniq_provider_subject UNIQUE (provider, provider_subject);
alter table user_identities add constraint user_identities_pkey PRIMARY KEY (id);
alter table user_identities add constraint user_identities_provider_check CHECK ((provider = ANY (ARRAY['google'::text, 'apple'::text, 'phone'::text, 'email'::text])));


-- ========================= FOREIGN KEYS =========================
alter table clubs add constraint clubs_created_by_fkey FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table clubs add constraint clubs_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table users add constraint users_auth_user_id_fkey FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table user_roles add constraint user_roles_club_id_fkey FOREIGN KEY (club_id) REFERENCES clubs(id) ON DELETE CASCADE;
alter table user_roles add constraint user_roles_created_by_fkey FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table user_roles add constraint user_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES roles(id);
alter table user_roles add constraint user_roles_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table user_roles add constraint user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
alter table role_permissions add constraint role_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE CASCADE;
alter table role_permissions add constraint role_permissions_role_id_fkey FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE;
alter table teams add constraint teams_agegroup_id_fkey FOREIGN KEY (agegroup_id) REFERENCES age_group(id) ON DELETE SET NULL;
alter table teams add constraint teams_club_id_fkey FOREIGN KEY (club_id) REFERENCES clubs(id) ON DELETE CASCADE;
alter table teams add constraint teams_created_by_fkey FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table teams add constraint teams_season_id_fkey FOREIGN KEY (season_id) REFERENCES seasons(id) ON DELETE SET NULL;
alter table teams add constraint teams_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table players add constraint players_coach_confirmed_by_fkey FOREIGN KEY (coach_confirmed_by) REFERENCES users(id);
alter table players add constraint players_created_by_fkey FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table players add constraint players_merged_into_player_id_fkey FOREIGN KEY (merged_into_player_id) REFERENCES players(id);
alter table players add constraint players_parent_confirmed_by_fkey FOREIGN KEY (parent_confirmed_by) REFERENCES users(id);
alter table players add constraint players_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table players add constraint players_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT;
alter table player_measurements add constraint player_measurements_player_id_fkey FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE RESTRICT;
alter table player_measurements add constraint player_measurements_recorded_by_fkey FOREIGN KEY (recorded_by) REFERENCES users(id) ON DELETE SET NULL;
alter table facilities add constraint facilities_club_id_fkey FOREIGN KEY (club_id) REFERENCES clubs(id) ON DELETE CASCADE;
alter table facilities add constraint facilities_created_by_fkey FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table facilities add constraint facilities_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table team_members add constraint team_members_created_by_fkey FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table team_members add constraint team_members_player_id_fkey FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE RESTRICT;
alter table team_members add constraint team_members_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE;
alter table team_members add constraint team_members_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table team_coaches add constraint team_coaches_created_by_fkey FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table team_coaches add constraint team_coaches_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE;
alter table team_coaches add constraint team_coaches_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table team_coaches add constraint team_coaches_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT;
alter table guardians add constraint guardians_created_by_fkey FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table guardians add constraint guardians_player_id_fkey FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE;
alter table guardians add constraint guardians_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table guardians add constraint guardians_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
alter table invitations add constraint invitations_claimed_by_user_id_fkey FOREIGN KEY (claimed_by_user_id) REFERENCES users(id) ON DELETE SET NULL;
alter table invitations add constraint invitations_club_id_fkey FOREIGN KEY (club_id) REFERENCES clubs(id) ON DELETE CASCADE;
alter table invitations add constraint invitations_inviter_id_fkey FOREIGN KEY (inviter_id) REFERENCES users(id) ON DELETE RESTRICT;
alter table invitations add constraint invitations_player_id_fkey FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE;
alter table invitations add constraint invitations_role_id_fkey FOREIGN KEY (role_id) REFERENCES roles(id);
alter table invitations add constraint invitations_target_user_id_fkey FOREIGN KEY (target_user_id) REFERENCES users(id) ON DELETE CASCADE;
alter table invitations add constraint invitations_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE;
alter table announcements add constraint announcements_author_id_fkey FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE RESTRICT;
alter table announcements add constraint announcements_club_id_fkey FOREIGN KEY (club_id) REFERENCES clubs(id) ON DELETE CASCADE;
alter table announcements add constraint announcements_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE;
alter table announcements add constraint announcements_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table club_blackout_dates add constraint club_blackout_dates_club_id_fkey FOREIGN KEY (club_id) REFERENCES clubs(id) ON DELETE CASCADE;
alter table club_blackout_dates add constraint club_blackout_dates_created_by_fkey FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table club_blackout_dates add constraint club_blackout_dates_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table knowledge_base add constraint knowledge_base_club_id_fkey FOREIGN KEY (club_id) REFERENCES clubs(id) ON DELETE CASCADE;
alter table knowledge_base add constraint knowledge_base_created_by_fkey FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table knowledge_base add constraint knowledge_base_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table events add constraint events_coach_id_fkey FOREIGN KEY (coach_id) REFERENCES users(id) ON DELETE SET NULL;
alter table events add constraint events_created_by_user_fkey FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL;
alter table events add constraint events_facility_id_fkey FOREIGN KEY (facility_id) REFERENCES facilities(id) ON DELETE SET NULL;
alter table events add constraint events_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE;
alter table events add constraint events_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table event_responses add constraint event_responses_player_id_fkey FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE RESTRICT;
alter table event_responses add constraint rsvps_event_id_fkey FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE;
alter table event_responses add constraint rsvps_responded_by_user_fkey FOREIGN KEY (responded_by) REFERENCES users(id) ON DELETE SET NULL;
alter table attendance add constraint attendance_event_id_fkey FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE;
alter table attendance add constraint attendance_marked_by_user_fkey FOREIGN KEY (marked_by) REFERENCES users(id) ON DELETE SET NULL;
alter table attendance add constraint attendance_player_id_fkey FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE RESTRICT;
alter table player_feedback add constraint player_feedback_coach_id_fkey FOREIGN KEY (coach_id) REFERENCES users(id) ON DELETE RESTRICT;
alter table player_feedback add constraint player_feedback_event_id_fkey FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE SET NULL;
alter table player_feedback add constraint player_feedback_feedback_type_id_fkey FOREIGN KEY (feedback_type_id) REFERENCES feedback_type(id) ON DELETE SET NULL;
alter table player_feedback add constraint player_feedback_player_id_fkey FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE RESTRICT;
alter table player_feedback add constraint player_feedback_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE SET NULL;
alter table team_media add constraint team_media_event_id_fkey FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE SET NULL;
alter table team_media add constraint team_media_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES users(id) ON DELETE SET NULL;
alter table team_media add constraint team_media_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE;
alter table team_media add constraint team_media_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table team_media_reactions add constraint team_media_reactions_media_id_fkey FOREIGN KEY (media_id) REFERENCES team_media(id) ON DELETE CASCADE;
alter table team_media_reactions add constraint team_media_reactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
alter table games_live_session add constraint games_live_session_created_by_fkey FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table games_live_session add constraint games_live_session_event_id_fkey FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE;
alter table games_live_session add constraint games_live_session_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table game_events_log add constraint game_events_log_created_by_fkey FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table game_events_log add constraint game_events_log_game_session_id_fkey FOREIGN KEY (game_session_id) REFERENCES games_live_session(id) ON DELETE CASCADE;
alter table game_events_log add constraint game_events_log_player_id_fkey FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE RESTRICT;
alter table game_events_log add constraint game_events_log_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE;
alter table game_events_log add constraint game_events_log_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table performance_reviews add constraint performance_reviews_club_id_fkey FOREIGN KEY (club_id) REFERENCES clubs(id) ON DELETE SET NULL;
alter table performance_reviews add constraint performance_reviews_created_by_fkey FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table performance_reviews add constraint performance_reviews_player_id_fkey FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE RESTRICT;
alter table performance_reviews add constraint performance_reviews_review_period_id_fkey FOREIGN KEY (review_period_id) REFERENCES review_periods(id);
alter table performance_reviews add constraint performance_reviews_reviewee_user_id_fkey FOREIGN KEY (reviewee_user_id) REFERENCES users(id) ON DELETE RESTRICT;
alter table performance_reviews add constraint performance_reviews_reviewer_user_id_fkey FOREIGN KEY (reviewer_user_id) REFERENCES users(id) ON DELETE SET NULL;
alter table performance_reviews add constraint performance_reviews_season_id_fkey FOREIGN KEY (season_id) REFERENCES seasons(id) ON DELETE CASCADE;
alter table performance_reviews add constraint performance_reviews_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE SET NULL;
alter table performance_reviews add constraint performance_reviews_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table playbooks add constraint playbooks_author_id_fkey FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE RESTRICT;
alter table playbooks add constraint playbooks_club_id_fkey FOREIGN KEY (club_id) REFERENCES clubs(id) ON DELETE CASCADE;
alter table playbooks add constraint playbooks_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE SET NULL;
alter table playbooks add constraint playbooks_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table plays add constraint plays_created_by_fkey FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table plays add constraint plays_playbook_id_fkey FOREIGN KEY (playbook_id) REFERENCES playbooks(id) ON DELETE CASCADE;
alter table plays add constraint plays_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table play_views add constraint play_views_play_id_fkey FOREIGN KEY (play_id) REFERENCES plays(id) ON DELETE CASCADE;
alter table play_views add constraint play_views_player_id_fkey FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE;
alter table depth_charts add constraint depth_charts_created_by_fkey FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table depth_charts add constraint depth_charts_player_id_fkey FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE;
alter table depth_charts add constraint depth_charts_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE;
alter table depth_charts add constraint depth_charts_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table team_weekly_focus add constraint team_weekly_focus_created_by_fkey FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL;
alter table team_weekly_focus add constraint team_weekly_focus_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE;
alter table team_weekly_focus add constraint team_weekly_focus_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE RESTRICT;
alter table consents add constraint consents_granted_by_fkey FOREIGN KEY (granted_by) REFERENCES users(id);
alter table consents add constraint consents_player_id_fkey FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE;
alter table team_join_requests add constraint team_join_requests_club_id_fkey FOREIGN KEY (club_id) REFERENCES clubs(id) ON DELETE CASCADE;
alter table team_join_requests add constraint team_join_requests_player_id_fkey FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE;
alter table team_join_requests add constraint team_join_requests_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES users(id) ON DELETE CASCADE;
alter table team_join_requests add constraint team_join_requests_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES users(id);
alter table team_join_requests add constraint team_join_requests_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE;
alter table user_identities add constraint user_identities_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;


-- ============================= INDEXES =============================
-- (primary-key / unique / exclusion indexes are created by their
--  constraints above and are not repeated here.)
CREATE INDEX idx_user_roles_club_id ON public.user_roles USING btree (club_id);
CREATE INDEX idx_user_roles_role_id ON public.user_roles USING btree (role_id);
CREATE UNIQUE INDEX user_roles_one_clubless_role_per_user ON public.user_roles USING btree (user_id, role_id) WHERE (club_id IS NULL);
CREATE UNIQUE INDEX user_roles_one_role_per_user_club ON public.user_roles USING btree (user_id, club_id, role_id) WHERE (club_id IS NOT NULL);
CREATE INDEX user_roles_user_id_idx ON public.user_roles USING btree (user_id);
CREATE INDEX idx_role_permissions_permission_id ON public.role_permissions USING btree (permission_id);
CREATE INDEX idx_teams_agegroup_id ON public.teams USING btree (agegroup_id);
CREATE INDEX idx_teams_club_id ON public.teams USING btree (club_id);
CREATE INDEX idx_teams_season_id ON public.teams USING btree (season_id);
CREATE INDEX idx_players_coach_confirmed_by ON public.players USING btree (coach_confirmed_by);
CREATE INDEX idx_players_merged_into_player_id ON public.players USING btree (merged_into_player_id);
CREATE INDEX idx_players_parent_confirmed_by ON public.players USING btree (parent_confirmed_by);
CREATE UNIQUE INDEX players_id_number_hash_key ON public.players USING btree (id_number_hash);
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
CREATE INDEX idx_invitations_claimed_by_user_id ON public.invitations USING btree (claimed_by_user_id);
CREATE INDEX idx_invitations_club_id ON public.invitations USING btree (club_id);
CREATE INDEX idx_invitations_inviter_id ON public.invitations USING btree (inviter_id);
CREATE INDEX idx_invitations_player_id ON public.invitations USING btree (player_id);
CREATE INDEX idx_invitations_role_id ON public.invitations USING btree (role_id);
CREATE INDEX idx_invitations_target_user_id ON public.invitations USING btree (target_user_id);
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
CREATE INDEX idx_player_feedback_feedback_type_id ON public.player_feedback USING btree (feedback_type_id);
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
CREATE INDEX audit_log_changed_at_idx ON public.audit_log USING btree (changed_at DESC);
CREATE INDEX audit_log_changed_by_idx ON public.audit_log USING btree (changed_by);
CREATE INDEX audit_log_table_row_idx ON public.audit_log USING btree (table_name, row_id, changed_at DESC);
CREATE INDEX idx_consents_granted_by ON public.consents USING btree (granted_by);
CREATE INDEX idx_consents_player_id ON public.consents USING btree (player_id);
CREATE INDEX idx_tjr_club_id ON public.team_join_requests USING btree (club_id);
CREATE INDEX idx_tjr_player_id ON public.team_join_requests USING btree (player_id);
CREATE INDEX idx_tjr_requested_by ON public.team_join_requests USING btree (requested_by);
CREATE INDEX idx_tjr_reviewed_by ON public.team_join_requests USING btree (reviewed_by);
CREATE UNIQUE INDEX team_join_requests_no_dup ON public.team_join_requests USING btree (team_id, player_id) WHERE (status = 'pending'::text);
CREATE INDEX idx_user_identities_user_id ON public.user_identities USING btree (user_id);


-- ============================ FUNCTIONS ============================
-- Every application function in public; extension (btree_gist) support
-- functions are omitted. Bodies are not validated at create time so that
-- SQL functions may reference functions defined later in this file.
set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public._id_number_key()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'id_number_encryption_key'
$function$;

CREATE OR REPLACE FUNCTION public.approve_join_request(p_request_id uuid, p_id_number text, p_idem_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_auth_uid uuid := auth.uid();
  v_cached   jsonb;
  v_req      record;
  v_owner    uuid;
  v_hash     text;
  v_result   jsonb;
BEGIN
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'must be authenticated';
  END IF;

  SELECT result INTO v_cached FROM public.idempotency_keys
   WHERE auth_user_id = v_auth_uid AND key = p_idem_key;
  IF FOUND THEN
    RETURN v_cached;
  END IF;

  SELECT * INTO v_req FROM public.team_join_requests WHERE id = p_request_id FOR UPDATE;
  IF v_req.id IS NULL THEN
    RAISE EXCEPTION 'join request not found';
  END IF;
  IF v_req.status <> 'pending' THEN
    RAISE EXCEPTION 'join request is not pending (status=%)', v_req.status;
  END IF;
  IF v_req.team_id NOT IN (SELECT public.current_user_managed_team_ids()) THEN
    RAISE EXCEPTION 'not authorized for this team';
  END IF;

  PERFORM 1 FROM public.clubs WHERE id = v_req.club_id FOR UPDATE;   -- lock order: clubs first

  v_hash := encode(extensions.hmac(p_id_number, public._id_number_key(), 'sha256'), 'hex');

  SELECT id INTO v_owner FROM public.players WHERE id_number_hash = v_hash;
  IF v_owner IS NOT NULL AND v_owner <> v_req.player_id THEN
    RAISE EXCEPTION 'id_number belongs to a different player (id=%) — merge required before approving (merge_players(), not yet available)', v_owner;
  END IF;

  ------------------------------------------------------------------------
  -- step 1 — team_members, always first. May already exist (season
  -- renewal, §5.5, or a prior stint on this same team) — reactivate
  -- rather than violate team_members_team_id_player_id_key.
  ------------------------------------------------------------------------
  PERFORM 1 FROM public.team_members WHERE team_id = v_req.team_id AND player_id = v_req.player_id FOR UPDATE;
  IF EXISTS (SELECT 1 FROM public.team_members WHERE team_id = v_req.team_id AND player_id = v_req.player_id) THEN
    UPDATE public.team_members
       SET is_active = true, status = 'active', end_date = NULL
     WHERE team_id = v_req.team_id AND player_id = v_req.player_id;
  ELSE
    INSERT INTO public.team_members (team_id, player_id) VALUES (v_req.team_id, v_req.player_id);
  END IF;

  ------------------------------------------------------------------------
  -- step 2 — players.id_number (now encrypted+hash), only now that step 1
  -- has happened.
  ------------------------------------------------------------------------
  IF v_owner IS NULL THEN
    UPDATE public.players
       SET id_number_encrypted = extensions.pgp_sym_encrypt(p_id_number, public._id_number_key()),
           id_number_hash = v_hash
     WHERE id = v_req.player_id;
  END IF;   -- v_owner = v_req.player_id case: already this player's own number, no write needed

  ------------------------------------------------------------------------
  -- step 3 — coach confirmation for the visibility gate (§6.1). Not an
  -- identity field per protect_pii_updates()'s own comparison tuple, so
  -- unaffected by roster-membership gating either way.
  ------------------------------------------------------------------------
  UPDATE public.players
     SET coach_confirmed_at = now(), coach_confirmed_by = public.current_person_id()
   WHERE id = v_req.player_id;

  ------------------------------------------------------------------------
  -- step 4 — close the request.
  ------------------------------------------------------------------------
  UPDATE public.team_join_requests
     SET status = 'approved', reviewed_by = public.current_person_id(), reviewed_at = now()
   WHERE id = p_request_id;

  v_result := jsonb_build_object('request_id', p_request_id, 'player_id', v_req.player_id,
                                  'team_id', v_req.team_id);

  INSERT INTO public.idempotency_keys (auth_user_id, key, operation, result)
  VALUES (v_auth_uid, p_idem_key, 'approve_join_request', v_result);

  RETURN v_result;
END; $function$;

CREATE OR REPLACE FUNCTION public.check_rate_limit(p_actor_key text, p_bucket text, p_max_hits integer, p_window interval)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_window_secs  double precision := extract(epoch from p_window);
  v_window_start timestamptz;
  v_hits         int;
BEGIN
  IF p_actor_key IS NULL OR length(p_actor_key) = 0 THEN
    RAISE EXCEPTION 'actor_key is required';
  END IF;
  IF p_bucket IS NULL OR length(p_bucket) = 0 THEN
    RAISE EXCEPTION 'bucket is required';
  END IF;
  IF v_window_secs IS NULL OR v_window_secs <= 0 THEN
    RAISE EXCEPTION 'window must be a positive interval';
  END IF;
  IF p_max_hits IS NULL OR p_max_hits <= 0 THEN
    RAISE EXCEPTION 'max_hits must be a positive integer';
  END IF;

  v_window_start := to_timestamp(floor(extract(epoch from now()) / v_window_secs) * v_window_secs);

  INSERT INTO public.rate_counters (actor_key, bucket, window_start, hits)
  VALUES (p_actor_key, p_bucket, v_window_start, 1)
  ON CONFLICT (actor_key, bucket, window_start)
  DO UPDATE SET hits = public.rate_counters.hits + 1
  RETURNING hits INTO v_hits;

  IF v_hits > p_max_hits THEN
    RAISE EXCEPTION 'rate limit exceeded for bucket %: % per %', p_bucket, p_max_hits, p_window;
  END IF;

  RETURN v_hits;
END; $function$;

CREATE OR REPLACE FUNCTION public.claim_invitation(p_token text, p_idem_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_auth_uid       uuid := auth.uid();
  v_hash           text;
  v_inv            record;
  v_person         uuid;
  v_is_new_person  boolean := false;
  v_auth_email     text;
  v_auth_phone     text;
  v_email_verified boolean;
  v_phone_verified boolean;
  v_role_row       record;
  v_active_mgrs    int;
  v_inviter_ok     boolean;
  v_is_active      boolean;
  v_has_primary    boolean;
  v_space          int;
  v_first          text;
  v_last           text;
  v_cached         jsonb;
  v_result         jsonb;
BEGIN
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'must be authenticated to claim an invitation';
  END IF;

  SELECT result INTO v_cached FROM public.idempotency_keys
   WHERE auth_user_id = v_auth_uid AND key = p_idem_key;
  IF FOUND THEN
    RETURN v_cached;
  END IF;

  v_hash := encode(extensions.digest(p_token, 'sha256'), 'hex');

  UPDATE public.invitations
     SET status = 'accepted', claimed_at = now()
   WHERE token_hash = v_hash AND status = 'pending' AND expires_at > now()
  RETURNING id, club_id, team_id, player_id, role_id, inviter_id, email, cellphone, target_name, target_user_id
    INTO v_inv;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'invitation not available';
  END IF;

  PERFORM 1 FROM public.clubs WHERE id = v_inv.club_id FOR UPDATE;

  SELECT email, phone,
         email_confirmed_at IS NOT NULL, phone_confirmed_at IS NOT NULL
    INTO v_auth_email, v_auth_phone, v_email_verified, v_phone_verified
    FROM auth.users WHERE id = v_auth_uid;

  ----------------------------------------------------------------------
  -- §2.7 assisted recovery: re-point an EXISTING person's auth_user_id
  -- and contact info onto the new, verified channel. Orthogonal to
  -- role_id — checked before anything role_id-shaped.
  ----------------------------------------------------------------------
  IF v_inv.target_user_id IS NOT NULL THEN
    IF NOT (
      (v_inv.cellphone IS NOT NULL AND v_phone_verified AND v_auth_phone = v_inv.cellphone)
      OR (v_inv.email IS NOT NULL AND v_email_verified AND lower(v_auth_email) = lower(v_inv.email))
    ) THEN
      RAISE EXCEPTION 'verified identity does not match the recovery invitation''s channel';
    END IF;

    UPDATE public.users
       SET auth_user_id = v_auth_uid,
           email             = coalesce(v_inv.email, email),
           cellphone         = coalesce(v_inv.cellphone, cellphone),
           email_verified_at = CASE WHEN v_inv.email     IS NOT NULL THEN now() ELSE email_verified_at END,
           phone_verified_at = CASE WHEN v_inv.cellphone IS NOT NULL THEN now() ELSE phone_verified_at END
     WHERE id = v_inv.target_user_id;

    UPDATE public.invitations SET claimed_by_user_id = v_inv.target_user_id WHERE id = v_inv.id;

    v_result := jsonb_build_object('person_id', v_inv.target_user_id, 'kind', 'channel_recovery');
    INSERT INTO public.idempotency_keys (auth_user_id, key, operation, result)
    VALUES (v_auth_uid, p_idem_key, 'claim_invitation', v_result);
    RETURN v_result;
  END IF;

  ----------------------------------------------------------------------
  -- §5.6 device-binding invite (role_id=3): the "person" IS the shadow
  -- player itself, resolved by player_id — no contact info to search by.
  ----------------------------------------------------------------------
  IF v_inv.player_id IS NOT NULL AND v_inv.role_id = 3 THEN
    SELECT user_id INTO v_person FROM public.players WHERE id = v_inv.player_id;
    IF v_person IS NULL THEN
      RAISE EXCEPTION 'invitation targets an unknown player';
    END IF;

    UPDATE public.users
       SET auth_user_id = v_auth_uid, cellphone = v_inv.cellphone
     WHERE id = v_person;

    UPDATE public.invitations SET claimed_by_user_id = v_person WHERE id = v_inv.id;

    v_result := jsonb_build_object('person_id', v_person, 'player_id', v_inv.player_id,
                                    'kind', 'device_binding');
    INSERT INTO public.idempotency_keys (auth_user_id, key, operation, result)
    VALUES (v_auth_uid, p_idem_key, 'claim_invitation', v_result);
    RETURN v_result;
  END IF;

  IF v_inv.role_id = 4 AND v_inv.player_id IS NULL THEN
    RAISE EXCEPTION 'guardian invitation missing player_id';
  END IF;

  ----------------------------------------------------------------------
  -- §4.2 step ב'/ג' — normal person resolution by verified contact info.
  -- Applies to management/coach invites (role_id 1/2) AND guardian
  -- pending-link invites (role_id 4 with player_id set) alike: in both
  -- cases the claimer is a real person being identified, not a shadow.
  ----------------------------------------------------------------------
  v_person := NULL;
  IF v_inv.cellphone IS NOT NULL THEN
    SELECT id INTO v_person FROM public.users WHERE cellphone = v_inv.cellphone;
  END IF;
  IF v_person IS NULL AND v_inv.email IS NOT NULL THEN
    SELECT id INTO v_person FROM public.users WHERE email = v_inv.email;
  END IF;

  IF v_person IS NULL THEN
    v_is_new_person := true;

    IF NOT (
      (v_inv.cellphone IS NOT NULL AND v_phone_verified AND v_auth_phone = v_inv.cellphone)
      OR (v_inv.email IS NOT NULL AND v_email_verified AND lower(v_auth_email) = lower(v_inv.email))
    ) THEN
      RAISE EXCEPTION 'verified identity does not match invitation';
    END IF;

    v_space := position(' ' in coalesce(v_inv.target_name, ''));
    IF v_space > 0 THEN
      v_first := substring(v_inv.target_name from 1 for v_space - 1);
      v_last  := substring(v_inv.target_name from v_space + 1);
    ELSE
      v_first := coalesce(v_inv.target_name, '');
      v_last  := '';
    END IF;

    INSERT INTO public.users (auth_user_id, email, cellphone, first_name, last_name)
    VALUES (v_auth_uid, v_inv.email, v_inv.cellphone, v_first, v_last)
    RETURNING id INTO v_person;
  ELSE
    IF NOT (
      (v_phone_verified AND v_auth_phone IS NOT NULL
        AND EXISTS (SELECT 1 FROM public.users u WHERE u.id = v_person AND u.cellphone = v_auth_phone))
      OR (v_email_verified AND v_auth_email IS NOT NULL
        AND EXISTS (SELECT 1 FROM public.users u WHERE u.id = v_person AND lower(u.email) = lower(v_auth_email)))
    ) THEN
      RAISE EXCEPTION 'verified identity does not match the invited person';
    END IF;

    UPDATE public.users SET auth_user_id = v_auth_uid
     WHERE id = v_person AND auth_user_id IS NULL;
  END IF;

  UPDATE public.invitations SET claimed_by_user_id = v_person WHERE id = v_inv.id;

  ----------------------------------------------------------------------
  -- §5.2 route 2 — guardian pending-link: closing action is a guardians
  -- row, not a club role grant. Ensures the clubless Parent role exists
  -- once per lifetime (§3.3), same as create_own_child().
  ----------------------------------------------------------------------
  IF v_inv.role_id = 4 THEN
    PERFORM 1 FROM public.user_roles WHERE user_id = v_person AND club_id IS NULL AND role_id = 4 FOR UPDATE;
    IF NOT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = v_person AND club_id IS NULL AND role_id = 4) THEN
      INSERT INTO public.user_roles (user_id, club_id, role_id, is_active) VALUES (v_person, NULL, 4, true);
    END IF;

    v_has_primary := EXISTS (
      SELECT 1 FROM public.guardians WHERE player_id = v_inv.player_id AND is_active AND is_primary
    );

    IF NOT EXISTS (SELECT 1 FROM public.guardians WHERE player_id = v_inv.player_id AND user_id = v_person) THEN
      INSERT INTO public.guardians (player_id, user_id, relationship_type, is_primary, can_rsvp)
      VALUES (v_inv.player_id, v_person, 'parent', NOT v_has_primary, true);
    END IF;

    v_result := jsonb_build_object('person_id', v_person, 'player_id', v_inv.player_id,
                                    'is_new_person', v_is_new_person, 'kind', 'guardian_link');
    INSERT INTO public.idempotency_keys (auth_user_id, key, operation, result)
    VALUES (v_auth_uid, p_idem_key, 'claim_invitation', v_result);
    RETURN v_result;
  END IF;

  ----------------------------------------------------------------------
  -- §4.2 step ד' — role grant (role_id 1/2), with §4.4 point 2's
  -- documented override for role_id = 1.
  ----------------------------------------------------------------------
  PERFORM 1 FROM public.user_roles
   WHERE user_id = v_person AND club_id = v_inv.club_id AND role_id = v_inv.role_id
   FOR UPDATE;

  SELECT id, is_active INTO v_role_row
    FROM public.user_roles
   WHERE user_id = v_person AND club_id = v_inv.club_id AND role_id = v_inv.role_id;

  IF v_inv.role_id = 1 THEN
    v_active_mgrs := (SELECT count(*) FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id
                        WHERE ur.club_id = v_inv.club_id AND ur.is_active AND r.can_manage_club);
    v_inviter_ok := EXISTS (SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id
                             WHERE ur.user_id = v_inv.inviter_id AND ur.club_id = v_inv.club_id
                               AND ur.is_active AND r.can_manage_club);
    v_is_active := (v_active_mgrs = 1 AND v_inviter_ok);

    IF v_role_row.id IS NULL THEN
      INSERT INTO public.user_roles (user_id, club_id, role_id, is_active)
      VALUES (v_person, v_inv.club_id, v_inv.role_id, v_is_active);
    ELSE
      UPDATE public.user_roles
         SET is_active    = is_active OR v_is_active,
             ended_at     = CASE WHEN v_is_active THEN NULL ELSE ended_at END,
             ended_reason = CASE WHEN v_is_active THEN NULL ELSE ended_reason END
       WHERE id = v_role_row.id;
    END IF;
  ELSE
    IF v_role_row.id IS NULL THEN
      INSERT INTO public.user_roles (user_id, club_id, role_id, is_active)
      VALUES (v_person, v_inv.club_id, v_inv.role_id, false);
    ELSIF NOT v_role_row.is_active THEN
      UPDATE public.user_roles
         SET is_active = true, ended_at = NULL, ended_reason = NULL
       WHERE id = v_role_row.id;
    END IF;
  END IF;

  IF v_inv.role_id = 2 AND v_inv.team_id IS NOT NULL THEN
    PERFORM 1 FROM public.team_coaches WHERE team_id = v_inv.team_id AND user_id = v_person FOR UPDATE;
    IF NOT EXISTS (SELECT 1 FROM public.team_coaches WHERE team_id = v_inv.team_id AND user_id = v_person) THEN
      INSERT INTO public.team_coaches (team_id, user_id, role, is_active)
      VALUES (v_inv.team_id, v_person, 'other', false);
    END IF;
  END IF;

  v_result := jsonb_build_object(
    'person_id', v_person, 'club_id', v_inv.club_id, 'role_id', v_inv.role_id,
    'is_new_person', v_is_new_person
  );

  INSERT INTO public.idempotency_keys (auth_user_id, key, operation, result)
  VALUES (v_auth_uid, p_idem_key, 'claim_invitation', v_result);

  RETURN v_result;
END; $function$;

CREATE OR REPLACE FUNCTION public.close_previous_measurement()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  update player_measurements
     set is_current = false, valid_to = now()
   where player_id = new.player_id
     and is_current = true;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_own_child(p_first_name text, p_last_name text, p_birth_date date, p_gender text, p_idem_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_auth_uid uuid := auth.uid();
  v_parent   uuid;
  v_cached   jsonb;
  v_shadow   uuid;
  v_player   uuid;
  v_dup      boolean;
  v_result   jsonb;
BEGIN
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'must be authenticated to create a child profile';
  END IF;

  SELECT result INTO v_cached FROM public.idempotency_keys
   WHERE auth_user_id = v_auth_uid AND key = p_idem_key;
  IF FOUND THEN
    RETURN v_cached;
  END IF;

  v_parent := public.current_person_id();
  IF v_parent IS NULL THEN
    INSERT INTO public.users (auth_user_id, email, cellphone, first_name, last_name)
    SELECT v_auth_uid, email, phone, '', '' FROM auth.users WHERE id = v_auth_uid
    RETURNING id INTO v_parent;
  END IF;

  PERFORM 1 FROM public.user_roles WHERE user_id = v_parent AND club_id IS NULL AND role_id = 4 FOR UPDATE;

  IF NOT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = v_parent AND club_id IS NULL AND role_id = 4) THEN
    INSERT INTO public.user_roles (user_id, club_id, role_id, is_active) VALUES (v_parent, NULL, 4, true);
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.players p JOIN public.guardians g ON g.player_id = p.id
     WHERE g.user_id = v_parent AND g.is_active
       AND p.first_name = p_first_name AND p.last_name = p_last_name AND p.birth_date = p_birth_date
  ) INTO v_dup;

  INSERT INTO public.users (auth_user_id, first_name, last_name)
  VALUES (NULL, p_first_name, p_last_name)
  RETURNING id INTO v_shadow;

  INSERT INTO public.players (user_id, first_name, last_name, birth_date, gender)
  VALUES (v_shadow, p_first_name, p_last_name, p_birth_date, p_gender)
  RETURNING id INTO v_player;

  INSERT INTO public.guardians (player_id, user_id, relationship_type, is_primary, can_rsvp)
  VALUES (v_player, v_parent, 'parent', true, true);

  v_result := jsonb_build_object('player_id', v_player, 'parent_person_id', v_parent, 'duplicate_warning', v_dup);

  INSERT INTO public.idempotency_keys (auth_user_id, key, operation, result)
  VALUES (v_auth_uid, p_idem_key, 'create_own_child', v_result);

  RETURN v_result;
END; $function$;

CREATE OR REPLACE FUNCTION public.current_person_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select id from users where auth_user_id = auth.uid()
$function$;

CREATE OR REPLACE FUNCTION public.current_session_aal()
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  SELECT coalesce(auth.jwt() ->> 'aal', 'aal1')
$function$;

CREATE OR REPLACE FUNCTION public.current_user_club_ids()
 RETURNS SETOF uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select ur.club_id from user_roles ur
    join roles r on r.id = ur.role_id
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

CREATE OR REPLACE FUNCTION public.digital_age_consent_threshold()
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  SELECT 16 -- PLACEHOLDER pending §13 item 2 (legal counsel) -- GDPR Art. 8 default
$function$;

CREATE OR REPLACE FUNCTION public.end_club_membership(p_player_id uuid, p_club_id uuid, p_reason text, p_idem_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_auth_uid uuid := auth.uid();
  v_cached   jsonb;
  v_is_mgmt  boolean;
  v_other_club_active boolean;
  v_result   jsonb;
BEGIN
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'must be authenticated';
  END IF;

  SELECT result INTO v_cached FROM public.idempotency_keys
   WHERE auth_user_id = v_auth_uid AND key = p_idem_key;
  IF FOUND THEN
    RETURN v_cached;
  END IF;

  v_is_mgmt := p_club_id IN (SELECT public.current_user_club_ids());
  IF NOT v_is_mgmt THEN
    RAISE EXCEPTION 'not authorized — club management only';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.players WHERE id = p_player_id) THEN
    RAISE EXCEPTION 'player not found';
  END IF;

  v_other_club_active := EXISTS (
    SELECT 1 FROM public.team_members tm JOIN public.teams t ON t.id = tm.team_id
     WHERE tm.player_id = p_player_id AND tm.is_active AND t.club_id <> p_club_id
  );

  IF NOT v_other_club_active THEN
    UPDATE public.players SET coach_confirmed_at = NULL, coach_confirmed_by = NULL
     WHERE id = p_player_id;
    PERFORM public.set_parent_consent(p_player_id, false, NULL, NULL, NULL, NULL, p_idem_key || '-consent-reset');
  END IF;

  UPDATE public.team_members tm
     SET is_active = false, end_date = current_date, status = 'inactive'
   WHERE tm.player_id = p_player_id AND tm.is_active
     AND tm.team_id IN (SELECT id FROM public.teams WHERE club_id = p_club_id);

  v_result := jsonb_build_object('player_id', p_player_id, 'club_id', p_club_id, 'reason', p_reason);

  INSERT INTO public.idempotency_keys (auth_user_id, key, operation, result)
  VALUES (v_auth_uid, p_idem_key, 'end_club_membership', v_result);

  RETURN v_result;
END; $function$;

CREATE OR REPLACE FUNCTION public.end_guardianship(p_guardian_id uuid, p_reason text, p_idem_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_auth_uid   uuid := auth.uid();
  v_cached     jsonb;
  v_row        record;
  v_is_self    boolean;
  v_is_primary_caller boolean;
  v_is_staff   boolean;
  v_has_own_account boolean;
  v_other_active_guardian boolean;
  v_confirmed_by uuid;
  v_result     jsonb;
BEGIN
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'must be authenticated';
  END IF;

  SELECT result INTO v_cached FROM public.idempotency_keys
   WHERE auth_user_id = v_auth_uid AND key = p_idem_key;
  IF FOUND THEN
    RETURN v_cached;
  END IF;

  SELECT * INTO v_row FROM public.guardians WHERE id = p_guardian_id FOR UPDATE;
  IF v_row.id IS NULL THEN
    RAISE EXCEPTION 'guardian record not found';
  END IF;
  IF NOT v_row.is_active THEN
    RAISE EXCEPTION 'guardianship already ended';
  END IF;

  v_is_self := (public.current_person_id() IS NOT NULL AND v_row.user_id = public.current_person_id());
  v_is_primary_caller := v_row.player_id IN (SELECT public.current_user_primary_player_ids());
  v_is_staff := EXISTS (
    SELECT 1 FROM public.team_members tm
     WHERE tm.player_id = v_row.player_id AND tm.is_active
       AND tm.team_id IN (SELECT public.current_user_managed_team_ids())
  );
  IF NOT v_is_self AND NOT v_is_primary_caller AND NOT v_is_staff THEN
    RAISE EXCEPTION 'not authorized — requires self, the primary guardian, or club staff';
  END IF;

  IF v_row.is_primary THEN
    v_has_own_account := EXISTS (
      SELECT 1 FROM public.players p JOIN public.users u ON u.id = p.user_id
       WHERE p.id = v_row.player_id AND u.auth_user_id IS NOT NULL
    );
    IF NOT v_has_own_account THEN
      v_other_active_guardian := EXISTS (
        SELECT 1 FROM public.guardians WHERE player_id = v_row.player_id AND is_active AND id <> p_guardian_id
      );
      IF NOT v_other_active_guardian THEN
        RAISE EXCEPTION 'cannot remove the last primary guardian of a player with no account of their own — add a replacement guardian first';
      END IF;
    END IF;
  END IF;

  SELECT parent_confirmed_by INTO v_confirmed_by FROM public.players WHERE id = v_row.player_id;
  IF v_confirmed_by = v_row.user_id THEN
    PERFORM public.set_parent_consent(v_row.player_id, false, NULL, NULL, NULL, NULL, p_idem_key || '-consent-reset');
  END IF;

  UPDATE public.guardians
     SET is_active = false, ended_at = now(), ended_reason = p_reason
   WHERE id = p_guardian_id;

  v_result := jsonb_build_object('guardian_id', p_guardian_id, 'player_id', v_row.player_id, 'reason', p_reason);

  INSERT INTO public.idempotency_keys (auth_user_id, key, operation, result)
  VALUES (v_auth_uid, p_idem_key, 'end_guardianship', v_result);

  RETURN v_result;
END; $function$;

CREATE OR REPLACE FUNCTION public.ended_implies_inactive()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  IF new.ended_at IS NOT NULL THEN new.is_active := false; END IF;
  RETURN new;
END; $function$;

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
  from roles where id = new.role_id;

  if v_requires_club and new.club_id is null then
    raise exception 'Role "%" is club-scoped — club_id is required', v_role_name;
  end if;

  if not v_requires_club and new.club_id is not null then
    raise exception 'Role "%" is not club-scoped — club_id must be null', v_role_name;
  end if;

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.expire_stale_consents(p_club_id uuid, p_idem_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_auth_uid uuid := auth.uid();
  v_cached   jsonb;
  v_is_mgmt  boolean;
  v_player   record;
  v_reset_ids uuid[] := '{}';
  v_result   jsonb;
BEGIN
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'must be authenticated';
  END IF;

  SELECT result INTO v_cached FROM public.idempotency_keys
   WHERE auth_user_id = v_auth_uid AND key = p_idem_key;
  IF FOUND THEN
    RETURN v_cached;
  END IF;

  v_is_mgmt := p_club_id IN (SELECT public.current_user_club_ids());
  IF NOT v_is_mgmt THEN
    RAISE EXCEPTION 'not authorized — club management only';
  END IF;

  FOR v_player IN
    SELECT DISTINCT p.id FROM public.players p
     JOIN public.team_members tm ON tm.player_id = p.id
     JOIN public.teams t ON t.id = tm.team_id
     WHERE t.club_id = p_club_id AND tm.is_active AND p.is_active
       AND public.player_consent_needs_renewal(p.id)
  LOOP
    PERFORM public.set_parent_consent(v_player.id, false, NULL, NULL, NULL, NULL,
      p_idem_key || '-player-' || v_player.id);
    v_reset_ids := array_append(v_reset_ids, v_player.id);
  END LOOP;

  v_result := jsonb_build_object('club_id', p_club_id, 'reset_player_ids', v_reset_ids,
                                  'reset_count', coalesce(array_length(v_reset_ids, 1), 0));

  INSERT INTO public.idempotency_keys (auth_user_id, key, operation, result)
  VALUES (v_auth_uid, p_idem_key, 'expire_stale_consents', v_result);

  RETURN v_result;
END; $function$;

CREATE OR REPLACE FUNCTION public.fn_audit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_old     jsonb;
  v_new     jsonb;
  v_row_id  uuid;
  v_changed text[];
begin
  if tg_op = 'UPDATE' then
    v_old := to_jsonb(old);
    v_new := to_jsonb(new);
    v_row_id := new.id;
    v_changed := array(
      select key
        from jsonb_each(v_old) o
        full join jsonb_each(v_new) n using (key)
       where o.value is distinct from n.value
         and key not in ('updated_at', 'updated_by')
    );
    if cardinality(v_changed) = 0 then
      return new;                         -- only updated_at moved: nothing to record
    end if;

  elsif tg_op = 'DELETE' then
    v_old := to_jsonb(old);
    v_row_id := old.id;

  elsif tg_op = 'INSERT' then
    v_new := to_jsonb(new);
    v_row_id := new.id;
  end if;

  insert into public.audit_log (
    table_name, row_id, action, old_row, new_row, changed_columns, changed_by, changed_by_auth
  ) values (
    tg_table_name, v_row_id, tg_op, v_old, v_new, v_changed,
    coalesce(public.current_person_id(),
             nullif(current_setting('app.actor_id', true), '')::uuid),
    auth.uid()
  );

  return coalesce(new, old);
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_player_id_number(p_player_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_is_primary boolean;
  v_is_staff   boolean;
  v_encrypted  bytea;
BEGIN
  v_is_primary := p_player_id IN (SELECT public.current_user_primary_player_ids());
  v_is_staff := EXISTS (
    SELECT 1 FROM public.team_members tm
     WHERE tm.player_id = p_player_id AND tm.is_active
       AND tm.team_id IN (SELECT public.current_user_managed_team_ids())
  );
  IF NOT v_is_primary AND NOT v_is_staff THEN
    RAISE EXCEPTION 'not authorized — requires the primary guardian or club staff';
  END IF;

  SELECT id_number_encrypted INTO v_encrypted FROM public.players WHERE id = p_player_id;
  IF v_encrypted IS NULL THEN
    RETURN NULL;
  END IF;

  RETURN extensions.pgp_sym_decrypt(v_encrypted, public._id_number_key());
END; $function$;

CREATE OR REPLACE FUNCTION public.initiate_channel_recovery(p_user_id uuid, p_club_id uuid, p_new_email text, p_new_cellphone text, p_idem_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_auth_uid uuid := auth.uid();
  v_cached   jsonb;
  v_is_mgmt  boolean;
  v_role_id  int;
  v_token    text;
  v_inv      uuid;
  v_result   jsonb;
BEGIN
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'must be authenticated';
  END IF;

  SELECT result INTO v_cached FROM public.idempotency_keys
   WHERE auth_user_id = v_auth_uid AND key = p_idem_key;
  IF FOUND THEN
    RETURN v_cached;
  END IF;

  v_is_mgmt := p_club_id IN (SELECT public.current_user_club_ids());
  IF NOT v_is_mgmt THEN
    RAISE EXCEPTION 'not authorized — club management only';
  END IF;

  IF p_new_email IS NULL AND p_new_cellphone IS NULL THEN
    RAISE EXCEPTION 'at least one of new_email/new_cellphone is required';
  END IF;

  SELECT ur.role_id INTO v_role_id FROM public.user_roles ur
   WHERE ur.user_id = p_user_id AND ur.club_id = p_club_id AND ur.is_active
   LIMIT 1;
  IF v_role_id IS NULL THEN
    IF EXISTS (
      SELECT 1 FROM public.guardians g JOIN public.team_members tm ON tm.player_id = g.player_id
       JOIN public.teams t ON t.id = tm.team_id
       WHERE g.user_id = p_user_id AND g.is_active AND tm.is_active AND t.club_id = p_club_id
    ) THEN
      v_role_id := 4;
    ELSE
      RAISE EXCEPTION 'target person has no active relationship to this club';
    END IF;
  END IF;

  v_token := encode(extensions.gen_random_bytes(32), 'hex');

  INSERT INTO public.invitations (club_id, role_id, inviter_id, target_user_id, email, cellphone, token_hash)
  VALUES (p_club_id, v_role_id, public.current_person_id(), p_user_id, p_new_email, p_new_cellphone,
          encode(extensions.digest(v_token, 'sha256'), 'hex'))
  RETURNING id INTO v_inv;

  v_result := jsonb_build_object('invitation_id', v_inv, 'token', v_token);

  INSERT INTO public.idempotency_keys (auth_user_id, key, operation, result)
  VALUES (v_auth_uid, p_idem_key, 'initiate_channel_recovery', v_result);

  RETURN v_result;
END; $function$;

CREATE OR REPLACE FUNCTION public.invitation_ttl()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  IF new.role_id IN (3, 4) OR new.target_user_id IS NOT NULL THEN
    new.expires_at := least(new.expires_at, now() + interval '48 hours');
  END IF;
  RETURN new;
END; $function$;

CREATE OR REPLACE FUNCTION public.invite_guardian(p_player_id uuid, p_cellphone text, p_target_name text, p_idem_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_auth_uid uuid := auth.uid();
  v_cached   jsonb;
  v_club     uuid;
  v_token    text;
  v_inv      uuid;
  v_result   jsonb;
BEGIN
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'must be authenticated';
  END IF;
  IF NOT public.current_user_is_staff() THEN
    RAISE EXCEPTION 'staff only';
  END IF;

  SELECT result INTO v_cached FROM public.idempotency_keys
   WHERE auth_user_id = v_auth_uid AND key = p_idem_key;
  IF FOUND THEN
    RETURN v_cached;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.players WHERE id = p_player_id) THEN
    RAISE EXCEPTION 'player not found';
  END IF;

  SELECT t.club_id INTO v_club
    FROM public.team_members tm JOIN public.teams t ON t.id = tm.team_id
   WHERE tm.player_id = p_player_id AND tm.is_active
   LIMIT 1;
  IF v_club IS NULL THEN
    RAISE EXCEPTION 'player has no active team — assign to a team before inviting a guardian';
  END IF;

  v_token := encode(extensions.gen_random_bytes(32), 'hex');

  INSERT INTO public.invitations (club_id, role_id, inviter_id, player_id, cellphone, target_name, token_hash)
  VALUES (v_club, 4, public.current_person_id(), p_player_id, p_cellphone, p_target_name,
          encode(extensions.digest(v_token, 'sha256'), 'hex'))
  RETURNING id INTO v_inv;

  v_result := jsonb_build_object('invitation_id', v_inv, 'token', v_token);

  INSERT INTO public.idempotency_keys (auth_user_id, key, operation, result)
  VALUES (v_auth_uid, p_idem_key, 'invite_guardian', v_result);

  RETURN v_result;
END; $function$;

CREATE OR REPLACE FUNCTION public.invite_player_device(p_player_id uuid, p_cellphone text, p_idem_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_auth_uid       uuid := auth.uid();
  v_cached         jsonb;
  v_club           uuid;
  v_is_primary     boolean;
  v_is_staff_of_pl boolean;
  v_has_primary    boolean;
  v_is_management  boolean;
  v_token          text;
  v_inv            uuid;
  v_result         jsonb;
BEGIN
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'must be authenticated';
  END IF;

  SELECT result INTO v_cached FROM public.idempotency_keys
   WHERE auth_user_id = v_auth_uid AND key = p_idem_key;
  IF FOUND THEN
    RETURN v_cached;
  END IF;

  v_is_primary := p_player_id IN (SELECT public.current_user_primary_player_ids());

  v_is_staff_of_pl := EXISTS (
    SELECT 1 FROM public.team_members tm
     WHERE tm.player_id = p_player_id AND tm.is_active
       AND tm.team_id IN (SELECT public.current_user_managed_team_ids())
  );

  IF NOT v_is_primary AND NOT v_is_staff_of_pl THEN
    RAISE EXCEPTION 'not authorized for this player';
  END IF;

  v_has_primary := EXISTS (
    SELECT 1 FROM public.guardians WHERE player_id = p_player_id AND is_active AND is_primary
  );

  IF NOT v_is_primary AND NOT v_has_primary THEN
    v_is_management := EXISTS (
      SELECT 1 FROM public.team_members tm JOIN public.teams t ON t.id = tm.team_id
       WHERE tm.player_id = p_player_id AND tm.is_active
         AND t.club_id IN (SELECT public.current_user_club_ids())
    );
    IF NOT v_is_management THEN
      RAISE EXCEPTION 'no active guardian for this player — only club management may issue this invitation';
    END IF;
  END IF;

  SELECT t.club_id INTO v_club
    FROM public.team_members tm JOIN public.teams t ON t.id = tm.team_id
   WHERE tm.player_id = p_player_id AND tm.is_active
   LIMIT 1;
  IF v_club IS NULL THEN
    RAISE EXCEPTION 'player has no active team — club cannot be derived for this invitation';
  END IF;

  v_token := encode(extensions.gen_random_bytes(32), 'hex');

  INSERT INTO public.invitations (club_id, role_id, inviter_id, player_id, cellphone, token_hash)
  VALUES (v_club, 3, public.current_person_id(), p_player_id, p_cellphone,
          encode(extensions.digest(v_token, 'sha256'), 'hex'))
  RETURNING id INTO v_inv;

  v_result := jsonb_build_object('invitation_id', v_inv, 'token', v_token);

  INSERT INTO public.idempotency_keys (auth_user_id, key, operation, result)
  VALUES (v_auth_uid, p_idem_key, 'invite_player_device', v_result);

  RETURN v_result;
END; $function$;

CREATE OR REPLACE FUNCTION public.link_identity(p_provider text, p_provider_subject text, p_idem_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_auth_uid uuid := auth.uid();
  v_cached   jsonb;
  v_person   uuid;
  v_existing_user_id uuid;
  v_existing_name    text;
  v_identity_id uuid;
  v_result   jsonb;
BEGIN
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'must be authenticated';
  END IF;

  SELECT result INTO v_cached FROM public.idempotency_keys
   WHERE auth_user_id = v_auth_uid AND key = p_idem_key;
  IF FOUND THEN
    RETURN v_cached;
  END IF;

  v_person := public.current_person_id();
  IF v_person IS NULL THEN
    RAISE EXCEPTION 'no existing person for this session — link_identity() is for an already-recognized person (§2.6)';
  END IF;

  SELECT id, user_id INTO v_identity_id, v_existing_user_id
    FROM public.user_identities WHERE provider = p_provider AND provider_subject = p_provider_subject;

  IF v_existing_user_id IS NOT NULL AND v_existing_user_id <> v_person THEN
    SELECT trim(coalesce(first_name,'') || ' ' || coalesce(last_name,'')) INTO v_existing_name
      FROM public.users WHERE id = v_existing_user_id;
    RAISE EXCEPTION 'this % account is already linked to % — to sign in as a separate person, use a phone number',
      p_provider, coalesce(nullif(v_existing_name, ''), 'another person');
  END IF;

  IF v_identity_id IS NULL THEN
    INSERT INTO public.user_identities (user_id, provider, provider_subject, verified_at)
    VALUES (v_person, p_provider, p_provider_subject, now())
    RETURNING id INTO v_identity_id;

    IF p_provider = 'email' THEN
      UPDATE public.users SET email_verified_at = now() WHERE id = v_person;
    ELSIF p_provider = 'phone' THEN
      UPDATE public.users SET phone_verified_at = now() WHERE id = v_person;
    END IF;
  END IF;

  v_result := jsonb_build_object('identity_id', v_identity_id, 'person_id', v_person, 'provider', p_provider);

  INSERT INTO public.idempotency_keys (auth_user_id, key, operation, result)
  VALUES (v_auth_uid, p_idem_key, 'link_identity', v_result);

  RETURN v_result;
END; $function$;

CREATE OR REPLACE FUNCTION public.lock_completed_reviews()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is null then
    return new;                          -- service_role / system may still correct
  end if;
  if old.status = 'completed'
     and (to_jsonb(new) - 'updated_at' - 'is_active')
         is distinct from
         (to_jsonb(old) - 'updated_at' - 'is_active')
  then
    raise exception 'performance_review % is completed and can no longer be edited', old.id;
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.merge_players(p_keep_id uuid, p_drop_id uuid, p_idem_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_auth_uid        uuid := auth.uid();
  v_cached          jsonb;
  v_keep            record;
  v_drop            record;
  v_is_guardian     boolean;
  v_is_staff        boolean;
  v_lock_first      uuid;
  v_lock_second     uuid;
  v_row             record;
  v_existing        record;
  v_keep_has_primary boolean;
  v_moved           int := 0;
  v_deactivated     int := 0;
  v_result          jsonb;
BEGIN
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'must be authenticated';
  END IF;

  SELECT result INTO v_cached FROM public.idempotency_keys
   WHERE auth_user_id = v_auth_uid AND key = p_idem_key;
  IF FOUND THEN
    RETURN v_cached;
  END IF;

  IF p_keep_id = p_drop_id THEN
    RAISE EXCEPTION 'keep_id and drop_id must differ';
  END IF;

  IF p_keep_id::text < p_drop_id::text THEN
    v_lock_first := p_keep_id; v_lock_second := p_drop_id;
  ELSE
    v_lock_first := p_drop_id; v_lock_second := p_keep_id;
  END IF;
  PERFORM 1 FROM public.players WHERE id = v_lock_first  FOR UPDATE;
  PERFORM 1 FROM public.players WHERE id = v_lock_second FOR UPDATE;

  SELECT * INTO v_keep FROM public.players WHERE id = p_keep_id;
  SELECT * INTO v_drop FROM public.players WHERE id = p_drop_id;
  IF v_keep.id IS NULL THEN RAISE EXCEPTION 'keep_id not found'; END IF;
  IF v_drop.id IS NULL THEN RAISE EXCEPTION 'drop_id not found'; END IF;
  IF NOT v_drop.is_active THEN
    RAISE EXCEPTION 'drop_id is not an active player record (already merged or ended)';
  END IF;

  v_is_guardian := EXISTS (
    SELECT 1 FROM public.guardians
     WHERE player_id = p_keep_id AND user_id = public.current_person_id() AND is_active
  );
  v_is_staff := EXISTS (
    SELECT 1 FROM public.team_members tm
     WHERE tm.player_id IN (p_keep_id, p_drop_id) AND tm.is_active
       AND tm.team_id IN (SELECT public.current_user_managed_team_ids())
  );
  IF NOT v_is_guardian AND NOT v_is_staff THEN
    RAISE EXCEPTION 'not authorized — requires an existing guardian of the kept record or club staff';
  END IF;

  IF EXISTS (SELECT 1 FROM public.team_members WHERE player_id = p_drop_id AND is_active) THEN
    RAISE EXCEPTION 'drop_id still has an active roster membership — merge_players() only re-points guardians (§5.4); resolve team_members manually first';
  END IF;

  FOR v_row IN SELECT * FROM public.guardians WHERE player_id = p_drop_id LOOP
    SELECT * INTO v_existing FROM public.guardians
     WHERE player_id = p_keep_id AND user_id = v_row.user_id;

    IF v_existing.id IS NOT NULL THEN
      UPDATE public.guardians
         SET is_active = false, is_primary = false, ended_at = now(), ended_reason = 'merged'
       WHERE id = v_row.id;
      v_deactivated := v_deactivated + 1;

      IF v_row.is_primary AND NOT v_existing.is_primary THEN
        UPDATE public.guardians SET is_primary = true WHERE id = v_existing.id;
      END IF;
    ELSE
      v_keep_has_primary := EXISTS (SELECT 1 FROM public.guardians WHERE player_id = p_keep_id AND is_primary);
      UPDATE public.guardians
         SET player_id = p_keep_id,
             is_primary = (v_row.is_primary AND NOT v_keep_has_primary)
       WHERE id = v_row.id;
      v_moved := v_moved + 1;
    END IF;
  END LOOP;

  UPDATE public.players
     SET is_active = false, merged_into_player_id = p_keep_id, merged_at = now()
   WHERE id = p_drop_id;

  v_result := jsonb_build_object(
    'keep_id', p_keep_id, 'drop_id', p_drop_id,
    'guardians_moved', v_moved, 'guardians_deactivated', v_deactivated
  );

  INSERT INTO public.idempotency_keys (auth_user_id, key, operation, result)
  VALUES (v_auth_uid, p_idem_key, 'merge_players', v_result);

  RETURN v_result;
END; $function$;

CREATE OR REPLACE FUNCTION public.mfa_required_for_club_management()
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT false  -- TEMPORARILY OFF. §9.3 requires true for role_id = 1.
                -- Flip to true once passkey enrollment exists for role 1 and
                -- every active role_id = 1 account has a verified factor —
                -- check with:
                --   SELECT u.email,
                --          (SELECT count(*) FROM auth.mfa_factors f
                --            WHERE f.user_id = u.id AND f.status = 'verified')
                --     FROM auth.users u
                --     JOIN public.users pu ON pu.auth_user_id = u.id
                --     JOIN public.user_roles ur ON ur.user_id = pu.id
                --    WHERE ur.role_id = 1 AND ur.is_active;
                -- Flipping it with a manager still unenrolled locks that
                -- manager out of all 30 tables again.
$function$;

CREATE OR REPLACE FUNCTION public.normalize_cellphone()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE d text;
BEGIN
  IF new.cellphone IS NULL THEN RETURN new; END IF;
  d := regexp_replace(new.cellphone, '[^0-9+]', '', 'g');
  IF    d ~ '^0[59][0-9]{8}$'  THEN d := '+972' || substring(d from 2);
  ELSIF d ~ '^972[0-9]{9}$'    THEN d := '+' || d;
  ELSIF d ~ '^\+972[0-9]{9}$'  THEN NULL;
  ELSIF d ~ '^\+[0-9]{8,15}$'  THEN NULL;
  ELSE  RAISE EXCEPTION 'Invalid phone format: %', new.cellphone;
  END IF;
  new.cellphone := d;
  RETURN new;
END; $function$;

CREATE OR REPLACE FUNCTION public.player_consent_needs_renewal(p_player_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_consent   record;
  v_birth     date;
  v_threshold int := public.digital_age_consent_threshold();
  v_age_then  int;
  v_age_now   int;
BEGIN
  SELECT c.policy_version, c.consent_type, c.granted_at INTO v_consent
    FROM public.consents c
   WHERE c.player_id = p_player_id AND c.revoked_at IS NULL
   ORDER BY c.granted_at DESC LIMIT 1;

  IF v_consent IS NULL THEN
    RETURN false;
  END IF;

  IF v_consent.policy_version <> (
    SELECT current_version FROM public.policy_versions WHERE consent_type = v_consent.consent_type
  ) THEN
    RETURN true;
  END IF;

  SELECT birth_date INTO v_birth FROM public.players WHERE id = p_player_id;
  IF v_birth IS NOT NULL THEN
    v_age_then := date_part('year', age(v_consent.granted_at::date, v_birth))::int;
    v_age_now  := date_part('year', age(current_date, v_birth))::int;
    IF v_age_then < v_threshold AND v_age_now >= v_threshold THEN
      RETURN true;
    END IF;
  END IF;

  RETURN false;
END; $function$;

CREATE OR REPLACE FUNCTION public.player_fully_verified(p_player_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  SELECT p.parent_confirmed_at IS NOT NULL
     AND p.coach_confirmed_at  IS NOT NULL
     AND p.parent_confirmed_by IS DISTINCT FROM p.coach_confirmed_by
  FROM public.players p WHERE p.id = p_player_id
$function$;

CREATE OR REPLACE FUNCTION public.player_gate_status(p_player_id uuid)
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  SELECT CASE
    WHEN p.parent_confirmed_at IS NULL THEN 'waiting_parent_approval'
    WHEN p.coach_confirmed_at  IS NULL THEN 'waiting_staff_approval'
    WHEN p.parent_confirmed_by = p.coach_confirmed_by THEN 'waiting_external_staff_approval'
    ELSE 'open'
  END
  FROM public.players p WHERE p.id = p_player_id
$function$;

CREATE OR REPLACE FUNCTION public.protect_pii_updates()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_on_roster boolean;
  v_may_edit  boolean;
BEGIN
  v_on_roster := exists (select 1 from public.team_members tm
                          where tm.player_id = new.id and tm.is_active);

  if v_on_roster then
    v_may_edit := exists (select 1 from public.team_members tm
                           where tm.player_id = new.id and tm.is_active
                             and tm.team_id in (select public.current_user_managed_team_ids()));
  else
    v_may_edit := new.id in (select public.current_user_primary_player_ids());
  end if;

  if (new.id_number_hash, new.first_name, new.last_name, new.birth_date, new.gender)
       is distinct from
     (old.id_number_hash, old.first_name, old.last_name, old.birth_date, old.gender)
     and not v_may_edit
  then
    raise exception 'not authorized to change player identity fields';
  end if;

  return new;
END; $function$;

CREATE OR REPLACE FUNCTION public.set_actor_columns()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_authed boolean := auth.uid() is not null;
  v_actor  uuid    := case when auth.uid() is not null then public.current_person_id() end;
begin
  if tg_op = 'INSERT' then
    if v_authed then
      new.created_by := v_actor;
      new.updated_by := v_actor;
    else
      new.updated_by := coalesce(new.updated_by, new.created_by);
    end if;
  else
    if v_authed then
      new.created_by := old.created_by;
      new.updated_by := v_actor;
    elsif new.updated_by is not distinct from old.updated_by then
      new.updated_by := null;
    end if;
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.set_actor_updated_by()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is not null then
    new.updated_by := public.current_person_id();
  elsif tg_op = 'UPDATE' and new.updated_by is not distinct from old.updated_by then
    new.updated_by := null;
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.set_club_role_active(p_user_role_id uuid, p_active boolean, p_idem_key text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_club   uuid;
  v_role   int;
  v_cached jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'must be authenticated';
  END IF;

  SELECT result INTO v_cached FROM public.idempotency_keys
   WHERE auth_user_id = auth.uid() AND key = p_idem_key;
  IF FOUND THEN
    RETURN;
  END IF;

  SELECT club_id, role_id INTO v_club, v_role FROM public.user_roles WHERE id = p_user_role_id;
  IF v_club IS NULL THEN
    RAISE EXCEPTION 'role not found or clubless';
  END IF;

  PERFORM 1 FROM public.clubs WHERE id = v_club FOR UPDATE;

  IF v_role = 1 THEN
    RAISE EXCEPTION 'management roles are activated by the system administrator only';
  END IF;

  IF v_club NOT IN (SELECT public.current_user_club_ids()) THEN
    RAISE EXCEPTION 'not authorized for this club';
  END IF;

  IF NOT p_active AND v_role <> 1 THEN
    NULL;
  END IF;

  UPDATE public.user_roles
     SET is_active    = p_active,
         ended_at     = CASE WHEN p_active THEN NULL ELSE ended_at END,
         ended_reason = CASE WHEN p_active THEN NULL ELSE ended_reason END
   WHERE id = p_user_role_id;

  INSERT INTO public.idempotency_keys (auth_user_id, key, operation, result)
  VALUES (auth.uid(), p_idem_key, 'set_club_role_active', jsonb_build_object('user_role_id', p_user_role_id));
END; $function$;

CREATE OR REPLACE FUNCTION public.set_parent_consent(p_player_id uuid, p_granted boolean, p_consent_type text, p_policy_version text, p_method text, p_evidence jsonb, p_idem_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_auth_uid   uuid := auth.uid();
  v_cached     jsonb;
  v_is_primary boolean;
  v_is_staff   boolean;
  v_consent_id uuid;
  v_result     jsonb;
BEGIN
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'must be authenticated';
  END IF;

  SELECT result INTO v_cached FROM public.idempotency_keys
   WHERE auth_user_id = v_auth_uid AND key = p_idem_key;
  IF FOUND THEN
    RETURN v_cached;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.players WHERE id = p_player_id) THEN
    RAISE EXCEPTION 'player not found';
  END IF;

  IF p_granted AND p_consent_type IS NULL THEN
    RAISE EXCEPTION 'consent_type is required when granting';
  END IF;

  v_is_primary := p_player_id IN (SELECT public.current_user_primary_player_ids());
  v_is_staff := EXISTS (
    SELECT 1 FROM public.team_members tm
     WHERE tm.player_id = p_player_id AND tm.is_active
       AND tm.team_id IN (SELECT public.current_user_managed_team_ids())
  );
  IF NOT v_is_primary AND NOT v_is_staff THEN
    RAISE EXCEPTION 'not authorized — requires the primary guardian or club staff';
  END IF;

  IF p_granted THEN
    INSERT INTO public.consents (player_id, granted_by, consent_type, policy_version, method, evidence)
    VALUES (p_player_id, public.current_person_id(), p_consent_type, p_policy_version, p_method, p_evidence)
    RETURNING id INTO v_consent_id;

    UPDATE public.players
       SET parent_confirmed_at = now(), parent_confirmed_by = public.current_person_id()
     WHERE id = p_player_id;
  ELSE
    IF p_consent_type IS NOT NULL THEN
      UPDATE public.consents SET revoked_at = now()
       WHERE player_id = p_player_id AND consent_type = p_consent_type AND revoked_at IS NULL
      RETURNING id INTO v_consent_id;
    END IF;

    UPDATE public.players
       SET parent_confirmed_at = NULL, parent_confirmed_by = NULL
     WHERE id = p_player_id;
  END IF;

  v_result := jsonb_build_object(
    'player_id', p_player_id, 'granted', p_granted,
    'consent_id', v_consent_id, 'consent_type', p_consent_type
  );

  INSERT INTO public.idempotency_keys (auth_user_id, key, operation, result)
  VALUES (v_auth_uid, p_idem_key, 'set_parent_consent', v_result);

  RETURN v_result;
END; $function$;

CREATE OR REPLACE FUNCTION public.set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  new.updated_at := now();
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.tjr_derive_club()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  SELECT club_id INTO new.club_id FROM public.teams WHERE id = new.team_id;
  IF new.club_id IS NULL THEN RAISE EXCEPTION 'team % not found', new.team_id; END IF;
  RETURN new;
END; $function$;

CREATE OR REPLACE FUNCTION public.validate_measurement_date()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if new.measured_on > current_date then
    raise exception 'measured_on (%) is in the future', new.measured_on;
  end if;
  return new;
end;
$function$;

set check_function_bodies = on;


-- ============================ TRIGGERS ============================
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.age_group FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.announcements FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_set_actor BEFORE INSERT OR UPDATE ON public.announcements FOR EACH ROW EXECUTE FUNCTION set_actor_updated_by();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.attendance FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_audit AFTER DELETE OR UPDATE ON public.attendance FOR EACH ROW EXECUTE FUNCTION fn_audit();
CREATE TRIGGER trg_set_actor BEFORE INSERT OR UPDATE ON public.club_blackout_dates FOR EACH ROW EXECUTE FUNCTION set_actor_columns();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.clubs FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.clubs FOR EACH ROW EXECUTE FUNCTION fn_audit();
CREATE TRIGGER trg_set_actor BEFORE INSERT OR UPDATE ON public.clubs FOR EACH ROW EXECUTE FUNCTION set_actor_columns();
CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.consents FOR EACH ROW EXECUTE FUNCTION fn_audit();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.depth_charts FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_set_actor BEFORE INSERT OR UPDATE ON public.depth_charts FOR EACH ROW EXECUTE FUNCTION set_actor_columns();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.event_responses FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_audit AFTER DELETE OR UPDATE ON public.event_responses FOR EACH ROW EXECUTE FUNCTION fn_audit();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.events FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_set_actor BEFORE INSERT OR UPDATE ON public.events FOR EACH ROW EXECUTE FUNCTION set_actor_columns();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.facilities FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_set_actor BEFORE INSERT OR UPDATE ON public.facilities FOR EACH ROW EXECUTE FUNCTION set_actor_columns();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.feedback_type FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.game_events_log FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_set_actor BEFORE INSERT OR UPDATE ON public.game_events_log FOR EACH ROW EXECUTE FUNCTION set_actor_columns();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.games_live_session FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_set_actor BEFORE INSERT OR UPDATE ON public.games_live_session FOR EACH ROW EXECUTE FUNCTION set_actor_columns();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.guardians FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.guardians FOR EACH ROW EXECUTE FUNCTION fn_audit();
CREATE TRIGGER trg_ended_implies_inactive BEFORE INSERT OR UPDATE ON public.guardians FOR EACH ROW EXECUTE FUNCTION ended_implies_inactive();
CREATE TRIGGER trg_set_actor BEFORE INSERT OR UPDATE ON public.guardians FOR EACH ROW EXECUTE FUNCTION set_actor_columns();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.invitations FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.invitations FOR EACH ROW EXECUTE FUNCTION fn_audit();
CREATE TRIGGER trg_invitation_ttl BEFORE INSERT OR UPDATE OF expires_at, role_id ON public.invitations FOR EACH ROW EXECUTE FUNCTION invitation_ttl();
CREATE TRIGGER trg_normalize_cellphone BEFORE INSERT OR UPDATE OF cellphone ON public.invitations FOR EACH ROW EXECUTE FUNCTION normalize_cellphone();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.knowledge_base FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_set_actor BEFORE INSERT OR UPDATE ON public.knowledge_base FOR EACH ROW EXECUTE FUNCTION set_actor_columns();
CREATE TRIGGER lock_completed_reviews BEFORE UPDATE ON public.performance_reviews FOR EACH ROW EXECUTE FUNCTION lock_completed_reviews();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.performance_reviews FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_audit AFTER DELETE OR UPDATE ON public.performance_reviews FOR EACH ROW EXECUTE FUNCTION fn_audit();
CREATE TRIGGER trg_set_actor BEFORE INSERT OR UPDATE ON public.performance_reviews FOR EACH ROW EXECUTE FUNCTION set_actor_columns();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.play_views FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.playbooks FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_set_actor BEFORE INSERT OR UPDATE ON public.playbooks FOR EACH ROW EXECUTE FUNCTION set_actor_updated_by();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.player_feedback FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_audit AFTER DELETE OR UPDATE ON public.player_feedback FOR EACH ROW EXECUTE FUNCTION fn_audit();
CREATE TRIGGER close_previous_measurement BEFORE INSERT ON public.player_measurements FOR EACH ROW EXECUTE FUNCTION close_previous_measurement();
CREATE TRIGGER trg_audit AFTER DELETE OR UPDATE ON public.player_measurements FOR EACH ROW EXECUTE FUNCTION fn_audit();
CREATE TRIGGER validate_measurement_date BEFORE INSERT OR UPDATE ON public.player_measurements FOR EACH ROW EXECUTE FUNCTION validate_measurement_date();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.players FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.players FOR EACH ROW EXECUTE FUNCTION fn_audit();
CREATE TRIGGER trg_protect_pii_updates BEFORE UPDATE ON public.players FOR EACH ROW EXECUTE FUNCTION protect_pii_updates();
CREATE TRIGGER trg_set_actor BEFORE INSERT OR UPDATE ON public.players FOR EACH ROW EXECUTE FUNCTION set_actor_columns();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.plays FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_set_actor BEFORE INSERT OR UPDATE ON public.plays FOR EACH ROW EXECUTE FUNCTION set_actor_columns();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.policy_versions FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.review_periods FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.roles FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.seasons FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.team_coaches FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.team_coaches FOR EACH ROW EXECUTE FUNCTION fn_audit();
CREATE TRIGGER trg_set_actor BEFORE INSERT OR UPDATE ON public.team_coaches FOR EACH ROW EXECUTE FUNCTION set_actor_columns();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.team_join_requests FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER tjr_derive_club_trg BEFORE INSERT OR UPDATE ON public.team_join_requests FOR EACH ROW EXECUTE FUNCTION tjr_derive_club();
CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.team_join_requests FOR EACH ROW EXECUTE FUNCTION fn_audit();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.team_media FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.team_media_reactions FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.team_members FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.team_members FOR EACH ROW EXECUTE FUNCTION fn_audit();
CREATE TRIGGER trg_set_actor BEFORE INSERT OR UPDATE ON public.team_members FOR EACH ROW EXECUTE FUNCTION set_actor_columns();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.team_weekly_focus FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_set_actor BEFORE INSERT OR UPDATE ON public.team_weekly_focus FOR EACH ROW EXECUTE FUNCTION set_actor_columns();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.teams FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.teams FOR EACH ROW EXECUTE FUNCTION fn_audit();
CREATE TRIGGER trg_set_actor BEFORE INSERT OR UPDATE ON public.teams FOR EACH ROW EXECUTE FUNCTION set_actor_columns();
CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.user_identities FOR EACH ROW EXECUTE FUNCTION fn_audit();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.user_roles FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.user_roles FOR EACH ROW EXECUTE FUNCTION fn_audit();
CREATE TRIGGER trg_ended_implies_inactive BEFORE INSERT OR UPDATE OF ended_at ON public.user_roles FOR EACH ROW EXECUTE FUNCTION ended_implies_inactive();
CREATE TRIGGER trg_set_actor BEFORE INSERT OR UPDATE ON public.user_roles FOR EACH ROW EXECUTE FUNCTION set_actor_columns();
CREATE TRIGGER user_roles_club_scope_check BEFORE INSERT OR UPDATE ON public.user_roles FOR EACH ROW EXECUTE FUNCTION enforce_user_role_club_scope();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION fn_audit();
CREATE TRIGGER trg_normalize_cellphone BEFORE INSERT OR UPDATE OF cellphone ON public.users FOR EACH ROW EXECUTE FUNCTION normalize_cellphone();


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
alter table audit_log enable row level security;
alter table consents enable row level security;
alter table idempotency_keys enable row level security;
alter table policy_versions enable row level security;
alter table rate_counters enable row level security;
alter table team_join_requests enable row level security;
alter table user_identities enable row level security;

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
create policy "read visible teams" on teams for select to public
  using (((id IN ( SELECT current_user_team_ids() AS current_user_team_ids)) OR (club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids))));
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
create policy "delete club_blackout_dates" on club_blackout_dates for delete to authenticated
  using ((club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids)));
create policy "manage club_blackout_dates" on club_blackout_dates for insert to authenticated
  with check ((club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids)));
create policy "read club_blackout_dates" on club_blackout_dates for select to authenticated
  using ((club_id IN ( SELECT current_user_visible_club_ids() AS current_user_visible_club_ids)));
create policy "update club_blackout_dates" on club_blackout_dates for update to authenticated
  using ((club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids)))
  with check ((club_id IN ( SELECT current_user_club_ids() AS current_user_club_ids)));

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

-- audit_log
create policy "audit_log_select_staff" on audit_log for select to authenticated
  using (current_user_is_staff());

-- consents
create policy "guardians read own player consents" on consents for select to public
  using ((player_id IN ( SELECT current_user_own_player_ids() AS current_user_own_player_ids)));
create policy "staff read managed player consents" on consents for select to public
  using ((player_id IN ( SELECT tm.player_id
   FROM team_members tm
  WHERE (tm.is_active AND (tm.team_id IN ( SELECT current_user_managed_team_ids() AS current_user_managed_team_ids))))));

-- policy_versions
create policy "authenticated read policy versions" on policy_versions for select to public
  using ((( SELECT auth.uid() AS uid) IS NOT NULL));

-- team_join_requests
create policy "guardian requests own player" on team_join_requests for insert to public
  with check (((requested_by = current_person_id()) AND (player_id IN ( SELECT current_user_own_player_ids() AS current_user_own_player_ids))));
create policy "read own or managed requests" on team_join_requests for select to public
  using (((requested_by = current_person_id()) OR (team_id IN ( SELECT current_user_managed_team_ids() AS current_user_managed_team_ids))));
create policy "staff review requests" on team_join_requests for update to public
  using ((team_id IN ( SELECT current_user_managed_team_ids() AS current_user_managed_team_ids)));

-- user_identities
create policy "read own identities" on user_identities for select to public
  using ((user_id = current_person_id()));


-- ==================== GRANTS ====================
-- Supabase grants ALL privileges on new public objects to anon and
-- authenticated. Each statement below narrows that to what the live database
-- actually has (an object that is not listed keeps the full default).
revoke references, trigger, truncate on age_group from anon, authenticated;
revoke references, trigger, truncate on announcements from anon, authenticated;
revoke references, trigger, truncate on attendance from anon, authenticated;
revoke all on audit_log from anon;
revoke delete, insert, references, trigger, truncate, update on audit_log from authenticated;
revoke references, trigger, truncate on club_blackout_dates from anon, authenticated;
revoke references, trigger, truncate on clubs from anon, authenticated;
revoke references, trigger, truncate on consents from anon, authenticated;
revoke references, trigger, truncate on depth_charts from anon, authenticated;
revoke references, trigger, truncate on event_responses from anon, authenticated;
revoke references, trigger, truncate on events from anon, authenticated;
revoke references, trigger, truncate on facilities from anon, authenticated;
revoke references, trigger, truncate on feedback_type from anon, authenticated;
revoke references, trigger, truncate on game_events_log from anon, authenticated;
revoke references, trigger, truncate on games_live_session from anon, authenticated;
revoke references, trigger, truncate on guardians from anon, authenticated;
revoke all on idempotency_keys from anon, authenticated;
revoke references, trigger, truncate on invitations from anon, authenticated;
revoke references, trigger, truncate on knowledge_base from anon, authenticated;
revoke references, trigger, truncate on performance_reviews from anon, authenticated;
revoke references, trigger, truncate on permissions from anon, authenticated;
revoke references, trigger, truncate on play_views from anon, authenticated;
revoke references, trigger, truncate on playbooks from anon, authenticated;
revoke references, trigger, truncate on player_feedback from anon, authenticated;
revoke references, trigger, truncate on player_measurements from anon, authenticated;
revoke references, trigger, truncate on players from anon, authenticated;
revoke references, trigger, truncate on plays from anon, authenticated;
revoke references, trigger, truncate on policy_versions from anon, authenticated;
revoke all on rate_counters from anon, authenticated;
revoke references, trigger, truncate on review_periods from anon, authenticated;
revoke references, trigger, truncate on role_permissions from anon, authenticated;
revoke references, trigger, truncate on roles from anon, authenticated;
revoke delete, insert, references, trigger, truncate, update on safe_players from anon, authenticated;
revoke delete, insert, references, trigger, truncate, update on safe_users from anon, authenticated;
revoke references, trigger, truncate on seasons from anon, authenticated;
revoke references, trigger, truncate on team_coaches from anon, authenticated;
revoke references, trigger, truncate on team_join_requests from anon, authenticated;
revoke references, trigger, truncate on team_media from anon, authenticated;
revoke references, trigger, truncate on team_media_reactions from anon, authenticated;
revoke references, trigger, truncate on team_members from anon, authenticated;
revoke references, trigger, truncate on team_weekly_focus from anon, authenticated;
revoke references, trigger, truncate on teams from anon, authenticated;
revoke references, trigger, truncate on user_identities from anon, authenticated;
revoke references, trigger, truncate on user_roles from anon, authenticated;
revoke references, trigger, truncate on users from anon, authenticated;


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

insert into feedback_type (feedback_name, is_positive) values
  -- overall practice rating
  ('אימון נהדר',           true),
  ('אימון טוב',            true),
  ('דורש שיפור',           false),
  ('אימון חלש',            false),
  -- positive, specific
  ('מאמץ והתמדה',          true),
  ('הגנה חזקה',            true),
  ('משחק קבוצתי',          true),
  ('שיפור מורגש',          true),
  ('מנהיגות ואחריות',      true),
  ('יחס חיובי ואנרגיה',    true),
  ('קשב ומשמעת',           true),
  -- less positive, specific
  ('חוסר ריכוז',           false),
  ('מאמץ נמוך',            false),
  ('איחור או היעדרות',     false),
  ('נדרש שיפור בהגנה',     false),
  ('נדרש שיפור בטכניקה',   false),
  ('בעיית יחס או התנהגות', false);

-- permissions / role_permissions are created empty; the admin permission
-- matrix screen defines and grants them.
