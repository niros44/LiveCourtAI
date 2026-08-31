-- CourtSide — unique(user_id, club_id, role) on user_roles (UserStory 22).
-- Drops the earlier same-columns constraint (added under a different name
-- by unmerged work on another branch, already live) if present, then
-- re-adds it with this column order/name so this branch's migration
-- history matches the live schema exactly.

alter table user_roles drop constraint if exists user_roles_user_id_role_club_key;
alter table user_roles add constraint user_roles_user_id_club_id_role_key unique (user_id, club_id, role);
