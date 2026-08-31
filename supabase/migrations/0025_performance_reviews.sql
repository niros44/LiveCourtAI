-- CourtSide — performance_reviews: self-rating + reviewer's final rating
-- (UserStory 22). Covers two cases, not just player reviews: a coach
-- reviewing a player, AND management reviewing a coach (spec 8 — "יכולת
-- לראות דירוג מאמנים"). Field names are generic (self_*/reviewer_*)
-- rather than player_*/coach_* so the same table works for both.
--
-- Exactly one of player_id / reviewee_user_id is set, matching which
-- review_type the row is — same "exactly one" pattern used for
-- team_members_one_subject earlier in this schema's history.

create table performance_reviews (
  id uuid primary key default gen_random_uuid(),
  review_type text not null check (review_type in ('player_review', 'coach_review')),
  player_id uuid references players (id) on delete cascade,
  reviewee_user_id uuid references users (id) on delete cascade,
  team_id uuid references teams (id) on delete set null,
  club_id uuid references clubs (id) on delete set null,
  season_id uuid not null references seasons (season_id) on delete cascade,
  review_period text not null check (review_period in ('mid_season', 'end_season')),
  self_rating int check (self_rating between 1 and 5),
  self_comments text,
  self_submitted_at timestamptz,
  reviewer_rating int check (reviewer_rating between 1 and 5),
  reviewer_comments text,
  reviewer_user_id uuid references users (id) on delete set null,
  status text not null default 'pending_self_rating' check (status in ('pending_self_rating', 'awaiting_reviewer', 'completed')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  check (
    (review_type = 'player_review' and player_id is not null and reviewee_user_id is null)
    or
    (review_type = 'coach_review' and reviewee_user_id is not null and player_id is null)
  )
);

-- One review per subject/season/period — split in two (rather than a
-- single unique(player_id, reviewee_user_id, ...)) because NULL columns
-- never conflict with each other in a plain UNIQUE constraint, the same
-- gap handled for user_roles' parent rows earlier.
create unique index performance_reviews_one_player_review
  on performance_reviews (player_id, season_id, review_period)
  where review_type = 'player_review';

create unique index performance_reviews_one_coach_review
  on performance_reviews (reviewee_user_id, season_id, review_period)
  where review_type = 'coach_review';

alter table performance_reviews enable row level security;
create policy "authenticated read/write — performance_reviews" on performance_reviews for all to authenticated using (true) with check (true);
