-- CourtSide — player_feedback: track by user_id instead of player_id
-- (UserStory 22), same shift as team_members/attendance. Also links
-- feedback to the event it relates to.

alter table player_feedback drop constraint if exists player_feedback_player_id_fkey;
alter table player_feedback rename column player_id to user_id;
alter table player_feedback add constraint player_feedback_user_id_fkey foreign key (user_id) references users (id) on delete cascade;

alter table player_feedback add column updated_at timestamptz;
alter table player_feedback add column is_active boolean not null default true;
alter table player_feedback add column event_id uuid references events (id) on delete set null;
