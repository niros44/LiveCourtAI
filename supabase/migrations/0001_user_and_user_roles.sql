-- CourtSide — "user" + user_roles (UserStory 16, `users` renamed to `user`).
--
-- Note: `user` is a reserved word in Postgres (it's shorthand for
-- CURRENT_USER), so unlike `users`/`user_roles`, it must stay double-quoted
-- in every SQL statement here: `"user"`. This is a SQL-source-only concern —
-- it does NOT affect the Supabase client, `supabase.from('user')` works
-- exactly like any other table name.
--
-- user_roles keeps its plural name (not renamed) — say the word if you want
-- that singular too (user_role).

drop table if exists user_roles cascade;
drop table if exists "user" cascade;
drop table if exists users cascade;
drop table if exists user_role cascade;
drop table if exists "UserRole" cascade;
drop table if exists "User" cascade;

create table "user" (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  email text,
  cellphone text,
  gender text,
  age int,
  city text,
  address text,
  country text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references "user" (id) on delete cascade,
  role text not null check (role in ('admin', 'coach', 'player', 'parent')),
  created_at timestamptz not null default now(),
  unique (user_id, role)
);

alter table "user" enable row level security;
alter table user_roles enable row level security;

-- Placeholder policies: tighten to admin-only writes on user_roles once the
-- admin console (spec section 8) can manage role assignments.
create policy "authenticated read/write — user" on "user" for all to authenticated using (true) with check (true);
create policy "authenticated read/write — user_roles" on user_roles for all to authenticated using (true) with check (true);
