/**
 * Layout tokens — the one place spacing, corner radius and type sizes live, so
 * screens stop hard-coding numbers. Use these instead of literals.
 *
 * Colour rule of thumb (see colors.ts): ~90% neutral surfaces + navy text,
 * `buzzer` (orange) only for the primary action / current selection, and
 * green / red / gold only to communicate a STATUS (in, out, urgent, hurt).
 */

/** 4px base; prefer 8 / 12 / 16 / 24 between blocks. */
export const spacing = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  xxl: 24,
} as const;

export const radius = {
  sm: 8,
  md: 12,
  lg: 16,
  pill: 999,
} as const;

/** Type scale. Pair with `typography` weights (heading / label / body). */
export const fontSize = {
  caption: 11,
  small: 12,
  body: 14,
  subtitle: 15,
  title: 20,
  display: 26,
} as const;

/** Minimum comfortable tap size (iOS 44pt / Material 48dp). The live-game cockpit will need larger. */
export const touchTarget = 44;
