-- CourtSide — rename rsvps to event_responses (UserStory 22).
-- All columns, constraints, and FKs carry over automatically on rename.

alter table rsvps rename to event_responses;
alter policy "authenticated read/write — rsvps" on event_responses rename to "authenticated read/write — event_responses";
