import { Ionicons } from '@expo/vector-icons';
import { ColorValue, Platform } from 'react-native';

import { colors } from '@/theme/colors';

/** Shared look for every role's bottom tab bar — pill-style active tab like the mockups. */
export const sharedTabsScreenOptions = {
  headerShown: false,
  tabBarActiveTintColor: colors.white,
  tabBarInactiveTintColor: colors.inkSoft,
  tabBarStyle: {
    backgroundColor: colors.white,
    borderTopColor: colors.line,
    height: Platform.select({ ios: 92, default: 68 }),
    paddingTop: 8,
    paddingBottom: Platform.select({ ios: 30, default: 10 }),
  },
  tabBarLabelStyle: {
    fontSize: 9,
    fontWeight: '700' as const,
    letterSpacing: 0.5,
    textTransform: 'uppercase' as const,
  },
  tabBarItemStyle: {
    marginHorizontal: 4,
    borderRadius: 16,
  },
  tabBarActiveBackgroundColor: colors.buzzer,
};

export function tabIcon(name: keyof typeof Ionicons.glyphMap) {
  return {
    tabBarIcon: ({ color, size }: { color: ColorValue; size: number }) => (
      <Ionicons name={name} color={color as string} size={size - 2} />
    ),
  };
}
