-- CourtSide — revert attendance/player_feedback to reference players
-- instead of users (UserStory 22). Consistent with guardians/rsvps:
-- attendance and feedback are about the player as a person, and a Proxy
-- Mode player (no login, no users row) still needs both tracked.
-- Everything else added to these tables in 0014/0015/0017
-- (created_at, updated_at, is_active, comments, event_id, feedback_id)
-- stays as-is — only the identity reference flips back.

alter table attendance drop constraint if exists unique_event_player_attendance;
alter table attendance drop constraint if exists attendance_user_id_fkey;
alter table attendance rename column user_id to player_id;
alter table attendance add constraint attendance_player_id_fkey foreign key (player_id) references players (id) on delete cascade;
alter table attendance add constraint unique_event_player_attendance unique (event_id, player_id);

alter table player_feedback drop constraint if exists player_feedback_user_id_fkey;
alter table player_feedback rename column user_id to player_id;
alter table player_feedback add constraint player_feedback_player_id_fkey foreign key (player_id) references players (id) on delete cascade;
