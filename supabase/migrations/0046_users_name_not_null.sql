-- CourtSide — users.first_name / last_name become required.
--
-- Since 0040, users is the only place a person's name lives — every
-- player, coach, and parent resolves their display name through this
-- one table, with no fallback anywhere else in the schema. A row with
-- no name is a person nobody can identify on any screen: roster, feed,
-- live cockpit, review history.
--
-- Backfills any existing gaps with a placeholder first, so the
-- constraint can be added without failing against real data.

update users set first_name = 'לא ידוע' where first_name is null;
update users set last_name = 'לא ידוע' where last_name is null;

alter table users alter column first_name set not null;
alter table users alter column last_name set not null;
