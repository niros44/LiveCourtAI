-- CourtSide — seasons + age_group reference tables (UserStory 22).

create table seasons (
  season_id uuid primary key default gen_random_uuid(),
  season_name text,
  start_date date,
  end_date date,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

create table age_group (
  agegroup_id uuid primary key default gen_random_uuid(),
  agegroup_name text,
  is_active boolean not null default true,
  comment text,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

-- Same placeholder RLS pattern as the other reference tables (clubs, teams):
-- readable/writable by any authenticated user for now.
alter table seasons enable row level security;
alter table age_group enable row level security;

create policy "authenticated read/write — seasons" on seasons for all to authenticated using (true) with check (true);
create policy "authenticated read/write — age_group" on age_group for all to authenticated using (true) with check (true);
