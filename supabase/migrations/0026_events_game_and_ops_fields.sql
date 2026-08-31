-- CourtSide — events: game/logistics, coach ops, status, and recurring
-- series fields (UserStory 22).
--
-- Picked `location_url` over the alternative `waze_url` you offered —
-- more generic (can hold a Waze or Google Maps link either way) and
-- future-proof if another nav provider is added later.
--
-- recurrence_group_id has no FK target on purpose — it's just a shared
-- value across the rows in one recurring series (e.g. every Mon/Wed
-- practice), not a reference to a separate series table.

alter table events add column opponent_name text;
alter table events add column is_home_game boolean;
alter table events add column location_url text;

alter table events add column coach_note text;
alter table events add column coach_id uuid references users (id) on delete set null;

alter table events add column status text not null default 'scheduled' check (status in ('scheduled', 'cancelled', 'completed'));

alter table events add column recurrence_group_id uuid;

-- opponent_name is required specifically for games, per spec.
alter table events add constraint events_opponent_required_for_games check (type != 'game' or opponent_name is not null);
