-- CourtSide — feedback_type reference table (UserStory 22).
-- feedback_id is int (not uuid, unlike seasons/age_group) — using an
-- identity column so it still auto-generates on insert like the uuid PKs
-- do elsewhere, rather than requiring a manually-assigned number.

create table feedback_type (
  feedback_id int generated always as identity primary key,
  feedback_name text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

alter table feedback_type enable row level security;
create policy "authenticated read/write — feedback_type" on feedback_type for all to authenticated using (true) with check (true);
