-- CourtSide — User + UserRole only. Adds these two tables standalone;
-- does not touch/drop anything else that may already exist in the project.
--
-- UserRole holds which role(s) a user has (a user can hold more than one,
-- e.g. a coach who's also a parent). The rank hierarchy itself is NOT
-- stored here — it lives in src/constants/roles.ts as the single source
-- of truth and is looked up in app code from the `role` value:
--   admin: 4, coach: 3, player: 2, parent: 1
--
-- Quoting note: Postgres lowercases unquoted identifiers, and `user` is a
-- reserved word — so "User" / "UserRole" must stay double-quoted in every
-- SQL statement, and referenced with matching case from the Supabase client
-- (e.g. `supabase.from('User')`, not `supabase.from('user')`).

create table "User" (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null,
  email text,
  phone text,
  created_at timestamptz not null default now()
);

create table "UserRole" (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references "User" (id) on delete cascade,
  role text not null check (role in ('admin', 'coach', 'player', 'parent')),
  created_at timestamptz not null default now(),
  unique (user_id, role)
);

alter table "User" enable row level security;
alter table "UserRole" enable row level security;

-- Placeholder policy: tighten to admin-only writes on UserRole once the
-- admin console (spec section 8) can manage role assignments.
create policy "authenticated read/write — User" on "User" for all to authenticated using (true) with check (true);
create policy "authenticated read/write — UserRole" on "UserRole" for all to authenticated using (true) with check (true);
