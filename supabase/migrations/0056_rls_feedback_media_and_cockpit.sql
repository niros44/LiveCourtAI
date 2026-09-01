-- CourtSide — RLS group 4: feedback, reviews, measurements, media and
-- the live cockpit (UserStory 22). Last of the policy migrations; after
-- this no table in the schema is left on USING (true).

create or replace function public.current_user_visible_media_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select m.id from team_media m
   where m.team_id in (select public.current_user_team_ids())
$$;

create or replace function public.current_user_visible_session_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select s.id from games_live_session s
    join events e on e.id = s.event_id
   where e.team_id in (select public.current_user_team_ids())
$$;

create or replace function public.current_user_managed_session_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select s.id from games_live_session s
   where s.event_id in (select public.current_user_managed_event_ids())
$$;

grant execute on function public.current_user_visible_media_ids()   to authenticated;
grant execute on function public.current_user_visible_session_ids() to authenticated;
grant execute on function public.current_user_managed_session_ids() to authenticated;

-- ---------------------------------------------------------------------
-- player_feedback
-- ---------------------------------------------------------------------
drop policy if exists "authenticated read/write — player_feedback" on player_feedback;
drop policy if exists "read visible feedback"     on player_feedback;
drop policy if exists "coaches write feedback"    on player_feedback;
drop policy if exists "coaches edit own feedback" on player_feedback;

create policy "read visible feedback" on player_feedback for select to authenticated
  using (player_id in (select public.current_user_player_ids()));

-- coach_id must be the caller: a coach cannot file feedback under a
-- colleague's name, which matters because the player and their parents
-- read it attributed.
create policy "coaches write feedback" on player_feedback for insert to authenticated
  with check (public.current_user_is_staff()
              and coach_id = public.current_person_id()
              and player_id in (select public.current_user_player_ids()));

create policy "coaches edit own feedback" on player_feedback for update to authenticated
  using      (coach_id = public.current_person_id())
  with check (coach_id = public.current_person_id());

-- ---------------------------------------------------------------------
-- performance_reviews
--
-- An anonymous review is hidden at the row level from the person it is
-- about. Worth being precise about what that does and does not buy:
-- reviewer_user_id is still stored, so club management can see who
-- rated whom. Real anonymity means not storing the link at all — the
-- same caveat recorded in 0050 when the flag was added.
-- ---------------------------------------------------------------------
drop policy if exists "authenticated read/write — performance_reviews" on performance_reviews;
drop policy if exists "read visible reviews"        on performance_reviews;
drop policy if exists "staff create reviews"        on performance_reviews;
drop policy if exists "participants update reviews" on performance_reviews;

create policy "read visible reviews" on performance_reviews for select to authenticated
  using (player_id in (select public.current_user_player_ids())
         or (reviewee_user_id = public.current_person_id() and not is_anonymous)
         or reviewer_user_id = public.current_person_id()
         or club_id in (select public.current_user_club_ids()));

create policy "staff create reviews" on performance_reviews for insert to authenticated
  with check (public.current_user_is_staff());

-- Both sides of the conversation can write: the reviewer fills their
-- half, the subject fills self_rating and self_comments before the
-- meeting (spec 2).
--
-- Known limit: RLS is row-level, not column-level, so nothing here stops
-- a player who may update the row from also overwriting
-- reviewer_comments. Closing that properly needs column-level
-- GRANT UPDATE (col, ...) — a separate change if it ever matters.
create policy "participants update reviews" on performance_reviews for update to authenticated
  using      (reviewer_user_id = public.current_person_id()
              or reviewee_user_id = public.current_person_id()
              or player_id in (select public.current_user_own_player_ids())
              or club_id in (select public.current_user_club_ids()))
  with check (reviewer_user_id = public.current_person_id()
              or reviewee_user_id = public.current_person_id()
              or player_id in (select public.current_user_own_player_ids())
              or club_id in (select public.current_user_club_ids()));

-- ---------------------------------------------------------------------
-- player_measurements
-- ---------------------------------------------------------------------
drop policy if exists "authenticated read/write — player_measurements" on player_measurements;
drop policy if exists "read visible measurements" on player_measurements;
drop policy if exists "staff record measurements" on player_measurements;
drop policy if exists "staff update measurements" on player_measurements;

create policy "read visible measurements" on player_measurements for select to authenticated
  using (player_id in (select public.current_user_player_ids()));

create policy "staff record measurements" on player_measurements for insert to authenticated
  with check (public.current_user_is_staff()
              and player_id in (select public.current_user_player_ids()));

create policy "staff update measurements" on player_measurements for update to authenticated
  using      (public.current_user_is_staff()
              and player_id in (select public.current_user_player_ids()))
  with check (public.current_user_is_staff()
              and player_id in (select public.current_user_player_ids()));

-- ---------------------------------------------------------------------
-- team_media
--
-- Scope note: 0021 sketched approval at age-group level, where any coach
-- of any team sharing the agegroup_id could moderate. Narrowed here to
-- the media's own team coaches, since that is the smaller grant and
-- nobody has asked for the wider one. Widening later is one policy.
-- ---------------------------------------------------------------------
drop policy if exists "authenticated read/write — team_media" on team_media;
drop policy if exists "read approved media" on team_media;
drop policy if exists "upload own media"    on team_media;
drop policy if exists "moderate media"      on team_media;

-- Pending media is visible only to whoever uploaded it and to the
-- team's coaches, who are the moderators. Everyone else sees the feed
-- only once a coach has approved it.
create policy "read approved media" on team_media for select to authenticated
  using (team_id in (select public.current_user_team_ids())
         and (status = 'approved'
              or uploaded_by = public.current_person_id()
              or team_id in (select public.current_user_managed_team_ids())));

create policy "upload own media" on team_media for insert to authenticated
  with check (team_id in (select public.current_user_team_ids())
              and uploaded_by = public.current_person_id());

create policy "moderate media" on team_media for update to authenticated
  using      (uploaded_by = public.current_person_id()
              or team_id in (select public.current_user_managed_team_ids()))
  with check (uploaded_by = public.current_person_id()
              or team_id in (select public.current_user_managed_team_ids()));

-- ---------------------------------------------------------------------
-- team_media_reactions
-- ---------------------------------------------------------------------
drop policy if exists "authenticated read/write — team_media_reactions" on team_media_reactions;
drop policy if exists "read visible reactions" on team_media_reactions;
drop policy if exists "react as self"          on team_media_reactions;
drop policy if exists "change own reaction"    on team_media_reactions;

create policy "read visible reactions" on team_media_reactions for select to authenticated
  using (media_id in (select public.current_user_visible_media_ids()));

create policy "react as self" on team_media_reactions for insert to authenticated
  with check (user_id = public.current_person_id()
              and media_id in (select public.current_user_visible_media_ids()));

-- Changing or clearing a reaction is an UPDATE, not a DELETE: the unique
-- on (media_id, user_id) means there is only ever one row per person per
-- item, so is_active carries the "un-reacted" state.
create policy "change own reaction" on team_media_reactions for update to authenticated
  using      (user_id = public.current_person_id())
  with check (user_id = public.current_person_id());

-- ---------------------------------------------------------------------
-- games_live_session and game_events_log
--
-- Spec 6 describes the cockpit being run by a coach, an assistant coach
-- OR a bench player. Only staff can write here — handing the cockpit to
-- a player needs an explicit delegation mechanism that does not exist in
-- the schema yet, and inventing one silently inside an RLS policy would
-- be the wrong place for it.
-- ---------------------------------------------------------------------
drop policy if exists "authenticated read/write — games_live_session" on games_live_session;
drop policy if exists "read visible sessions" on games_live_session;
drop policy if exists "staff open session"    on games_live_session;
drop policy if exists "staff run session"     on games_live_session;

create policy "read visible sessions" on games_live_session for select to authenticated
  using (event_id in (select e.id from events e
                      where e.team_id in (select public.current_user_team_ids())));

create policy "staff open session" on games_live_session for insert to authenticated
  with check (event_id in (select public.current_user_managed_event_ids()));

create policy "staff run session" on games_live_session for update to authenticated
  using      (event_id in (select public.current_user_managed_event_ids()))
  with check (event_id in (select public.current_user_managed_event_ids()));

drop policy if exists "authenticated read/write — game_events_log" on game_events_log;
drop policy if exists "read visible game log" on game_events_log;
drop policy if exists "staff log game events" on game_events_log;
drop policy if exists "staff fix game log"    on game_events_log;

create policy "read visible game log" on game_events_log for select to authenticated
  using (game_session_id in (select public.current_user_visible_session_ids()));

create policy "staff log game events" on game_events_log for insert to authenticated
  with check (game_session_id in (select public.current_user_managed_session_ids()));

create policy "staff fix game log" on game_events_log for update to authenticated
  using      (game_session_id in (select public.current_user_managed_session_ids()))
  with check (game_session_id in (select public.current_user_managed_session_ids()));
