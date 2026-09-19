import type { CourtMarker, Playbook } from '@/lib/coachData';
import type {
  Announcement,
  AttendanceSummary,
  EventStatus,
  FeedbackSummary,
  GameLine,
  Measurement,
  MyEvent,
  MyProfile,
  Playership,
  SeasonStats,
  SeasonTotals,
  TeamHeader,
  TeammateContact,
  WeeklyFocus,
} from '@/lib/playerData';
import { buildTotals } from '@/lib/gameEvents';
import { colors } from '@/theme/colors';

/**
 * DESIGN PREVIEW ONLY — realistic, fully-populated sample data for the player
 * screens, so layout work can be judged on screens that aren't empty.
 *
 * Switched on by `EXPO_PUBLIC_DESIGN_PREVIEW=1` in a dev build (see
 * DESIGN_PREVIEW below). It replaces reads and turns writes into
 * no-ops — the shared Supabase project is never touched. Delete this file
 * (and the `DESIGN_PREVIEW` early returns) once the design pass is done.
 */

/** Dev builds only; production bundles always get `false`. */
export const DESIGN_PREVIEW = __DEV__ && process.env.EXPO_PUBLIC_DESIGN_PREVIEW === '1';

const DAY = 24 * 60 * 60 * 1000;

/** `daysFromNow` at a given local hour. */
function at(daysFromNow: number, hour: number, minute = 0): Date {
  const d = new Date(Date.now() + daysFromNow * DAY);
  d.setHours(hour, minute, 0, 0);
  return d;
}

const PLAYER_ID = 'fx-player-1';

export const fxProfile: MyProfile = {
  personId: 'fx-person-1',
  name: 'Nir Sarid',
  initials: 'NS',
  avatarUrl: null,
  birthDate: '2010-04-12',
  age: 16,
};

export const fxPlayerships: Playership[] = [
  {
    playerId: PLAYER_ID,
    teamId: 'fx-team-1',
    clubId: 'fx-club-1',
    teamName: 'נתניה-4',
    clubName: 'אליצור נתניה',
    label: 'אליצור נתניה · נתניה-4',
    jersey: 14,
    color: colors.navy,
  },
  {
    playerId: PLAYER_ID,
    teamId: 'fx-team-2',
    clubId: 'fx-club-1',
    teamName: 'נבחרת מחוז',
    clubName: 'אליצור נתניה',
    label: 'אליצור נתניה · נבחרת מחוז',
    jersey: 7,
    color: colors.navy,
  },
];

export const fxTeamHeader = (teamId: string): TeamHeader => ({
  teamId,
  teamName: teamId === 'fx-team-2' ? 'נבחרת מחוז' : 'נתניה-4',
  clubName: 'אליצור נתניה',
  ageGroupName: 'U16',
  headCoachName: 'דני לוי',
  record: { wins: 7, losses: 3 },
});

type Template = {
  day: number;
  hour: number;
  minute?: number;
  type: 'practice' | 'game';
  title: string;
  facility: string;
  opponent?: string;
  home?: boolean;
  rsvp: EventStatus | null;
};

// Offsets are relative to today, so "next up" is always in the near future
// and a few past events exist for the schedule's history.
const TEMPLATES: Template[] = [
  { day: -9, hour: 18, type: 'practice', title: 'אימון - נתניה-4', facility: 'אולם אליצור נתניה', rsvp: 'attending' },
  { day: -5, hour: 19, minute: 30, type: 'game', title: 'משחק ליגה', facility: 'אולם מכבי חיפה', opponent: 'מכבי חיפה', home: false, rsvp: 'attending' },
  { day: -2, hour: 18, type: 'practice', title: 'אימון - נתניה-4', facility: 'אולם אליצור נתניה', rsvp: 'not_attending' },
  { day: 0, hour: 23, minute: 30, type: 'practice', title: 'אימון ערב', facility: 'אולם אליצור נתניה', rsvp: null },
  { day: 1, hour: 18, type: 'practice', title: 'אימון - נתניה-4', facility: 'אולם אליצור נתניה', rsvp: null },
  { day: 3, hour: 19, minute: 30, type: 'game', title: 'משחק ליגה', facility: 'אולם אליצור נתניה', opponent: 'הפועל חדרה', home: true, rsvp: null },
  { day: 5, hour: 18, type: 'practice', title: 'אימון - נתניה-4', facility: 'אולם אליצור נתניה', rsvp: 'undecided' },
  { day: 8, hour: 17, minute: 30, type: 'practice', title: 'אימון כושר', facility: 'מרכז הספורט העירוני', rsvp: 'injured' },
  { day: 10, hour: 20, type: 'game', title: 'משחק ליגה', facility: 'אולם בית״ר ירושלים', opponent: 'בית״ר ירושלים', home: false, rsvp: null },
  { day: 12, hour: 18, type: 'practice', title: 'אימון - נתניה-4', facility: 'אולם אליצור נתניה', rsvp: null },
  { day: 15, hour: 18, type: 'practice', title: 'אימון - נתניה-4', facility: 'אולם אליצור נתניה', rsvp: null },
  { day: 17, hour: 19, minute: 30, type: 'game', title: 'משחק גביע', facility: 'אולם אליצור נתניה', opponent: 'מכבי רעננה', home: true, rsvp: null },
  { day: 22, hour: 18, type: 'practice', title: 'אימון - נתניה-4', facility: 'אולם אליצור נתניה', rsvp: null },
  { day: 26, hour: 19, type: 'game', title: 'משחק ליגה', facility: 'אולם הפועל גליל עליון', opponent: 'הפועל גליל עליון', home: false, rsvp: null },
];

// Mutable so the RSVP buttons visibly react in preview (the write itself is a no-op).
const rsvpOverrides = new Map<string, EventStatus>();

export function fxEvents(playerships: Playership[], range: { from: Date; to: Date }): MyEvent[] {
  const teamIds = new Set(playerships.map((p) => p.teamId));
  const out: MyEvent[] = [];
  for (const teamId of teamIds) {
    TEMPLATES.forEach((t, i) => {
      // The second team plays a lighter, offset schedule.
      if (teamId === 'fx-team-2' && i % 3 !== 0) return;
      const start = at(t.day + (teamId === 'fx-team-2' ? 1 : 0), t.hour, t.minute ?? 0);
      if (start < range.from || start > range.to) return;
      const end = new Date(start.getTime() + (t.type === 'game' ? 2 : 1.5) * 60 * 60 * 1000);
      const id = `fx-${teamId}-${i}`;
      out.push({
        id,
        teamId,
        playerId: PLAYER_ID,
        type: t.type,
        title: t.title,
        eventStatus: start.getTime() < Date.now() ? 'completed' : 'scheduled',
        startsAt: start.toISOString(),
        endsAt: end.toISOString(),
        facilityName: t.facility,
        locationUrl: 'https://maps.google.com',
        opponentName: t.opponent ?? null,
        isHomeGame: t.home ?? null,
        rsvp: rsvpOverrides.get(id) ?? t.rsvp,
      });
    });
  }
  return out.sort((a, b) => (a.startsAt < b.startsAt ? -1 : 1));
}

export function fxSetRsvp(eventId: string, status: EventStatus): void {
  rsvpOverrides.set(eventId, status);
}

const NAMES: [string, string, string][] = [
  ['דניאל', 'כהן', 'PG'],
  ['יונתן', 'לוי', 'SG'],
  ['איתי', 'מזרחי', 'SF'],
  ['עומר', 'פרידמן', 'PF'],
  ['נועם', 'אברהם', 'C'],
  ['אורי', 'ביטון', 'SG'],
  ['רועי', 'דהן', 'PG'],
  ['תומר', 'שמעוני', 'SF'],
  ['גיא', 'אזולאי', 'PF'],
  ['אלון', 'חדד', 'C'],
  ['ליאור', 'גולן', 'SG'],
  ['יובל', 'רוזן', 'SF'],
];

export const fxRoster: TeammateContact[] = [
  ...NAMES.map(([first, last, position], i) => ({
    playerId: `fx-mate-${i}`,
    jersey: [3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 15, 21][i],
    name: `${first} ${last}`,
    initials: `${first[0]}${last[0]}`,
    position,
    cellphone: `050-${String(1000000 + i * 137911).slice(0, 7)}`,
    email: `player${i + 1}@example.com`,
  })),
  {
    playerId: PLAYER_ID,
    jersey: 14,
    name: 'Nir Sarid',
    initials: 'NS',
    position: 'SG',
    cellphone: '050-1234567',
    email: 'nir@example.com',
  },
].sort((a, b) => (a.jersey ?? 99) - (b.jersey ?? 99));

export const fxAttendance: AttendanceSummary = {
  totalMarked: 24,
  present: 19,
  late: 2,
  absent: 3,
  participationPct: 88,
  currentStreak: 6,
  gamesMarked: 9,
  practicesMarked: 15,
  practicesAttended: 13,
};

export const fxMeasurement: Measurement = {
  heightCm: 178,
  weightKg: 66,
  wingspanCm: 183,
  verticalJumpCm: 58,
  measuredOn: at(-30, 12).toISOString().slice(0, 10),
};

// Ten games, oldest first: [daysAgo, opponent, pts, reb, ast, stl, tov, fouls, fgM, fgA, 3M, 3A, ftM, ftA, min]
const GAME_ROWS: [number, string, number, number, number, number, number, number, number, number, number, number, number, number, number][] = [
  [63, 'מכבי חיפה', 9, 3, 2, 1, 3, 2, 4, 11, 0, 3, 1, 2, 17],
  [56, 'הפועל חדרה', 12, 5, 3, 2, 2, 3, 5, 12, 1, 4, 1, 2, 21],
  [49, 'בית״ר ירושלים', 15, 4, 4, 1, 3, 2, 6, 13, 1, 3, 2, 3, 24],
  [42, 'מכבי רעננה', 11, 6, 3, 2, 2, 4, 4, 10, 1, 4, 2, 2, 22],
  [35, 'הפועל גליל עליון', 18, 5, 5, 3, 1, 2, 7, 14, 2, 5, 2, 2, 26],
  [28, 'מכבי חיפה', 13, 4, 4, 1, 2, 3, 5, 12, 1, 3, 2, 4, 23],
  [21, 'הפועל חדרה', 17, 5, 3, 2, 3, 2, 7, 15, 2, 6, 1, 2, 25],
  [14, 'בית״ר ירושלים', 16, 4, 5, 2, 2, 1, 6, 12, 2, 4, 2, 3, 27],
  [9, 'מכבי רעננה', 20, 6, 4, 3, 1, 2, 8, 15, 2, 5, 2, 2, 28],
  [5, 'מכבי חיפה', 11, 4, 3, 1, 3, 3, 4, 11, 1, 4, 2, 3, 22],
];

const fxGames: GameLine[] = GAME_ROWS.map(([daysAgo, opponent, pts, reb, ast, stl, tov, fouls, fgMade, fgAtt, fg3Made, fg3Att, ftMade, ftAtt, minutes], i) => ({
  sessionId: `fx-session-${i}`,
  eventId: `fx-game-event-${i}`,
  startsAt: at(-daysAgo, 19, 30).toISOString(),
  opponent,
  pts,
  reb,
  ast,
  stl,
  tov,
  fouls,
  fgMade,
  fgAtt,
  fg3Made,
  fg3Att,
  ftMade,
  ftAtt,
  minutes,
}));

export const fxSeasonStats: SeasonStats = {
  totals: buildTotals(fxGames, { fg2: 96, fg3: 41, ft: 38, fouls: 22, turnovers: 21 }),
  games: fxGames,
};

export const fxSeasonTotals: SeasonTotals = fxSeasonStats.totals;

export const fxFeedbackSummary: FeedbackSummary = { total: 14, positive: 9 };

export const fxWeeklyFocus: WeeklyFocus = {
  title: 'הגנה בזוגות ותקשורת',
  description: 'השבוע עובדים על החלפות בהגנה, קריאות בקול רם ומעבר מהיר להתקפה אחרי חטיפה.',
  weekStart: at(-((new Date().getDay() + 6) % 7), 0).toISOString().slice(0, 10),
};

export const fxAnnouncements: Announcement[] = [
  {
    id: 'fx-ann-1',
    title: 'שינוי שעת אימון',
    content: 'האימון ביום חמישי יתחיל ב-19:00 במקום 18:00 בגלל אירוע באולם. נא להגיע עם בקבוק מים וחולצה בהירה.',
    authorName: 'דני לוי',
    teamName: 'נתניה-4',
    createdAt: at(-1, 9).toISOString(),
    isUrgent: true,
  },
  {
    id: 'fx-ann-2',
    title: 'משחק ביתי בשבת',
    content: 'מפגש בשעה 18:45 באולם. חובה נעליים נקיות ושתי חולצות (כהה ובהירה).',
    authorName: 'דני לוי',
    teamName: 'נתניה-4',
    createdAt: at(-3, 20).toISOString(),
    isUrgent: false,
  },
];

const m = (id: string, side: 'offense' | 'defense', x: number, y: number, path: { x: number; y: number }[] = []): CourtMarker => ({
  id,
  side,
  num: Number(id.slice(1)),
  x,
  y,
  path,
});

export const fxPlaybooks: Playbook[] = [
  {
    id: 'fx-pb-1',
    teamId: 'fx-team-1',
    title: 'התקפה - סטים',
    category: 'offense',
    plays: [
      {
        id: 'fx-play-1',
        playbookId: 'fx-pb-1',
        title: 'פיק אנד רול חמישייה',
        notes: 'הרכז מושך את ההגנה, הרכז החוצה פותח לשלוש. הסנטר גולל לסל.',
        displayOrder: 1,
        canvasData: {
          markers: [
            m('O1', 'offense', 0.5, 0.62, [{ x: 0.5, y: 0.62 }, { x: 0.62, y: 0.48 }]),
            m('O2', 'offense', 0.22, 0.38),
            m('O3', 'offense', 0.78, 0.38),
            m('O4', 'offense', 0.36, 0.22),
            m('O5', 'offense', 0.58, 0.46, [{ x: 0.58, y: 0.46 }, { x: 0.52, y: 0.18 }]),
          ],
        },
      },
      {
        id: 'fx-play-2',
        playbookId: 'fx-pb-1',
        title: 'קאט אחורי',
        notes: null,
        displayOrder: 2,
        canvasData: {
          markers: [
            m('O1', 'offense', 0.5, 0.66),
            m('O2', 'offense', 0.2, 0.4, [{ x: 0.2, y: 0.4 }, { x: 0.42, y: 0.16 }]),
            m('O3', 'offense', 0.8, 0.4),
            m('O4', 'offense', 0.35, 0.24),
            m('O5', 'offense', 0.65, 0.24),
          ],
        },
      },
    ],
  },
  {
    id: 'fx-pb-2',
    teamId: 'fx-team-1',
    title: 'הגנה - אזורית 2-3',
    category: 'defense',
    plays: [
      {
        id: 'fx-play-3',
        playbookId: 'fx-pb-2',
        title: 'אזורית 2-3 בסיסית',
        notes: 'שני הגארדים על קו העונשין, שלושת הגבוהים סביב הצבע.',
        displayOrder: 1,
        canvasData: {
          markers: [
            m('X1', 'defense', 0.38, 0.42),
            m('X2', 'defense', 0.62, 0.42),
            m('X3', 'defense', 0.24, 0.2),
            m('X4', 'defense', 0.5, 0.14),
            m('X5', 'defense', 0.76, 0.2),
          ],
        },
      },
    ],
  },
];
