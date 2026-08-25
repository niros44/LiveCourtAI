import { StyleSheet, Text, View } from 'react-native';

import { colors } from '@/theme/colors';
import { typography } from '@/theme/typography';

type SectionHeaderProps = {
  title: string;
  tag?: string;
};

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
    ...typography.heading,
    fontSize: 16,
    color: colors.navy,
  },
  tag: {
    ...typography.label,
    fontSize: 11,
    color: colors.buzzerDark,
  },
});
