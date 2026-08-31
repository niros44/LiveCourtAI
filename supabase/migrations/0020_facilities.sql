-- CourtSide — facilities: club halls/courts (UserStory 22). Feeds the
-- admin Gantt board's conflict detection and gives parents/players a
-- direct Waze/Google Maps link to practice/game locations.

create table facilities (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references clubs (id) on delete cascade,
  name text not null,
  address text,
  latitude numeric,
  longitude numeric,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

alter table facilities enable row level security;
create policy "authenticated read/write — facilities" on facilities for all to authenticated using (true) with check (true);

-- Link events to a real facility (for conflict detection); `location`
-- stays as a free-text fallback for away games not in this table.
alter table events add column facility_id uuid references facilities (id) on delete set null;
