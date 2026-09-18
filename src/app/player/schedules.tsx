import { Ionicons } from '@expo/vector-icons';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, Modal, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import { Badge, type BadgeTone } from '@/components/ui/Badge';
import { Card } from '@/components/ui/Card';
import { Chip } from '@/components/ui/Chip';
import { Screen } from '@/components/ui/Screen';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { getCurrentPersonId } from '@/lib/auth';
import {
  type EventStatus,
  type MyEvent,
  type Playership,
  formatEventTime,
  getMyEvents,
  getMyPlayerships,
  setMyRsvp,
} from '@/lib/playerData';
import { colors } from '@/theme/colors';
import { typography } from '@/theme/typography';

const STATUS_TONE: Record<EventStatus, BadgeTone> = { attending: 'in', not_attending: 'out', undecided: 'pending', injured: 'pending' };
const STATUS_LABEL: Record<EventStatus, string> = { attending: 'Confirmed', not_attending: 'Declined', undecided: 'Undecided', injured: 'Injured' };

function isSameDay(a: Date, b: Date) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

export default function PlayerSchedulesScreen() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [personId, setPersonId] = useState<string | null>(null);
  const [playerships, setPlayerships] = useState<Playership[]>([]);
  const [selectedTeamId, setSelectedTeamId] = useState<string | null>(null);
  const [monthAnchor, setMonthAnchor] = useState(new Date());
  const [events, setEvents] = useState<MyEvent[]>([]);
  const [selectedDay, setSelectedDay] = useState<Date | null>(null);
  const [saving, setSaving] = useState(false);

  const selectedShip = playerships.find((p) => p.teamId === selectedTeamId) ?? null;

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
      const ships = await getMyPlayerships(id);
      setPlayerships(ships);
      if (ships.length) setSelectedTeamId(ships[0].teamId);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Something went wrong loading your teams.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const loadMonth = useCallback(async () => {
    if (!selectedShip) return;
    const from = new Date(monthAnchor.getFullYear(), monthAnchor.getMonth(), 1);
    const to = new Date(monthAnchor.getFullYear(), monthAnchor.getMonth() + 1, 0, 23, 59, 59, 999);
    const monthEvents = await getMyEvents([selectedShip], { from, to });
    setEvents(monthEvents);
  }, [selectedShip, monthAnchor]);

  useEffect(() => {
    loadMonth().catch((e) => setError(e instanceof Error ? e.message : 'Failed to load schedule.'));
  }, [loadMonth]);

  const monthGrid = useMemo(() => {
    const year = monthAnchor.getFullYear();
    const month = monthAnchor.getMonth();
    const first = new Date(year, month, 1);
    const startOffset = first.getDay();
    const daysInMonth = new Date(year, month + 1, 0).getDate();
    const cells: (Date | null)[] = [];
    for (let i = 0; i < startOffset; i++) cells.push(null);
    for (let d = 1; d <= daysInMonth; d++) cells.push(new Date(year, month, d));
    return cells;
  }, [monthAnchor]);

  const eventsFor = useCallback((day: Date) => events.filter((e) => isSameDay(new Date(e.startsAt), day)), [events]);

  async function handleRsvp(event: MyEvent, status: EventStatus) {
    if (!personId) return;
    setSaving(true);
    try {
      await setMyRsvp(event.id, event.playerId, status, personId);
      setEvents((prev) => prev.map((e) => (e.id === event.id ? { ...e, rsvp: status } : e)));
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to save your response.');
    } finally {
      setSaving(false);
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
        <SectionHeader title="SCHEDULE" />
        <Card>
          <Text style={styles.emptyText}>You&apos;re not on a team roster yet.</Text>
        </Card>
      </Screen>
    );
  }

  const dayEvents = selectedDay ? eventsFor(selectedDay) : [];

  return (
    <Screen>
      <SectionHeader title="SCHEDULE" />

      {playerships.length > 1 ? (
        <View>
          <Text style={styles.scopeLabel}>TEAM:</Text>
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8 }}>
            {playerships.map((p) => (
              <Chip key={p.teamId} label={p.teamName} active={selectedTeamId === p.teamId} onPress={() => setSelectedTeamId(p.teamId)} />
            ))}
          </ScrollView>
        </View>
      ) : null}

      <View style={styles.monthNav}>
        <Pressable onPress={() => setMonthAnchor((a) => new Date(a.getFullYear(), a.getMonth() - 1, 1))} hitSlop={8}>
          <Ionicons name="chevron-back" size={18} color={colors.navy} />
        </Pressable>
        <Text style={styles.monthLabel}>{monthAnchor.toLocaleDateString('en-US', { month: 'long', year: 'numeric' })}</Text>
        <Pressable onPress={() => setMonthAnchor((a) => new Date(a.getFullYear(), a.getMonth() + 1, 1))} hitSlop={8}>
          <Ionicons name="chevron-forward" size={18} color={colors.navy} />
        </Pressable>
      </View>

      <View style={styles.weekHeaderRow}>
        {['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((d, i) => (
          <Text key={`${d}${i}`} style={styles.weekHeaderCell}>
            {d}
          </Text>
        ))}
      </View>
      <View style={styles.grid}>
        {monthGrid.map((day, i) => {
          if (!day) return <View key={`blank-${i}`} style={styles.cell} />;
          const dayEvts = eventsFor(day);
          const today = isSameDay(day, new Date());
          const hasGame = dayEvts.some((e) => e.type === 'game');
          return (
            <Pressable key={day.toISOString()} onPress={() => setSelectedDay(day)} style={[styles.cell, today && styles.cellToday]}>
              <Text style={styles.cellNum}>{day.getDate()}</Text>
              {dayEvts.length > 0 ? <View style={[styles.cellBar, { backgroundColor: hasGame ? colors.buzzer : colors.navy }]} /> : null}
            </Pressable>
          );
        })}
      </View>

      <Modal visible={Boolean(selectedDay)} transparent animationType="fade" onRequestClose={() => setSelectedDay(null)}>
        <View style={styles.modalBackdrop}>
          <View style={styles.modalCard}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>
                {selectedDay?.toLocaleDateString('en-US', { weekday: 'long', day: 'numeric', month: 'short' })}
              </Text>
              <Pressable onPress={() => setSelectedDay(null)} hitSlop={8}>
                <Ionicons name="close" size={20} color={colors.inkSoft} />
              </Pressable>
            </View>

            {dayEvents.length === 0 ? (
              <Text style={styles.emptyText}>No events this day.</Text>
            ) : (
              dayEvents.map((event) => (
                <View key={event.id} style={styles.modalEventBlock}>
                  <Text style={styles.modalEventTitle}>{event.type === 'game' && event.opponentName ? `vs ${event.opponentName}` : event.title}</Text>
                  <Text style={styles.modalEventMeta}>
                    {formatEventTime(event.startsAt)} - {formatEventTime(event.endsAt)}
                  </Text>
                  {event.facilityName ? <Text style={styles.modalEventMeta}>{event.facilityName}</Text> : null}

                  {event.rsvp === 'attending' || event.rsvp === 'not_attending' ? (
                    <Badge label={STATUS_LABEL[event.rsvp]} tone={STATUS_TONE[event.rsvp]} />
                  ) : (
                    <View style={styles.modalRsvpRow}>
                      <Pressable style={[styles.modalRsvpBtn, styles.modalRsvpIn]} onPress={() => handleRsvp(event, 'attending')} disabled={saving}>
                        <Text style={styles.modalRsvpInLabel}>I&apos;m in</Text>
                      </Pressable>
                      <Pressable style={[styles.modalRsvpBtn, styles.modalRsvpOut]} onPress={() => handleRsvp(event, 'not_attending')} disabled={saving}>
                        <Text style={styles.modalRsvpOutLabel}>Can&apos;t make it</Text>
                      </Pressable>
                    </View>
                  )}
                </View>
              ))
            )}
          </View>
        </View>
      </Modal>
    </Screen>
  );
}

const styles = StyleSheet.create({
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingTop: 60 },
  errorText: { fontSize: 13, color: colors.inkSoft, textAlign: 'center' },
  emptyText: { fontSize: 13, color: colors.inkSoft, lineHeight: 19 },
  scopeLabel: { ...typography.label, fontSize: 10, color: colors.inkSoft, marginBottom: 8 },
  monthNav: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 14 },
  monthLabel: { ...typography.heading, fontSize: 15, color: colors.navy },
  weekHeaderRow: { flexDirection: 'row' },
  weekHeaderCell: { flex: 1, textAlign: 'center', fontSize: 11, fontWeight: '700', color: colors.inkSoft },
  grid: { flexDirection: 'row', flexWrap: 'wrap' },
  cell: { width: `${100 / 7}%`, aspectRatio: 1, alignItems: 'center', justifyContent: 'center', gap: 4 },
  cellToday: { backgroundColor: colors.tintOrange, borderRadius: 10 },
  cellNum: { fontSize: 13, fontWeight: '700', color: colors.navy },
  cellBar: { width: 16, height: 3, borderRadius: 2 },
  modalBackdrop: { flex: 1, backgroundColor: 'rgba(19,43,77,0.45)', alignItems: 'center', justifyContent: 'center', padding: 20 },
  modalCard: { backgroundColor: colors.white, borderRadius: 18, padding: 18, width: '100%', maxWidth: 420, gap: 10 },
  modalHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: 4 },
  modalTitle: { ...typography.heading, fontSize: 14, color: colors.navy, flex: 1 },
  modalEventBlock: { borderWidth: 1, borderColor: colors.line, borderRadius: 12, padding: 12, gap: 6 },
  modalEventTitle: { ...typography.heading, fontSize: 14, color: colors.navy },
  modalEventMeta: { fontSize: 12, color: colors.inkSoft },
  modalRsvpRow: { flexDirection: 'row', gap: 8, marginTop: 4 },
  modalRsvpBtn: { flex: 1, borderRadius: 9, paddingVertical: 9, alignItems: 'center', borderWidth: 1.5 },
  modalRsvpIn: { backgroundColor: colors.green, borderColor: colors.green },
  modalRsvpOut: { backgroundColor: colors.white, borderColor: colors.red },
  modalRsvpInLabel: { color: colors.white, fontSize: 12, fontWeight: '800' },
  modalRsvpOutLabel: { color: colors.redDark, fontSize: 12, fontWeight: '800' },
});
