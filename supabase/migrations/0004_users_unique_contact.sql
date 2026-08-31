-- CourtSide — unique email/cellphone on users (UserStory 22).
-- Both stay nullable (not every user has both channels), and Postgres
-- treats multiple NULLs as non-conflicting for UNIQUE, so this only
-- blocks actual duplicate values — not missing ones. A UNIQUE constraint
-- also creates its backing index automatically, so this covers both the
-- dedup requirement and fast lookup by email/cellphone during OTP login.

alter table users add constraint users_email_key unique (email);
alter table users add constraint users_cellphone_key unique (cellphone);
