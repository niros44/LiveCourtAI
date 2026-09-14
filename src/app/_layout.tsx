import { DefaultTheme, Stack, ThemeProvider } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { useEffect } from 'react';
import { Platform } from 'react-native';
import { NavigationBar } from 'expo-navigation-bar';

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
      <Stack screenOptions={{ headerShown: false }}>
        <Stack.Screen name="index" />
        <Stack.Screen name="login" />
        <Stack.Screen name="verify-otp" />
        <Stack.Screen name="onboarding" />
        <Stack.Screen name="player" />
        <Stack.Screen name="coach" />
        <Stack.Screen name="parent" />
      </Stack>
    </ThemeProvider>
  );
}
