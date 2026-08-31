-- CourtSide — team_coaches: coach ↔ team assignment (UserStory 22).
-- Mirrors team_members' shape/conventions (same column names/types,
-- same unique-per-stint pattern) but carries no player-only fields
-- (jersey_number, court_position, status) — those don't apply to a coach.

create table team_coaches (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references teams (id) on delete cascade,
  user_id uuid not null references users (id) on delete cascade,
  start_date date,
  end_date date,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  unique (team_id, user_id, start_date)
);

alter table team_coaches enable row level security;
create policy "authenticated read/write — team_coaches" on team_coaches for all to authenticated using (true) with check (true);
