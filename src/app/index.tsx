import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, Pressable, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { getCurrentPersonId, signOut } from '@/lib/auth';
import { supabase } from '@/lib/supabase';
import { colors } from '@/theme/colors';
import { typography } from '@/theme/typography';

/**
 * Auth gate + (for now) role preview picker.
 *
 * Real routing is in place: no session -> /login, session but no `users`
 * row yet -> /onboarding. What's still a stand-in is the destination for an
 * authenticated, onboarded person — this shows the same manual role picker
 * as before instead of resolving their actual role(s) from `user_roles`,
 * since that table has no data for real accounts yet. Swap this screen's
 * body for an automatic redirect once role assignment is wired up.
 */
const ROLES = [
  { href: '/player' as const, label: 'Player', sub: 'Rookie Mode', icon: 'basketball-outline' as const },
  { href: '/coach' as const, label: 'Coach', sub: 'Pro Mode', icon: 'clipboard-outline' as const },
  { href: '/parent' as const, label: 'Parent', sub: 'Family Home', icon: 'people-outline' as const },
];

export default function RoleSelectScreen() {
  const [checking, setChecking] = useState(true);

  const resolve = useCallback(async () => {
    const { data } = await supabase.auth.getSession();
    if (!data.session) {
      router.replace('/login');
      return;
    }

    try {
      const personId = await getCurrentPersonId();
      if (!personId) {
        router.replace('/onboarding');
        return;
      }
    } catch {
      // If the lookup itself fails, don't strand the user on a spinner —
      // fall through to the picker; any real data fetch below will surface
      // its own error.
    }

    setChecking(false);
  }, []);

  useEffect(() => {
    resolve();
    const { data: subscription } = supabase.auth.onAuthStateChange((event) => {
      if (event === 'SIGNED_OUT') router.replace('/login');
    });
    return () => subscription.subscription.unsubscribe();
  }, [resolve]);

  async function handleSignOut() {
    await signOut();
    router.replace('/login');
  }

  if (checking) {
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
        <Text style={styles.tagline}>Choose a view to preview</Text>
      </View>

      <View style={styles.cards}>
        {/* Plain Pressable + router.push, not <Link asChild><Pressable>.
            asChild is supposed to clone its props onto the child, but with
            a function-style Pressable it silently dropped the style/layout —
            the icon and chevron rendered with no card background, row
            layout, or title/subtitle text. Driving navigation ourselves
            sidesteps that clone entirely and is just as correct here. */}
        {ROLES.map((role) => (
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

      <Text style={styles.signOut} onPress={handleSignOut}>
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
