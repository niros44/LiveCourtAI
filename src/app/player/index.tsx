import { Ionicons } from '@expo/vector-icons';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, ScrollView, StyleSheet, Text, View } from 'react-native';

import { Card } from '@/components/ui/Card';
import { Chip } from '@/components/ui/Chip';
import { EventRow } from '@/components/ui/EventRow';
import { Screen } from '@/components/ui/Screen';
import { ScreenHeader } from '@/components/ui/ScreenHeader';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { getCurrentPersonId } from '@/lib/auth';
import {
  type Announcement,
  type EventStatus,
  type MyEvent,
  type MyProfile,
  type Playership,
  type TeamHeader,
  type WeeklyFocus,
  formatEventDay,
  formatEventTime,
  getAnnouncements,
  getCurrentWeeklyFocus,
  getMyEvents,
  getMyPlayerships,
  getMyProfile,
  getTeamHeader,
  getWeekRange,
  setMyRsvp,
} from '@/lib/playerData';
import { errorMessage } from '@/lib/errors';
import { colors } from '@/theme/colors';
import { fontSize, spacing } from '@/theme/tokens';
import { typography } from '@/theme/typography';

const shortDay = (d: Date) => d.toLocaleDateString('en-US', { day: 'numeric', month: 'short' });

export default function PlayerHomeScreen() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [personId, setPersonId] = useState<string | null>(null);
  const [profile, setProfile] = useState<MyProfile | null>(null);
  const [playerships, setPlayerships] = useState<Playership[]>([]);
  const [selectedTeamId, setSelectedTeamId] = useState<string | null>(null);
  const [team, setTeam] = useState<TeamHeader | null>(null);
  const [weekEvents, setWeekEvents] = useState<MyEvent[]>([]);
  const [weeklyFocus, setWeeklyFocus] = useState<WeeklyFocus | null>(null);
  const [announcements, setAnnouncements] = useState<Announcement[]>([]);
  const [scopeLoading, setScopeLoading] = useState(false);
  const [savingEventId, setSavingEventId] = useState<string | null>(null);

  const week = useMemo(() => getWeekRange(), []);
  // Fixed at mount so render stays pure; only decides which events still take an RSVP.
  const [now] = useState(() => Date.now());

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
    (async () => {
      const [header, evts, focus, ann] = await Promise.all([
        getTeamHeader(selectedTeamId),
        getMyEvents([ship], week),
        getCurrentWeeklyFocus(selectedTeamId),
        getAnnouncements([ship]),
      ]);
      setTeam(header);
      setWeekEvents(evts);
      setWeeklyFocus(focus);
      setAnnouncements(ann);
    })()
      .catch((e) => setError(errorMessage(e, 'Failed to load your team.')))
      .finally(() => setScopeLoading(false));
  }, [selectedTeamId, playerships, week]);

  const selectedShip = playerships.find((p) => p.teamId === selectedTeamId) ?? null;

  async function handleRsvp(event: MyEvent, status: EventStatus) {
    if (!personId) return;
    setSavingEventId(event.id);
    try {
      await setMyRsvp(event.id, event.playerId, status, personId);
      setWeekEvents((prev) => prev.map((e) => (e.id === event.id ? { ...e, rsvp: status } : e)));
    } catch (e) {
      setError(errorMessage(e, 'Failed to save your response.'));
    } finally {
      setSavingEventId(null);
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
        <ScreenHeader title="Home" />
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

      <View style={styles.section}>
        <SectionHeader title={playerships.length > 1 ? 'My teams' : 'My team'} />
        {playerships.length > 1 ? (
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: spacing.sm }}>
            {playerships.map((p) => (
              <Chip key={p.teamId} label={p.teamName} active={selectedTeamId === p.teamId} onPress={() => setSelectedTeamId(p.teamId)} />
            ))}
          </ScrollView>
        ) : null}
        {team ? (
          <Card style={styles.teamCard}>
            <Text style={styles.teamName}>{team.teamName}</Text>
            <Text style={styles.teamSub}>
              {team.clubName}
              {team.ageGroupName ? ` · ${team.ageGroupName}` : ''}
            </Text>
            <View style={styles.infoRow}>
              <Info label="Coach" value={team.headCoachName ?? '–'} />
              <Info label="Record" value={team.record ? `${team.record.wins}–${team.record.losses}` : '–'} />
              <Info label="My number" value={selectedShip?.jersey != null ? `#${selectedShip.jersey}` : '–'} />
            </View>
          </Card>
        ) : null}
      </View>

      {scopeLoading ? (
        <ActivityIndicator color={colors.buzzer} />
      ) : (
        <>
          <View style={styles.section}>
            <SectionHeader title="This week" tag={`${shortDay(week.from)} – ${shortDay(week.to)}`} />
            <View style={styles.list}>
              {weekEvents.length === 0 ? (
                <Card>
                  <Text style={styles.emptyText}>Nothing scheduled this week.</Text>
                </Card>
              ) : (
                weekEvents.map((e) => {
                  const upcoming = new Date(e.startsAt).getTime() >= now;
                  return (
                    <EventRow
                      key={e.id}
                      type={e.type}
                      title={e.type === 'game' && e.opponentName ? `vs ${e.opponentName}` : e.title}
                      when={`${formatEventDay(e.startsAt)} · ${formatEventTime(e.startsAt)}`}
                      where={e.facilityName}
                      rsvp={e.rsvp}
                      onRsvp={upcoming ? (status) => handleRsvp(e, status) : undefined}
                      rsvpDisabled={savingEventId === e.id}
                    />
                  );
                })
              )}
            </View>
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

function Info({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.info}>
      <Text style={styles.infoLabel}>{label}</Text>
      <Text style={styles.infoValue} numberOfLines={1}>
        {value}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingTop: 60 },
  errorText: { fontSize: fontSize.body, color: colors.inkSoft, textAlign: 'center' },
  emptyText: { fontSize: fontSize.body, color: colors.inkSoft, lineHeight: 20 },
  section: { gap: spacing.sm },
  list: { gap: spacing.sm },
  teamCard: { gap: 2 },
  teamName: { ...typography.heading, fontSize: fontSize.title, color: colors.navy },
  teamSub: { fontSize: fontSize.small, color: colors.inkSoft },
  infoRow: { flexDirection: 'row', gap: spacing.md, marginTop: spacing.md },
  info: { flex: 1, gap: 2 },
  infoLabel: { fontSize: fontSize.caption, color: colors.inkSoft },
  infoValue: { ...typography.heading, fontSize: fontSize.body, color: colors.navy },
  focusCard: { backgroundColor: colors.tintNavy, borderColor: colors.tintNavy },
  focusTitle: { ...typography.heading, fontSize: fontSize.body, color: colors.navy },
  focusDesc: { fontSize: fontSize.body, color: colors.inkSoft, marginTop: spacing.xs, lineHeight: 20 },
  msgTitle: { ...typography.heading, fontSize: fontSize.body, color: colors.navy },
  msgBody: { fontSize: fontSize.small, color: colors.inkSoft, marginTop: spacing.xs, lineHeight: 18 },
  msgMeta: { fontSize: fontSize.caption, color: colors.inkSoft, marginTop: spacing.sm },
});
