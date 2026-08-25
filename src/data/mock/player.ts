export type RsvpStatus = 'in' | 'out' | 'undecided';

export const currentPlayer = {
  name: 'Jonny K.',
  initials: 'JK',
  team: 'Maccabi TLV · U12 A',
};

export const nextEvent = {
  id: 'ev1',
  title: 'Practice',
  date: 'Today',
  time: '17:00 - 19:00',
  location: 'Maccabi Hall',
  rsvp: 'undecided' as RsvpStatus,
};

export const weeklyFocus = 'Ball-handling under pressure + free throw routine';

export const attendanceStreak = 6;

export const yearStats = [
  { label: 'Games Played', value: '14' },
  { label: 'Points / Game', value: '9.2' },
  { label: 'Attendance', value: '93%' },
  { label: 'Assists / Game', value: '3.1' },
];

export const upcomingEvents = [
  { id: 'e1', title: 'Practice', date: 'Today', time: '17:00', type: 'practice' as const },
  { id: 'e2', title: 'League Game vs Tigers', date: 'Thu', time: '10:00', type: 'game' as const },
  { id: 'e3', title: 'Practice', date: 'Fri', time: '17:00', type: 'practice' as const },
];

export const coachMessages = [
  { id: 'm1', author: 'Coach Dan', date: '2d ago', text: 'Great hustle at practice, keep the intensity up before Thursday’s game.' },
];
