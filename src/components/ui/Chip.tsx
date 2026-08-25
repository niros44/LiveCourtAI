import { Pressable, StyleSheet, Text } from 'react-native';

import { colors } from '@/theme/colors';

type ChipProps = {
  label: string;
  active?: boolean;
  onPress?: () => void;
};

/** Filter/switch chip — `.switch-chip` in the mockups. */
export function Chip({ label, active, onPress }: ChipProps) {
  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [
        styles.chip,
        active && styles.chipActive,
        pressed && { opacity: 0.8 },
      ]}>
      <Text style={[styles.label, active && styles.labelActive]}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  chip: {
    flexShrink: 0,
    paddingVertical: 8,
    paddingHorizontal: 14,
    borderRadius: 20,
    borderWidth: 1.5,
    borderColor: colors.line,
    backgroundColor: colors.white,
  },
  chipActive: {
    backgroundColor: colors.buzzer,
    borderColor: colors.buzzer,
  },
  label: {
    fontSize: 12,
    fontWeight: '600',
    color: colors.inkSoft,
  },
  labelActive: {
    color: colors.white,
  },
});
