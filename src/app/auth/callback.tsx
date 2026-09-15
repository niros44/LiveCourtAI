import { router, useLocalSearchParams } from 'expo-router';
import { useEffect, useRef } from 'react';
import { ActivityIndicator, StyleSheet, Text } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { supabase } from '@/lib/supabase';
import { colors } from '@/theme/colors';

/**
 * Landing pad for the OAuth redirect (`exp://.../--/auth/callback` in Expo
 * Go, `courtside://auth/callback` in a dev/production build).
 *
 * signInWithGoogle() in lib/auth.ts is the PRIMARY path: it opens the
 * authorize URL with WebBrowser.openAuthSessionAsync and, when that
 * resolves with the redirect URL, exchanges the code itself — without ever
 * navigating here. This screen is the FALLBACK: on some Android / Custom
 * Tabs combinations the OS hands the redirect to the app as an ordinary
 * deep link instead of (or in addition to) resolving openAuthSessionAsync's
 * promise, and Expo Router then auto-navigates here based on the URL. If
 * that happens we finish the code exchange ourselves and bounce onward, so
 * a dropped promise no longer strands the user on a blank/failed browser
 * tab. Safe to run twice — exchanging an already-used code just errors,
 * which we swallow since the primary path already succeeded.
 */
export default function AuthCallbackScreen() {
  const { code } = useLocalSearchParams<{ code?: string }>();
  const ran = useRef(false);

  useEffect(() => {
    if (ran.current) return;
    ran.current = true;

    (async () => {
      if (typeof code === 'string') {
        await supabase.auth.exchangeCodeForSession(code).catch(() => {
          // Already exchanged via signInWithGoogle(), or the code is stale
          // — either way there's nothing more to do here.
        });
      }
      router.replace('/');
    })();
  }, [code]);

  return (
    <SafeAreaView style={styles.root}>
      <ActivityIndicator color={colors.buzzer} />
      <Text style={styles.text}>Signing you in…</Text>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: colors.paper,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 12,
  },
  text: {
    fontSize: 13,
    color: colors.inkSoft,
  },
});
