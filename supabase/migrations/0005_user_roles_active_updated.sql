-- CourtSide — add is_active + updated_at to user_roles (UserStory 22).

alter table user_roles add column is_active boolean not null default true;
alter table user_roles add column updated_at timestamptz;
