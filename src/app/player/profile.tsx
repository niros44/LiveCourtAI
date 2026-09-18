import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, Image, ScrollView, StyleSheet, Text, View } from 'react-native';

import { Avatar } from '@/components/ui/Avatar';
import { Card } from '@/components/ui/Card';
import { Screen } from '@/components/ui/Screen';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { getCurrentPersonId } from '@/lib/auth';
import {
  type AttendanceSummary,
  type Measurement,
  type MyProfile,
  type Playership,
  type SeasonTotals,
  getAttendanceSummary,
  getMyMeasurement,
  getMyPlayerships,
  getMyProfile,
  getSeasonTotals,
} from '@/lib/playerData';
import { colors } from '@/theme/colors';
import { typography } from '@/theme/typography';

export default function PlayerProfileScreen() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [profile, setProfile] = useState<MyProfile | null>(null);
  const [playerships, setPlayerships] = useState<Playership[]>([]);
  const [measurement, setMeasurement] = useState<Measurement | null>(null);
  const [attendance, setAttendance] = useState<AttendanceSummary | null>(null);
  const [season, setSeason] = useState<SeasonTotals | null>(null);

  const load = useCallback(async () => {
    try {
      setError(null);
      const id = await getCurrentPersonId();
      if (!id) {
        setError('No profile found for this account.');
        setLoading(false);
        return;
      }
      const [me, ships] = await Promise.all([getMyProfile(id), getMyPlayerships(id)]);
      setProfile(me);
      setPlayerships(ships);

      const primaryPlayerId = ships[0]?.playerId ?? null;
      if (primaryPlayerId) {
        const [meas, att, totals] = await Promise.all([
          getMyMeasurement(primaryPlayerId),
          getAttendanceSummary(primaryPlayerId),
          getSeasonTotals(primaryPlayerId),
        ]);
        setMeasurement(meas);
        setAttendance(att);
        setSeason(totals);
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Something went wrong loading your profile.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

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
        <View style={styles.centered}>
          <Text style={styles.errorText}>{error}</Text>
        </View>
      </Screen>
    );
  }

  return (
    <Screen>
      <SectionHeader title="PROFILE" />

      <View style={styles.headerBlock}>
        {profile?.avatarUrl ? (
          <Image source={{ uri: profile.avatarUrl }} style={styles.avatarImage} />
        ) : (
          <Avatar initials={profile?.initials ?? '?'} size={72} color={colors.buzzer} />
        )}
        <Text style={styles.name}>{profile?.name}</Text>
        {profile?.age != null ? <Text style={styles.age}>Age {profile.age}</Text> : null}
      </View>

      {playerships.length > 0 ? (
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8 }}>
          {playerships.map((p) => (
            <View key={p.teamId} style={[styles.teamChip, { borderColor: p.color }]}>
              <Text style={[styles.teamChipLabel, { color: p.color }]}>
                {p.teamName}
                {p.jersey != null ? ` · #${p.jersey}` : ''}
              </Text>
            </View>
          ))}
        </ScrollView>
      ) : null}

      <View>
        <SectionHeader title="PHYSICAL" />
        <Card style={styles.physicalGrid}>
          <PhysicalStat label="Height" value={measurement?.heightCm != null ? `${measurement.heightCm} cm` : '–'} />
          <PhysicalStat label="Weight" value={measurement?.weightKg != null ? `${measurement.weightKg} kg` : '–'} />
          <PhysicalStat label="Wingspan" value={measurement?.wingspanCm != null ? `${measurement.wingspanCm} cm` : '–'} />
          <PhysicalStat label="Vertical" value={measurement?.verticalJumpCm != null ? `${measurement.verticalJumpCm} cm` : '–'} />
        </Card>
        {!measurement ? <Text style={styles.hint}>No measurements recorded yet.</Text> : null}
      </View>

      <View>
        <SectionHeader title="SEASON TOTALS" />
        <View style={styles.statsGrid}>
          <StatTile label="Games Played" value={season && season.gamesWithStats > 0 ? String(season.gamesWithStats) : '–'} />
          <StatTile label="Total Points" value={season && season.gamesWithStats > 0 ? String(season.totalPts) : '–'} />
          <StatTile label="FG %" value={season?.fgPct != null ? `${season.fgPct}%` : '–'} />
          <StatTile label="3PT %" value={season?.threePct != null ? `${season.threePct}%` : '–'} />
        </View>
        {season && season.gamesWithStats === 0 ? <Text style={styles.hint}>No game stats recorded yet this season.</Text> : null}
      </View>

      <View>
        <SectionHeader title="PER-GAME AVERAGES" />
        <View style={styles.statsGrid}>
          <StatTile label="Points" value={season?.avgPts != null ? season.avgPts.toFixed(1) : '–'} />
          <StatTile label="Rebounds" value={season?.avgReb != null ? season.avgReb.toFixed(1) : '–'} />
          <StatTile label="Assists" value={season?.avgAst != null ? season.avgAst.toFixed(1) : '–'} />
          <StatTile label="Steals" value={season?.avgStl != null ? season.avgStl.toFixed(1) : '–'} />
        </View>
      </View>

      <View>
        <SectionHeader title="ATTENDANCE" />
        <Card style={styles.attendanceRow}>
          <PhysicalStat label="Participation" value={attendance?.participationPct != null ? `${attendance.participationPct}%` : '–'} />
          <PhysicalStat label="Current Streak" value={attendance ? String(attendance.currentStreak) : '–'} />
          <PhysicalStat label="Events Marked" value={attendance ? String(attendance.totalMarked) : '–'} />
        </Card>
      </View>
    </Screen>
  );
}

function StatTile({ label, value }: { label: string; value: string }) {
  return (
    <Card style={styles.statTile}>
      <Text style={styles.statValue}>{value}</Text>
      <Text style={styles.statLabel}>{label}</Text>
    </Card>
  );
}

function PhysicalStat({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.physicalStat}>
      <Text style={styles.physicalValue}>{value}</Text>
      <Text style={styles.physicalLabel}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingTop: 60 },
  errorText: { fontSize: 13, color: colors.inkSoft, textAlign: 'center' },
  hint: { fontSize: 11, color: colors.inkSoft, marginTop: 8, textAlign: 'center' },
  headerBlock: { alignItems: 'center', gap: 4 },
  avatarImage: { width: 72, height: 72, borderRadius: 36 },
  name: { ...typography.heading, fontSize: 18, color: colors.navy, marginTop: 8 },
  age: { fontSize: 12, color: colors.inkSoft },
  teamChip: { borderWidth: 1.5, borderRadius: 20, paddingVertical: 6, paddingHorizontal: 12 },
  teamChipLabel: { fontSize: 12, fontWeight: '700' },
  physicalGrid: { flexDirection: 'row', justifyContent: 'space-between' },
  physicalStat: { alignItems: 'center', flex: 1 },
  physicalValue: { ...typography.heading, fontSize: 16, color: colors.navy },
  physicalLabel: { fontSize: 10, color: colors.inkSoft, marginTop: 4, textAlign: 'center' },
  attendanceRow: { flexDirection: 'row', justifyContent: 'space-between' },
  statsGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginTop: 8 },
  statTile: { width: '48%', alignItems: 'center', paddingVertical: 16 },
  statValue: { ...typography.heading, fontSize: 20, color: colors.navy },
  statLabel: { fontSize: 11, color: colors.inkSoft, marginTop: 4, textAlign: 'center' },
});
