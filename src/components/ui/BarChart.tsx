import { StyleSheet, Text, View } from 'react-native';

import { colors } from '@/theme/colors';
import { fontSize, radius, spacing } from '@/theme/tokens';

export type BarDatum = { label: string; value: number | null };

type BarChartProps = {
  data: BarDatum[];
  /** Decimal places for the value printed above each bar. */
  decimals?: number;
  height?: number;
};

/**
 * Plain-View bar chart (no chart library): one bar per game, value on top,
 * label below, a dashed line at the average. The newest bar is solid navy,
 * earlier ones are a soft navy tint — one colour, no rainbow.
 */
export function BarChart({ data, decimals = 0, height = 140 }: BarChartProps) {
  const values = data.map((d) => d.value).filter((v): v is number => v != null);
  const max = Math.max(...values, 1);
  const avg = values.length ? values.reduce((a, b) => a + b, 0) / values.length : null;
  const lastIndex = data.length - 1;

  return (
    <View>
      <View style={[styles.plot, { height }]}>
        {avg != null ? <View style={[styles.avgLine, { bottom: (avg / max) * (height - 22) + 22 }]} /> : null}
        {data.map((d, i) => {
          const h = d.value != null ? Math.max(3, (d.value / max) * (height - 22)) : 0;
          return (
            <View key={`${d.label}-${i}`} style={styles.col}>
              <Text style={styles.value}>{d.value != null ? d.value.toFixed(decimals) : '–'}</Text>
              <View style={[styles.bar, { height: h }, i === lastIndex ? styles.barLatest : styles.barPast]} />
            </View>
          );
        })}
      </View>
      <View style={styles.labels}>
        {data.map((d, i) => (
          <Text key={`${d.label}-${i}`} style={styles.label} numberOfLines={1}>
            {d.label}
          </Text>
        ))}
      </View>
      {avg != null ? <Text style={styles.avgText}>Average {avg.toFixed(decimals === 0 ? 1 : decimals)}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  plot: { flexDirection: 'row', alignItems: 'flex-end', gap: spacing.xs },
  col: { flex: 1, alignItems: 'center', justifyContent: 'flex-end', gap: 3 },
  value: { fontSize: fontSize.caption, fontWeight: '700', color: colors.navy },
  bar: { width: '70%', borderRadius: radius.sm - 4 },
  barLatest: { backgroundColor: colors.navy },
  barPast: { backgroundColor: `${colors.navy}33` },
  avgLine: { position: 'absolute', left: 0, right: 0, borderTopWidth: 1, borderColor: colors.buzzer, borderStyle: 'dashed' },
  labels: { flexDirection: 'row', gap: spacing.xs, marginTop: spacing.xs },
  label: { flex: 1, textAlign: 'center', fontSize: 10, color: colors.inkSoft },
  avgText: { marginTop: spacing.sm, fontSize: fontSize.caption, color: colors.inkSoft },
});
