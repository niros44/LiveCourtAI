-- CourtSide — align legacy identity FKs with "user", then drop profiles
-- (UserStory 18). `profiles` was the pre-UserStory-16 identity table; every
-- other table still pointed at it even after "user"/user_roles replaced it.
-- This repoints all of them and removes the now-unused `profiles`.
--
-- Renaming `profile_id` -> `user_id` (players, team_members, guardians)
-- automatically carries forward any CHECK/UNIQUE constraint that mentions
-- the column by name (team_members_one_subject, guardians' unique pair) —
-- Postgres updates the constraint definition on rename, no need to redefine
-- those. Only the FK constraints need explicit work, since renaming a local
-- column doesn't change which table it references.

-- 1. Rename the columns that literally mirrored "profile" in their name.
alter table players rename column profile_id to user_id;
alter table team_members rename column profile_id to user_id;
alter table guardians rename column profile_id to user_id;

-- 2. Point every dependent FK at "user" instead of profiles. Old FK
-- constraints (still pointing at profiles, under their original names) are
-- left in place here and cleaned up by the CASCADE drop in step 3 — no need
-- to guess their auto-generated names.
alter table players
  add constraint players_user_id_fkey foreign key (user_id) references "user" (id) on delete set null;

alter table team_members
  add constraint team_members_user_id_fkey foreign key (user_id) references "user" (id) on delete cascade;

alter table guardians
  add constraint guardians_user_id_fkey foreign key (user_id) references "user" (id) on delete cascade;

alter table events
  add constraint events_created_by_user_fkey foreign key (created_by) references "user" (id) on delete set null;

alter table rsvps
  add constraint rsvps_responded_by_user_fkey foreign key (responded_by) references "user" (id) on delete set null;

alter table attendance
  add constraint attendance_marked_by_user_fkey foreign key (marked_by) references "user" (id) on delete set null;

alter table player_feedback
  add constraint player_feedback_coach_id_user_fkey foreign key (coach_id) references "user" (id) on delete cascade;

-- 3. Drop the now-unused legacy identity table. CASCADE removes the old
-- FK constraints (and profiles' own RLS policy) that still referenced it.
drop table profiles cascade;
