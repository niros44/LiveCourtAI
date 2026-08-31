-- CourtSide — roles lookup table, replacing the inline CHECK on
-- user_roles.role (UserStory 22). Consistent with feedback_type/
-- player_feedback.feedback_id already in this schema: a numeric identity
-- PK (role_id) as the FK target, so user_roles carries a numeric FK
-- instead of a text one. `code` stays as a stable text handle for app
-- code/RLS to reference by name (e.g. role_id via a lookup, or reading
-- `code` back after a join) without hardcoding numbers; `name` holds the
-- capitalized display value you asked for.
--
-- Renamed admin -> management at the `code`/`name` level too, not just
-- display — flagging this since "admin" is the term used everywhere else
-- so far (branch names, the stashed /admin screens on another branch).
-- Say so if you only meant the display label to change.

create table roles (
  role_id int generated always as identity primary key,
  code text not null unique,
  name text not null,
  hierarchy_depth int not null unique,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

-- Seed data lives in 0036_roles_identity_restart.sql, not here — kept
-- structure and data separate after the seed needed redoing twice.

alter table roles enable row level security;
create policy "authenticated read/write — roles" on roles for all to authenticated using (true) with check (true);

-- user_roles.role (text) -> role_id (int), FK to roles.role_id.
alter table user_roles drop constraint if exists user_roles_role_check;
alter table user_roles add column role_id int references roles (role_id);
update user_roles ur set role_id = r.role_id from roles r where r.code = ur.role;
alter table user_roles alter column role_id set not null;
alter table user_roles drop column role;

-- The old unique(user_id, role, club_id) implicitly covered role_id too
-- once renamed; recreate it explicitly under the new column name.
alter table user_roles drop constraint if exists user_roles_user_id_role_club_key;
alter table user_roles add constraint user_roles_user_id_role_id_club_key unique (user_id, role_id, club_id);
