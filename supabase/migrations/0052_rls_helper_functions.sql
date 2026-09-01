-- CourtSide — RLS helper functions (UserStory 22). No policies change
-- here; this is the foundation the policy migrations build on.
--
-- The spec requires row-level isolation: a parent sees only their own
-- children, a coach only their teams, management only their club. Today
-- 21 of 23 tables still carry the placeholder policy from their
-- creating migration — USING (true) WITH CHECK (true) — so any signed-in
-- user can read and write every club's data.
--
-- Expressing that isolation inline in 22 separate policies would mean
-- writing the same joins over and over, and getting one of them subtly
-- wrong is a silent leak, not an error. These four functions hold the
-- logic once.
--
-- SECURITY DEFINER is a requirement here, not a convenience: a policy on
-- players that reads guardians would trigger guardians' own policy,
-- which reads players, which triggers players' policy — infinite
-- recursion. Running the lookups as the definer bypasses RLS and breaks
-- the cycle.

-- ---------------------------------------------------------------------
-- The "who manages a club" rule, as data.
--
-- Same reasoning as roles.requires_club in 0043: the roles table was
-- dropped and reseeded several times while this schema was designed and
-- the ids moved each time, so a literal role_id inside a function would
-- eventually point at whichever role happens to sit there. Making a
-- future role (a club secretary, say) a manager is then an UPDATE
-- rather than a migration.
-- ---------------------------------------------------------------------
alter table roles add column if not exists can_manage_club boolean not null default false;
update roles set can_manage_club = true where name = 'Management';

-- ---------------------------------------------------------------------
-- 1. BASE: the players this caller is personally attached to — the
-- player row that is them, and any child they actively guard.
--
-- Deliberately contains no team logic. That is what lets the two
-- functions below reference it without the pair calling each other in a
-- cycle: own_players -> teams -> all players, never back again.
-- ---------------------------------------------------------------------
create or replace function public.current_user_own_player_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select p.id from players p
   where p.user_id = public.current_person_id()
  union
  select g.player_id from guardians g
   where g.user_id = public.current_person_id() and g.is_active
$$;

-- ---------------------------------------------------------------------
-- 2. Clubs this caller manages.
-- ---------------------------------------------------------------------
create or replace function public.current_user_club_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select ur.club_id from user_roles ur
    join roles r on r.role_id = ur.role_id
   where ur.user_id = public.current_person_id()
     and ur.is_active and r.can_manage_club and ur.club_id is not null
$$;

-- ---------------------------------------------------------------------
-- 3. Teams this caller may see: teams they currently coach, teams their
-- own players are on, and every team in a club they manage.
--
-- The end_date check matters — spec 3 has coaches handing teams over
-- mid-season, and a coach who has left should stop seeing the roster.
-- ---------------------------------------------------------------------
create or replace function public.current_user_team_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
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
$$;

-- ---------------------------------------------------------------------
-- 4. Every player this caller may see: their own, plus everyone on a
-- team they have access to.
-- ---------------------------------------------------------------------
create or replace function public.current_user_player_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select public.current_user_own_player_ids()
  union
  select tm.player_id from team_members tm
   where tm.team_id in (select public.current_user_team_ids())
$$;

grant execute on function public.current_user_own_player_ids() to authenticated;
grant execute on function public.current_user_club_ids()      to authenticated;
grant execute on function public.current_user_team_ids()      to authenticated;
grant execute on function public.current_user_player_ids()    to authenticated;
