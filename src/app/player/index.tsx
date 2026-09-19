import { Ionicons } from '@expo/vector-icons';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import { Badge } from '@/components/ui/Badge';
import { Card } from '@/components/ui/Card';
import { Chip } from '@/components/ui/Chip';
import { EventRow, EventTypeTag } from '@/components/ui/EventRow';
import { Screen } from '@/components/ui/Screen';
import { ScreenHeader } from '@/components/ui/ScreenHeader';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { getCurrentPersonId } from '@/lib/auth';
import {
  type Announcement,
  type AttendanceSummary,
  type EventStatus,
  type MyEvent,
  type MyProfile,
  type Playership,
  type SeasonTotals,
  type WeeklyFocus,
  formatEventDay,
  formatEventTime,
  getAnnouncements,
  getAttendanceSummary,
  getCurrentWeeklyFocus,
  getMyEvents,
  getMyPlayerships,
  getMyProfile,
  getSeasonTotals,
  setMyRsvp,
} from '@/lib/playerData';
import { errorMessage } from '@/lib/errors';
import { colors } from '@/theme/colors';
import { fontSize, radius, spacing, touchTarget } from '@/theme/tokens';
import { typography } from '@/theme/typography';

export default function PlayerHomeScreen() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [personId, setPersonId] = useState<string | null>(null);
  const [profile, setProfile] = useState<MyProfile | null>(null);
  const [playerships, setPlayerships] = useState<Playership[]>([]);
  const [selectedTeamId, setSelectedTeamId] = useState<string | null>(null);
  const [events, setEvents] = useState<MyEvent[]>([]);
  const [weeklyFocus, setWeeklyFocus] = useState<WeeklyFocus | null>(null);
  const [attendance, setAttendance] = useState<AttendanceSummary | null>(null);
  const [season, setSeason] = useState<SeasonTotals | null>(null);
  const [announcements, setAnnouncements] = useState<Announcement[]>([]);
  const [scopeLoading, setScopeLoading] = useState(false);
  const [rsvpSaving, setRsvpSaving] = useState(false);

  const load = useCallback(async () => {
    try {
      setError(null);
      const id = await getCurrentPersonId();
      if (!id) {
        setError('No profile found for this account.');
        setLoading(false);
        return;
      }
      setPersonId(id);
      const [me, ships] = await Promise.all([getMyProfile(id), getMyPlayerships(id)]);
      setProfile(me);
      setPlayerships(ships);
      if (ships.length) setSelectedTeamId(ships[0].teamId);
    } catch (e) {
      setError(errorMessage(e, 'Something went wrong loading your profile.'));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    if (!selectedTeamId || !playerships.length) return;
    const ship = playerships.find((p) => p.teamId === selectedTeamId);
    if (!ship) return;
    setScopeLoading(true);
    const from = new Date();
    const to = new Date();
    to.setDate(to.getDate() + 30);
    (async () => {
      const [evts, focus, att, totals, ann] = await Promise.all([
        getMyEvents([ship], { from, to }),
        getCurrentWeeklyFocus(selectedTeamId),
        getAttendanceSummary(ship.playerId),
        getSeasonTotals(ship.playerId),
        getAnnouncements([ship]),
      ]);
      setEvents(evts);
      setWeeklyFocus(focus);
      setAttendance(att);
      setSeason(totals);
      setAnnouncements(ann);
    })()
      .catch((e) => setError(errorMessage(e, 'Failed to load your team.')))
      .finally(() => setScopeLoading(false));
  }, [selectedTeamId, playerships]);

  const nextEvent = useMemo(() => events.find((e) => new Date(e.startsAt).getTime() >= Date.now()) ?? null, [events]);
  const upcoming = useMemo(() => events.filter((e) => e.id !== nextEvent?.id).slice(0, 4), [events, nextEvent]);
  const selectedShip = playerships.find((p) => p.teamId === selectedTeamId) ?? null;

  async function handleRsvp(status: EventStatus) {
    if (!nextEvent || !personId) return;
    setRsvpSaving(true);
    try {
      await setMyRsvp(nextEvent.id, nextEvent.playerId, status, personId);
      setEvents((prev) => prev.map((e) => (e.id === nextEvent.id ? { ...e, rsvp: status } : e)));
    } catch (e) {
      setError(errorMessage(e, 'Failed to save your response.'));
    } finally {
      setRsvpSaving(false);
    }
  }

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
  if (playerships.length === 0) {
    return (
      <Screen>
        <SectionHeader title="HOME" />
        <Card>
          <Text style={styles.emptyText}>You&apos;re not on a team roster yet.</Text>
        </Card>
      </Screen>
    );
  }

  return (
    <Screen>
      <ScreenHeader
        title={profile?.name ?? ''}
        subtitle={selectedShip?.label}
        initials={profile?.initials ?? '?'}
        right={<Ionicons name="notifications-outline" size={22} color={colors.navy} />}
      />

      {playerships.length > 1 ? (
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: spacing.sm }}>
          {playerships.map((p) => (
            <Chip key={p.teamId} label={p.teamName} active={selectedTeamId === p.teamId} onPress={() => setSelectedTeamId(p.teamId)} />
          ))}
        </ScrollView>
      ) : null}

      {scopeLoading ? (
        <ActivityIndicator color={colors.buzzer} />
      ) : (
        <>
          <View style={styles.section}>
            <SectionHeader title="Next up" />
            {nextEvent ? (
              <Card style={styles.nextCard}>
                <View style={styles.tagWrap}>
                  <EventTypeTag type={nextEvent.type} />
                </View>
                <Text style={styles.nextTitle}>
                  {nextEvent.type === 'game' && nextEvent.opponentName ? `vs ${nextEvent.opponentName}` : nextEvent.title}
                </Text>
                <View style={styles.metaRow}>
                  <Ionicons name="calendar-outline" size={14} color={colors.inkSoft} />
                  <Text style={styles.metaText}>
                    {formatEventDay(nextEvent.startsAt)} · {formatEventTime(nextEvent.startsAt)}
                  </Text>
                </View>
                {nextEvent.facilityName ? (
                  <View style={styles.metaRow}>
                    <Ionicons name="location-outline" size={14} color={colors.inkSoft} />
                    <Text style={styles.metaText}>{nextEvent.facilityName}</Text>
                  </View>
                ) : null}

                {nextEvent.rsvp === 'attending' || nextEvent.rsvp === 'not_attending' ? (
                  <Badge label={nextEvent.rsvp === 'attending' ? "You're in" : "You can't make it"} tone={nextEvent.rsvp === 'attending' ? 'in' : 'out'} />
                ) : (
                  <View style={styles.rsvpRow}>
                    <Pressable style={[styles.rsvpBtn, styles.rsvpIn]} onPress={() => handleRsvp('attending')} disabled={rsvpSaving}>
                      <Text style={styles.rsvpInLabel}>I&apos;m in</Text>
                    </Pressable>
                    <Pressable style={[styles.rsvpBtn, styles.rsvpOut]} onPress={() => handleRsvp('not_attending')} disabled={rsvpSaving}>
                      <Text style={styles.rsvpOutLabel}>Can&apos;t make it</Text>
                    </Pressable>
                  </View>
                )}
              </Card>
            ) : (
              <Card>
                <Text style={styles.emptyText}>No upcoming events scheduled.</Text>
              </Card>
            )}
          </View>

          {weeklyFocus ? (
            <View style={styles.section}>
              <SectionHeader title="This week's focus" />
              <Card style={styles.focusCard}>
                <Text style={styles.focusTitle}>{weeklyFocus.title}</Text>
                {weeklyFocus.description ? <Text style={styles.focusDesc}>{weeklyFocus.description}</Text> : null}
              </Card>
            </View>
          ) : null}

          {attendance && attendance.currentStreak > 0 ? (
            <Card style={styles.streakCard}>
              <Ionicons name="flame" size={20} color={colors.buzzer} />
              <Text style={styles.streakText}>
                <Text style={styles.streakNum}>{attendance.currentStreak}</Text> event attendance streak
              </Text>
            </Card>
          ) : null}

          <View style={styles.section}>
            <SectionHeader title="Season stats" />
            <View style={styles.statsGrid}>
              <StatTile label="Games played" value={season && season.gamesWithStats > 0 ? String(season.gamesWithStats) : '–'} />
              <StatTile label="Points / game" value={season?.avgPts != null ? season.avgPts.toFixed(1) : '–'} />
              <StatTile label="Attendance" value={attendance?.participationPct != null ? `${attendance.participationPct}%` : '–'} />
              <StatTile label="Assists / game" value={season?.avgAst != null ? season.avgAst.toFixed(1) : '–'} />
            </View>
            {season && season.gamesWithStats === 0 ? (
              <Text style={styles.statsHint}>No game stats recorded yet this season.</Text>
            ) : null}
          </View>

          <View style={styles.section}>
            <SectionHeader title="Upcoming" />
            <View style={styles.list}>
              {upcoming.length === 0 ? (
                <Card>
                  <Text style={styles.emptyText}>Nothing else on the schedule yet.</Text>
                </Card>
              ) : (
                upcoming.map((e) => (
                  <EventRow
                    key={e.id}
                    type={e.type}
                    title={e.type === 'game' && e.opponentName ? `vs ${e.opponentName}` : e.title}
                    when={`${formatEventDay(e.startsAt)} · ${formatEventTime(e.startsAt)}`}
                    rsvp={e.rsvp}
                  />
                ))
              )}
            </View>
          </View>

          <View style={styles.section}>
            <SectionHeader title="Coach messages" />
            <View style={styles.list}>
              {announcements.length === 0 ? (
                <Card>
                  <Text style={styles.emptyText}>No messages from your coach yet.</Text>
                </Card>
              ) : (
                announcements.map((a) => (
                  <Card key={a.id} accentColor={a.isUrgent ? colors.buzzer : undefined}>
                    <Text style={styles.msgTitle}>{a.title}</Text>
                    <Text style={styles.msgBody}>{a.content}</Text>
                    <Text style={styles.msgMeta}>
                      {a.authorName} · {formatEventDay(a.createdAt)}
                    </Text>
                  </Card>
                ))
              )}
            </View>
          </View>
        </>
      )}
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

const styles = StyleSheet.create({
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingTop: 60 },
  errorText: { fontSize: fontSize.body, color: colors.inkSoft, textAlign: 'center' },
  emptyText: { fontSize: fontSize.body, color: colors.inkSoft, lineHeight: 20 },
  section: { gap: spacing.sm },
  list: { gap: spacing.sm },
  nextCard: { gap: spacing.sm },
  tagWrap: { alignSelf: 'flex-start' },
  nextTitle: { ...typography.heading, fontSize: fontSize.title, color: colors.navy },
  metaRow: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  metaText: { fontSize: fontSize.small, color: colors.inkSoft },
  rsvpRow: { flexDirection: 'row', gap: spacing.md, marginTop: spacing.xs },
  rsvpBtn: { flex: 1, minHeight: touchTarget, borderRadius: radius.md, alignItems: 'center', justifyContent: 'center', borderWidth: 1 },
  rsvpIn: { backgroundColor: colors.buzzer, borderColor: colors.buzzer },
  rsvpOut: { backgroundColor: colors.white, borderColor: colors.line },
  rsvpInLabel: { color: colors.white, fontSize: fontSize.body, fontWeight: '800' },
  rsvpOutLabel: { color: colors.navy, fontSize: fontSize.body, fontWeight: '700' },
  focusCard: { backgroundColor: colors.tintNavy, borderColor: colors.tintNavy },
  focusTitle: { ...typography.heading, fontSize: fontSize.body, color: colors.navy },
  focusDesc: { fontSize: fontSize.body, color: colors.inkSoft, marginTop: spacing.xs, lineHeight: 20 },
  streakCard: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
  streakText: { fontSize: fontSize.body, color: colors.navy },
  streakNum: { ...typography.heading, fontSize: fontSize.subtitle, color: colors.buzzer },
  statsGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
  statTile: { flexGrow: 1, flexBasis: '45%', alignItems: 'center', paddingVertical: spacing.lg },
  statValue: { ...typography.heading, fontSize: fontSize.display, color: colors.navy },
  statLabel: { fontSize: fontSize.caption, color: colors.inkSoft, marginTop: spacing.xs, textAlign: 'center' },
  statsHint: { fontSize: fontSize.caption, color: colors.inkSoft, textAlign: 'center' },
  msgTitle: { ...typography.heading, fontSize: fontSize.body, color: colors.navy },
  msgBody: { fontSize: fontSize.small, color: colors.inkSoft, marginTop: spacing.xs, lineHeight: 18 },
  msgMeta: { fontSize: fontSize.caption, color: colors.inkSoft, marginTop: spacing.sm },
});
