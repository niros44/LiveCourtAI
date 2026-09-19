import { Ionicons } from '@expo/vector-icons';
import { router, useFocusEffect } from 'expo-router';
import { useCallback } from 'react';
import { ActivityIndicator, Pressable, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { signOut } from '@/lib/auth';
import { useAuth } from '@/lib/authContext';
import { colors } from '@/theme/colors';
import { typography } from '@/theme/typography';

/**
 * Role router — the anchor screen every guarded route falls back to.
 *
 * The auth state itself (and the route guards that enforce it) live in
 * AuthProvider / the root layout. This screen just acts on it: signed out ->
 * /login, no `users` row yet -> /onboarding, exactly one navigable role ->
 * straight there, more than one -> a picker built from real role/team/child
 * data, and zero (a fresh signup with no invite/assignment yet) -> the
 * generic preview picker so nothing is stranded on an empty screen.
 */
export default function RoleSelectScreen() {
  const { status, destinations, isPreview } = useAuth();

  const soleDestination = status === 'ready' && !isPreview && destinations.length === 1 ? destinations[0] : null;

  // Only while focused: on a deep link this screen is mounted underneath the
  // target as the anchor, and a replace() from there would hit the target.
  useFocusEffect(
    useCallback(() => {
      if (status === 'signedOut') router.replace('/login');
      else if (status === 'needsOnboarding') router.replace('/onboarding');
      else if (soleDestination) router.replace(soleDestination.href);
    }, [status, soleDestination])
  );

  if (status !== 'ready' || soleDestination) {
    return (
      <SafeAreaView style={[styles.root, styles.centered]}>
        <ActivityIndicator color={colors.buzzer} />
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.root}>
      <View style={styles.header}>
        <Text style={styles.brand}>COURTSIDE</Text>
        <Text style={styles.tagline}>{isPreview ? 'Choose a view to preview' : 'Choose how to continue'}</Text>
      </View>

      <View style={styles.cards}>
        {/* Plain Pressable + router.push, not <Link asChild><Pressable>.
            asChild is supposed to clone its props onto the child, but with
            a function-style Pressable it silently dropped the style/layout —
            the icon and chevron rendered with no card background, row
            layout, or title/subtitle text. Driving navigation ourselves
            sidesteps that clone entirely and is just as correct here. */}
        {destinations.map((role) => (
          <Pressable
            key={role.href}
            onPress={() => router.push(role.href)}
            style={({ pressed }) => [styles.card, pressed && styles.cardPressed]}>
            <View style={styles.iconWrap}>
              <Ionicons name={role.icon} size={26} color={colors.buzzer} />
            </View>
            <View style={{ flex: 1 }}>
              <Text style={styles.cardTitle}>{role.label}</Text>
              <Text style={styles.cardSub}>{role.sub}</Text>
            </View>
            <Ionicons name="chevron-forward" size={20} color={colors.inkSoft} />
          </Pressable>
        ))}
      </View>

      <Text style={styles.signOut} onPress={() => signOut()}>
        Sign out
      </Text>
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
  centered: {
    alignItems: 'center',
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
  cardPressed: {
    opacity: 0.85,
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
  signOut: {
    textAlign: 'center',
    fontSize: 13,
    color: colors.inkSoft,
    textDecorationLine: 'underline',
  },
});
