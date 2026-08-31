-- CourtSide — separate "person" from "account" (UserStory 22).
--
-- Replaces 0039's approach of duplicating names onto `players`. The root
-- problem was that `users` conflated two things: a person, and a login
-- account. A minor in Proxy Mode is a person with no account, so they
-- had nowhere to store a name.
--
-- After this:
--   users   = a PERSON. Everyone has one — coach, parent, and the
--             9-year-old with no phone. Holds the name.
--   auth_user_id = the login, nullable. Set only for people who can
--             actually sign in. This is what auth.uid() matches now.
--   players = the ATHLETIC dimension of a person. user_id is NOT NULL
--             (every player is a person); id_number is their permanent
--             real-world identifier.
--
-- Names now live in exactly one place. team_members.player_id (added in
-- 0039) stays — it's correct under this model too.

-- ---------------------------------------------------------------------
-- 1. Undo 0039's identity columns on players — users owns these now.
-- (users already has first_name/last_name/birth_date/gender/avatar_url
-- from 0003, so nothing needs adding there.)
-- ---------------------------------------------------------------------
alter table players drop column first_name;
alter table players drop column last_name;
alter table players drop column birth_date;
alter table players drop column gender;
alter table players drop column avatar_url;

-- ---------------------------------------------------------------------
-- 2. users.id stops being auth.users' id and becomes a standalone key;
-- auth_user_id carries the login link instead.
-- ---------------------------------------------------------------------
alter table users drop constraint if exists user_id_fkey;
alter table users drop constraint if exists users_id_fkey;
alter table users alter column id set default gen_random_uuid();

alter table users add column auth_user_id uuid unique references auth.users (id) on delete set null;

-- ---------------------------------------------------------------------
-- 3. Every player is a person.
-- ---------------------------------------------------------------------
alter table players alter column user_id set not null;

-- ---------------------------------------------------------------------
-- 4. RLS: auth.uid() no longer equals users.id, so every policy that
-- compared them has to be rewritten or it silently matches nothing.
-- This helper maps the caller's login to their person row.
-- ---------------------------------------------------------------------
create or replace function public.current_person_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from users where auth_user_id = auth.uid()
$$;

grant execute on function public.current_person_id() to authenticated;

-- Drop whichever policy set is live (the permissive originals, or the
-- tightened ones from the parked US_9 work) before recreating.
drop policy if exists "authenticated read/write — user" on users;
drop policy if exists "authenticated read/write — users" on users;
drop policy if exists "read own user row" on users;
drop policy if exists "insert own user row" on users;
drop policy if exists "update own user row" on users;

create policy "read own person row" on users for select to authenticated using (auth_user_id = auth.uid());
create policy "insert own person row" on users for insert to authenticated with check (auth_user_id = auth.uid());
create policy "update own person row" on users for update to authenticated using (auth_user_id = auth.uid()) with check (auth_user_id = auth.uid());

drop policy if exists "authenticated read/write — user_roles" on user_roles;
drop policy if exists "read own roles" on user_roles;

create policy "read own roles" on user_roles for select to authenticated using (user_id = public.current_person_id());
