-- CourtSide — RLS group 2: identity and roster (UserStory 22).
--
-- This group also closes a hole that would have shown up the moment any
-- screen went live. 0040 left users with "own row only" policies, and
-- also made users the single place a person's name lives — so a coach
-- could not read the name of any player on their own team. The roster,
-- the team feed, the live cockpit and the player card would all have
-- rendered without a single name on them.

-- ---------------------------------------------------------------------
-- Three more helpers.
-- ---------------------------------------------------------------------

-- People the caller may see: themselves, the person behind any player
-- they can see, the coaches of their teams, and the guardians of their
-- players. That last one is spec 3's "מסך שחקנים: ניהול קשר" — the
-- coach needing to reach a parent.
create or replace function public.current_user_visible_person_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
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
$$;

-- Teams the caller may CHANGE. Narrower than the teams they can see, on
-- purpose: a parent can see the team their child plays on, but must not
-- be able to edit its roster.
create or replace function public.current_user_managed_team_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select tc.team_id from team_coaches tc
   where tc.user_id = public.current_person_id() and tc.is_active
     and (tc.end_date is null or tc.end_date >= current_date)
  union
  select t.id from teams t where t.club_id in (select public.current_user_club_ids())
$$;

-- Players the caller is the PRIMARY guardian of. Spec 4 gives only the
-- primary guardian the right to invite further family members, which is
-- what made the 0047 fix load-bearing: while every grandparent was
-- created with is_primary = true, every one of them could invite more.
create or replace function public.current_user_primary_player_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select g.player_id from guardians g
   where g.user_id = public.current_person_id() and g.is_primary and g.is_active
$$;

grant execute on function public.current_user_visible_person_ids() to authenticated;
grant execute on function public.current_user_managed_team_ids()   to authenticated;
grant execute on function public.current_user_primary_player_ids() to authenticated;

-- ---------------------------------------------------------------------
-- users
-- ---------------------------------------------------------------------
drop policy if exists "read own person row"   on users;
drop policy if exists "insert own person row" on users;
drop policy if exists "update own person row" on users;
drop policy if exists "read visible people"   on users;
drop policy if exists "create person rows"    on users;
drop policy if exists "update person rows"    on users;

create policy "read visible people" on users for select to authenticated
  using (id in (select public.current_user_visible_person_ids()));

-- Two insert cases: signing yourself up, and staff creating the shadow
-- person row for a child who has no login of their own (auth_user_id
-- null) — the Proxy Mode case 0040 built the schema for.
create policy "create person rows" on users for insert to authenticated
  with check (auth_user_id = auth.uid()
              or (auth_user_id is null and public.current_user_is_staff()));

-- Known edge: updating a shadow row that has no players row yet is
-- denied, because nothing makes it visible. The normal onboarding flow
-- writes users and players together, so this should not surface — but
-- it is the first thing to check if onboarding throws an odd error.
create policy "update person rows" on users for update to authenticated
  using      (auth_user_id = auth.uid()
              or (auth_user_id is null and public.current_user_is_staff()
                  and id in (select public.current_user_visible_person_ids())))
  with check (auth_user_id = auth.uid()
              or (auth_user_id is null and public.current_user_is_staff()));

-- ---------------------------------------------------------------------
-- players
-- ---------------------------------------------------------------------
drop policy if exists "authenticated read/write — players" on players;
drop policy if exists "read visible players"  on players;
drop policy if exists "staff create players"  on players;
drop policy if exists "update own players"    on players;

create policy "read visible players" on players for select to authenticated
  using (id in (select public.current_user_player_ids()));

create policy "staff create players" on players for insert to authenticated
  with check (public.current_user_is_staff());

create policy "update own players" on players for update to authenticated
  using (id in (select public.current_user_player_ids())
         and (public.current_user_is_staff()
              or id in (select public.current_user_own_player_ids())))
  with check (id in (select public.current_user_player_ids()));

-- ---------------------------------------------------------------------
-- teams
-- ---------------------------------------------------------------------
drop policy if exists "authenticated read/write — teams" on teams;
drop policy if exists "read visible teams"    on teams;
drop policy if exists "managers write teams"  on teams;
drop policy if exists "managers update teams" on teams;

create policy "read visible teams" on teams for select to authenticated
  using (id in (select public.current_user_team_ids()));

create policy "managers write teams" on teams for insert to authenticated
  with check (club_id in (select public.current_user_club_ids()));

create policy "managers update teams" on teams for update to authenticated
  using      (club_id in (select public.current_user_club_ids()))
  with check (club_id in (select public.current_user_club_ids()));

-- ---------------------------------------------------------------------
-- team_members (the roster)
-- ---------------------------------------------------------------------
drop policy if exists "authenticated read/write — team_members" on team_members;
drop policy if exists "read visible roster" on team_members;
drop policy if exists "staff write roster"  on team_members;
drop policy if exists "staff update roster" on team_members;

create policy "read visible roster" on team_members for select to authenticated
  using (team_id in (select public.current_user_team_ids()));

create policy "staff write roster" on team_members for insert to authenticated
  with check (team_id in (select public.current_user_managed_team_ids()));

create policy "staff update roster" on team_members for update to authenticated
  using      (team_id in (select public.current_user_managed_team_ids()))
  with check (team_id in (select public.current_user_managed_team_ids()));

-- ---------------------------------------------------------------------
-- team_coaches
-- ---------------------------------------------------------------------
drop policy if exists "authenticated read/write — team_coaches" on team_coaches;
drop policy if exists "read visible coaches"    on team_coaches;
drop policy if exists "managers assign coaches" on team_coaches;
drop policy if exists "managers update coaches" on team_coaches;

create policy "read visible coaches" on team_coaches for select to authenticated
  using (team_id in (select public.current_user_team_ids()));

-- Assigning coaches is a management action (spec 8 — inviting coaches
-- and attaching them to teams), not something a coach does for the team
-- they already coach.
create policy "managers assign coaches" on team_coaches for insert to authenticated
  with check (team_id in (select t.id from teams t
                          where t.club_id in (select public.current_user_club_ids())));

create policy "managers update coaches" on team_coaches for update to authenticated
  using      (team_id in (select t.id from teams t
                          where t.club_id in (select public.current_user_club_ids())))
  with check (team_id in (select t.id from teams t
                          where t.club_id in (select public.current_user_club_ids())));

-- ---------------------------------------------------------------------
-- guardians
-- ---------------------------------------------------------------------
drop policy if exists "authenticated read/write — guardians" on guardians;
drop policy if exists "read own family links"    on guardians;
drop policy if exists "primary guardian invites" on guardians;
drop policy if exists "primary guardian updates" on guardians;

create policy "read own family links" on guardians for select to authenticated
  using (user_id = public.current_person_id()
         or player_id in (select public.current_user_player_ids()));

create policy "primary guardian invites" on guardians for insert to authenticated
  with check (player_id in (select public.current_user_primary_player_ids())
              or public.current_user_is_staff());

create policy "primary guardian updates" on guardians for update to authenticated
  using      (player_id in (select public.current_user_primary_player_ids())
              or public.current_user_is_staff())
  with check (player_id in (select public.current_user_primary_player_ids())
              or public.current_user_is_staff());
