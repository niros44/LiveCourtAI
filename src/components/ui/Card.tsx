import { PropsWithChildren } from 'react';
import { StyleSheet, View, ViewStyle } from 'react-native';

import { colors } from '@/theme/colors';
import { radius, spacing } from '@/theme/tokens';

type CardProps = PropsWithChildren<{
  style?: ViewStyle;
  accentColor?: string;
}>;

/** Generic white bordered card used throughout the mockups (`.row-wrap`, `.stat-tile`, etc). */
export function Card({ children, style, accentColor }: CardProps) {
  return (
    <View
      style={[
        styles.card,
        accentColor ? { borderStartWidth: 3, borderStartColor: accentColor } : null,
        style,
      ]}>
      {children}
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: colors.white,
    borderWidth: 1,
    borderColor: colors.line,
    borderRadius: radius.md + 2,
    padding: spacing.lg - 2,
  },
});
