-- CourtSide — live game cockpit: games_live_session + game_events_log
-- (UserStory 22, spec section 6).

create table games_live_session (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null unique references events (id) on delete cascade,
  quarter int not null default 1,
  game_clock_seconds int not null default 600,
  home_score int not null default 0,
  away_score int not null default 0,
  is_active boolean not null default true,
  started_at timestamptz,
  ended_at timestamptz
);

-- Play-by-play log: every tap in the cockpit. Feeds the box score,
-- +/- calculation, and heat maps (pos_x/pos_y).
create table game_events_log (
  id uuid primary key default gen_random_uuid(),
  game_session_id uuid not null references games_live_session (id) on delete cascade,
  player_id uuid not null references players (id) on delete cascade,
  team_id uuid not null references teams (id) on delete cascade,
  event_type text not null check (event_type in (
    'points_2', 'points_3', 'free_throw', 'foul', 'rebound',
    'assist', 'turnover', 'steal', 'sub_in', 'sub_out'
  )),
  is_success boolean not null default true,
  pos_x numeric(5, 2),
  pos_y numeric(5, 2),
  game_clock_snapshot int,
  created_at timestamptz not null default now()
);

-- Postgres doesn't auto-index FK columns (only the PK side they point
-- to) — explicit indexes here since this table is both write-heavy
-- (every cockpit tap) and read-heavy (box score / heat map queries).
create index game_events_log_session_idx on game_events_log (game_session_id);
create index game_events_log_player_idx on game_events_log (player_id);

alter table games_live_session enable row level security;
alter table game_events_log enable row level security;

create policy "authenticated read/write — games_live_session" on games_live_session for all to authenticated using (true) with check (true);
create policy "authenticated read/write — game_events_log" on game_events_log for all to authenticated using (true) with check (true);
