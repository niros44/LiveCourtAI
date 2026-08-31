-- CourtSide — drop roles.code (UserStory 22). Redundant now that
-- role_id is the real numeric identifier — a text handle alongside it
-- would just be the thing the numeric-FK move was meant to replace.
-- (0037 was already applied with `code` before this was raised — this
-- is the live fix; 0037's own file has been edited to not create it in
-- the first place, for anyone replaying migrations from scratch.)

alter table roles drop column code;

-- The live table was created by the old 0037 (before this fix), where
-- `name` had no unique constraint — add it so the live schema matches
-- 0037's edited version.
alter table roles add constraint roles_name_key unique (name);
