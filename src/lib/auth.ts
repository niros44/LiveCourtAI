import { useEffect, useState } from 'react';
import { Platform } from 'react-native';
import * as AppleAuthentication from 'expo-apple-authentication';
import * as Crypto from 'expo-crypto';
import * as Linking from 'expo-linking';
import * as WebBrowser from 'expo-web-browser';
import type { Session } from '@supabase/supabase-js';

import { supabase } from '@/lib/supabase';

/**
 * Auth helpers for the login/OTP/onboarding screens.
 *
 * DB context (verified against the live schema, see chat history — not a
 * migration, this is all pre-existing):
 *  - public.users.auth_user_id -> auth.users(id), unique, nullable ("shadow"
 *    persons created by staff have no auth_user_id and no contact info).
 *  - public.user_identities tracks which providers (google/apple/email/phone)
 *    are linked to a person; nothing populates it automatically on OAuth
 *    login, so we call link_identity() ourselves after every sign-in.
 *  - current_person_id() resolves `auth.uid()` -> the caller's own `users.id`
 *    (or null if this auth user has no person row yet).
 *  - RLS already allows a brand-new auth user to INSERT their own row in
 *    `users` with auth_user_id = auth.uid() — that's the self-signup path
 *    used by createSelfProfile() below. Invitation-based signup instead goes
 *    through the existing claim_invitation() RPC (not wired into these
 *    screens yet — see follow-up note in onboarding.tsx).
 */

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function isEmail(value: string): boolean {
  return EMAIL_RE.test(value.trim());
}

// ---------------------------------------------------------------------------
// Session
// ---------------------------------------------------------------------------

export function useSession() {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let active = true;

    supabase.auth.getSession().then(({ data }) => {
      if (!active) return;
      setSession(data.session);
      setLoading(false);
    });

    const { data: subscription } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      if (!active) return;
      setSession(nextSession);
    });

    return () => {
      active = false;
      subscription.subscription.unsubscribe();
    };
  }, []);

  return { session, loading };
}

export async function signOut(): Promise<void> {
  await supabase.auth.signOut();
}

// ---------------------------------------------------------------------------
// Google — browser-based OAuth (no native Google SDK needed)
// ---------------------------------------------------------------------------

export async function signInWithGoogle(): Promise<{ cancelled: boolean }> {
  const redirectTo = Linking.createURL('auth/callback');

  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: { redirectTo, skipBrowserRedirect: true },
  });
  if (error) throw error;
  if (!data?.url) throw new Error('Supabase did not return an authorization URL');

  const result = await WebBrowser.openAuthSessionAsync(data.url, redirectTo);
  if (result.type !== 'success' || !result.url) {
    return { cancelled: true };
  }

  const { queryParams } = Linking.parse(result.url);
  const code = queryParams?.code;
  if (typeof code !== 'string') {
    throw new Error(
      'No authorization code came back from Google — check that the redirect URL is allow-listed in Supabase Auth settings'
    );
  }

  const { error: exchangeError } = await supabase.auth.exchangeCodeForSession(code);
  if (exchangeError) throw exchangeError;

  return { cancelled: false };
}

// ---------------------------------------------------------------------------
// Apple — native Sign In with Apple (required by App Store guidelines
// whenever another social login is offered)
// ---------------------------------------------------------------------------

export async function isAppleSignInAvailable(): Promise<boolean> {
  if (Platform.OS !== 'ios') return false;
  return AppleAuthentication.isAvailableAsync();
}

export async function signInWithApple(): Promise<AppleAuthentication.AppleAuthenticationCredential> {
  const credential = await AppleAuthentication.signInAsync({
    requestedScopes: [
      AppleAuthentication.AppleAuthenticationScope.FULL_NAME,
      AppleAuthentication.AppleAuthenticationScope.EMAIL,
    ],
  });

  if (!credential.identityToken) {
    throw new Error('Apple did not return an identity token');
  }

  const { error } = await supabase.auth.signInWithIdToken({
    provider: 'apple',
    token: credential.identityToken,
  });
  if (error) throw error;

  // Apple only sends `fullName` on the FIRST authorization ever — the caller
  // uses this to prefill the onboarding screen for brand-new sign-ups.
  return credential;
}

// ---------------------------------------------------------------------------
// OTP — email or phone, whichever the user typed
// ---------------------------------------------------------------------------

export type OtpChannel = 'email' | 'phone';

export async function requestOtp(identifier: string): Promise<{ channel: OtpChannel; identifier: string }> {
  const value = identifier.trim();
  if (!value) throw new Error('Enter your email or phone number');

  if (isEmail(value)) {
    const { error } = await supabase.auth.signInWithOtp({ email: value });
    if (error) throw error;
    return { channel: 'email', identifier: value };
  }

  const { error } = await supabase.auth.signInWithOtp({ phone: value });
  if (error) throw error;
  return { channel: 'phone', identifier: value };
}

export async function verifyOtp(identifier: string, channel: OtpChannel, token: string): Promise<void> {
  const code = token.trim();
  if (!code) throw new Error('Enter the code we sent you');

  const { error } =
    channel === 'email'
      ? await supabase.auth.verifyOtp({ email: identifier, token: code, type: 'email' })
      : await supabase.auth.verifyOtp({ phone: identifier, token: code, type: 'sms' });
  if (error) throw error;
}

// ---------------------------------------------------------------------------
// Person record (public.users) + identity linking
// ---------------------------------------------------------------------------

/** Resolves auth.uid() -> the caller's own users.id, or null if none exists yet. */
export async function getCurrentPersonId(): Promise<string | null> {
  const { data, error } = await supabase.rpc('current_person_id');
  if (error) throw error;
  return (data as string | null) ?? null;
}

type NameHint = { firstName: string; lastName: string };

/** Best-effort prefill for the onboarding screen from whatever the provider handed back. */
export async function getNameHint(): Promise<NameHint> {
  const { data } = await supabase.auth.getUser();
  const metadata = data.user?.user_metadata ?? {};
  const full: string = metadata.full_name ?? metadata.name ?? '';
  const given: string = metadata.given_name ?? metadata.first_name ?? '';
  const family: string = metadata.family_name ?? metadata.last_name ?? '';

  if (given || family) return { firstName: given, lastName: family };

  const parts = full.trim().split(/\s+/).filter(Boolean);
  return { firstName: parts[0] ?? '', lastName: parts.slice(1).join(' ') };
}

/**
 * Self-signup path: creates the caller's own `users` row. Only valid for a
 * cold sign-up with no invitation — RLS permits this because
 * `auth_user_id = auth.uid()` is the caller's own id.
 */
export async function createSelfProfile(firstName: string, lastName: string): Promise<string> {
  const { data: userRes, error: userErr } = await supabase.auth.getUser();
  if (userErr) throw userErr;
  const authUser = userRes.user;
  if (!authUser) throw new Error('No authenticated user — sign in again');

  const { data, error } = await supabase
    .from('users')
    .insert({
      auth_user_id: authUser.id,
      first_name: firstName.trim(),
      last_name: lastName.trim(),
      email: authUser.email ?? null,
      cellphone: authUser.phone ?? null,
    })
    .select('id')
    .single();

  if (error) {
    if (error.code === '23505') {
      // A profile already exists for this auth user (most likely this
      // account was onboarded before and landed here again by mistake —
      // e.g. after signing back in) or the email/phone is taken by someone
      // else. Try to recover instead of hard-failing: if current_person_id()
      // resolves, this auth user already has a row — use it.
      const existingId = await getCurrentPersonId().catch(() => null);
      if (existingId) return existingId;
      throw new Error('An account already exists with this email or phone number');
    }
    throw error;
  }

  return data.id as string;
}

/**
 * Records every provider on the current auth session in `user_identities`,
 * via the existing `link_identity()` RPC. Safe to call on every sign-in —
 * link_identity() is idempotent per (provider, provider_subject).
 *
 * Must run AFTER a `users` row exists for this auth user (link_identity()
 * resolves the person via current_person_id() and raises if there isn't
 * one), so call this after createSelfProfile() on first sign-up, or right
 * after a successful login for a returning person.
 */
export async function syncIdentities(): Promise<void> {
  const { data, error } = await supabase.auth.getUser();
  if (error || !data.user) return;

  for (const identity of data.user.identities ?? []) {
    const { error: linkError } = await supabase.rpc('link_identity', {
      p_provider: identity.provider,
      p_provider_subject: identity.id,
      p_idem_key: Crypto.randomUUID(),
    });
    if (linkError) {
      // A genuine "this account is linked to someone else" conflict is
      // something the user needs to see; anything else here is non-fatal
      // and shouldn't block the sign-in flow that's already succeeded.
      if (linkError.message?.includes('already linked')) throw linkError;
    }
  }
}
