-- CourtSide — RLS group 3: schedule, RSVP and attendance (UserStory 22).
--
-- Two columns that have existed since early migrations start actually
-- meaning something here. guardians.can_rsvp has been in the schema
-- since 0001 without anything enforcing it, and attendance has always
-- been writable by whoever was signed in.

-- ---------------------------------------------------------------------
-- Players the caller may RESPOND for.
--
-- This is where spec 4's view-only delegation finally bites: a
-- grandparent added with can_rsvp = false can see the schedule but
-- cannot answer for the child. Note this is narrower than
-- current_user_own_player_ids, which ignores can_rsvp because seeing a
-- child and answering for them are different rights.
-- ---------------------------------------------------------------------
create or replace function public.current_user_rsvp_player_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select p.id from players p where p.user_id = public.current_person_id()
  union
  select g.player_id from guardians g
   where g.user_id = public.current_person_id() and g.is_active and g.can_rsvp
$$;

-- Events belonging to a team the caller runs, so a coach can act on a
-- whole event at once rather than row by row.
create or replace function public.current_user_managed_event_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select e.id from events e
   where e.team_id in (select public.current_user_managed_team_ids())
$$;

grant execute on function public.current_user_rsvp_player_ids()   to authenticated;
grant execute on function public.current_user_managed_event_ids() to authenticated;

-- ---------------------------------------------------------------------
-- events
-- ---------------------------------------------------------------------
drop policy if exists "authenticated read/write — events" on events;
drop policy if exists "read visible events" on events;
drop policy if exists "staff create events" on events;
drop policy if exists "staff update events" on events;

create policy "read visible events" on events for select to authenticated
  using (team_id in (select public.current_user_team_ids()));

-- Creating, editing and cancelling events is the coach's job (spec 3).
-- No DELETE policy: cancelling sets status = 'cancelled', which is what
-- drives the strikethrough in the calendar and the cancellation push to
-- parents and players. A deleted event would just vanish silently.
create policy "staff create events" on events for insert to authenticated
  with check (team_id in (select public.current_user_managed_team_ids()));

create policy "staff update events" on events for update to authenticated
  using      (team_id in (select public.current_user_managed_team_ids()))
  with check (team_id in (select public.current_user_managed_team_ids()));

-- ---------------------------------------------------------------------
-- event_responses (RSVP)
-- ---------------------------------------------------------------------
drop policy if exists "authenticated read/write — event_responses" on event_responses;
drop policy if exists "read visible responses"  on event_responses;
drop policy if exists "respond for own players" on event_responses;
drop policy if exists "update own responses"    on event_responses;

-- A coach sees the whole team's intentions ahead of the session; a
-- parent sees their own children only. Both fall out of the same
-- helper, because both are "players I can see".
create policy "read visible responses" on event_responses for select to authenticated
  using (player_id in (select public.current_user_player_ids()));

create policy "respond for own players" on event_responses for insert to authenticated
  with check (player_id in (select public.current_user_rsvp_player_ids())
              or event_id in (select public.current_user_managed_event_ids()));

create policy "update own responses" on event_responses for update to authenticated
  using      (player_id in (select public.current_user_rsvp_player_ids())
              or event_id in (select public.current_user_managed_event_ids()))
  with check (player_id in (select public.current_user_rsvp_player_ids())
              or event_id in (select public.current_user_managed_event_ids()));

-- ---------------------------------------------------------------------
-- attendance (Roll Call)
-- ---------------------------------------------------------------------
drop policy if exists "authenticated read/write — attendance" on attendance;
drop policy if exists "read visible attendance" on attendance;
drop policy if exists "staff mark attendance"   on attendance;
drop policy if exists "staff update attendance" on attendance;

-- Read by players and parents, since attendance is what feeds the
-- streak counter on the player home screen. Written only by the coach:
-- spec 3 puts Roll Call in the coach's hands, and a streak the child
-- can set for themselves is not a streak.
create policy "read visible attendance" on attendance for select to authenticated
  using (player_id in (select public.current_user_player_ids()));

create policy "staff mark attendance" on attendance for insert to authenticated
  with check (event_id in (select public.current_user_managed_event_ids()));

create policy "staff update attendance" on attendance for update to authenticated
  using      (event_id in (select public.current_user_managed_event_ids()))
  with check (event_id in (select public.current_user_managed_event_ids()));
