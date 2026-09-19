import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useEffect, useState } from 'react';
import { Platform, StyleSheet, Text, TextInput, View } from 'react-native';
import Animated, {
  Easing,
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withSequence,
  withTiming,
} from 'react-native-reanimated';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Button } from '@/components/ui/Button';
import { isAppleSignInAvailable, requestOtp, signInWithApple, signInWithGoogle } from '@/lib/auth';
import { colors } from '@/theme/colors';
import { typography } from '@/theme/typography';

type Busy = 'google' | 'apple' | 'otp' | null;

const BOUNCE_HEIGHT = 34;
const BOUNCE_DURATION = 420;

/** A small dribbling basketball above the wordmark — purely decorative. */
function DribblingBasketball() {
  const lift = useSharedValue(0);

  useEffect(() => {
    lift.value = withRepeat(
      withSequence(
        withTiming(1, { duration: BOUNCE_DURATION, easing: Easing.out(Easing.quad) }),
        withTiming(0, { duration: BOUNCE_DURATION, easing: Easing.in(Easing.quad) })
      ),
      -1,
      false
    );
  }, [lift]);

  const ballStyle = useAnimatedStyle(() => ({
    transform: [
      { translateY: lift.value * -BOUNCE_HEIGHT },
      { scale: 1 - lift.value * 0.06 },
      { rotate: `${lift.value * -18}deg` },
    ],
  }));

  const shadowStyle = useAnimatedStyle(() => ({
    transform: [{ scaleX: 1 - lift.value * 0.45 }],
    opacity: 0.28 - lift.value * 0.16,
  }));

  return (
    <View style={styles.bounceWrap}>
      <Animated.View style={ballStyle}>
        <Ionicons name="basketball" size={36} color={colors.buzzer} />
      </Animated.View>
      <Animated.View style={[styles.bounceShadow, shadowStyle]} />
    </View>
  );
}

export default function LoginScreen() {
  const [identifier, setIdentifier] = useState('');
  const [busy, setBusy] = useState<Busy>(null);
  const [error, setError] = useState<string | null>(null);
  const [appleAvailable, setAppleAvailable] = useState(false);

  useEffect(() => {
    isAppleSignInAvailable().then(setAppleAvailable);
  }, []);

  async function handleGoogle() {
    setError(null);
    setBusy('google');
    try {
      await signInWithGoogle();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Google sign-in failed');
    } finally {
      setBusy(null);
    }
  }

  async function handleApple() {
    setError(null);
    setBusy('apple');
    try {
      await signInWithApple();
    } catch (err: any) {
      if (err?.code !== 'ERR_REQUEST_CANCELED') {
        setError(err instanceof Error ? err.message : 'Apple sign-in failed');
      }
    } finally {
      setBusy(null);
    }
  }

  async function handleOtp() {
    setError(null);
    if (!identifier.trim()) {
      setError('Enter your email or phone number');
      return;
    }
    setBusy('otp');
    try {
      const result = await requestOtp(identifier);
      router.push({
        pathname: '/verify-otp',
        params: { identifier: result.identifier, channel: result.channel },
      });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not send code');
    } finally {
      setBusy(null);
    }
  }

  const disabled = busy !== null;

  return (
    <SafeAreaView style={styles.root}>
      <View style={styles.header}>
        <DribblingBasketball />
        <Text style={styles.brand}>LiveCourtAI</Text>
        <Text style={styles.tagline}>Sign in to your team</Text>
      </View>

      <View style={styles.actions}>
        <Button
          label="Continue with Google"
          icon="logo-google"
          variant="social"
          loading={busy === 'google'}
          disabled={disabled}
          onPress={handleGoogle}
        />

        {Platform.OS === 'ios' && appleAvailable ? (
          <Button
            label="Continue with Apple"
            icon="logo-apple"
            variant="social"
            loading={busy === 'apple'}
            disabled={disabled}
            onPress={handleApple}
          />
        ) : null}

        <View style={styles.divider}>
          <View style={styles.dividerLine} />
          <Text style={styles.dividerText}>OR</Text>
          <View style={styles.dividerLine} />
        </View>

        <TextInput
          style={styles.input}
          placeholder="Email or phone number"
          placeholderTextColor={colors.inkSoft}
          autoCapitalize="none"
          autoCorrect={false}
          keyboardType="email-address"
          value={identifier}
          onChangeText={setIdentifier}
          editable={!disabled}
        />

        <Button label="Send code" loading={busy === 'otp'} disabled={disabled} onPress={handleOtp} />

        {error ? <Text style={styles.error}>{error}</Text> : null}
      </View>

      <Text style={styles.footnote}>By continuing you agree to CourtSide&apos;s terms and privacy policy.</Text>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: colors.paper,
    paddingHorizontal: 24,
    justifyContent: 'center',
    gap: 32,
  },
  header: {
    alignItems: 'center',
    gap: 6,
  },
  bounceWrap: {
    height: BOUNCE_HEIGHT + 20,
    alignItems: 'center',
    justifyContent: 'flex-end',
    marginBottom: 4,
  },
  bounceShadow: {
    width: 30,
    height: 8,
    borderRadius: 5,
    backgroundColor: colors.navy,
    marginTop: 6,
  },
  brand: {
    ...typography.heading,
    fontSize: 28,
    color: colors.navy,
  },
  tagline: {
    fontSize: 13,
    color: colors.inkSoft,
  },
  actions: {
    gap: 12,
  },
  divider: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    marginVertical: 4,
  },
  dividerLine: {
    flex: 1,
    height: 1,
    backgroundColor: colors.line,
  },
  dividerText: {
    ...typography.label,
    fontSize: 11,
    color: colors.inkSoft,
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
  footnote: {
    fontSize: 11,
    color: colors.inkSoft,
    textAlign: 'center',
  },
});
