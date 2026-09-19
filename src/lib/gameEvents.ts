import type { GameLine, SeasonTotals, ShotBadgeCounts } from '@/lib/playerData';

/**
 * `game_events_log.event_type` vocabulary.
 *
 * The DB CHECK constraint allows exactly these values:
 *   points_2, points_3, free_throw, foul, rebound, assist, turnover, steal,
 *   sub_in, sub_out
 * (there is no block event). The stats code aggregates on shorter internal
 * codes, so every read goes through `normalizeEventType`. Unknown values pass
 * through unchanged, which also keeps the legacy short codes working.
 */
export type StatEvent = 'fg2' | 'fg3' | 'ft' | 'reb' | 'ast' | 'stl' | 'tov' | 'foul' | 'sub_in' | 'sub_out';

const FROM_DB: Record<string, StatEvent> = {
  points_2: 'fg2',
  points_3: 'fg3',
  free_throw: 'ft',
  rebound: 'reb',
  assist: 'ast',
  steal: 'stl',
  turnover: 'tov',
  foul: 'foul',
  sub_in: 'sub_in',
  sub_out: 'sub_out',
};

export function normalizeEventType(dbValue: string): string {
  return FROM_DB[dbValue] ?? dbValue;
}

/** DB values for the two field-goal events, for `.in('event_type', ...)` filters. */
export const FIELD_GOAL_DB_TYPES = ['points_2', 'points_3'];

/**
 * Length of a quarter in seconds, used to turn (quarter, clock) into elapsed
 * game time for minutes played. The schema only stores the *current* clock
 * (default 600), not the quarter length, so this is an assumption: 10-minute
 * quarters. Change here if the league plays 8 or 12.
 */
export const QUARTER_SECONDS = 600;

/** Season totals + per-game averages from a player's game lines (pure, so fixtures can reuse it). */
export function buildTotals(games: GameLine[], badges: ShotBadgeCounts): SeasonTotals {
  const n = games.length;
  const sum = (f: (g: GameLine) => number) => games.reduce((a, g) => a + f(g), 0);
  const avg = (total: number) => (n > 0 ? Math.round((total / n) * 10) / 10 : null);
  const pct = (made: number, att: number) => (att > 0 ? Math.round((made / att) * 100) : null);
  const withMinutes = games.filter((g) => g.minutes != null);

  return {
    gamesPlayed: n,
    totalPts: sum((g) => g.pts),
    avgPts: avg(sum((g) => g.pts)),
    avgReb: avg(sum((g) => g.reb)),
    avgAst: avg(sum((g) => g.ast)),
    avgStl: avg(sum((g) => g.stl)),
    avgTov: avg(sum((g) => g.tov)),
    fgPct: pct(sum((g) => g.fgMade), sum((g) => g.fgAtt)),
    threePct: pct(sum((g) => g.fg3Made), sum((g) => g.fg3Att)),
    ftPct: pct(sum((g) => g.ftMade), sum((g) => g.ftAtt)),
    avgMin: withMinutes.length ? Math.round((withMinutes.reduce((a, g) => a + (g.minutes as number), 0) / withMinutes.length) * 10) / 10 : null,
    badges,
  };
}
