-- CourtSide — restore the "club_id required except for Parent" rule
-- (UserStory 22). It was lost silently in 0031: dropping the old
-- user_roles.role text column made Postgres drop the CHECK that depended
-- on it, along with the partial unique index limiting a user to one
-- parent role.
--
-- Why not just re-add a CHECK: a CHECK can't contain a subquery, so it
-- would have to hardcode `role_id = 4`. That's fragile — the roles table
-- was dropped and reseeded several times while designing this, and the
-- ids moved each time. A hardcoded 4 would then silently enforce the
-- rule against whatever role happens to sit at id 4.
--
-- Instead the rule becomes DATA: roles.requires_club says whether a role
-- is club-scoped, and a trigger enforces it. Making a future role global
-- (say, a system-wide Management account) is then an UPDATE, not a
-- schema migration.

-- ---------------------------------------------------------------------
-- 1. The rule, as data
-- ---------------------------------------------------------------------
alter table roles add column requires_club boolean not null default true;

update roles set requires_club = false where name = 'Parent';

-- ---------------------------------------------------------------------
-- 2. Enforce it. SECURITY DEFINER so the lookup into `roles` works
-- regardless of the caller's RLS visibility.
-- ---------------------------------------------------------------------
create or replace function public.enforce_user_role_club_scope()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_requires_club boolean;
  v_role_name text;
begin
  select requires_club, name into v_requires_club, v_role_name
  from roles where role_id = new.role_id;

  if v_requires_club and new.club_id is null then
    raise exception 'Role "%" is club-scoped — club_id is required', v_role_name;
  end if;

  if not v_requires_club and new.club_id is not null then
    raise exception 'Role "%" is not club-scoped — club_id must be null', v_role_name;
  end if;

  return new;
end;
$$;

drop trigger if exists user_roles_club_scope_check on user_roles;
create trigger user_roles_club_scope_check
  before insert or update on user_roles
  for each row execute function public.enforce_user_role_club_scope();

-- ---------------------------------------------------------------------
-- 3. Replace the lost partial index — but role-agnostic this time.
--
-- UNIQUE(user_id, role_id, club_id) does NOT catch duplicates when
-- club_id is null, because Postgres treats each NULL as distinct. This
-- index closes that hole for ANY club-less role, without naming one:
-- at most one row per (user, role) among the rows with no club.
-- ---------------------------------------------------------------------
create unique index if not exists user_roles_one_clubless_role_per_user
  on user_roles (user_id, role_id)
  where club_id is null;
