-- CourtSide — Phase 1 (MVP) schema: core identities + scheduling.
-- Covers spec section 1 (Core Identities) plus the minimum needed to back
-- the Player/Coach/Parent Home screens (teams, events, RSVP, attendance).
-- RLS is enabled everywhere with permissive "authenticated" policies for now;
-- the real permissions matrix (spec section 8) is a follow-up migration.

-- ---------------------------------------------------------------------------
-- Adults: one row per auth.users, holds contact info shared across roles.
-- ---------------------------------------------------------------------------
create table profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null,
  email text,
  phone text,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Clubs & teams
-- ---------------------------------------------------------------------------
create table clubs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table teams (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references clubs (id) on delete cascade,
  name text not null,
  color text,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Player passport: ID-number-backed player identity (spec 1 — "דרכון השחקן").
-- profile_id is nullable: a player may have no login of their own yet
-- (Proxy Mode / Player-Only fallback, per spec 1 edge cases).
-- ---------------------------------------------------------------------------
create table players (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid references profiles (id) on delete set null,
  id_number text not null unique,
  full_name text not null,
  birth_date date,
  jersey_number int,
  court_position text,
  status text not null default 'active' check (status in ('active', 'injured')),
  height_cm numeric,
  wingspan_cm numeric,
  weight_kg numeric,
  vertical_jump_cm numeric,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Bridge table: dynamically links a profile OR a player to a team with a
-- role (spec 1 — "חיבור דינמי של תפקידים דרך טבלאות גישור").
-- ---------------------------------------------------------------------------
create table team_members (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references teams (id) on delete cascade,
  profile_id uuid references profiles (id) on delete cascade,
  player_id uuid references players (id) on delete cascade,
  role text not null check (role in ('coach', 'parent', 'player', 'manager')),
  joined_at timestamptz not null default now(),
  constraint team_members_one_subject check (
    (profile_id is not null and player_id is null) or
    (profile_id is null and player_id is not null)
  )
);

-- ---------------------------------------------------------------------------
-- Guardian links: which parent profile can act for which player, and
-- whether it's a view-only delegation (spec 4 — grandparent/sibling access).
-- ---------------------------------------------------------------------------
create table guardians (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references players (id) on delete cascade,
  profile_id uuid not null references profiles (id) on delete cascade,
  can_rsvp boolean not null default true,
  created_at timestamptz not null default now(),
  unique (player_id, profile_id)
);

-- ---------------------------------------------------------------------------
-- Schedule
-- ---------------------------------------------------------------------------
create table events (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references teams (id) on delete cascade,
  type text not null check (type in ('practice', 'game', 'meeting', 'other')),
  title text not null,
  starts_at timestamptz not null,
  ends_at timestamptz,
  location text,
  notes text,
  created_by uuid references profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create table rsvps (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references events (id) on delete cascade,
  player_id uuid not null references players (id) on delete cascade,
  status text not null default 'undecided' check (status in ('in', 'out', 'undecided')),
  decline_reason text,
  responded_by uuid references profiles (id) on delete set null,
  responded_at timestamptz,
  unique (event_id, player_id)
);

create table attendance (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references events (id) on delete cascade,
  player_id uuid not null references players (id) on delete cascade,
  status text not null check (status in ('present', 'late', 'absent')),
  marked_by uuid references profiles (id) on delete set null,
  marked_at timestamptz not null default now(),
  unique (event_id, player_id)
);

-- ---------------------------------------------------------------------------
-- Coach feedback (spec 3 — personal notes / short video to a player's file)
-- ---------------------------------------------------------------------------
create table player_feedback (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references players (id) on delete cascade,
  coach_id uuid not null references profiles (id) on delete cascade,
  note text,
  video_url text,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Row Level Security — permissive placeholder policies.
-- Every table is readable/writable by any authenticated user for now so the
-- app is usable end-to-end; tighten per-role once the spec 8 permissions
-- matrix is implemented.
-- ---------------------------------------------------------------------------
alter table profiles enable row level security;
alter table clubs enable row level security;
alter table teams enable row level security;
alter table players enable row level security;
alter table team_members enable row level security;
alter table guardians enable row level security;
alter table events enable row level security;
alter table rsvps enable row level security;
alter table attendance enable row level security;
alter table player_feedback enable row level security;

create policy "authenticated read/write — profiles" on profiles for all to authenticated using (true) with check (true);
create policy "authenticated read/write — clubs" on clubs for all to authenticated using (true) with check (true);
create policy "authenticated read/write — teams" on teams for all to authenticated using (true) with check (true);
create policy "authenticated read/write — players" on players for all to authenticated using (true) with check (true);
create policy "authenticated read/write — team_members" on team_members for all to authenticated using (true) with check (true);
create policy "authenticated read/write — guardians" on guardians for all to authenticated using (true) with check (true);
create policy "authenticated read/write — events" on events for all to authenticated using (true) with check (true);
create policy "authenticated read/write — rsvps" on rsvps for all to authenticated using (true) with check (true);
create policy "authenticated read/write — attendance" on attendance for all to authenticated using (true) with check (true);
create policy "authenticated read/write — player_feedback" on player_feedback for all to authenticated using (true) with check (true);
