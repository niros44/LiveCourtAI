/**
 * CourtSide brand palette — ported from the Rookie/Coach/Parent HTML mockups
 * so the RN screens stay visually consistent with the approved designs.
 * Light-only for now; dark mode can be layered on later.
 */
export const colors = {
  navy: '#132B4D',
  navyDeep: '#0B1B34',
  paper: '#FBF9F5',
  ink: '#132B4D',
  inkSoft: 'rgba(19,43,77,0.58)',
  buzzer: '#FF6A1A',
  buzzerDark: '#C24E0E',
  tintNavy: '#EAF0F9',
  tintOrange: '#FFEBDF',
  tintGold: '#FFF4D9',
  gold: '#FFB627',
  goldDark: '#B9820A',
  green: '#2E9E5B',
  greenDark: '#1C6B3C',
  red: '#E4483C',
  redDark: '#A82E24',
  blue: '#0EA5E9',
  purple: '#8B5CF6',
  line: '#E7E1D4',
  white: '#FFFFFF',
  screenBackdrop: '#E4E0D2',
} as const;

export type BrandColor = keyof typeof colors;
