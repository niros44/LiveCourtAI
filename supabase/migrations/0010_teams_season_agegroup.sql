-- CourtSide — link teams to seasons and age_group (UserStory 22).
-- uuid, matching the actual primary keys on seasons.season_id and
-- age_group.agegroup_id (a foreign key must share its referenced
-- column's type, so this can't be int against those uuid PKs).

alter table teams add column season_id uuid references seasons (season_id) on delete set null;
alter table teams add column agegroup_id uuid references age_group (agegroup_id) on delete set null;
