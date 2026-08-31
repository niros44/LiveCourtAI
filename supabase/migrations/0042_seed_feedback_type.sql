-- CourtSide — seed feedback_type (UserStory 22). The table was created
-- in 0016 with no values, leaving it undefined.
--
-- These are the coach's overall assessment of a player's session — a
-- qualitative scale, not topic categories. Inserted best-to-worst so
-- feedback_id also reads as the scale order (1 = best), which the UI can
-- sort by without needing an extra column.
--
-- Hebrew here (unlike `roles`, which is English) because these strings
-- are what the coach picks and the player reads — they're content, not
-- structural identifiers.
--
-- Safe to run twice: an earlier draft of this file seeded English
-- category names (Technique/Participation/...), so it clears those if
-- they're present and guards the constraint that draft may have added.

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'feedback_type'::regclass and conname = 'feedback_type_name_key'
  ) then
    alter table feedback_type add constraint feedback_type_name_key unique (feedback_name);
  end if;
end $$;

delete from feedback_type
where feedback_name in ('Technique', 'Participation', 'Persistence', 'General');

insert into feedback_type (feedback_name) values
  ('אימון נהדר'),
  ('אימון טוב'),
  ('דורש שיפור'),
  ('אימון חלש')
on conflict (feedback_name) do nothing;
