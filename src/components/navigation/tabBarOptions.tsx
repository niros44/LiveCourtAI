import { Ionicons } from '@expo/vector-icons';
import { ColorValue, Platform, StyleSheet, View } from 'react-native';

import { colors } from '@/theme/colors';

/**
 * Shared look for every role's bottom tab bar. The active tab is marked by a
 * navy filled icon + label and a short orange bar on the top edge — orange is
 * kept for accents, not for big blocks.
 */
export const sharedTabsScreenOptions = {
  headerShown: false,
  tabBarActiveTintColor: colors.navy,
  tabBarInactiveTintColor: colors.inkSoft,
  tabBarStyle: {
    backgroundColor: colors.white,
    borderTopColor: colors.line,
    height: Platform.select({ ios: 92, default: 68 }),
    paddingTop: 8,
    paddingBottom: Platform.select({ ios: 30, default: 10 }),
  },
  tabBarLabelStyle: {
    fontSize: 10,
    fontWeight: '700' as const,
    letterSpacing: 0.4,
    textTransform: 'uppercase' as const,
  },
  tabBarItemStyle: {
    marginHorizontal: 4,
  },
};

type IconName = keyof typeof Ionicons.glyphMap;

export function tabIcon(name: IconName) {
  // Filled variant when active, if the icon set has one ("home-outline" -> "home").
  const filledName = name.replace(/-outline$/, '') as IconName;
  const filled = filledName in Ionicons.glyphMap ? filledName : name;

  return {
    tabBarIcon: ({ color, size, focused }: { color: ColorValue; size: number; focused: boolean }) => (
      <View style={styles.iconWrap}>
        {focused ? <View style={styles.activeBar} /> : null}
        <Ionicons name={focused ? filled : name} color={color as string} size={size - 2} />
      </View>
    ),
  };
}

const styles = StyleSheet.create({
  iconWrap: { alignItems: 'center', justifyContent: 'center' },
  // Sits on the tab bar's top edge (the bar has 8px top padding).
  activeBar: {
    position: 'absolute',
    top: -8,
    width: 28,
    height: 3,
    borderRadius: 2,
    backgroundColor: colors.buzzer,
  },
});
