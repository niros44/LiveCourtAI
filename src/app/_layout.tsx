import { DefaultTheme, Stack, ThemeProvider } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { useEffect } from 'react';
import { ActivityIndicator, Platform, View } from 'react-native';
import { NavigationBar } from 'expo-navigation-bar';

import { AuthProvider, useAuth } from '@/lib/authContext';
import { colors } from '@/theme/colors';

const CourtSideTheme = {
  ...DefaultTheme,
  colors: {
    ...DefaultTheme.colors,
    background: colors.paper,
    primary: colors.buzzer,
    text: colors.navy,
    card: colors.white,
    border: colors.line,
  },
};

/**
 * Route guards. A screen whose guard is false can't be reached at all —
 * deep link, web refresh and restored navigation state included — and if a
 * guard flips while the user is on it (e.g. sign-out, revoked session) the
 * router sends them back to the anchor `index`, which then routes them to
 * the right place. `index` and `auth/callback` stay open to everyone: the
 * first is the router, the second finishes the OAuth redirect before any
 * session exists.
 */
function RootNavigator() {
  const { status, destinations, initialized } = useAuth();
  const canEnter = (href: string) => status === 'ready' && destinations.some((d) => d.href === href);

  // Don't mount the navigator until we know who the user is: with every
  // guard closed during the first resolve, a deep link would be bounced to
  // `index` and its target lost. Kept mounted afterwards (a later sign-in
  // must not reset the stack).
  if (!initialized) {
    return (
      <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.paper }}>
        <ActivityIndicator color={colors.buzzer} />
      </View>
    );
  }

  return (
    <Stack screenOptions={{ headerShown: false }}>
      <Stack.Screen name="index" />
      <Stack.Screen name="auth/callback" />

      <Stack.Protected guard={status === 'signedOut'}>
        <Stack.Screen name="login" />
        <Stack.Screen name="verify-otp" />
      </Stack.Protected>

      <Stack.Protected guard={status === 'needsOnboarding'}>
        <Stack.Screen name="onboarding" />
      </Stack.Protected>

      <Stack.Protected guard={canEnter('/player')}>
        <Stack.Screen name="player" />
      </Stack.Protected>
      <Stack.Protected guard={canEnter('/coach')}>
        <Stack.Screen name="coach" />
      </Stack.Protected>
      <Stack.Protected guard={canEnter('/parent')}>
        <Stack.Screen name="parent" />
      </Stack.Protected>
    </Stack>
  );
}

export default function RootLayout() {
  useEffect(() => {
    if (Platform.OS !== 'android') return;
    // Hide the 3-button/gesture nav bar so it can't sit on top of (and eat
    // taps meant for) our own bottom tab bars. This SDK's API dropped the
    // old setVisibilityAsync/setBehaviorAsync pair (both deprecated, no
    // "overlay-swipe" option anymore) in favor of this single sync call —
    // Android's own edge-to-edge handling now owns the reveal-on-swipe
    // behavior, so the user still isn't locked out of system nav.
    NavigationBar.setHidden(true);
  }, []);

  return (
    <ThemeProvider value={CourtSideTheme}>
      <StatusBar style="dark" />
      <AuthProvider>
        <RootNavigator />
      </AuthProvider>
    </ThemeProvider>
  );
}
