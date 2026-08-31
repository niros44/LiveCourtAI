-- CourtSide — players field changes (UserStory 22).

alter table players drop column full_name;
alter table players drop column birth_date;
alter table players drop column jersey_number;
alter table players drop column court_position;

alter table players add column updated_at timestamptz;
alter table players add column is_active boolean not null default true;
