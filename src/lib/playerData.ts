import * as fx from '@/lib/designFixtures';
import { QUARTER_SECONDS, buildTotals, normalizeEventType } from '@/lib/gameEvents';
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

// One calm identity colour: teams are told apart by name and jersey number, not by a rainbow.
const TEAM_COLORS = [colors.navy];

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
  /** Practices marked present or late (out of `practicesMarked`). */
  practicesAttended: number;
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
  let practicesAttended = 0;
  for (const r of rows) {
    if (r.status === 'present') present += 1;
    else if (r.status === 'late') late += 1;
    else if (r.status === 'absent') absent += 1;
    if (r.type === 'game') gamesMarked += 1;
    else if (r.type === 'practice') {
      practicesMarked += 1;
      if (r.status === 'present' || r.status === 'late') practicesAttended += 1;
    }
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
    practicesAttended,
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
  gamesPlayed: number;
  totalPts: number;
  avgPts: number | null;
  avgReb: number | null;
  avgAst: number | null;
  avgStl: number | null;
  avgTov: number | null;
  fgPct: number | null;
  threePct: number | null;
  ftPct: number | null;
  /** Minutes per game, over the games whose minutes could be worked out; null if none. */
  avgMin: number | null;
  badges: ShotBadgeCounts;
};

/** One game of the season, for the per-game charts. */
export type GameLine = {
  sessionId: string;
  eventId: string | null;
  startsAt: string | null;
  opponent: string | null;
  pts: number;
  reb: number;
  ast: number;
  stl: number;
  tov: number;
  fouls: number;
  fgMade: number;
  fgAtt: number;
  fg3Made: number;
  fg3Att: number;
  ftMade: number;
  ftAtt: number;
  /** null when the sub in/out log can't tell (no starter flag and no substitutions). */
  minutes: number | null;
};

export type SeasonStats = { totals: SeasonTotals; games: GameLine[] };

type GameBucket = Omit<GameLine, 'sessionId' | 'eventId' | 'startsAt' | 'opponent' | 'minutes'>;

const emptyBucket = (): GameBucket => ({ pts: 0, reb: 0, ast: 0, stl: 0, tov: 0, fouls: 0, fgMade: 0, fgAtt: 0, fg3Made: 0, fg3Att: 0, ftMade: 0, ftAtt: 0 });

/**
 * Minutes on court in one game, from the substitution log.
 * Elapsed game time = (quarter - 1) * QUARTER_SECONDS + (QUARTER_SECONDS - clock),
 * assuming the stored clock counts down within a quarter. A starter (listed in
 * the session lineup) is on court from 0 until a sub_out; a game with neither a
 * starter flag nor any substitution says nothing about minutes -> null.
 */
function minutesForGame(
  starter: boolean,
  subs: { type: string; quarter: number; clock: number | null }[],
  lastQuarter: number
): number | null {
  if (!starter && subs.length === 0) return null;
  const at = (s: { quarter: number; clock: number | null }) => (s.clock == null ? null : (s.quarter - 1) * QUARTER_SECONDS + (QUARTER_SECONDS - s.clock));

  const timed = subs.map((s) => ({ type: s.type, t: at(s) }));
  if (timed.some((s) => s.t == null)) return null;
  timed.sort((a, b) => (a.t as number) - (b.t as number));

  const gameEnd = Math.max(4, lastQuarter) * QUARTER_SECONDS;
  let onSince: number | null = starter ? 0 : null;
  let seconds = 0;
  for (const s of timed) {
    const t = s.t as number;
    if (s.type === 'sub_in' && onSince == null) onSince = t;
    else if (s.type === 'sub_out' && onSince != null) {
      seconds += t - onSince;
      onSince = null;
    }
  }
  if (onSince != null) seconds += gameEnd - onSince;
  return Math.round((seconds / 60) * 10) / 10;
}

/**
 * Season box-score for one player: per-game lines + totals/averages, built
 * from `game_events_log` (+ the session lineups for starters and the events
 * table for dates/opponents). Honestly empty until a live-game recorder
 * exists (see coachData.ts) — that is a real "no stats yet" result.
 */
export async function getSeasonStats(playerId: string): Promise<SeasonStats> {
  if (fx.DESIGN_PREVIEW) return fx.fxSeasonStats;

  const { data: logRows, error } = await supabase
    .from('game_events_log')
    .select('game_session_id, event_type, is_success, quarter, game_clock_snapshot')
    .eq('player_id', playerId)
    .eq('is_active', true);
  if (error) throw error;

  // Games the player started but has no stat line in still count as played.
  const { data: starterRows, error: starterError } = await supabase
    .from('games_live_session')
    .select('id')
    .or(`home_lineup.cs.{${playerId}},away_lineup.cs.{${playerId}}`);
  if (starterError) throw starterError;
  const starterSessions = new Set((starterRows ?? []).map((r) => r.id as string));

  const buckets = new Map<string, GameBucket>();
  const subsBySession = new Map<string, { type: string; quarter: number; clock: number | null }[]>();
  const lastQuarter = new Map<string, number>();
  const badges: ShotBadgeCounts = { fg2: 0, fg3: 0, ft: 0, fouls: 0, turnovers: 0 };

  for (const log of logRows ?? []) {
    const sessionId = log.game_session_id as string;
    const b = buckets.get(sessionId) ?? emptyBucket();
    const type = normalizeEventType(log.event_type as string);
    const success = Boolean(log.is_success);
    const quarter = (log.quarter as number | null) ?? 1;
    lastQuarter.set(sessionId, Math.max(lastQuarter.get(sessionId) ?? 1, quarter));

    if (type === 'fg2') {
      badges.fg2 += 1;
      b.fgAtt += 1;
      if (success) {
        b.fgMade += 1;
        b.pts += 2;
      }
    } else if (type === 'fg3') {
      badges.fg3 += 1;
      b.fgAtt += 1;
      b.fg3Att += 1;
      if (success) {
        b.fgMade += 1;
        b.fg3Made += 1;
        b.pts += 3;
      }
    } else if (type === 'ft') {
      badges.ft += 1;
      b.ftAtt += 1;
      if (success) {
        b.ftMade += 1;
        b.pts += 1;
      }
    } else if (type === 'reb') b.reb += 1;
    else if (type === 'ast') b.ast += 1;
    else if (type === 'stl') b.stl += 1;
    else if (type === 'tov') {
      b.tov += 1;
      badges.turnovers += 1;
    } else if (type === 'foul') {
      b.fouls += 1;
      badges.fouls += 1;
    } else if (type === 'sub_in' || type === 'sub_out') {
      const list = subsBySession.get(sessionId) ?? [];
      list.push({ type, quarter, clock: (log.game_clock_snapshot as number | null) ?? null });
      subsBySession.set(sessionId, list);
    }
    buckets.set(sessionId, b);
  }
  for (const id of starterSessions) if (!buckets.has(id)) buckets.set(id, emptyBucket());

  const sessionIds = [...buckets.keys()];
  if (!sessionIds.length) return { totals: buildTotals([], badges), games: [] };

  const { data: sessionRows } = await supabase.from('games_live_session').select('id, event_id').in('id', sessionIds);
  const eventBySession = new Map((sessionRows ?? []).map((s) => [s.id as string, s.event_id as string]));
  const eventIds = [...new Set(eventBySession.values())];
  const { data: eventRows } = eventIds.length
    ? await supabase.from('events').select('id, starts_at, opponent_name').in('id', eventIds)
    : { data: [] as { id: string; starts_at: string; opponent_name: string | null }[] };
  const eventById = new Map((eventRows ?? []).map((e) => [e.id as string, e]));

  const games: GameLine[] = sessionIds.map((sessionId) => {
    const eventId = eventBySession.get(sessionId) ?? null;
    const ev = eventId ? eventById.get(eventId) : undefined;
    return {
      sessionId,
      eventId,
      startsAt: (ev?.starts_at as string | undefined) ?? null,
      opponent: (ev?.opponent_name as string | null | undefined) ?? null,
      ...(buckets.get(sessionId) as GameBucket),
      minutes: minutesForGame(starterSessions.has(sessionId), subsBySession.get(sessionId) ?? [], lastQuarter.get(sessionId) ?? 1),
    };
  });
  games.sort((a, b) => (a.startsAt ?? '') .localeCompare(b.startsAt ?? ''));

  return { totals: buildTotals(games, badges), games };
}

export async function getSeasonTotals(playerId: string): Promise<SeasonTotals> {
  return (await getSeasonStats(playerId)).totals;
}

// ---------------------------------------------------------------------------
// Coach feedback the player received
// ---------------------------------------------------------------------------

export type FeedbackSummary = {
  total: number;
  /** null until `feedback_type.is_positive` exists in the DB (or if no type is flagged). */
  positive: number | null;
};

export async function getFeedbackSummary(playerId: string): Promise<FeedbackSummary> {
  if (fx.DESIGN_PREVIEW) return fx.fxFeedbackSummary;

  const withType = await supabase.from('player_feedback').select('id, feedback_type ( is_positive )').eq('player_id', playerId).eq('is_active', true);
  if (!withType.error) {
    const rows = withType.data ?? [];
    const positive = rows.filter((r) => (r as any).feedback_type?.is_positive === true).length;
    return { total: rows.length, positive };
  }

  // 42703 = column does not exist: the is_positive migration hasn't been applied yet.
  if (withType.error.code !== '42703') throw withType.error;
  const plain = await supabase.from('player_feedback').select('id').eq('player_id', playerId).eq('is_active', true);
  if (plain.error) throw plain.error;
  return { total: plain.data?.length ?? 0, positive: null };
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

/** The calendar week (Sunday 00:00 -> Saturday 23:59:59) containing `now`. */
export function getWeekRange(now = new Date()): { from: Date; to: Date } {
  const from = new Date(now);
  from.setHours(0, 0, 0, 0);
  from.setDate(from.getDate() - from.getDay());
  const to = new Date(from);
  to.setDate(to.getDate() + 6);
  to.setHours(23, 59, 59, 999);
  return { from, to };
}

export function formatEventDay(iso: string): string {
  return new Date(iso).toLocaleDateString('en-US', { weekday: 'short', day: 'numeric', month: 'short' });
}
export function formatEventTime(iso: string): string {
  return new Date(iso).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: false });
}
