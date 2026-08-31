-- CourtSide — move `status` from players to team_members (UserStory 22),
-- same reasoning as jersey_number/court_position: fitness status is a
-- per-team-membership attribute, not a global player one.

alter table players drop column status;

alter table team_members add column status text not null default 'active' check (status in ('active', 'injured'));
