/**
 * Human-readable message from anything a `catch` can receive.
 *
 * supabase-js (PostgREST) errors are plain `{ message, code, details, hint }`
 * objects, NOT `Error` instances, so `e instanceof Error ? e.message : ...`
 * silently drops the real reason and shows only the generic fallback.
 */
export function errorMessage(e: unknown, fallback: string): string {
  if (e instanceof Error && e.message) return e.message;
  if (typeof e === 'object' && e !== null && 'message' in e && typeof e.message === 'string' && e.message) {
    return e.message;
  }
  return fallback;
}
