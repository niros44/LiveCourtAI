import { ReactNode } from 'react';
import { StyleSheet, Text, View } from 'react-native';

import { Avatar } from '@/components/ui/Avatar';
import { colors } from '@/theme/colors';
import { fontSize, spacing } from '@/theme/tokens';
import { typography } from '@/theme/typography';

type ScreenHeaderProps = {
  /** Screen name ("Schedule") or, on a home screen, the person's name. */
  title: string;
  /** Active context — usually the club · team label. */
  subtitle?: string;
  /** Show the person's initials avatar at the start. */
  initials?: string;
  /** Trailing slot (notifications, role switcher, an action). */
  right?: ReactNode;
};

/** The one header every screen starts with, so the top of the app looks the same everywhere. */
export function ScreenHeader({ title, subtitle, initials, right }: ScreenHeaderProps) {
  return (
    <View style={styles.row}>
      {initials ? <Avatar initials={initials} color={colors.navy} /> : null}
      <View style={styles.text}>
        <Text style={styles.title} numberOfLines={1}>
          {title}
        </Text>
        {subtitle ? (
          <Text style={styles.subtitle} numberOfLines={1}>
            {subtitle}
          </Text>
        ) : null}
      </View>
      {right}
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
  text: { flex: 1 },
  title: { ...typography.heading, fontSize: fontSize.title, color: colors.navy },
  subtitle: { fontSize: fontSize.small, color: colors.inkSoft, marginTop: 2 },
});
