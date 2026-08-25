import { DefaultTheme, Stack, ThemeProvider } from 'expo-router';
import { StatusBar } from 'expo-status-bar';

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
  return (
    <ThemeProvider value={CourtSideTheme}>
      <StatusBar style="dark" />
      <Stack screenOptions={{ headerShown: false }}>
        <Stack.Screen name="index" />
        <Stack.Screen name="player" />
        <Stack.Screen name="coach" />
        <Stack.Screen name="parent" />
      </Stack>
    </ThemeProvider>
  );
}
