import AsyncStorage from '@react-native-async-storage/async-storage';
import { createClient } from '@supabase/supabase-js';
import 'react-native-url-polyfill/auto';

const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  console.warn(
    '[supabase] EXPO_PUBLIC_SUPABASE_URL / EXPO_PUBLIC_SUPABASE_ANON_KEY are not set. ' +
      'Copy .env.example to .env and fill in your project credentials. Screens will keep working off mock data until then.'
  );
}

// createClient() throws synchronously on an empty URL, which would crash
// every screen that imports this module (including ones that don't touch
// Supabase) before the app even renders. Falling back to a syntactically
// valid placeholder keeps the "screens keep working off mock data" promise
// above actually true — any real network call will just fail, not crash.
export const supabase = createClient(supabaseUrl || 'https://placeholder.supabase.co', supabaseAnonKey || 'placeholder-anon-key', {
  auth: {
    storage: AsyncStorage,
    autoRefreshToken: true,
    persistSession: true,
    // We handle the OAuth redirect ourselves (expo-web-browser + Linking.parse),
    // so Supabase shouldn't try to read the session out of the current URL.
    detectSessionInUrl: false,
    // PKCE is the correct flow for a native app: no client secret, and the
    // authorization code is exchanged for a session after the redirect lands
    // back in the app via our custom `courtside://` scheme.
    flowType: 'pkce',
  },
});
