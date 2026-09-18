import { supabase } from '@/lib/supabase';
import { colors } from '@/theme/colors';

/**
 * Parent-facing data access, backed by real Supabase tables (no mock data).
 *
 * Access chain (verified against live RLS policies):
 *  - guardians.user_id = me            -> which players are "my children"
 *  - team_members.player_id in (...)   -> which team(s) each child is on
 *  - events.team_id in (...)           -> events visible via current_user_team_ids()
 *  - event_responses(event_id, player_id) -> this child's RSVP for that event
 *
 * `event_responses` (RSVP) is a DIFFERENT table from `attendance` (the
 * coach's post-event actual-attendance log) — this module only ever touches
 * event_responses. Its `status` CHECK only allows 'attending' | 'not_attending'
 * | 'undecided' | 'injured', and `response_source` only allows 'player' |
 * 'guardian'. There is no color column anywhere on players/teams, so child
 * "colors" for the UI legend are assigned client-side from the app palette.
 */

const CHILD_COLORS = [colors.buzzer, colors.purple, colors.blue, colors.gold, colors.green, colors.red];

// ---------------------------------------------------------------------------
// Children
// ---------------------------------------------------------------------------

export type Child = {
  id: string; // players.id
  guardianId: string; // guardians.id
  name: string;
  firstName: string;
  initials: string;
  teamId: string | null;
  teamLabel: string; // "{club} · {team}"
  color: string;
  canRsvp: boolean;
};

export async function getMyChildren(personId: string): Promise<Child[]> {
  const { data: guardianRows, error } = await supabase
    .from('guardians')
    .select('id, player_id, can_rsvp, players ( id, first_name, last_name )')
    .eq('user_id', personId)
    .eq('is_active', true);
  if (error) throw error;

  const rows = guardianRows ?? [];
  if (!rows.length) return [];

  const playerIds = rows.map((r) => r.player_id as string);
  const { data: tmRows } = await supabase
    .from('team_members')
    .select('player_id, team_id, teams ( id, name, clubs ( name ) )')
    .in('player_id', playerIds)
    .eq('is_active', true);

  const teamByPlayer = new Map<string, { teamId: string; label: string }>();
  for (const tm of tmRows ?? []) {
    const team = (tm as any).teams as { id: string; name: string; clubs?: { name: string } } | null;
    if (!team) continue;
    const clubName = team.clubs?.name;
    teamByPlayer.set(tm.player_id as string, {
      teamId: tm.team_id as string,
      label: clubName ? `${clubName} · ${team.name}` : team.name,
    });
  }

  return rows.map((r, i) => {
    const player = (r as any).players as { first_name: string | null; last_name: string | null } | null;
    const first = player?.first_name ?? '';
    const last = player?.last_name ?? '';
    const name = [first, last].filter(Boolean).join(' ') || 'Player';
    const initials = `${first[0] ?? ''}${last[0] ?? ''}`.toUpperCase() || '?';
    const team = teamByPlayer.get(r.player_id as string);
    return {
      id: r.player_id as string,
      guardianId: r.id as string,
      name,
      firstName: first || name,
      initials,
      teamId: team?.teamId ?? null,
      teamLabel: team?.label ?? '',
      color: CHILD_COLORS[i % CHILD_COLORS.length],
      canRsvp: Boolean(r.can_rsvp),
    };
  });
}

/** The parent's own display name + initials, for the header avatar. */
export async function getMyProfile(personId: string): Promise<{ name: string; initials: string }> {
  const { data, error } = await supabase
    .from('users')
    .select('first_name, last_name')
    .eq('id', personId)
    .single();
  if (error) throw error;

  const first = data?.first_name ?? '';
  const last = data?.last_name ?? '';
  const name = [first, last].filter(Boolean).join(' ') || 'Parent';
  const initials = `${first[0] ?? ''}${last[0] ?? ''}`.toUpperCase() || '?';
  return { name, initials };
}

// ---------------------------------------------------------------------------
// Events + RSVPs
// ---------------------------------------------------------------------------

export type EventStatus = 'attending' | 'not_attending' | 'undecided' | 'injured';

export type ChildEvent = {
  id: string; // events.id
  childId: string; // players.id
  childName: string;
  childInitials: string;
  childColor: string;
  title: string;
  type: string; // 'practice' | 'game'
  eventStatus: string; // 'scheduled' | 'completed' | 'cancelled'
  startsAt: string;
  endsAt: string;
  facilityName: string | null;
  locationUrl: string | null;
  opponentName: string | null;
  isHomeGame: boolean | null;
  rsvp: EventStatus | null;
  canRsvp: boolean;
};

/**
 * Every event in `range` for any of `children`'s teams, one ChildEvent per
 * (event, child) pair — so a shared-team sibling scenario still shows one
 * card per child, each with that child's own RSVP.
 */
export async function getChildrenEvents(children: Child[], range: { from: Date; to: Date }): Promise<ChildEvent[]> {
  const teamIds = [...new Set(children.map((c) => c.teamId).filter((id): id is string => Boolean(id)))];
  if (!teamIds.length) return [];

  const { data: eventRows, error } = await supabase
    .from('events')
    .select(
      'id, team_id, type, title, starts_at, ends_at, status, opponent_name, is_home_game, facility_id, facilities ( name, location_url )'
    )
    .in('team_id', teamIds)
    .gte('starts_at', range.from.toISOString())
    .lte('starts_at', range.to.toISOString())
    .order('starts_at', { ascending: true });
  if (error) throw error;

  const events = eventRows ?? [];
  if (!events.length) return [];

  const playerIds = children.map((c) => c.id);
  const eventIds = events.map((e) => e.id as string);
  const { data: responseRows } = await supabase
    .from('event_responses')
    .select('event_id, player_id, status')
    .in('event_id', eventIds)
    .in('player_id', playerIds);

  const statusByKey = new Map<string, EventStatus>();
  for (const r of responseRows ?? []) {
    statusByKey.set(`${r.event_id}:${r.player_id}`, r.status as EventStatus);
  }

  const childrenByTeam = new Map<string, Child[]>();
  for (const c of children) {
    if (!c.teamId) continue;
    const list = childrenByTeam.get(c.teamId) ?? [];
    list.push(c);
    childrenByTeam.set(c.teamId, list);
  }

  const out: ChildEvent[] = [];
  for (const e of events) {
    const kids = childrenByTeam.get(e.team_id as string) ?? [];
    const facility = (e as any).facilities as { name: string; location_url: string | null } | null;
    for (const child of kids) {
      out.push({
        id: e.id as string,
        childId: child.id,
        childName: child.firstName,
        childInitials: child.initials,
        childColor: child.color,
        title: e.title as string,
        type: e.type as string,
        eventStatus: e.status as string,
        startsAt: e.starts_at as string,
        endsAt: e.ends_at as string,
        facilityName: facility?.name ?? null,
        locationUrl: facility?.location_url ?? null,
        opponentName: (e.opponent_name as string | null) ?? null,
        isHomeGame: (e.is_home_game as boolean | null) ?? null,
        rsvp: statusByKey.get(`${e.id}:${child.id}`) ?? null,
        canRsvp: child.canRsvp,
      });
    }
  }

  out.sort((a, b) => a.startsAt.localeCompare(b.startsAt));
  return out;
}

/** Upserts this guardian's RSVP for one child+event (event_responses is unique on (event_id, player_id)). */
export async function setEventResponse(
  eventId: string,
  playerId: string,
  status: EventStatus,
  respondedBy: string
): Promise<void> {
  const { error } = await supabase.from('event_responses').upsert(
    {
      event_id: eventId,
      player_id: playerId,
      status,
      response_source: 'guardian',
      responded_by: respondedBy,
      responded_at: new Date().toISOString(),
    },
    { onConflict: 'event_id,player_id' }
  );
  if (error) throw error;
}

// ---------------------------------------------------------------------------
// Formatting helpers shared by the Home + Events screens
// ---------------------------------------------------------------------------

export function formatEventDay(iso: string): string {
  return new Date(iso).toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
}

export function formatEventTime(iso: string): string {
  return new Date(iso).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: false });
}

export function isSameDay(a: Date, b: Date): boolean {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

export function startOfDay(d: Date): Date {
  const copy = new Date(d);
  copy.setHours(0, 0, 0, 0);
  return copy;
}

export function endOfDay(d: Date): Date {
  const copy = new Date(d);
  copy.setHours(23, 59, 59, 999);
  return copy;
}
