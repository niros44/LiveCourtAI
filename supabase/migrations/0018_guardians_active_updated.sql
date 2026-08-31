-- CourtSide — add updated_at + is_active to guardians (UserStory 22).

alter table guardians add column updated_at timestamptz;
alter table guardians add column is_active boolean not null default true;
