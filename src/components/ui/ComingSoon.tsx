import { Ionicons } from '@expo/vector-icons';
import { StyleSheet, Text, View } from 'react-native';

import { colors } from '@/theme/colors';
import { typography } from '@/theme/typography';

type ComingSoonProps = {
  icon: keyof typeof Ionicons.glyphMap;
  title: string;
  description: string;
};

/** Placeholder shell for tabs not yet built — mirrors `.shell-hero` in the mockups. */
export function ComingSoon({ icon, title, description }: ComingSoonProps) {
  return (
    <View style={styles.hero}>
      <Ionicons name={icon} size={34} color={colors.navy} />
      <Text style={styles.title}>{title}</Text>
      <Text style={styles.description}>{description}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  hero: {
    backgroundColor: colors.tintNavy,
    borderWidth: 1.5,
    borderColor: colors.navy,
    borderStyle: 'dashed',
    borderRadius: 16,
    paddingVertical: 28,
    paddingHorizontal: 20,
    alignItems: 'center',
    gap: 10,
  },
  title: {
    ...typography.heading,
    fontSize: 16,
    color: colors.navy,
  },
  description: {
    fontSize: 12.5,
    color: colors.inkSoft,
    textAlign: 'center',
    maxWidth: 260,
    lineHeight: 18,
  },
});
