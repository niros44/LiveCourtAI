/**
 * Mirrors the `role` column on `user_roles` in supabase/migrations/0001_user_and_user_roles.sql.
 * Keep the ranks in sync with the DB seed data — they're the single source
 * of truth for "does this user have at least X access" checks.
 */
export const ROLE_RANK = {
  admin: 4,
  coach: 3,
  player: 2,
  parent: 1,
} as const;

export type Role = keyof typeof ROLE_RANK;

export function hasMinRole(roles: Role[], min: Role): boolean {
  const highest = Math.max(0, ...roles.map((role) => ROLE_RANK[role]));
  return highest >= ROLE_RANK[min];
}
