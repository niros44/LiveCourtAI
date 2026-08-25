export const coach = {
  name: 'Dan Levi',
  initials: 'DL',
};

export const coachTeams = [
  { id: 'u14', name: 'U14 Maccabi', color: '#132B4D' },
  { id: 'u18', name: 'U18 Hapoel', color: '#FF6A1A' },
  { id: 'elite', name: 'Elite Academy', color: '#8B5CF6' },
];

export type CoachEventType = 'practice' | 'game';

export const coachEvents = [
  {
    id: 'ce1',
    teamId: 'u14',
    type: 'practice' as CoachEventType,
    title: 'Practice',
    time: '16:00 - 18:00',
    location: 'Maccabi Hall',
    attending: 12,
    roster: 12,
  },
  {
    id: 'ce2',
    teamId: 'u18',
    type: 'game' as CoachEventType,
    title: 'League Game vs. Tigers',
    time: '19:30 - 21:30',
    location: 'Home Arena',
    attending: 10,
    roster: 12,
  },
  {
    id: 'ce3',
    teamId: 'elite',
    type: 'practice' as CoachEventType,
    title: 'Individual Session',
    time: '17:00 - 17:45',
    location: 'Gym B',
    attending: 1,
    roster: 1,
  },
];
