import * as fx from '@/lib/designFixtures';
import { supabase } from '@/lib/supabase';
import { colors } from '@/theme/colors';

/**
 * Player-facing ("Rookie Mode") data access, backed by real Supabase tables.
 *
 * Reuses the same access chain already verified for Coach/Parent:
 *  - players.user_id = me                -> my own player row(s)
 *  - team_members.player_id in (mine)    -> which team(s) I'm on (a player
 *    can be on more than one team — one players.id, several team_members)
 *  - events / event_responses            -> schedule + my own RSVP
 *  - attendance (coach-marked, real)     -> participation %, attendance streak
 *  - player_measurements / game_events_log -> physical + per-game stats
 *    (game_events_log has no writer UI anywhere in this app yet, so season
 *    averages honestly resolve to "no stats recorded" until a live-game
 *    recorder exists — see coachData.ts's getLastGameBoxScore for the same
 *    note)
 *  - playbooks / plays (read-only here) + play_views (logs that I watched one)
 *  - team_weekly_focus / announcements   -> read-only team messages
 *
 * Team-member "contact card" (Team tab) deliberately reads users.cellphone /
 * email for teammates — RLS (`current_user_visible_person_ids`) already
 * allows this for anyone sharing a team, and showing it here was an explicit
 * product decision, not an RLS workaround.
 */

const TEAM_COLORS = [colors.navy, colors.buzzer, colors.purple, colors.blue, colors.green, colors.gold];

// ---------------------------------------------------------------------------
// My profile + team membership(s)
// ---------------------------------------------------------------------------

export type MyProfile = {
  personId: string;
  name: string;
  initials: string;
  avatarUrl: string | null;
  birthDate: string | null;
  age: number | null;
};

export async function getMyProfile(personId: string): Promise<MyProfile> {
  if (fx.DESIGN_PREVIEW) return fx.fxProfile;
  const { data, error } = await supabase.from('users').select('first_name, last_name, avatar_url').eq('id', personId).single();
  if (error) throw error;
  const first = data?.first_name ?? '';
  const last = data?.last_name ?? '';
  const name = [first, last].filter(Boolean).join(' ') || 'Player';

  const { data: playerRows } = await supabase.from('players').select('birth_date').eq('user_id', personId).limit(1);
  const birthDate = (playerRows?.[0]?.birth_date as string | null) ?? null;

  return {
    personId,
    name,
    initials: `${first[0] ?? ''}${last[0] ?? ''}`.toUpperCase() || '?',
    avatarUrl: (data?.avatar_url as string | null) ?? null,
    birthDate,
    age: birthDate ? ageFromBirthDate(birthDate) : null,
  };
}

function ageFromBirthDate(birthDate: string): number {
  const dob = new Date(birthDate);
  const now = new Date();
  let age = now.getFullYear() - dob.getFullYear();
  const monthDiff = now.getMonth() - dob.getMonth();
  if (monthDiff < 0 || (monthDiff === 0 && now.getDate() < dob.getDate())) age -= 1;
  return age;
}

export type Playership = {
  playerId: string;
  teamId: string;
  clubId: string;
  teamName: string;
  clubName: string;
  label: string;
  jersey: number | null;
  color: string;
};

export async function getMyPlayerships(personId: string): Promise<Playership[]> {
  if (fx.DESIGN_PREVIEW) return fx.fxPlayerships;
  const { data: playerRows, error } = await supabase.from('players').select('id').eq('user_id', personId);
  if (error) throw error;
  const playerIds = (playerRows ?? []).map((p) => p.id as string);
  if (!playerIds.length) return [];

  const { data, error: tmError } = await supabase
    .from('team_members')
    .select('player_id, jersey_number, team_id, teams ( id, name, club_id, clubs ( name ) )')
    .in('player_id', playerIds)
    .eq('is_active', true);
  if (tmError) throw tmError;

  return (data ?? []).map((r, i) => {
    const t = (r as any).teams as { id: string; name: string; club_id: string; clubs?: { name: string } } | null;
    return {
      playerId: r.player_id as string,
      teamId: r.team_id as string,
      clubId: t?.club_id ?? '',
      teamName: t?.name ?? '',
      clubName: t?.clubs?.name ?? '',
      label: t?.clubs?.name ? `${t.clubs.name} · ${t.name}` : t?.name ?? '',
      jersey: (r.jersey_number as number | null) ?? null,
      color: TEAM_COLORS[i % TEAM_COLORS.length],
    };
  });
}

export type TeamHeader = {
  teamId: string;
  teamName: string;
  clubName: string;
  ageGroupName: string | null;
  headCoachName: string | null;
  record: { wins: number; losses: number } | null;
};

export async function getTeamHeader(teamId: string): Promise<TeamHeader | null> {
  if (fx.DESIGN_PREVIEW) return fx.fxTeamHeader(teamId);
  const { data: team, error } = await supabase
    .from('teams')
    .select('id, name, club_id, clubs ( name ), age_group ( agegroup_name )')
    .eq('id', teamId)
    .single();
  if (error) throw error;
  if (!team) return null;

  const { data: coachRows, error: coachError } = await supabase
    .from('team_coaches')
    .select('role, users!team_coaches_user_id_fkey ( first_name, last_name )')
    .eq('team_id', teamId)
    .eq('is_active', true)
    .order('role', { ascending: true });
  // The coach name is decoration, so don't fail the whole header over it — but don't hide the reason either.
  if (coachError) console.warn('[getTeamHeader] head coach lookup failed:', coachError.message);
  const headCoach = (coachRows ?? []).find((c) => c.role === 'head_coach') ?? coachRows?.[0];
  const coachUser = (headCoach as any)?.users as { first_name: string | null; last_name: string | null } | undefined;
  const headCoachName = coachUser ? [coachUser.first_name, coachUser.last_name].filter(Boolean).join(' ') || null : null;

  // Record is only ever computed from real completed-game scores — with no
  // live-game recorder in the app yet, games_live_session is normally empty
  // and this honestly returns null (hidden in the UI) rather than "0-0".
  const { data: gameEvents } = await supabase.from('events').select('id, is_home_game').eq('team_id', teamId).eq('type', 'game').eq('status', 'completed');
  let wins = 0;
  let losses = 0;
  if (gameEvents?.length) {
    const { data: sessions } = await supabase
      .from('games_live_session')
      .select('event_id, home_score, away_score')
      .in(
        'event_id',
        gameEvents.map((e) => e.id as string)
      );
    const byEvent = new Map(gameEvents.map((e) => [e.id as string, e.is_home_game as boolean | null]));
    for (const s of sessions ?? []) {
      const isHome = byEvent.get(s.event_id as string);
      if (isHome === null || isHome === undefined) continue;
      const us = isHome ? (s.home_score as number) : (s.away_score as number);
      const them = isHome ? (s.away_score as number) : (s.home_score as number);
      if (us > them) wins += 1;
      else if (us < them) losses += 1;
    }
  }

  return {
    teamId: team.id as string,
    teamName: team.name as string,
    clubName: (team as any).clubs?.name ?? '',
    ageGroupName: (team as any).age_group?.agegroup_name ?? null,
    headCoachName,
    record: wins + losses > 0 ? { wins, losses } : null,
  };
}

// ---------------------------------------------------------------------------
// Schedule + my own RSVP
// ---------------------------------------------------------------------------

export type EventStatus = 'attending' | 'not_attending' | 'undecided' | 'injured';

export type MyEvent = {
  id: string;
  teamId: string;
  playerId: string;
  type: string;
  title: string;
  eventStatus: string;
  startsAt: string;
  endsAt: string;
  facilityName: string | null;
  locationUrl: string | null;
  opponentName: string | null;
  isHomeGame: boolean | null;
  rsvp: EventStatus | null;
};

export async function getMyEvents(playerships: Playership[], range: { from: Date; to: Date }): Promise<MyEvent[]> {
  if (fx.DESIGN_PREVIEW) return fx.fxEvents(playerships, range);
  const teamIds = [...new Set(playerships.map((p) => p.teamId))];
  if (!teamIds.length) return [];

  const { data: eventRows, error } = await supabase
    .from('events')
    .select(
      'id, team_id, type, title, starts_at, ends_at, status, opponent_name, is_home_game, facility_id, facilities ( name, location_url )'
    )
    .in('team_id', teamIds)
    .eq('is_active', true)
    .gte('starts_at', range.from.toISOString())
    .lte('starts_at', range.to.toISOString())
    .order('starts_at', { ascending: true });
  if (error) throw error;

  const events = eventRows ?? [];
  if (!events.length) return [];

  const playerByTeam = new Map(playerships.map((p) => [p.teamId, p.playerId]));
  const playerIds = [...new Set(playerships.map((p) => p.playerId))];
  const eventIds = events.map((e) => e.id as string);
  const { data: responseRows } = await supabase.from('event_responses').select('event_id, player_id, status').in('event_id', eventIds).in('player_id', playerIds);

  const statusByKey = new Map<string, EventStatus>();
  for (const r of responseRows ?? []) statusByKey.set(`${r.event_id}:${r.player_id}`, r.status as EventStatus);

  return events.map((e) => {
    const playerId = playerByTeam.get(e.team_id as string) as string;
    const facility = (e as any).facilities as { name: string; location_url: string | null } | null;
    return {
      id: e.id as string,
      teamId: e.team_id as string,
      playerId,
      type: e.type as string,
      title: e.title as string,
      eventStatus: e.status as string,
      startsAt: e.starts_at as string,
      endsAt: e.ends_at as string,
      facilityName: facility?.name ?? null,
      locationUrl: facility?.location_url ?? null,
      opponentName: (e.opponent_name as string | null) ?? null,
      isHomeGame: (e.is_home_game as boolean | null) ?? null,
      rsvp: statusByKey.get(`${e.id}:${playerId}`) ?? null,
    };
  });
}

export async function setMyRsvp(eventId: string, playerId: string, status: EventStatus, respondedBy: string): Promise<void> {
  if (fx.DESIGN_PREVIEW) return fx.fxSetRsvp(eventId, status);
  const { error } = await supabase.from('event_responses').upsert(
    { event_id: eventId, player_id: playerId, status, response_source: 'player', responded_by: respondedBy, responded_at: new Date().toISOString() },
    { onConflict: 'event_id,player_id' }
  );
  if (error) throw error;
}

// ---------------------------------------------------------------------------
// Roster (Team tab) — includes teammate contact info by product decision
// ---------------------------------------------------------------------------

export type TeammateContact = {
  playerId: string;
  jersey: number | null;
  name: string;
  initials: string;
  position: string | null;
  cellphone: string | null;
  email: string | null;
};

export async function getTeamRoster(teamId: string): Promise<TeammateContact[]> {
  if (fx.DESIGN_PREVIEW) return fx.fxRoster;
  const { data, error } = await supabase
    .from('team_members')
    .select('jersey_number, court_position, players ( id, first_name, last_name, users!players_user_id_fkey ( cellphone, email ) )')
    .eq('team_id', teamId)
    .eq('is_active', true)
    .order('jersey_number', { ascending: true });
  if (error) throw error;

  return (data ?? []).map((r) => {
    const p = (r as any).players as { id: string; first_name: string | null; last_name: string | null; users?: { cellphone: string | null; email: string | null } } | null;
    const first = p?.first_name ?? '';
    const last = p?.last_name ?? '';
    const name = [first, last].filter(Boolean).join(' ') || 'Player';
    return {
      playerId: p?.id as string,
      jersey: (r.jersey_number as number | null) ?? null,
      name,
      initials: `${first[0] ?? ''}${last[0] ?? ''}`.toUpperCase() || '?',
      position: (r.court_position as string | null) ?? null,
      cellphone: p?.users?.cellphone ?? null,
      email: p?.users?.email ?? null,
    };
  });
}

// ---------------------------------------------------------------------------
// Attendance (real data) — participation % + a self-computed streak
// ---------------------------------------------------------------------------

export type AttendanceSummary = {
  totalMarked: number;
  present: number;
  late: number;
  absent: number;
  participationPct: number | null;
  currentStreak: number;
  gamesMarked: number;
  practicesMarked: number;
};

export async function getAttendanceSummary(playerId: string): Promise<AttendanceSummary> {
  if (fx.DESIGN_PREVIEW) return fx.fxAttendance;
  const { data, error } = await supabase
    .from('attendance')
    .select('status, events ( type, starts_at )')
    .eq('player_id', playerId)
    .eq('is_active', true);
  if (error) throw error;

  const rows = (data ?? [])
    .map((r) => ({ status: r.status as string, type: (r as any).events?.type as string | undefined, startsAt: (r as any).events?.starts_at as string | undefined }))
    .filter((r) => r.startsAt)
    .sort((a, b) => (a.startsAt! < b.startsAt! ? 1 : -1)); // most recent first

  let present = 0;
  let late = 0;
  let absent = 0;
  let gamesMarked = 0;
  let practicesMarked = 0;
  for (const r of rows) {
    if (r.status === 'present') present += 1;
    else if (r.status === 'late') late += 1;
    else if (r.status === 'absent') absent += 1;
    if (r.type === 'game') gamesMarked += 1;
    else if (r.type === 'practice') practicesMarked += 1;
  }

  let currentStreak = 0;
  for (const r of rows) {
    if (r.status === 'present' || r.status === 'late') currentStreak += 1;
    else break;
  }

  const totalMarked = rows.length;
  return {
    totalMarked,
    present,
    late,
    absent,
    participationPct: totalMarked > 0 ? Math.round(((present + late) / totalMarked) * 100) : null,
    currentStreak,
    gamesMarked,
    practicesMarked,
  };
}

// ---------------------------------------------------------------------------
// Physical measurements + season box-score totals
// ---------------------------------------------------------------------------

export type Measurement = { heightCm: number | null; weightKg: number | null; wingspanCm: number | null; verticalJumpCm: number | null; measuredOn: string | null };

export async function getMyMeasurement(playerId: string): Promise<Measurement | null> {
  if (fx.DESIGN_PREVIEW) return fx.fxMeasurement;
  const { data, error } = await supabase
    .from('player_measurements')
    .select('height_cm, weight_kg, wingspan_cm, vertical_jump_cm, measured_on')
    .eq('player_id', playerId)
    .eq('is_current', true)
    .limit(1);
  if (error) throw error;
  const row = data?.[0];
  if (!row) return null;
  return {
    heightCm: (row.height_cm as number | null) ?? null,
    weightKg: (row.weight_kg as number | null) ?? null,
    wingspanCm: (row.wingspan_cm as number | null) ?? null,
    verticalJumpCm: (row.vertical_jump_cm as number | null) ?? null,
    measuredOn: (row.measured_on as string | null) ?? null,
  };
}

export type ShotBadgeCounts = { fg2: number; fg3: number; ft: number; fouls: number; turnovers: number };

export type SeasonTotals = {
  gamesWithStats: number;
  totalPts: number;
  avgPts: number | null;
  avgReb: number | null;
  avgAst: number | null;
  avgStl: number | null;
  avgBlk: number | null;
  avgTov: number | null;
  fgPct: number | null;
  threePct: number | null;
  badges: ShotBadgeCounts;
};

/**
 * Aggregates every `game_events_log` row this player has, across the whole
 * season, into season totals + per-game averages. Honestly empty until a
 * live-game recorder exists anywhere in the app (see coachData.ts note) —
 * this is a real "no stats yet" result, not a loading bug.
 */
export async function getSeasonTotals(playerId: string): Promise<SeasonTotals> {
  if (fx.DESIGN_PREVIEW) return fx.fxSeasonTotals;
  const { data: logRows, error } = await supabase.from('game_events_log').select('game_session_id, event_type, is_success').eq('player_id', playerId);
  if (error) throw error;

  const bySession = new Map<string, { pts: number; reb: number; ast: number; stl: number; blk: number; tov: number; fgMade: number; fgAtt: number; fg3Made: number; fg3Att: number }>();
  const badges: ShotBadgeCounts = { fg2: 0, fg3: 0, ft: 0, fouls: 0, turnovers: 0 };

  for (const log of logRows ?? []) {
    const sessionId = log.game_session_id as string;
    const bucket = bySession.get(sessionId) ?? { pts: 0, reb: 0, ast: 0, stl: 0, blk: 0, tov: 0, fgMade: 0, fgAtt: 0, fg3Made: 0, fg3Att: 0 };
    const type = log.event_type as string;
    const success = Boolean(log.is_success);
    if (type === 'fg2') {
      badges.fg2 += 1;
      bucket.fgAtt += 1;
      if (success) {
        bucket.fgMade += 1;
        bucket.pts += 2;
      }
    } else if (type === 'fg3') {
      badges.fg3 += 1;
      bucket.fgAtt += 1;
      bucket.fg3Att += 1;
      if (success) {
        bucket.fgMade += 1;
        bucket.fg3Made += 1;
        bucket.pts += 3;
      }
    } else if (type === 'ft') {
      badges.ft += 1;
      if (success) bucket.pts += 1;
    } else if (type === 'reb') bucket.reb += 1;
    else if (type === 'ast') bucket.ast += 1;
    else if (type === 'stl') bucket.stl += 1;
    else if (type === 'blk') bucket.blk += 1;
    else if (type === 'tov') {
      bucket.tov += 1;
      badges.turnovers += 1;
    } else if (type === 'foul') badges.fouls += 1;
    bySession.set(sessionId, bucket);
  }

  const sessions = [...bySession.values()];
  const gamesWithStats = sessions.length;
  const sum = (f: (s: (typeof sessions)[number]) => number) => sessions.reduce((a, s) => a + f(s), 0);
  const avg = (total: number) => (gamesWithStats > 0 ? Math.round((total / gamesWithStats) * 10) / 10 : null);

  const totalFgMade = sum((s) => s.fgMade);
  const totalFgAtt = sum((s) => s.fgAtt);
  const total3Made = sum((s) => s.fg3Made);
  const total3Att = sum((s) => s.fg3Att);

  return {
    gamesWithStats,
    totalPts: sum((s) => s.pts),
    avgPts: avg(sum((s) => s.pts)),
    avgReb: avg(sum((s) => s.reb)),
    avgAst: avg(sum((s) => s.ast)),
    avgStl: avg(sum((s) => s.stl)),
    avgBlk: avg(sum((s) => s.blk)),
    avgTov: avg(sum((s) => s.tov)),
    fgPct: totalFgAtt > 0 ? Math.round((totalFgMade / totalFgAtt) * 100) : null,
    threePct: total3Att > 0 ? Math.round((total3Made / total3Att) * 100) : null,
    badges,
  };
}

// ---------------------------------------------------------------------------
// Team weekly focus + announcements (read-only here)
// ---------------------------------------------------------------------------

export type WeeklyFocus = { title: string; description: string | null; weekStart: string };

export async function getCurrentWeeklyFocus(teamId: string): Promise<WeeklyFocus | null> {
  if (fx.DESIGN_PREVIEW) return fx.fxWeeklyFocus;
  const { data, error } = await supabase
    .from('team_weekly_focus')
    .select('focus_title, description, week_start_date')
    .eq('team_id', teamId)
    .lte('week_start_date', new Date().toISOString().slice(0, 10))
    .order('week_start_date', { ascending: false })
    .limit(1);
  if (error) throw error;
  const row = data?.[0];
  if (!row) return null;
  return { title: row.focus_title as string, description: (row.description as string | null) ?? null, weekStart: row.week_start_date as string };
}

export type Announcement = { id: string; title: string; content: string; authorName: string; teamName: string | null; createdAt: string; isUrgent: boolean };

export async function getAnnouncements(playerships: Playership[], limit = 10): Promise<Announcement[]> {
  if (fx.DESIGN_PREVIEW) return fx.fxAnnouncements;
  const teamIds = [...new Set(playerships.map((p) => p.teamId))];
  const clubIds = [...new Set(playerships.map((p) => p.clubId).filter(Boolean))];
  if (!teamIds.length && !clubIds.length) return [];

  const orClauses = [teamIds.length ? `team_id.in.(${teamIds.join(',')})` : null, clubIds.length ? `club_id.in.(${clubIds.join(',')})` : null].filter(Boolean).join(',');

  const { data, error } = await supabase
    .from('announcements')
    .select('id, title, content, is_urgent, created_at, team_id, teams ( name ), users!announcements_author_id_fkey ( first_name, last_name )')
    .or(orClauses)
    .eq('is_active', true)
    .order('created_at', { ascending: false })
    .limit(limit);
  if (error) throw error;

  return (data ?? []).map((r) => {
    const author = (r as any).users as { first_name: string | null; last_name: string | null } | null;
    return {
      id: r.id as string,
      title: r.title as string,
      content: r.content as string,
      authorName: author ? [author.first_name, author.last_name].filter(Boolean).join(' ') || 'Coach' : 'Coach',
      teamName: (r as any).teams?.name ?? null,
      createdAt: r.created_at as string,
      isUrgent: Boolean(r.is_urgent),
    };
  });
}

// ---------------------------------------------------------------------------
// Playbook (read-only) — types/shape shared with coachData.ts
// ---------------------------------------------------------------------------

export async function logPlayView(playId: string, playerId: string): Promise<void> {
  if (fx.DESIGN_PREVIEW) return;
  const { error } = await supabase.from('play_views').insert({ play_id: playId, player_id: playerId, viewed_at: new Date().toISOString() });
  if (error) throw error;
}

export function formatEventDay(iso: string): string {
  return new Date(iso).toLocaleDateString('en-US', { weekday: 'short', day: 'numeric', month: 'short' });
}
export function formatEventTime(iso: string): string {
  return new Date(iso).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: false });
}
