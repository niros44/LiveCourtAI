import { Ionicons } from '@expo/vector-icons';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import { Avatar } from '@/components/ui/Avatar';
import { Card } from '@/components/ui/Card';
import { Chip } from '@/components/ui/Chip';
import { Screen } from '@/components/ui/Screen';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { getCurrentPersonId } from '@/lib/auth';
import { type CoachEvent, type CoachTeam, getMyProfile, getMyTeams, getRosters, getTeamsEvents } from '@/lib/coachData';
import { errorMessage } from '@/lib/errors';
import { colors } from '@/theme/colors';
import { typography } from '@/theme/typography';

function startOfWeek(d: Date): Date {
  const copy = new Date(d);
  copy.setHours(0, 0, 0, 0);
  copy.setDate(copy.getDate() - copy.getDay());
  return copy;
}
function isSameDay(a: Date, b: Date) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}
function fmtTime(iso: string) {
  return new Date(iso).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: false });
}
function fmtDay(d: Date) {
  return d.toLocaleDateString('en-US', { weekday: 'long', day: 'numeric', month: 'short' });
}

export default function CoachHomeScreen() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [profile, setProfile] = useState({ name: 'Coach', initials: '?' });
  const [teams, setTeams] = useState<CoachTeam[]>([]);
  const [events, setEvents] = useState<CoachEvent[]>([]);
  const [selectedTeamId, setSelectedTeamId] = useState<string>('all');
  const [selectedDate, setSelectedDate] = useState<Date>(() => {
    const d = new Date();
    d.setHours(0, 0, 0, 0);
    return d;
  });

  const load = useCallback(async () => {
    try {
      setError(null);
      const personId = await getCurrentPersonId();
      if (!personId) {
        setError('No profile found for this account.');
        setLoading(false);
        return;
      }
      const [me, myTeams] = await Promise.all([getMyProfile(personId), getMyTeams(personId)]);
      setProfile(me);
      setTeams(myTeams);

      const from = startOfWeek(new Date());
      const to = new Date(from);
      to.setDate(to.getDate() + 6);
      to.setHours(23, 59, 59, 999);

      const roster = await getRosters(myTeams.map((t) => t.id));
      const weekEvents = await getTeamsEvents(myTeams, { from, to }, roster);
      setEvents(weekEvents);
    } catch (e) {
      setError(errorMessage(e, 'Something went wrong loading your teams.'));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const visibleEvents = useMemo(
    () => (selectedTeamId === 'all' ? events : events.filter((e) => e.teamId === selectedTeamId)),
    [events, selectedTeamId]
  );

  const weekDays = useMemo(() => {
    const from = startOfWeek(new Date());
    return Array.from({ length: 7 }, (_, i) => {
      const d = new Date(from);
      d.setDate(d.getDate() + i);
      return d;
    });
  }, []);

  const dayEvents = useCallback((day: Date) => visibleEvents.filter((e) => isSameDay(new Date(e.startsAt), day)), [visibleEvents]);
  const selectedDayEvents = dayEvents(selectedDate);
  const teamById = useMemo(() => new Map(teams.map((t) => [t.id, t])), [teams]);

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
      <View style={styles.header}>
        <Avatar initials={profile.initials} color={colors.navy} />
        <View style={{ flex: 1 }}>
          <Text style={styles.brand}>Coach · {profile.name}</Text>
        </View>
        <Ionicons name="notifications-outline" size={22} color={colors.navy} />
      </View>

      {teams.length === 0 ? (
        <Card>
          <Text style={styles.emptyText}>You&apos;re not assigned to coach any team yet.</Text>
        </Card>
      ) : (
        <>
          <View>
            <Text style={styles.scopeLabel}>SHOWING:</Text>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8 }}>
              <Chip label="All Teams" active={selectedTeamId === 'all'} onPress={() => setSelectedTeamId('all')} />
              {teams.map((team) => (
                <Chip key={team.id} label={team.name} active={selectedTeamId === team.id} onPress={() => setSelectedTeamId(team.id)} />
              ))}
            </ScrollView>
          </View>

          <View>
            <SectionHeader title="MY WEEK" tag={`${visibleEvents.length} event${visibleEvents.length === 1 ? '' : 's'} this week`} />
            <View style={styles.dayStrip}>
              {weekDays.map((day) => {
                const selected = isSameDay(day, selectedDate);
                const has = dayEvents(day).length > 0;
                return (
                  <Pressable key={day.toISOString()} onPress={() => setSelectedDate(day)} style={[styles.dayCell, selected && styles.dayCellSelected]}>
                    <Text style={[styles.dayLetter, selected && styles.dayLetterSelected]}>{day.toLocaleDateString('en-US', { weekday: 'narrow' })}</Text>
                    <Text style={[styles.dayNumber, selected && styles.dayNumberSelected]}>{day.getDate()}</Text>
                    <View style={[styles.dayDot, { backgroundColor: has ? (selected ? colors.white : colors.buzzer) : 'transparent' }]} />
                  </Pressable>
                );
              })}
            </View>

            <Text style={styles.dayHeading}>{fmtDay(selectedDate)}</Text>

            <View style={{ gap: 10, marginTop: 10 }}>
              {selectedDayEvents.length === 0 ? (
                <Card>
                  <Text style={styles.emptyText}>No events scheduled this day.</Text>
                </Card>
              ) : (
                selectedDayEvents.map((event) => {
                  const team = teamById.get(event.teamId);
                  const ratio = event.roster > 0 ? event.confirmed / event.roster : 0;
                  const low = ratio < 0.6;
                  return (
                    <Card key={event.id} style={low ? { borderLeftWidth: 3, borderLeftColor: colors.red } : undefined}>
                      <View style={styles.eventTop}>
                        <View style={{ flex: 1 }}>
                          <Text style={[styles.teamTag, { color: team?.color, backgroundColor: `${team?.color}1A` }]}>{team?.name}</Text>
                          <Text style={styles.eventTitle}>{event.title}</Text>
                          <View style={styles.metaRow}>
                            <Ionicons name="time-outline" size={13} color={colors.inkSoft} />
                            <Text style={styles.metaText}>
                              {fmtTime(event.startsAt)} - {fmtTime(event.endsAt)}
                            </Text>
                          </View>
                          {event.facilityName ? (
                            <View style={styles.metaRow}>
                              <Ionicons name="location-outline" size={13} color={colors.inkSoft} />
                              <Text style={styles.metaText}>{event.facilityName}</Text>
                            </View>
                          ) : null}
                        </View>
                        <View style={styles.attendCol}>
                          <Text style={styles.attendLabel}>ATTENDING</Text>
                          <Text style={styles.attendValue}>
                            {event.confirmed}
                            <Text style={styles.attendOf}>/{event.roster}</Text>
                          </Text>
                        </View>
                      </View>
                      <View style={styles.barTrack}>
                        <View style={[styles.barFill, { width: `${Math.round(ratio * 100)}%`, backgroundColor: low ? colors.red : colors.green }]} />
                      </View>
                    </Card>
                  );
                })
              )}
            </View>
          </View>
        </>
      )}
    </Screen>
  );
}

const styles = StyleSheet.create({
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingTop: 60 },
  errorText: { fontSize: 13, color: colors.inkSoft, textAlign: 'center' },
  emptyText: { fontSize: 13, color: colors.inkSoft, lineHeight: 19 },
  header: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  brand: { ...typography.heading, fontSize: 14, color: colors.navy },
  scopeLabel: { ...typography.label, fontSize: 10, color: colors.inkSoft, marginBottom: 8 },
  dayStrip: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    backgroundColor: colors.white,
    borderWidth: 1,
    borderColor: colors.line,
    borderRadius: 14,
    padding: 8,
    marginTop: 4,
  },
  dayCell: { flex: 1, alignItems: 'center', gap: 4, paddingVertical: 8, borderRadius: 10 },
  dayCellSelected: { backgroundColor: colors.navy },
  dayLetter: { fontSize: 10, fontWeight: '700', color: colors.inkSoft },
  dayLetterSelected: { color: colors.white },
  dayNumber: { fontSize: 14, fontWeight: '800', color: colors.navy },
  dayNumberSelected: { color: colors.white },
  dayDot: { width: 6, height: 6, borderRadius: 3 },
  dayHeading: { ...typography.label, fontSize: 11, color: colors.inkSoft, marginTop: 12 },
  eventTop: { flexDirection: 'row', gap: 10 },
  teamTag: { alignSelf: 'flex-start', fontSize: 11, fontWeight: '700', paddingVertical: 3, paddingHorizontal: 9, borderRadius: 6, marginBottom: 8 },
  eventTitle: { ...typography.heading, fontSize: 17, color: colors.navy, marginBottom: 6 },
  metaRow: { flexDirection: 'row', alignItems: 'center', gap: 5, marginBottom: 3 },
  metaText: { fontSize: 12, color: colors.inkSoft },
  attendCol: { width: 78, alignItems: 'flex-end' },
  attendLabel: { fontSize: 10, letterSpacing: 0.5, color: colors.inkSoft, textTransform: 'uppercase' },
  attendValue: { ...typography.heading, fontSize: 22, color: colors.navy },
  attendOf: { fontSize: 13, fontWeight: '400', color: colors.inkSoft },
  barTrack: { height: 5, borderRadius: 3, backgroundColor: colors.tintNavy, marginTop: 10, overflow: 'hidden' },
  barFill: { height: '100%', borderRadius: 3 },
});
