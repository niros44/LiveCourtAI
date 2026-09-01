-- CourtSide — RLS group 1: reference data (UserStory 22).
--
-- First of the migrations that actually replace the placeholder
-- USING (true) policies. Reference data comes first because every other
-- policy leans on the club and team lookups defined here.

-- ---------------------------------------------------------------------
-- Two more helpers.
-- ---------------------------------------------------------------------

-- Clubs the caller can SEE, which is broader than the ones they manage:
-- any club they hold an active role in, plus the club behind any team
-- they can see.
--
-- The second half is not redundant. 0043 made Parent a club-less role,
-- so a parent has no club_id anywhere in user_roles — their access to
-- the club's name, logo and colours has to be derived through their
-- child's team, or the app cannot brand a single screen for them.
create or replace function public.current_user_visible_club_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select ur.club_id from user_roles ur
   where ur.user_id = public.current_person_id()
     and ur.is_active and ur.club_id is not null
  union
  select t.club_id from teams t
   where t.id in (select public.current_user_team_ids())
$$;

-- Staff = anyone currently coaching a team or managing a club.
create or replace function public.current_user_is_staff()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from team_coaches tc
     where tc.user_id = public.current_person_id() and tc.is_active
       and (tc.end_date is null or tc.end_date >= current_date)
  ) or exists (select 1 from public.current_user_club_ids())
$$;

grant execute on function public.current_user_visible_club_ids() to authenticated;
grant execute on function public.current_user_is_staff()         to authenticated;

-- ---------------------------------------------------------------------
-- System lookups: everyone signed in reads, nobody writes.
--
-- Replacing the ALL policy with a SELECT-only one leaves INSERT, UPDATE
-- and DELETE with no policy at all, which denies them. Seeding these
-- tables still works from the SQL Editor and with the service_role key,
-- both of which bypass RLS — which is the right home for editing a
-- lookup list anyway.
-- ---------------------------------------------------------------------
do $do$
declare t text;
begin
  foreach t in array array['roles','review_periods','feedback_type','seasons','age_group']
  loop
    execute format('drop policy if exists "authenticated read/write — %s" on %I', t, t);
    execute format('drop policy if exists "read %s" on %I', t, t);
    execute format('create policy "read %s" on %I for select to authenticated using (true)', t, t);
  end loop;
end $do$;

-- ---------------------------------------------------------------------
-- clubs
-- ---------------------------------------------------------------------
drop policy if exists "authenticated read/write — clubs" on clubs;
drop policy if exists "read visible clubs" on clubs;
drop policy if exists "managers update their club" on clubs;

create policy "read visible clubs" on clubs for select to authenticated
  using (id in (select public.current_user_visible_club_ids()));

-- No INSERT or DELETE policy on purpose: creating or removing a tenant
-- is a system-admin action performed with the service_role key, not
-- something any signed-in user should be able to do.
create policy "managers update their club" on clubs for update to authenticated
  using      (id in (select public.current_user_club_ids()))
  with check (id in (select public.current_user_club_ids()));

-- ---------------------------------------------------------------------
-- facilities
-- ---------------------------------------------------------------------
drop policy if exists "authenticated read/write — facilities" on facilities;
drop policy if exists "read visible facilities" on facilities;
drop policy if exists "staff write facilities" on facilities;
drop policy if exists "staff update facilities" on facilities;

-- club_id IS NULL is the away/shared venue 0050 introduced. Visible to
-- everyone, which is the entire point of a shared venue directory.
create policy "read visible facilities" on facilities for select to authenticated
  using (club_id is null or club_id in (select public.current_user_visible_club_ids()));

-- Staff may add an away venue (they are the ones standing in an
-- opponent's hall); a club's own facilities stay with its managers.
create policy "staff write facilities" on facilities for insert to authenticated
  with check ((club_id is null and public.current_user_is_staff())
              or club_id in (select public.current_user_club_ids()));

create policy "staff update facilities" on facilities for update to authenticated
  using      ((club_id is null and public.current_user_is_staff())
              or club_id in (select public.current_user_club_ids()))
  with check ((club_id is null and public.current_user_is_staff())
              or club_id in (select public.current_user_club_ids()));

-- No DELETE policy anywhere in this group: "no hard deletes" is the
-- rule, and every one of these tables has is_active for retiring a row.
-- This completes at the policy level what 0048 did at the FK level.
