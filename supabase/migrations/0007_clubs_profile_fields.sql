-- CourtSide — add profile fields to clubs (UserStory 22).

alter table clubs add column is_active boolean not null default true;
alter table clubs add column updated_at timestamptz;
alter table clubs add column logo_url text;
alter table clubs add column city text;
