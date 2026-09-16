import { router } from 'expo-router';
import { useEffect, useState } from 'react';
import { ActivityIndicator, StyleSheet, Text, TextInput, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Button } from '@/components/ui/Button';
import { createSelfProfile, getCurrentPersonId, getNameHint, signOut, syncIdentities } from '@/lib/auth';
import { colors } from '@/theme/colors';
import { typography } from '@/theme/typography';

/**
 * Reached once, right after a brand-new auth user's first sign-in — there is
 * a Supabase auth session but no `public.users` row yet. Collecting a name
 * here is required because `users.first_name` / `last_name` are NOT NULL.
 *
 * This is the plain self-signup path (no invitation). A person who arrived
 * via an invite link should instead go through the existing
 * claim_invitation() RPC before ever reaching this screen — that flow isn't
 * wired into the UI yet, so for now every fresh sign-in lands here.
 */
export default function OnboardingScreen() {
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [checkingExisting, setCheckingExisting] = useState(true);

  useEffect(() => {
    getNameHint().then((hint) => {
      setFirstName((current) => current || hint.firstName);
      setLastName((current) => current || hint.lastName);
    });
  }, []);

  // Self-heal: this screen should only ever be reached once, right after a
  // brand-new sign-up with no `users` row yet. If a profile already exists
  // for this auth user — e.g. the caller signed back in, or index.tsx's
  // check raced the session and sent them here by mistake — bounce onward
  // instead of letting them hit the "already exists" error on submit.
  useEffect(() => {
    let active = true;
    getCurrentPersonId()
      .then((personId) => {
        if (!active) return;
        if (personId) {
          router.replace('/');
          return;
        }
        setCheckingExisting(false);
      })
      .catch(() => {
        if (active) setCheckingExisting(false);
      });
    return () => {
      active = false;
    };
  }, []);

  async function handleContinue() {
    setError(null);
    if (!firstName.trim() || !lastName.trim()) {
      setError('Enter your first and last name');
      return;
    }
    setBusy(true);
    try {
      await createSelfProfile(firstName, lastName);
      await syncIdentities().catch(() => {});
      router.replace('/');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not create your profile');
    } finally {
      setBusy(false);
    }
  }

  async function handleLogout() {
    setBusy(true);
    try {
      await signOut();
      router.replace('/login');
    } finally {
      setBusy(false);
    }
  }

  if (checkingExisting) {
    return (
      <SafeAreaView style={[styles.root, styles.centered]}>
        <ActivityIndicator color={colors.buzzer} />
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.root}>
      <View style={styles.header}>
        <Text style={styles.title}>Welcome to CourtSide</Text>
        <Text style={styles.subtitle}>Tell us your name to finish setting up your account</Text>
      </View>

      <TextInput
        style={styles.input}
        placeholder="First name"
        placeholderTextColor={colors.inkSoft}
        value={firstName}
        onChangeText={setFirstName}
        editable={!busy}
      />
      <TextInput
        style={styles.input}
        placeholder="Last name"
        placeholderTextColor={colors.inkSoft}
        value={lastName}
        onChangeText={setLastName}
        editable={!busy}
      />

      <Button label="Continue" onPress={handleContinue} loading={busy} />

      {error ? <Text style={styles.error}>{error}</Text> : null}

      <Button
        label="Log out"
        variant="ghost"
        icon="log-out-outline"
        onPress={handleLogout}
        disabled={busy}
        style={styles.logout}
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: colors.paper,
    paddingHorizontal: 24,
    justifyContent: 'center',
    gap: 14,
  },
  centered: {
    alignItems: 'center',
  },
  header: {
    alignItems: 'center',
    gap: 6,
    marginBottom: 8,
  },
  title: {
    ...typography.heading,
    fontSize: 22,
    color: colors.navy,
  },
  subtitle: {
    fontSize: 13,
    color: colors.inkSoft,
    textAlign: 'center',
  },
  input: {
    backgroundColor: colors.white,
    borderWidth: 1,
    borderColor: colors.line,
    borderRadius: 14,
    paddingVertical: 14,
    paddingHorizontal: 16,
    fontSize: 15,
    color: colors.navy,
  },
  error: {
    fontSize: 13,
    color: colors.red,
    textAlign: 'center',
  },
  logout: {
    marginTop: 4,
    alignSelf: 'center',
  },
});
