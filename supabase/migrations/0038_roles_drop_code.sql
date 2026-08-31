-- CourtSide — drop roles.code (UserStory 22). Redundant now that
-- role_id is the real numeric identifier — a text handle alongside it
-- would just be the thing the numeric-FK move was meant to replace.
--
-- Both statements are guarded because this file has two audiences:
--   * the live DB, where roles was created by the ORIGINAL 0037 (which
--     did create `code`, and left `name` without a unique constraint) —
--     here both statements do real work;
--   * a from-scratch replay, where 0037's edited version already omits
--     `code` and already marks `name` unique — here both are no-ops.
-- Without the guards, a replay would fail on the first statement.

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'roles' and column_name = 'code'
  ) then
    alter table roles drop column code;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'roles'::regclass and conname = 'roles_name_key'
  ) then
    alter table roles add constraint roles_name_key unique (name);
  end if;
end $$;
