-- CourtSide — enforce the "no hard deletes" rule at the FK level
-- (UserStory 22).
--
-- The rule is stated in the spec (section 8: "לאתר משתמש (למשל מאמן)
-- ולשנות את הסטטוס שלו או לשלול ממנו גישה במקרה של סיום העסקה" — change
-- status / revoke access, never delete), and every table carries an
-- is_active flag for it. But nothing enforced it: an audit of the live
-- database found 10 foreign keys onto users/players still set to
-- ON DELETE CASCADE, all of them on tables that hold history.
--
-- Deleting one coach silently deleted every piece of feedback they had
-- written, every photo they had uploaded, their whole coaching record,
-- and the performance reviews written about them. Deleting one player
-- took their attendance, RSVPs, game stats and roster history with them.
--
-- RESTRICT turns that into an upfront refusal: the delete fails loudly,
-- and the caller has to deactivate instead — which is what the spec
-- asked for in the first place.

-- ---------------------------------------------------------------------
-- 1. Adult history — the realistic case, a coach leaving the club.
-- ---------------------------------------------------------------------

-- Renamed off its ..._user_fkey spelling (a leftover from the 0002
-- profiles -> user repointing) now that it is being recreated anyway.
alter table player_feedback drop constraint if exists player_feedback_coach_id_user_fkey;
alter table player_feedback
  add constraint player_feedback_coach_id_fkey
  foreign key (coach_id) references users (id) on delete restrict;

alter table team_media drop constraint if exists team_media_uploaded_by_fkey;
alter table team_media
  add constraint team_media_uploaded_by_fkey
  foreign key (uploaded_by) references users (id) on delete restrict;

alter table team_coaches drop constraint if exists team_coaches_user_id_fkey;
alter table team_coaches
  add constraint team_coaches_user_id_fkey
  foreign key (user_id) references users (id) on delete restrict;

alter table performance_reviews drop constraint if exists performance_reviews_reviewee_user_id_fkey;
alter table performance_reviews
  add constraint performance_reviews_reviewee_user_id_fkey
  foreign key (reviewee_user_id) references users (id) on delete restrict;

-- ---------------------------------------------------------------------
-- 2. Player history — roster, attendance, RSVPs, stats, reviews.
-- ---------------------------------------------------------------------
alter table attendance drop constraint if exists attendance_player_id_fkey;
alter table attendance
  add constraint attendance_player_id_fkey
  foreign key (player_id) references players (id) on delete restrict;

-- Still carried its pre-rename name from 0030 (rsvps -> event_responses);
-- corrected here since the constraint is being recreated regardless.
alter table event_responses drop constraint if exists rsvps_player_id_fkey;
alter table event_responses
  add constraint event_responses_player_id_fkey
  foreign key (player_id) references players (id) on delete restrict;

alter table player_feedback drop constraint if exists player_feedback_player_id_fkey;
alter table player_feedback
  add constraint player_feedback_player_id_fkey
  foreign key (player_id) references players (id) on delete restrict;

alter table game_events_log drop constraint if exists game_events_log_player_id_fkey;
alter table game_events_log
  add constraint game_events_log_player_id_fkey
  foreign key (player_id) references players (id) on delete restrict;

alter table team_members drop constraint if exists team_members_player_id_fkey;
alter table team_members
  add constraint team_members_player_id_fkey
  foreign key (player_id) references players (id) on delete restrict;

alter table performance_reviews drop constraint if exists performance_reviews_player_id_fkey;
alter table performance_reviews
  add constraint performance_reviews_player_id_fkey
  foreign key (player_id) references players (id) on delete restrict;

-- ---------------------------------------------------------------------
-- 3. Deliberately left as CASCADE: user_roles, guardians and
-- team_media_reactions. These are pure linkage with no history of their
-- own — once the person is gone, their role grant, their family link and
-- their emoji carry no meaning worth preserving.
--
-- Also left alone: the columns that already used SET NULL and were
-- always right — attendance.marked_by, events.created_by, events.coach_id,
-- event_responses.responded_by, team_media.reviewed_by and
-- performance_reviews.reviewer_user_id. These record who performed an
-- action; the record survives, the attribution is simply dropped.
-- ---------------------------------------------------------------------
