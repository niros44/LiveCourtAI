import { Platform, TextStyle } from 'react-native';

/**
 * The mockups use Arial Black / Arial Narrow for headings and badges to get a
 * condensed, sporty look. We don't bundle those fonts yet, so we emulate the
 * feel with the system font at heavy weights + letter-spacing/uppercase.
 * Swap `heading.fontFamily` once a real condensed display font is bundled.
 */
export const typography = {
  heading: {
    fontFamily: Platform.select({ ios: 'System', android: 'sans-serif-black', default: 'System' }),
    fontWeight: '800',
    letterSpacing: 0.4,
  } satisfies TextStyle,
  label: {
    fontWeight: '700',
    letterSpacing: 1.2,
    textTransform: 'uppercase',
  } satisfies TextStyle,
  body: {
    fontWeight: '500',
  } satisfies TextStyle,
} as const;
