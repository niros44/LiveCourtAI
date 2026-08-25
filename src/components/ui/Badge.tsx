import { StyleSheet, Text, View } from 'react-native';

import { colors } from '@/theme/colors';

export type BadgeTone = 'in' | 'out' | 'neutral' | 'pending';

const TONE_STYLES: Record<BadgeTone, { bg: string; fg: string }> = {
  in: { bg: '#E9F7EF', fg: colors.greenDark },
  out: { bg: '#FDEDEC', fg: colors.redDark },
  neutral: { bg: colors.tintNavy, fg: colors.inkSoft },
  pending: { bg: '#FFF6E5', fg: colors.goldDark },
};

type BadgeProps = {
  label: string;
  tone?: BadgeTone;
};

/** Small status pill — mirrors `.status-badge` / `.rsvp-badge` in the mockups. */
export function Badge({ label, tone = 'neutral' }: BadgeProps) {
  const t = TONE_STYLES[tone];
  return (
    <View style={[styles.badge, { backgroundColor: t.bg }]}>
      <Text style={[styles.label, { color: t.fg }]}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  badge: {
    paddingVertical: 3,
    paddingHorizontal: 9,
    borderRadius: 8,
    alignSelf: 'flex-start',
  },
  label: {
    fontSize: 10.5,
    fontWeight: '700',
  },
});
