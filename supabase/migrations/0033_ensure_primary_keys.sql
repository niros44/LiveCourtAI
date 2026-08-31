-- CourtSide — safety net: ensure every table still has a primary key
-- (UserStory 22). Manual fixes during 0031 may have dropped user_roles'
-- PK along with the old `role` column, or others — this checks all 22
-- tables and adds back whichever PK is missing, on the correct column
-- for each. Safe to re-run: only acts where a PK is genuinely absent,
-- and RAISE NOTICE reports exactly what it fixed (visible in the SQL
-- Editor output).

do $$
declare
  t record;
begin
  for t in
    select * from (values
      ('users', 'id'),
      ('user_roles', 'id'),
      ('clubs', 'id'),
      ('teams', 'id'),
      ('players', 'id'),
      ('team_members', 'id'),
      ('team_coaches', 'id'),
      ('guardians', 'id'),
      ('events', 'id'),
      ('event_responses', 'id'),
      ('attendance', 'id'),
      ('player_feedback', 'id'),
      ('feedback_type', 'feedback_id'),
      ('seasons', 'season_id'),
      ('age_group', 'agegroup_id'),
      ('facilities', 'id'),
      ('team_media', 'id'),
      ('team_media_reactions', 'id'),
      ('games_live_session', 'id'),
      ('game_events_log', 'id'),
      ('performance_reviews', 'id'),
      ('roles', 'role_id')
    ) as x(table_name, pk_column)
  loop
    if not exists (
      select 1 from pg_constraint
      where conrelid = t.table_name::regclass and contype = 'p'
    ) then
      execute format('alter table %I add primary key (%I)', t.table_name, t.pk_column);
      raise notice 'Added missing PK on %.%', t.table_name, t.pk_column;
    end if;
  end loop;
end $$;
