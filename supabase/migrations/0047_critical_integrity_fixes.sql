-- CourtSide — critical data-integrity fixes (UserStory 22).
--
-- Written after a full read-only audit of the LIVE database
-- (pg_constraint / pg_indexes / pg_policies / information_schema),
-- not from the migration files — which turned out to disagree with
-- reality on point A below.
--
-- Idempotent: safe to run more than once.

-- ---------------------------------------------------------------------
-- A. users.first_name / last_name -> NOT NULL
--
-- 0046 is committed to this branch and claims to have done exactly
-- this, but the audit found both columns still nullable on the live DB
-- — the same half-applied-by-hand problem 0045 was written to fix for
-- user_roles.role_id (which DID land). Re-applying here so the branch
-- and the database finally agree.
--
-- Since 0040, users is the only place a person's name lives: every
-- player, coach and parent resolves their display name through this
-- one table, with no fallback anywhere. A row with no name is a person
-- no screen can render.
-- ---------------------------------------------------------------------
update users set first_name = 'לא ידוע' where first_name is null;
update users set last_name  = 'לא ידוע' where last_name  is null;

alter table users alter column first_name set not null;
alter table users alter column last_name  set not null;

-- ---------------------------------------------------------------------
-- B. players.user_id — an FK that contradicted its own column.
--
-- The column became NOT NULL in 0040, but the foreign key kept the
-- ON DELETE SET NULL action it was given back in 0002. The two rules
-- cancel each other out: deleting any user who is also a player made
-- Postgres try to null a NOT NULL column, so the DELETE could never
-- succeed — it failed with a not-null violation every time.
--
-- RESTRICT states that refusal honestly instead of failing halfway
-- through, and matches the spec's "no hard deletes" rule: a person who
-- leaves is deactivated (is_active = false), never deleted.
-- ---------------------------------------------------------------------
alter table players drop constraint if exists players_user_id_fkey;
alter table players
  add constraint players_user_id_fkey
  foreign key (user_id) references users (id) on delete restrict;

-- ---------------------------------------------------------------------
-- C. guardians.is_primary — wrong default, and nothing enforcing "one".
--
-- 0039 added the column with DEFAULT true, so every extra family
-- member added under spec 4 ("להוסיף בני משפחה (סבא, אח) עם הרשאות
-- צפייה בלו״ז בלבד") silently became a primary guardian of the child.
--
-- Behaviour change worth knowing: a newly inserted guardian is now
-- NOT primary. App code must set is_primary = true explicitly for the
-- registering parent during onboarding.
-- ---------------------------------------------------------------------
alter table guardians alter column is_primary set default false;

-- Demote all but the earliest primary per player, so the unique index
-- below is created against data that already satisfies it.
update guardians g set is_primary = false
where g.is_primary
  and g.id <> (
    select g2.id from guardians g2
    where g2.player_id = g.player_id and g2.is_primary
    order by g2.created_at, g2.id
    limit 1
  );

-- A partial unique index, not a UNIQUE constraint: the rule is "at most
-- one primary", so only the rows where is_primary is true participate.
create unique index if not exists guardians_one_primary_per_player
  on guardians (player_id) where is_primary;
