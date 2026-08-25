import { Ionicons } from '@expo/vector-icons';
import { Link } from 'expo-router';
import { StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { colors } from '@/theme/colors';
import { typography } from '@/theme/typography';

/**
 * Temporary dev entry point: picks which role's tab group to preview.
 * Once auth (Email/OTP + role bridge tables, per the spec) lands, this
 * screen goes away and the redirect happens automatically after login.
 */
const ROLES = [
  { href: '/player' as const, label: 'Player', sub: 'Rookie Mode', icon: 'basketball-outline' as const },
  { href: '/coach' as const, label: 'Coach', sub: 'Pro Mode', icon: 'clipboard-outline' as const },
  { href: '/parent' as const, label: 'Parent', sub: 'Family Home', icon: 'people-outline' as const },
];

export default function RoleSelectScreen() {
  return (
    <SafeAreaView style={styles.root}>
      <View style={styles.header}>
        <Text style={styles.brand}>COURTSIDE</Text>
        <Text style={styles.tagline}>Choose a view to preview</Text>
      </View>

      <View style={styles.cards}>
        {ROLES.map((role) => (
          <Link key={role.href} href={role.href} asChild>
            <View style={styles.card}>
              <View style={styles.iconWrap}>
                <Ionicons name={role.icon} size={26} color={colors.buzzer} />
              </View>
              <View style={{ flex: 1 }}>
                <Text style={styles.cardTitle}>{role.label}</Text>
                <Text style={styles.cardSub}>{role.sub}</Text>
              </View>
              <Ionicons name="chevron-forward" size={20} color={colors.inkSoft} />
            </View>
          </Link>
        ))}
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: colors.paper,
    paddingHorizontal: 24,
    justifyContent: 'center',
    gap: 32,
  },
  header: {
    alignItems: 'center',
    gap: 6,
  },
  brand: {
    ...typography.heading,
    fontSize: 28,
    color: colors.navy,
  },
  tagline: {
    fontSize: 13,
    color: colors.inkSoft,
  },
  cards: {
    gap: 12,
  },
  card: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
    backgroundColor: colors.white,
    borderWidth: 1,
    borderColor: colors.line,
    borderRadius: 16,
    padding: 16,
  },
  iconWrap: {
    width: 46,
    height: 46,
    borderRadius: 23,
    backgroundColor: colors.tintOrange,
    alignItems: 'center',
    justifyContent: 'center',
  },
  cardTitle: {
    ...typography.heading,
    fontSize: 15,
    color: colors.navy,
  },
  cardSub: {
    fontSize: 11,
    color: colors.inkSoft,
    marginTop: 2,
    textTransform: 'uppercase',
    letterSpacing: 1,
  },
});
