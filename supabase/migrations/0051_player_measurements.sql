-- CourtSide — measurement history and the growth chart (UserStory 22).
--
-- players.height_cm was a single value, so every new measurement
-- overwrote the last one. Spec 2 ("מעקב צמיחה בגובה") and spec 7
-- ("תיעוד ומעקב ארוך טווח אחר מוטת ידיים... וקפיצה אנכית") both need a
-- line over time, which no amount of application code can reconstruct
-- from one number.
--
-- This table does NOT replace anything — it changes what the four
-- numeric columns on players MEAN. They stop being the source of truth
-- and become a cache of the latest measurement, kept in step by the
-- sync trigger below.
--
-- Keeping the cache rather than dropping those columns is deliberate:
-- the roster screen, the player card and the cockpit's Tap-Tap bubbles
-- all want height inline, and without it each of them turns into a
-- "latest measurement per player" subquery. Same denormalisation
-- already used for attendance.streak_count in 0039, but with the drift
-- problem solved — 0039 warned the counter could drift if edited
-- directly, whereas here the trigger makes drift impossible.
--
-- Contract change for app code: the coach's "update measurements"
-- screen must INSERT INTO player_measurements. Writing straight to
-- players will be overwritten by the next measurement.

create table if not exists player_measurements (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references players (id) on delete restrict,
  measured_on date not null default current_date,
  height_cm numeric(5,2),
  wingspan_cm numeric(5,2),
  weight_kg numeric(5,2),
  vertical_jump_cm numeric(5,2),
  recorded_by uuid references users (id) on delete set null,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- One session per player per day; a correction on the same day is an
  -- UPDATE, not a second row.
  constraint player_measurements_one_per_day unique (player_id, measured_on)
);

-- The growth chart itself: every point for one player, in order.
create index if not exists player_measurements_player_date_idx
  on player_measurements (player_id, measured_on desc);

alter table player_measurements enable row level security;
drop policy if exists "authenticated read/write — player_measurements" on player_measurements;
create policy "authenticated read/write — player_measurements"
  on player_measurements for all to authenticated using (true) with check (true);

drop trigger if exists set_updated_at on player_measurements;
create trigger set_updated_at before update on player_measurements
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- Reject a measurement dated in the future.
--
-- Deliberately a trigger and not CHECK (measured_on <= CURRENT_DATE):
-- CURRENT_DATE is not IMMUTABLE. Postgres accepts such a CHECK without
-- complaint, but it then breaks pg_restore and every ALTER TABLE that
-- rewrites the table — a failure that only shows up the day you try to
-- restore a backup.
-- ---------------------------------------------------------------------
create or replace function public.validate_measurement_date()
returns trigger language plpgsql as $fn$
begin
  if new.measured_on > current_date then
    raise exception 'measured_on (%) is in the future', new.measured_on;
  end if;
  return new;
end;
$fn$;

drop trigger if exists validate_measurement_date on player_measurements;
create trigger validate_measurement_date before insert or update on player_measurements
  for each row execute function public.validate_measurement_date();

-- ---------------------------------------------------------------------
-- Keep players.* holding the latest value of each metric.
--
-- Each metric is resolved independently rather than from one "latest
-- row": a session that measured only height must not blank out the
-- weight recorded last month.
-- ---------------------------------------------------------------------
create or replace function public.sync_player_latest_measurements()
returns trigger language plpgsql as $fn$
declare
  v_player uuid := coalesce(new.player_id, old.player_id);
begin
  update players p set
    height_cm = (select m.height_cm from player_measurements m
                 where m.player_id = v_player and m.is_active and m.height_cm is not null
                 order by m.measured_on desc, m.created_at desc limit 1),
    wingspan_cm = (select m.wingspan_cm from player_measurements m
                 where m.player_id = v_player and m.is_active and m.wingspan_cm is not null
                 order by m.measured_on desc, m.created_at desc limit 1),
    weight_kg = (select m.weight_kg from player_measurements m
                 where m.player_id = v_player and m.is_active and m.weight_kg is not null
                 order by m.measured_on desc, m.created_at desc limit 1),
    vertical_jump_cm = (select m.vertical_jump_cm from player_measurements m
                 where m.player_id = v_player and m.is_active and m.vertical_jump_cm is not null
                 order by m.measured_on desc, m.created_at desc limit 1)
  where p.id = v_player;
  return null;
end;
$fn$;

drop trigger if exists sync_player_measurements on player_measurements;
create trigger sync_player_measurements
  after insert or update or delete on player_measurements
  for each row execute function public.sync_player_latest_measurements();

-- Give the cached columns the same precision as the source of truth.
-- Bare numeric accepted any value at all; (5,2) tops out at 999.99,
-- which is past any real height, weight or jump in centimetres.
alter table players alter column height_cm        type numeric(5,2);
alter table players alter column wingspan_cm      type numeric(5,2);
alter table players alter column weight_kg        type numeric(5,2);
alter table players alter column vertical_jump_cm type numeric(5,2);

-- Preserve whatever is already on players as measurement number one, so
-- no existing value is stranded outside the history.
insert into player_measurements
  (player_id, measured_on, height_cm, wingspan_cm, weight_kg, vertical_jump_cm, notes)
select id, created_at::date, height_cm, wingspan_cm, weight_kg, vertical_jump_cm,
       'Backfilled from players by migration 0051'
from players
where height_cm is not null or wingspan_cm is not null
   or weight_kg is not null or vertical_jump_cm is not null
on conflict (player_id, measured_on) do nothing;
