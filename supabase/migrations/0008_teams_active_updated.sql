-- CourtSide — add is_active + updated_at to teams (UserStory 22).

alter table teams add column is_active boolean not null default true;
alter table teams add column updated_at timestamptz;
