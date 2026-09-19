import { StyleSheet, Text, ViewStyle } from 'react-native';

import { Card } from '@/components/ui/Card';
import { colors } from '@/theme/colors';
import { fontSize, spacing } from '@/theme/tokens';
import { typography } from '@/theme/typography';

type StatTileProps = {
  label: string;
  value: string;
  /** Small line under the label, e.g. "of 15 marked". */
  hint?: string;
  style?: ViewStyle;
};

/** A big number with its label — sized so two sit side by side and fill the row. */
export function StatTile({ label, value, hint, style }: StatTileProps) {
  return (
    <Card style={{ ...styles.tile, ...style }}>
      <Text style={styles.value}>{value}</Text>
      <Text style={styles.label}>{label}</Text>
      {hint ? <Text style={styles.hint}>{hint}</Text> : null}
    </Card>
  );
}

const styles = StyleSheet.create({
  tile: { flexGrow: 1, flexBasis: '45%', alignItems: 'center', paddingVertical: spacing.lg },
  value: { ...typography.heading, fontSize: fontSize.display, color: colors.navy },
  label: { fontSize: fontSize.caption, color: colors.inkSoft, marginTop: spacing.xs, textAlign: 'center' },
  hint: { fontSize: fontSize.caption, color: colors.inkSoft, marginTop: 2, textAlign: 'center' },
});
