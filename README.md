# CourtSide

A basketball team management app for players, coaches and parents — one Expo
codebase with three role-specific experiences (Rookie/Pro Mode for players,
Pro Mode for coaches, Family Home for parents), backed by Supabase.

## Stack

- **React Native + Expo** (SDK 57, Expo Router, TypeScript)
- **Supabase** (Postgres + Auth + Storage)

## Project structure

```
src/
  app/                # Expo Router routes (file-based)
    index.tsx          # dev-only role picker — real auth will redirect here later
    player/             # Player / Rookie Mode tabs: Home, Schedule, Team, Playbook, Profile
    coach/               # Coach / Pro Mode tabs: Home, Schedule, Players, Review, Playbook, Stats
    parent/              # Parent / Family Home tabs: Home, Transactions, Carpool, Events
  components/
    navigation/          # shared tab bar styling
    ui/                   # Screen, Card, Chip, Badge, Avatar, ComingSoon, etc.
  data/mock/              # placeholder data so every screen renders without a backend yet
  lib/supabase.ts         # Supabase client (reads EXPO_PUBLIC_SUPABASE_* env vars)
  theme/                  # brand colors + typography ported from the approved mockups
supabase/
  migrations/             # SQL schema, applied via the Supabase SQL editor or `supabase db push`
```

Only the Home tab of each role is wired to real (mock) data so far; the other
tabs are placeholder "coming soon" shells ready to be filled in.

## Getting started

```bash
npm install
npx expo start --web   # or --ios / --android
```

### Connect Supabase

1. Copy `.env.example` to `.env` and fill in your project's URL and anon key
   (Supabase dashboard → Settings → API — the anon key is safe to use client-side).
2. Run the SQL in `supabase/migrations/0001_user_and_userrole.sql` against your
   project (Supabase dashboard → SQL Editor, or `supabase db push` once linked
   with `supabase link`).

The app runs fine on mock data with no `.env` present — screens just won't
read/write real data until it's set up.

## Spec

Product spec: `איפיון ופיתוח.docx` (Hebrew). Phase 1 (MVP) covers core
identities & onboarding, the three role interfaces above, and the admin
scheduling console — this scaffold covers the first three; admin (web) and
live in-game scoring are separate, later phases.
