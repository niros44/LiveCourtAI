import { Ionicons } from '@expo/vector-icons';
import { ActivityIndicator, Pressable, StyleSheet, Text, ViewStyle } from 'react-native';

import { colors } from '@/theme/colors';
import { typography } from '@/theme/typography';

type ButtonVariant = 'primary' | 'social' | 'ghost';

type ButtonProps = {
  label: string;
  onPress: () => void;
  variant?: ButtonVariant;
  icon?: keyof typeof Ionicons.glyphMap;
  loading?: boolean;
  disabled?: boolean;
  style?: ViewStyle;
};

/** Shared action button — primary (buzzer fill), social (bordered white), ghost (text-only). */
export function Button({
  label,
  onPress,
  variant = 'primary',
  icon,
  loading = false,
  disabled = false,
  style,
}: ButtonProps) {
  const isDisabled = disabled || loading;
  const labelColor = variant === 'primary' ? colors.white : colors.navy;

  return (
    <Pressable
      onPress={onPress}
      disabled={isDisabled}
      style={({ pressed }) => [
        styles.base,
        variant === 'primary' && styles.primary,
        variant === 'social' && styles.social,
        variant === 'ghost' && styles.ghost,
        isDisabled && styles.disabled,
        pressed && !isDisabled && styles.pressed,
        style,
      ]}>
      {loading ? (
        <ActivityIndicator color={labelColor} />
      ) : (
        <>
          {icon ? <Ionicons name={icon} size={18} color={labelColor} /> : null}
          <Text style={[styles.label, { color: labelColor }]}>{label}</Text>
        </>
      )}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  base: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 14,
    paddingVertical: 14,
    paddingHorizontal: 16,
    gap: 10,
  },
  primary: {
    backgroundColor: colors.buzzer,
  },
  social: {
    backgroundColor: colors.white,
    borderWidth: 1,
    borderColor: colors.line,
  },
  ghost: {
    backgroundColor: 'transparent',
    paddingVertical: 10,
  },
  disabled: {
    opacity: 0.5,
  },
  pressed: {
    opacity: 0.85,
  },
  label: {
    ...typography.label,
    fontSize: 13,
    letterSpacing: 0.6,
  },
});
