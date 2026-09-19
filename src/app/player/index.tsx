import { Ionicons } from '@expo/vector-icons';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import { Avatar } from '@/components/ui/Avatar';
import { Card } from '@/components/ui/Card';
import { Chip } from '@/components/ui/Chip';
import { Screen } from '@/components/ui/Screen';
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
      <View style={styles.header}>
        <Avatar initials={profile?.initials ?? '?'} color={colors.buzzer} />
        <View style={{ flex: 1 }}>
          <Text style={styles.playerName}>{profile?.name}</Text>
          <Text style={styles.teamLabel}>{selectedShip?.label}</Text>
        </View>
        <Ionicons name="notifications-outline" size={22} color={colors.navy} />
      </View>

      {playerships.length > 1 ? (
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8 }}>
          {playerships.map((p) => (
            <Chip key={p.teamId} label={p.teamName} active={selectedTeamId === p.teamId} onPress={() => setSelectedTeamId(p.teamId)} />
          ))}
        </ScrollView>
      ) : null}

      {scopeLoading ? (
        <ActivityIndicator color={colors.buzzer} />
      ) : (
        <>
          <View>
            <SectionHeader title="NEXT UP" />
            {nextEvent ? (
              <Card style={styles.nextCard}>
                <Text style={[styles.eventTypeTag, nextEvent.type === 'game' && styles.eventTypeTagGame]}>{nextEvent.type.toUpperCase()}</Text>
                <Text style={styles.nextTitle}>
                  {nextEvent.type === 'game' && nextEvent.opponentName ? `vs ${nextEvent.opponentName}` : nextEvent.title}
                </Text>
                <View style={styles.metaRow}>
                  <Ionicons name="calendar-outline" size={13} color={colors.inkSoft} />
                  <Text style={styles.metaText}>
                    {formatEventDay(nextEvent.startsAt)} · {formatEventTime(nextEvent.startsAt)}
                  </Text>
                </View>
                {nextEvent.facilityName ? (
                  <View style={styles.metaRow}>
                    <Ionicons name="location-outline" size={13} color={colors.inkSoft} />
                    <Text style={styles.metaText}>{nextEvent.facilityName}</Text>
                  </View>
                ) : null}

                {nextEvent.rsvp === 'attending' || nextEvent.rsvp === 'not_attending' ? (
                  <View style={[styles.rsvpDoneBadge, nextEvent.rsvp === 'attending' ? styles.rsvpDoneIn : styles.rsvpDoneOut]}>
                    <Text style={styles.rsvpDoneLabel}>{nextEvent.rsvp === 'attending' ? "You're in" : "You can't make it"}</Text>
                  </View>
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
            <View>
              <SectionHeader title="THIS WEEK'S FOCUS" />
              <Card accentColor={colors.gold}>
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

          <View>
            <SectionHeader title="SEASON STATS" />
            <View style={styles.statsGrid}>
              <StatTile label="Games Played" value={season && season.gamesWithStats > 0 ? String(season.gamesWithStats) : '–'} />
              <StatTile label="Points / Game" value={season?.avgPts != null ? season.avgPts.toFixed(1) : '–'} />
              <StatTile label="Attendance" value={attendance?.participationPct != null ? `${attendance.participationPct}%` : '–'} />
              <StatTile label="Assists / Game" value={season?.avgAst != null ? season.avgAst.toFixed(1) : '–'} />
            </View>
            {season && season.gamesWithStats === 0 ? (
              <Text style={styles.statsHint}>No game stats recorded yet this season.</Text>
            ) : null}
          </View>

          <View>
            <SectionHeader title="UPCOMING" />
            <View style={{ gap: 8, marginTop: 8 }}>
              {upcoming.length === 0 ? (
                <Card>
                  <Text style={styles.emptyText}>Nothing else on the schedule yet.</Text>
                </Card>
              ) : (
                upcoming.map((e) => (
                  <Card key={e.id} style={styles.upcomingRow}>
                    <Text style={[styles.eventTypeTagSmall, e.type === 'game' && styles.eventTypeTagGame]}>{e.type.toUpperCase()}</Text>
                    <View style={{ flex: 1 }}>
                      <Text style={styles.upcomingTitle}>{e.type === 'game' && e.opponentName ? `vs ${e.opponentName}` : e.title}</Text>
                      <Text style={styles.upcomingMeta}>
                        {formatEventDay(e.startsAt)} · {formatEventTime(e.startsAt)}
                      </Text>
                    </View>
                  </Card>
                ))
              )}
            </View>
          </View>

          <View>
            <SectionHeader title="COACH MESSAGES" />
            <View style={{ gap: 8, marginTop: 8 }}>
              {announcements.length === 0 ? (
                <Card>
                  <Text style={styles.emptyText}>No messages from your coach yet.</Text>
                </Card>
              ) : (
                announcements.map((a) => (
                  <Card key={a.id} accentColor={colors.gold}>
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
  errorText: { fontSize: 13, color: colors.inkSoft, textAlign: 'center' },
  emptyText: { fontSize: 13, color: colors.inkSoft, lineHeight: 19 },
  header: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  playerName: { ...typography.heading, fontSize: 15, color: colors.navy },
  teamLabel: { fontSize: 12, color: colors.inkSoft, marginTop: 2 },
  nextCard: { gap: 8 },
  eventTypeTag: {
    alignSelf: 'flex-start',
    fontSize: 10,
    fontWeight: '800',
    letterSpacing: 0.5,
    color: colors.buzzerDark,
    backgroundColor: colors.tintOrange,
    paddingVertical: 3,
    paddingHorizontal: 8,
    borderRadius: 6,
  },
  eventTypeTagSmall: {
    fontSize: 9,
    fontWeight: '800',
    color: colors.buzzerDark,
    backgroundColor: colors.tintOrange,
    paddingVertical: 3,
    paddingHorizontal: 6,
    borderRadius: 5,
    width: 58,
    textAlign: 'center',
  },
  eventTypeTagGame: { color: colors.navy, backgroundColor: colors.tintNavy },
  nextTitle: { ...typography.heading, fontSize: 17, color: colors.navy },
  metaRow: { flexDirection: 'row', alignItems: 'center', gap: 5 },
  metaText: { fontSize: 12, color: colors.inkSoft },
  rsvpRow: { flexDirection: 'row', gap: 10, marginTop: 4 },
  rsvpBtn: { flex: 1, borderRadius: 10, paddingVertical: 11, alignItems: 'center', borderWidth: 1.5 },
  rsvpIn: { backgroundColor: colors.green, borderColor: colors.green },
  rsvpOut: { backgroundColor: colors.white, borderColor: colors.red },
  rsvpInLabel: { color: colors.white, fontSize: 13, fontWeight: '800' },
  rsvpOutLabel: { color: colors.redDark, fontSize: 13, fontWeight: '800' },
  rsvpDoneBadge: { alignSelf: 'flex-start', borderRadius: 8, paddingVertical: 6, paddingHorizontal: 12, marginTop: 4 },
  rsvpDoneIn: { backgroundColor: '#E9F7EF' },
  rsvpDoneOut: { backgroundColor: '#FDEDEC' },
  rsvpDoneLabel: { fontSize: 12, fontWeight: '700', color: colors.navy },
  focusTitle: { ...typography.heading, fontSize: 14, color: colors.navy },
  focusDesc: { fontSize: 13, color: colors.inkSoft, marginTop: 4, lineHeight: 18 },
  streakCard: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  streakText: { fontSize: 13, color: colors.navy },
  streakNum: { ...typography.heading, fontSize: 15, color: colors.buzzer },
  statsGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginTop: 8 },
  statTile: { width: '48%', alignItems: 'center', paddingVertical: 16 },
  statValue: { ...typography.heading, fontSize: 22, color: colors.navy },
  statLabel: { fontSize: 11, color: colors.inkSoft, marginTop: 4, textAlign: 'center' },
  statsHint: { fontSize: 11, color: colors.inkSoft, marginTop: 8, textAlign: 'center' },
  upcomingRow: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  upcomingTitle: { ...typography.heading, fontSize: 13, color: colors.navy },
  upcomingMeta: { fontSize: 11, color: colors.inkSoft, marginTop: 2 },
  msgTitle: { ...typography.heading, fontSize: 13, color: colors.navy },
  msgBody: { fontSize: 12, color: colors.inkSoft, marginTop: 4, lineHeight: 17 },
  msgMeta: { fontSize: 10, color: colors.inkSoft, marginTop: 6 },
});
