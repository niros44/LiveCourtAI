export const parent = {
  name: 'Sarah K.',
  initials: 'SK',
};

export const children = [
  { id: 'jonny', name: 'Jonny K.', initials: 'JK', team: 'Maccabi TLV · U12 A', color: '#FF6A1A' },
  { id: 'maya', name: 'Maya K.', initials: 'MK', team: 'Maccabi TLV · U10 B', color: '#8B5CF6' },
];

export const actionItems = [
  { id: 'a1', childId: 'jonny', title: 'Liability Waiver 2026/27 needs your signature', cta: 'Sign Now' },
  { id: 'a2', childId: 'maya', title: 'League fee balance is due', cta: 'Pay $45' },
];

export const parentEvents = [
  { id: 'e1', childId: 'jonny', title: 'Practice', date: 'Today', time: '17:00', location: 'Maccabi Hall', rsvp: 'undecided' as const },
  { id: 'e2', childId: 'maya', title: 'Practice', date: 'Today', time: '16:00', location: 'Maccabi Hall', rsvp: 'in' as const },
  { id: 'e3', childId: 'jonny', title: 'League Game vs Tigers', date: 'Thu', time: '10:00', location: 'Maccabi Hall', rsvp: 'in' as const },
];
