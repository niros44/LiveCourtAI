-- CourtSide — enforce user_roles.role_id NOT NULL (UserStory 22).
--
-- 0031 already contained this line, but that migration was applied
-- partly by hand and the constraint didn't take. Found by validating
-- all 230 columns across the 23 tables against information_schema —
-- it was the only discrepancy in the whole schema.
--
-- Without it a user_roles row can exist with no role at all: a row that
-- grants membership in a club while saying nothing about what the user
-- may do there.
--
-- Cleans up any such orphan rows first, so the constraint can be added
-- on a table that already satisfies it.

delete from user_roles where role_id is null;

alter table user_roles alter column role_id set not null;
