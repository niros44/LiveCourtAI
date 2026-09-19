import { Ionicons } from '@expo/vector-icons';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, Modal, Pressable, ScrollView, StyleSheet, Switch, Text, TextInput, View } from 'react-native';

import { Card } from '@/components/ui/Card';
import { Chip } from '@/components/ui/Chip';
import { Screen } from '@/components/ui/Screen';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { getCurrentPersonId } from '@/lib/auth';
import {
  type CoachEvent,
  type CoachTeam,
  type Facility,
  createEvent,
  deactivateEvent,
  getFacilities,
  getMyTeams,
  getRosters,
  getTeamsEvents,
  updateEvent,
} from '@/lib/coachData';
import { errorMessage } from '@/lib/errors';
import { colors } from '@/theme/colors';
import { typography } from '@/theme/typography';

function isSameDay(a: Date, b: Date) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}
function pad(n: number) {
  return String(n).padStart(2, '0');
}
function timeOf(iso: string) {
  const d = new Date(iso);
  return `${pad(d.getHours())}:${pad(d.getMinutes())}`;
}
function combine(day: Date, hhmm: string): Date {
  const [h, m] = hhmm.split(':').map((v) => parseInt(v, 10) || 0);
  const d = new Date(day);
  d.setHours(h, m, 0, 0);
  return d;
}

type FormState = {
  type: 'practice' | 'game';
  title: string;
  start: string;
  end: string;
  facilityId: string | null;
  opponentName: string;
  isHomeGame: boolean;
};

const BLANK_FORM: FormState = { type: 'practice', title: 'Practice', start: '16:00', end: '18:00', facilityId: null, opponentName: '', isHomeGame: true };

export default function CoachScheduleScreen() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [personId, setPersonId] = useState<string | null>(null);
  const [teams, setTeams] = useState<CoachTeam[]>([]);
  const [selectedTeamId, setSelectedTeamId] = useState<string | null>(null);
  const [facilities, setFacilities] = useState<Facility[]>([]);
  const [monthAnchor, setMonthAnchor] = useState(new Date());
  const [events, setEvents] = useState<CoachEvent[]>([]);
  const [selectedDay, setSelectedDay] = useState<Date | null>(null);
  const [editingEvent, setEditingEvent] = useState<CoachEvent | null>(null);
  const [formOpen, setFormOpen] = useState(false);
  const [form, setForm] = useState<FormState>(BLANK_FORM);
  const [saving, setSaving] = useState(false);

  const selectedTeam = teams.find((t) => t.id === selectedTeamId) ?? null;

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
      const myTeams = await getMyTeams(id);
      setTeams(myTeams);
      if (myTeams.length) setSelectedTeamId(myTeams[0].id);
    } catch (e) {
      setError(errorMessage(e, 'Something went wrong loading your teams.'));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    if (!selectedTeam) return;
    getFacilities(selectedTeam.clubId).then(setFacilities).catch(() => setFacilities([]));
  }, [selectedTeam]);

  const loadMonth = useCallback(async () => {
    if (!selectedTeamId) return;
    const team = teams.find((t) => t.id === selectedTeamId);
    if (!team) return;
    const from = new Date(monthAnchor.getFullYear(), monthAnchor.getMonth(), 1);
    const to = new Date(monthAnchor.getFullYear(), monthAnchor.getMonth() + 1, 0, 23, 59, 59, 999);
    const roster = await getRosters([team.id]);
    const monthEvents = await getTeamsEvents([team], { from, to }, roster);
    setEvents(monthEvents);
  }, [selectedTeamId, monthAnchor, teams]);

  useEffect(() => {
    loadMonth().catch((e) => setError(errorMessage(e, 'Failed to load schedule.')));
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

  function openCreate(day: Date) {
    setSelectedDay(day);
    setEditingEvent(null);
    setForm(BLANK_FORM);
    setFormOpen(true);
  }
  function openEdit(day: Date, event: CoachEvent) {
    setSelectedDay(day);
    setEditingEvent(event);
    setForm({
      type: event.type as 'practice' | 'game',
      title: event.title,
      start: timeOf(event.startsAt),
      end: timeOf(event.endsAt),
      facilityId: event.facilityId,
      opponentName: event.opponentName ?? '',
      isHomeGame: event.isHomeGame ?? true,
    });
    setFormOpen(true);
  }

  async function handleDelete(event: CoachEvent) {
    setSaving(true);
    try {
      await deactivateEvent(event.id);
      setSelectedDay(null);
      await loadMonth();
    } catch (e) {
      setError(errorMessage(e, 'Failed to delete event.'));
    } finally {
      setSaving(false);
    }
  }

  async function handleSave() {
    if (!selectedDay || !selectedTeamId || !personId) return;
    setSaving(true);
    try {
      const startsAt = combine(selectedDay, form.start).toISOString();
      const endsAt = combine(selectedDay, form.end).toISOString();
      if (editingEvent) {
        await updateEvent(editingEvent.id, {
          title: form.title,
          startsAt,
          endsAt,
          facilityId: form.facilityId,
          opponentName: form.type === 'game' ? form.opponentName || null : null,
          isHomeGame: form.type === 'game' ? form.isHomeGame : null,
        });
      } else {
        await createEvent(
          {
            teamId: selectedTeamId,
            type: form.type,
            title: form.title,
            startsAt,
            endsAt,
            facilityId: form.facilityId,
            opponentName: form.type === 'game' ? form.opponentName || null : null,
            isHomeGame: form.type === 'game' ? form.isHomeGame : null,
          },
          personId
        );
      }
      setFormOpen(false);
      setSelectedDay(null);
      await loadMonth();
    } catch (e) {
      setError(errorMessage(e, 'Failed to save event.'));
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
  if (teams.length === 0) {
    return (
      <Screen>
        <SectionHeader title="SCHEDULES" />
        <Card>
          <Text style={styles.emptyText}>You&apos;re not assigned to coach any team yet.</Text>
        </Card>
      </Screen>
    );
  }

  const dayEvents = selectedDay ? eventsFor(selectedDay) : [];

  return (
    <Screen>
      <SectionHeader title="SCHEDULES" />

      <View>
        <Text style={styles.scopeLabel}>TEAM:</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8 }}>
          {teams.map((team) => (
            <Chip key={team.id} label={team.name} active={selectedTeamId === team.id} onPress={() => setSelectedTeamId(team.id)} />
          ))}
        </ScrollView>
      </View>

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
          return (
            <Pressable key={day.toISOString()} onPress={() => setSelectedDay(day)} style={[styles.cell, today && styles.cellToday]}>
              <Text style={styles.cellNum}>{day.getDate()}</Text>
              {dayEvts.length > 0 ? <View style={[styles.cellBar, { backgroundColor: selectedTeam?.color ?? colors.navy }]} /> : null}
            </Pressable>
          );
        })}
      </View>

      <Modal visible={Boolean(selectedDay) && !formOpen} transparent animationType="fade" onRequestClose={() => setSelectedDay(null)}>
        <View style={styles.modalBackdrop}>
          <View style={styles.modalCard}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>
                {selectedTeam?.name} · {selectedDay?.toLocaleDateString('en-US', { weekday: 'short', day: 'numeric', month: 'short' })}
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
                  <Text style={styles.modalEventTitle}>{event.title}</Text>
                  <Text style={styles.modalEventMeta}>
                    {timeOf(event.startsAt)} - {timeOf(event.endsAt)}
                  </Text>
                  {event.facilityName ? <Text style={styles.modalEventMeta}>{event.facilityName}</Text> : null}
                  <View style={styles.modalActions}>
                    <Pressable style={styles.modalBtn} onPress={() => selectedDay && openEdit(selectedDay, event)}>
                      <Ionicons name="pencil-outline" size={14} color={colors.navy} />
                      <Text style={styles.modalBtnLabel}>Edit</Text>
                    </Pressable>
                    <Pressable style={[styles.modalBtn, styles.modalBtnDanger]} onPress={() => handleDelete(event)} disabled={saving}>
                      <Ionicons name="trash-outline" size={14} color={colors.redDark} />
                      <Text style={[styles.modalBtnLabel, { color: colors.redDark }]}>Delete</Text>
                    </Pressable>
                  </View>
                </View>
              ))
            )}

            <Pressable style={styles.addBtn} onPress={() => selectedDay && openCreate(selectedDay)}>
              <Text style={styles.addBtnLabel}>+ Schedule an event on this day</Text>
            </Pressable>
          </View>
        </View>
      </Modal>

      <Modal visible={formOpen} transparent animationType="fade" onRequestClose={() => setFormOpen(false)}>
        <View style={styles.modalBackdrop}>
          <ScrollView contentContainerStyle={styles.modalCard}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>{editingEvent ? 'Edit Event' : 'New Event'}</Text>
              <Pressable onPress={() => setFormOpen(false)} hitSlop={8}>
                <Ionicons name="close" size={20} color={colors.inkSoft} />
              </Pressable>
            </View>

            <View style={styles.formRow}>
              <Chip label="Practice" active={form.type === 'practice'} onPress={() => setForm((f) => ({ ...f, type: 'practice' }))} />
              <Chip label="Game" active={form.type === 'game'} onPress={() => setForm((f) => ({ ...f, type: 'game' }))} />
            </View>

            <Text style={styles.fieldLabel}>Title</Text>
            <TextInput style={styles.input} value={form.title} onChangeText={(v) => setForm((f) => ({ ...f, title: v }))} placeholder="Practice" />

            <View style={styles.formRow}>
              <View style={{ flex: 1 }}>
                <Text style={styles.fieldLabel}>Start</Text>
                <TextInput style={styles.input} value={form.start} onChangeText={(v) => setForm((f) => ({ ...f, start: v }))} placeholder="16:00" />
              </View>
              <View style={{ flex: 1 }}>
                <Text style={styles.fieldLabel}>End</Text>
                <TextInput style={styles.input} value={form.end} onChangeText={(v) => setForm((f) => ({ ...f, end: v }))} placeholder="18:00" />
              </View>
            </View>

            {facilities.length > 0 ? (
              <>
                <Text style={styles.fieldLabel}>Location</Text>
                <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8 }}>
                  {facilities.map((f) => (
                    <Chip key={f.id} label={f.name} active={form.facilityId === f.id} onPress={() => setForm((s) => ({ ...s, facilityId: f.id }))} />
                  ))}
                </ScrollView>
              </>
            ) : null}

            {form.type === 'game' ? (
              <>
                <Text style={styles.fieldLabel}>Opponent</Text>
                <TextInput style={styles.input} value={form.opponentName} onChangeText={(v) => setForm((f) => ({ ...f, opponentName: v }))} placeholder="Opponent club" />
                <View style={styles.formRow}>
                  <Text style={styles.fieldLabel}>Home game</Text>
                  <Switch value={form.isHomeGame} onValueChange={(v) => setForm((f) => ({ ...f, isHomeGame: v }))} />
                </View>
              </>
            ) : null}

            <Pressable style={styles.saveBtn} onPress={handleSave} disabled={saving}>
              <Text style={styles.saveBtnLabel}>{saving ? 'Saving…' : 'Save'}</Text>
            </Pressable>
          </ScrollView>
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
  modalEventBlock: { borderWidth: 1, borderColor: colors.line, borderRadius: 12, padding: 12, gap: 3 },
  modalEventTitle: { ...typography.heading, fontSize: 14, color: colors.navy },
  modalEventMeta: { fontSize: 12, color: colors.inkSoft },
  modalActions: { flexDirection: 'row', gap: 8, marginTop: 8 },
  modalBtn: { flexDirection: 'row', alignItems: 'center', gap: 5, borderWidth: 1, borderColor: colors.line, borderRadius: 9, paddingVertical: 7, paddingHorizontal: 12 },
  modalBtnDanger: { borderColor: '#F5C6C1' },
  modalBtnLabel: { fontSize: 12, fontWeight: '700', color: colors.navy },
  addBtn: { borderWidth: 1.5, borderColor: colors.line, borderStyle: 'dashed', borderRadius: 12, paddingVertical: 12, alignItems: 'center', marginTop: 4 },
  addBtnLabel: { fontSize: 13, fontWeight: '700', color: colors.buzzerDark },
  formRow: { flexDirection: 'row', gap: 10, alignItems: 'center' },
  fieldLabel: { ...typography.label, fontSize: 10, color: colors.inkSoft, marginTop: 6 },
  input: { borderWidth: 1, borderColor: colors.line, borderRadius: 10, paddingVertical: 9, paddingHorizontal: 12, fontSize: 14, color: colors.navy },
  saveBtn: { backgroundColor: colors.buzzer, borderRadius: 12, paddingVertical: 13, alignItems: 'center', marginTop: 10 },
  saveBtnLabel: { color: colors.white, fontSize: 14, fontWeight: '800' },
});
