import { StyleSheet, Text, View } from 'react-native';

import { colors } from '@/theme/colors';
import { fontSize } from '@/theme/tokens';
import { typography } from '@/theme/typography';

type SectionHeaderProps = {
  title: string;
  tag?: string;
};

/** Quiet section label — content is the hero, not the heading. */
export function SectionHeader({ title, tag }: SectionHeaderProps) {
  return (
    <View style={styles.row}>
      <Text style={styles.title}>{title}</Text>
      {tag ? <Text style={styles.tag}>{tag}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'baseline',
    justifyContent: 'space-between',
  },
  title: {
    ...typography.label,
    fontSize: fontSize.small,
    color: colors.inkSoft,
  },
  tag: {
    fontSize: fontSize.small,
    fontWeight: '600',
    color: colors.inkSoft,
  },
});
