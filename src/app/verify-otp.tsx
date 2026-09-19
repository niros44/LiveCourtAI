import { useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { StyleSheet, Text, TextInput, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Button } from '@/components/ui/Button';
import { getCurrentPersonId, requestOtp, syncIdentities, verifyOtp, type OtpChannel } from '@/lib/auth';
import { useAuth } from '@/lib/authContext';
import { colors } from '@/theme/colors';
import { typography } from '@/theme/typography';

export default function VerifyOtpScreen() {
  const params = useLocalSearchParams<{ identifier: string; channel: string }>();
  const { refresh } = useAuth();
  const identifier = params.identifier ?? '';
  const channel: OtpChannel = params.channel === 'phone' ? 'phone' : 'email';

  const [code, setCode] = useState('');
  const [busy, setBusy] = useState(false);
  const [resending, setResending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleVerify() {
    setError(null);
    setBusy(true);
    try {
      await verifyOtp(identifier, channel, code);

      // Returning person on a possibly-new device/provider — make sure this
      // login channel is on record too. (A brand-new person has no row to
      // link to yet; onboarding does it after creating the profile.)
      if (await getCurrentPersonId()) await syncIdentities().catch(() => {});

      // Route guards take it from here: onboarding for a new person, the
      // role router for everyone else.
      await refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Invalid code');
    } finally {
      setBusy(false);
    }
  }

  async function handleResend() {
    setError(null);
    setResending(true);
    try {
      await requestOtp(identifier);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not resend code');
    } finally {
      setResending(false);
    }
  }

  return (
    <SafeAreaView style={styles.root}>
      <View style={styles.header}>
        <Text style={styles.title}>Enter your code</Text>
        <Text style={styles.subtitle}>We sent a 6-digit code to {identifier}</Text>
      </View>

      <TextInput
        style={styles.codeInput}
        placeholder="000000"
        placeholderTextColor={colors.inkSoft}
        keyboardType="number-pad"
        maxLength={6}
        value={code}
        onChangeText={setCode}
        editable={!busy}
        autoFocus
      />

      <Button label="Verify" onPress={handleVerify} loading={busy} disabled={code.trim().length < 4} />
      <Button
        label={resending ? 'Sending…' : 'Resend code'}
        variant="ghost"
        onPress={handleResend}
        disabled={resending || busy}
      />

      {error ? <Text style={styles.error}>{error}</Text> : null}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: colors.paper,
    paddingHorizontal: 24,
    justifyContent: 'center',
    gap: 20,
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
  codeInput: {
    backgroundColor: colors.white,
    borderWidth: 1,
    borderColor: colors.line,
    borderRadius: 14,
    paddingVertical: 16,
    fontSize: 24,
    letterSpacing: 8,
    textAlign: 'center',
    color: colors.navy,
  },
  error: {
    fontSize: 13,
    color: colors.red,
    textAlign: 'center',
  },
});
