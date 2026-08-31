-- CourtSide — seed the roles rows (UserStory 22). The table ended up
-- empty: 0037's CREATE landed but its INSERT didn't, and 0038 then
-- dropped the `code` column, so this inserts (name, hierarchy_depth)
-- only.
--
-- Not optional: user_roles.role_id is NOT NULL with an FK to this table,
-- so no role can be assigned to anyone while it's empty.
--
-- hierarchy_depth reads as actual depth — 1 is closest to the root
-- (most senior), 4 is furthest.

insert into roles (name, hierarchy_depth) values
  ('Management', 1),
  ('Coach', 2),
  ('Player', 3),
  ('Parent', 4)
on conflict (name) do nothing;
