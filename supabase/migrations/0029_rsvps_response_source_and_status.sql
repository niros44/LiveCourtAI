-- CourtSide — rsvps: response_source + unified status values
-- (UserStory 22).
--
-- responded_by already exists and already means exactly what's described
-- (the acting user's id — child's if they responded themselves, parent's
-- if Proxy Mode, or null if the child has no users account at all) — no
-- schema change needed there, just documenting the existing intent.
--
-- response_source is new: distinguishes *who* the response came from
-- (player vs guardian) independent of which user_id ended up in
-- responded_by — so the coach/parent can tell whether the kid answered
-- themselves or a parent answered for them.

alter table rsvps add column response_source text check (response_source in ('player', 'guardian'));

-- Status values unified to the spec's set, replacing the earlier
-- in/out/undecided (the default 'undecided' is still valid, unchanged).
alter table rsvps drop constraint if exists rsvps_status_check;
alter table rsvps add constraint rsvps_status_check check (status in ('attending', 'not_attending', 'undecided', 'injured'));
