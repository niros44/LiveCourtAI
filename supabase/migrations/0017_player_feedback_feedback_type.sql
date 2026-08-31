-- CourtSide — link player_feedback to feedback_type (UserStory 22).

alter table player_feedback add column feedback_id int references feedback_type (feedback_id) on delete set null;
