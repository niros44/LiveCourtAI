-- CourtSide — team_media: the closed team photo/video feed (UserStory 22).
-- Approval is scoped to age group, not the exact team: `reviewed_by`
-- just needs to be *some* coach of *some* team sharing this media's
-- team's agegroup_id — derived via teams/team_coaches at query time
-- (teams.agegroup_id -> team_coaches), no extra table needed for that.
--
-- No free-text comments anywhere in this feature (see team_media_reactions
-- below) — the anti-bullying design constraint from the spec is enforced
-- by the schema itself, not just the UI.

create table team_media (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references teams (id) on delete cascade,
  uploaded_by uuid not null references users (id) on delete cascade,
  event_id uuid references events (id) on delete set null,
  media_url text not null,
  media_type text not null check (media_type in ('image', 'video')),
  caption text,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  reviewed_by uuid references users (id) on delete set null,
  reviewed_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

-- Emoji-only reactions — one active reaction per user per media item.
-- No text column exists here at all, by design.
create table team_media_reactions (
  id uuid primary key default gen_random_uuid(),
  media_id uuid not null references team_media (id) on delete cascade,
  user_id uuid not null references users (id) on delete cascade,
  emoji text not null,
  created_at timestamptz not null default now(),
  unique (media_id, user_id)
);

alter table team_media enable row level security;
alter table team_media_reactions enable row level security;

-- Placeholder policies, same pattern as the rest of the schema: tighten
-- once the age-group-scoped approval check (above) has real screens.
create policy "authenticated read/write — team_media" on team_media for all to authenticated using (true) with check (true);
create policy "authenticated read/write — team_media_reactions" on team_media_reactions for all to authenticated using (true) with check (true);
