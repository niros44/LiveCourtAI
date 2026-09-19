import { useCallback, useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, ScrollView, StyleSheet, Text, View } from 'react-native';

import { BarChart } from '@/components/ui/BarChart';
import { Card } from '@/components/ui/Card';
import { Chip } from '@/components/ui/Chip';
import { Screen } from '@/components/ui/Screen';
import { ScreenHeader } from '@/components/ui/ScreenHeader';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { StatTile } from '@/components/ui/StatTile';
import { getCurrentPersonId } from '@/lib/auth';
import { errorMessage } from '@/lib/errors';
import {
  type AttendanceSummary,
  type FeedbackSummary,
  type GameLine,
  type SeasonStats,
  getAttendanceSummary,
  getFeedbackSummary,
  getMyPlayerships,
  getSeasonStats,
} from '@/lib/playerData';
import { colors } from '@/theme/colors';
import { fontSize, spacing } from '@/theme/tokens';

type Category = { key: string; label: string; decimals: number; value: (g: GameLine) => number | null };

const CATEGORIES: Category[] = [
  { key: 'pts', label: 'Points', decimals: 0, value: (g) => g.pts },
  { key: 'ast', label: 'Assists', decimals: 0, value: (g) => g.ast },
  { key: 'reb', label: 'Rebounds', decimals: 0, value: (g) => g.reb },
  { key: 'stl', label: 'Steals', decimals: 0, value: (g) => g.stl },
  { key: 'tov', label: 'Turnovers', decimals: 0, value: (g) => g.tov },
  { key: 'min', label: 'Minutes', decimals: 1, value: (g) => g.minutes },
];

const CHART_GAMES = 10;

const dayMonth = (iso: string | null) => (iso ? new Date(iso).toLocaleDateString('en-GB', { day: 'numeric', month: 'numeric' }) : '–');
const oneDecimal = (n: number | null) => (n != null ? n.toFixed(1) : '–');
const percent = (n: number | null) => (n != null ? `${n}%` : '–');

export default function PlayerStatsScreen() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [stats, setStats] = useState<SeasonStats | null>(null);
  const [attendance, setAttendance] = useState<AttendanceSummary | null>(null);
  const [feedback, setFeedback] = useState<FeedbackSummary | null>(null);
  const [categoryKey, setCategoryKey] = useState(CATEGORIES[0].key);

  const load = useCallback(async () => {
    try {
      setError(null);
      const personId = await getCurrentPersonId();
      if (!personId) {
        setError('No profile found for this account.');
        return;
      }
      const ships = await getMyPlayerships(personId);
      if (!ships.length) {
        setError("You're not on a team roster yet.");
        return;
      }
      // One players.id per person, even when they are on several teams.
      const playerId = ships[0].playerId;
      const [season, att, fb] = await Promise.all([getSeasonStats(playerId), getAttendanceSummary(playerId), getFeedbackSummary(playerId)]);
      setStats(season);
      setAttendance(att);
      setFeedback(fb);
    } catch (e) {
      setError(errorMessage(e, 'Something went wrong loading your stats.'));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const category = CATEGORIES.find((c) => c.key === categoryKey) ?? CATEGORIES[0];
  const chartData = useMemo(
    () => (stats?.games ?? []).slice(-CHART_GAMES).map((g) => ({ label: dayMonth(g.startsAt), value: category.value(g) })),
    [stats, category]
  );

  if (loading) {
    return (
      <Screen>
        <View style={styles.centered}>
          <ActivityIndicator color={colors.buzzer} />
        </View>
      </Screen>
    );
  }
  if (error) {
    return (
      <Screen>
        <ScreenHeader title="Stats" />
        <View style={styles.centered}>
          <Text style={styles.errorText}>{error}</Text>
        </View>
      </Screen>
    );
  }

  const totals = stats?.totals;
  const played = totals?.gamesPlayed ?? 0;
  const practicesTotal = attendance?.practicesMarked ?? 0;
  const practicesPct = practicesTotal > 0 ? Math.round(((attendance?.practicesAttended ?? 0) / practicesTotal) * 100) : null;

  return (
    <Screen>
      <ScreenHeader title="Stats" subtitle="This season" />

      <View style={styles.section}>
        <SectionHeader title="Summary" />
        <View style={styles.grid}>
          <StatTile label="Games played" value={played > 0 ? String(played) : '–'} />
          <StatTile label="Points / game" value={oneDecimal(totals?.avgPts ?? null)} />
          <StatTile
            label="Practices attended"
            value={practicesTotal > 0 ? `${attendance?.practicesAttended ?? 0}/${practicesTotal}` : '–'}
            hint={practicesPct != null ? `${practicesPct}% of marked practices` : undefined}
          />
          <StatTile label="Assists / game" value={oneDecimal(totals?.avgAst ?? null)} />
          <StatTile
            label={feedback?.positive != null ? 'Positive feedback' : 'Coach feedback'}
            value={feedback ? String(feedback.positive ?? feedback.total) : '–'}
            hint={feedback && feedback.positive != null ? `of ${feedback.total} received` : feedback ? 'received' : undefined}
          />
          <StatTile label="Minutes / game" value={oneDecimal(totals?.avgMin ?? null)} />
        </View>
        {played === 0 ? <Text style={styles.hint}>No game stats recorded yet this season.</Text> : null}
      </View>

      <View style={styles.section}>
        <SectionHeader title="Over the season" tag={chartData.length ? `Last ${chartData.length} games` : undefined} />
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: spacing.sm }}>
          {CATEGORIES.map((c) => (
            <Chip key={c.key} label={c.label} active={c.key === categoryKey} onPress={() => setCategoryKey(c.key)} />
          ))}
        </ScrollView>
        <Card>
          {chartData.length > 0 ? (
            <BarChart data={chartData} decimals={category.decimals} />
          ) : (
            <Text style={styles.hint}>The chart fills in as games are recorded.</Text>
          )}
        </Card>
      </View>

      <View style={styles.section}>
        <SectionHeader title="Shooting" />
        <View style={styles.grid}>
          <StatTile style={styles.third} label="FG %" value={percent(totals?.fgPct ?? null)} />
          <StatTile style={styles.third} label="3PT %" value={percent(totals?.threePct ?? null)} />
          <StatTile style={styles.third} label="FT %" value={percent(totals?.ftPct ?? null)} />
        </View>
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingTop: 60 },
  errorText: { fontSize: fontSize.body, color: colors.inkSoft, textAlign: 'center' },
  section: { gap: spacing.sm },
  grid: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
  third: { flexBasis: '30%' },
  hint: { fontSize: fontSize.small, color: colors.inkSoft, textAlign: 'center' },
});
