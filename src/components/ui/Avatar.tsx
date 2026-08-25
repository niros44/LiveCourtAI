import { StyleSheet, Text, View } from 'react-native';

import { colors } from '@/theme/colors';

type AvatarProps = {
  initials: string;
  size?: number;
  color?: string;
};

/** Initials-circle avatar — every mockup falls back to this instead of real photos. */
export function Avatar({ initials, size = 42, color = colors.navy }: AvatarProps) {
  return (
    <View
      style={[
        styles.circle,
        { width: size, height: size, borderRadius: size / 2, backgroundColor: `${color}1F` },
      ]}>
      <Text style={[styles.initials, { color, fontSize: size * 0.36 }]}>{initials}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  circle: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  initials: {
    fontWeight: '900',
  },
});
