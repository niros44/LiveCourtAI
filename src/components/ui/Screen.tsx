import { PropsWithChildren } from 'react';
import { ScrollView, StyleSheet, View, ViewStyle } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { colors } from '@/theme/colors';

type ScreenProps = PropsWithChildren<{
  scroll?: boolean;
  contentStyle?: ViewStyle;
}>;

/** Shared page wrapper matching the mockups' `.app-shell` + `.pad` gutters. */
export function Screen({ children, scroll = true, contentStyle }: ScreenProps) {
  const insets = useSafeAreaInsets();
  const content = (
    <View style={[styles.content, { paddingBottom: insets.bottom + 24 }, contentStyle]}>
      {children}
    </View>
  );

  if (!scroll) {
    return <View style={styles.root}>{content}</View>;
  }

  return (
    <ScrollView style={styles.root} contentContainerStyle={{ flexGrow: 1 }}>
      {content}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: colors.paper,
  },
  content: {
    paddingHorizontal: 20,
    paddingTop: 18,
    gap: 22,
  },
});
