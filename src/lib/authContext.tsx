import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';

import { getCurrentPersonId, getMyRoleDestinations, type RoleDestination } from '@/lib/auth';
import { supabase } from '@/lib/supabase';

/**
 * Single source of truth for "who is using the app and where may they go".
 *
 * The root layout feeds `status` / `destinations` into `Stack.Protected`
 * guards, so a screen the caller isn't entitled to is unreachable no matter
 * how they got there (deep link, web refresh, restored navigation state).
 * This is a UX guard only — RLS in Supabase is what actually protects data.
 *
 *  - loading         first resolve still in flight (or just signed in)
 *  - signedOut       no Supabase session
 *  - needsOnboarding session, but no `public.users` row yet
 *  - ready           session + person row; `destinations` says which areas
 *                    of the app they may open
 */
export type AuthStatus = 'loading' | 'signedOut' | 'needsOnboarding' | 'ready';

type AuthState = {
  status: AuthStatus;
  personId: string | null;
  destinations: RoleDestination[];
  /** True when the person has no real navigable role yet and sees the generic preview picker. */
  isPreview: boolean;
};

type AuthContextValue = AuthState & {
  /** False only until the very first resolve finishes; never goes back to false. */
  initialized: boolean;
  /** Re-resolve the state now — call after something that changes it without an auth event (e.g. creating the profile). */
  refresh: () => Promise<void>;
};

// Shown to a person with no navigable role yet (fresh signup with no
// invite/assignment) so they aren't stranded on an empty screen.
const FALLBACK_ROLES: RoleDestination[] = [
  { href: '/player', label: 'Player', sub: 'Rookie Mode', icon: 'basketball-outline' },
  { href: '/coach', label: 'Coach', sub: 'Pro Mode', icon: 'clipboard-outline' },
  { href: '/parent', label: 'Parent', sub: 'Family Home', icon: 'people-outline' },
];

const LOADING: AuthState = { status: 'loading', personId: null, destinations: [], isPreview: false };
const SIGNED_OUT: AuthState = { status: 'signedOut', personId: null, destinations: [], isPreview: false };
const NEEDS_ONBOARDING: AuthState = { status: 'needsOnboarding', personId: null, destinations: [], isPreview: false };

async function resolveAuthState(): Promise<AuthState> {
  const { data } = await supabase.auth.getSession();
  if (!data.session) return SIGNED_OUT;

  try {
    const personId = await getCurrentPersonId();
    if (!personId) return NEEDS_ONBOARDING;

    const real = await getMyRoleDestinations(personId);
    if (real.length > 0) return { status: 'ready', personId, destinations: real, isPreview: false };
    return { status: 'ready', personId, destinations: FALLBACK_ROLES, isPreview: true };
  } catch {
    // If the lookup itself fails, don't strand the user on a spinner — fall
    // back to the preview picker; any real data fetch will surface its own error.
    return { status: 'ready', personId: null, destinations: FALLBACK_ROLES, isPreview: true };
  }
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>(LOADING);
  const [initialized, setInitialized] = useState(false);
  // Only the newest resolve may write state, so a slow earlier one can't
  // overwrite a later result (or a sign-out).
  const latest = useRef(0);

  const refresh = useCallback(async () => {
    const id = ++latest.current;
    const next = await resolveAuthState();
    if (id === latest.current) {
      setState(next);
      setInitialized(true);
    }
  }, []);

  useEffect(() => {
    refresh();

    const { data: subscription } = supabase.auth.onAuthStateChange((event) => {
      // Token refreshes don't change who the user is; INITIAL_SESSION is
      // covered by the refresh() above.
      if (event === 'TOKEN_REFRESHED' || event === 'INITIAL_SESSION') return;

      if (event === 'SIGNED_OUT') {
        latest.current++; // drop any resolve still in flight
        setState(SIGNED_OUT);
        setInitialized(true);
        return;
      }

      // Just signed in: hold on `loading` (instead of `signedOut`) until the
      // person/roles are resolved, so the login screens hand over cleanly.
      setState((current) => (current.status === 'signedOut' ? LOADING : current));
      // supabase-js can deadlock if a listener awaits another supabase call,
      // so resolve outside the callback.
      setTimeout(refresh, 0);
    });

    return () => subscription.subscription.unsubscribe();
  }, [refresh]);

  const value = useMemo(() => ({ ...state, initialized, refresh }), [state, initialized, refresh]);
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const value = useContext(AuthContext);
  if (!value) throw new Error('useAuth must be used inside <AuthProvider>');
  return value;
}
