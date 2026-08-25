import { PropsWithChildren } from 'react';
import { StyleSheet, View, ViewStyle } from 'react-native';

import { colors } from '@/theme/colors';

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
        accentColor ? { borderLeftWidth: 3, borderLeftColor: accentColor } : null,
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
    borderRadius: 14,
    padding: 14,
  },
});
