-- CourtSide — reshape the "user" table (UserStory 22):
-- rename to plural `users`, split full_name into first/last name, add
-- updated_at + avatar_url, and replace age with birth_date.
-- No data migration needed — the table has been empty throughout.

alter table "user" rename to users;

alter table users add column first_name text;
alter table users add column last_name text;
alter table users drop column full_name;

alter table users add column updated_at timestamptz;

alter table users add column avatar_url text;

alter table users add column birth_date date;
alter table users drop column age;
