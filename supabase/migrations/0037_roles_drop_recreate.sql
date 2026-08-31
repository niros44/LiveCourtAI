-- CourtSide — drop and recreate roles from scratch (UserStory 22), so
-- role_id's identity naturally starts at 1 instead of being restarted by
-- hand. CASCADE removes user_roles.role_id's FK constraint along with
-- the table (user_roles itself and its data are untouched — CASCADE
-- only drops the constraint, not the referencing table); the FK is
-- re-added at the end once roles exists again.

drop table if exists roles cascade;

create table roles (
  role_id int generated always as identity primary key,
  name text not null unique,
  hierarchy_depth int not null unique,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

-- No separate `code` column — role_id is the real identifier once app
-- code/RLS reference roles numerically; a text handle alongside it would
-- just be the thing this whole numeric-FK move was meant to replace.
insert into roles (name, hierarchy_depth) values
  ('Management', 1),
  ('Coach', 2),
  ('Player', 3),
  ('Parent', 4);

alter table roles enable row level security;
create policy "authenticated read/write — roles" on roles for all to authenticated using (true) with check (true);

alter table user_roles add constraint user_roles_role_id_fkey foreign key (role_id) references roles (role_id);
