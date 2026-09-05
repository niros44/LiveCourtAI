/**
 * Mirrors the `roles` table (code + hierarchy_depth) seeded in
 * supabase/migrations/0031_roles_table.sql, reversed by
 * 0034_reverse_role_hierarchy_depth.sql. Keep these values in sync with
 * the DB seed data.
 *
 * Lower depth = closer to the root = more access (management=1 is the
 * most senior, parent=4 the least) — the opposite of the old rank-style
 * "higher number wins", so hasMinRole compares with <=, not >=.
 */
export const ROLE_HIERARCHY_DEPTH = {
  management: 1,
  coach: 2,
  player: 3,
  parent: 4,
} as const;

export type Role = keyof typeof ROLE_HIERARCHY_DEPTH;

export function hasMinRole(roles: Role[], min: Role): boolean {
  if (roles.length === 0) return false;
  const shallowest = Math.min(...roles.map((role) => ROLE_HIERARCHY_DEPTH[role]));
  return shallowest <= ROLE_HIERARCHY_DEPTH[min];
}
