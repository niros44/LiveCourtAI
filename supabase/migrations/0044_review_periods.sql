-- CourtSide — review_period becomes a lookup table (UserStory 22).
-- Mid-season / end-season are the two conversation points today, but a
-- club may well want more later (season-opening, quarterly, exit
-- interview) — as rows that's an INSERT, not a migration.
--
-- Deliberately NOT doing the same to review_type (player_review /
-- coach_review): that one is a structural switch, not a list. A CHECK on
-- performance_reviews depends on its value to decide which subject
-- column must be filled, so turning it numeric would force that CHECK to
-- hardcode an id — the same brittleness already hit with roles. It also
-- won't grow: there are exactly two kinds of subject in this system.

create table review_periods (
  review_period_id int generated always as identity primary key,
  name text not null unique,
  display_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

insert into review_periods (name, display_order) values
  ('שיחת אמצע עונה', 1),
  ('שיחת סוף עונה', 2);

alter table review_periods enable row level security;
create policy "authenticated read/write — review_periods" on review_periods for all to authenticated using (true) with check (true);

-- Swap the text column for a numeric FK, mapping the existing values
-- across first so nothing is lost if rows already exist.
alter table performance_reviews add column review_period_id int references review_periods (review_period_id);

update performance_reviews set review_period_id = rp.review_period_id
from review_periods rp
where (performance_reviews.review_period = 'mid_season' and rp.name = 'שיחת אמצע עונה')
   or (performance_reviews.review_period = 'end_season' and rp.name = 'שיחת סוף עונה');

alter table performance_reviews alter column review_period_id set not null;
alter table performance_reviews drop column review_period;

-- The two partial unique indexes from 0025 referenced review_period, so
-- dropping that column dropped them too — recreate against the new
-- column. One review per subject per season per period, kept separate
-- for players and coaches because each uses a different subject column.
create unique index performance_reviews_one_player_review
  on performance_reviews (player_id, season_id, review_period_id)
  where review_type = 'player_review';

create unique index performance_reviews_one_coach_review
  on performance_reviews (reviewee_user_id, season_id, review_period_id)
  where review_type = 'coach_review';
