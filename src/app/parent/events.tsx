import { Ionicons } from '@expo/vector-icons';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import { Avatar } from '@/components/ui/Avatar';
import { Badge, type BadgeTone } from '@/components/ui/Badge';
import { Card } from '@/components/ui/Card';
import { Chip } from '@/components/ui/Chip';
import { Screen } from '@/components/ui/Screen';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { getCurrentPersonId } from '@/lib/auth';
import {
  type Child,
  type ChildEvent,
  type EventStatus,
  endOfDay,
  formatEventDay,
  formatEventTime,
  getChildrenEvents,
  getMyChildren,
  isSameDay,
  setEventResponse,
  startOfDay,
} from '@/lib/parentData';
import { colors } from '@/theme/colors';
import { typography } from '@/theme/typography';

type RangeMode = 'week' | 'month' | 'year';

const STATUS_TONE: Record<EventStatus, BadgeTone> = {
  attending: 'in',
  not_attending: 'out',
  undecided: 'pending',
  injured: 'pending',
};
const STATUS_LABEL: Record<EventStatus, string> = {
  attending: 'Attending',
  not_attending: "Can't Go",
  undecided: 'Undecided',
  injured: 'Injured',
};

function startOfWeek(d: Date): Date {
  const copy = startOfDay(d);
  copy.setDate(copy.getDate() - copy.getDay());
  return copy;
}

function rangeFor(mode: RangeMode, anchor: Date): { from: Date; to: Date } {
  if (mode === 'week') {
    const from = startOfWeek(anchor);
    const to = new Date(from);
    to.setDate(to.getDate() + 6);
    return { from, to: endOfDay(to) };
  }
  if (mode === 'month') {
    const from = new Date(anchor.getFullYear(), anchor.getMonth(), 1);
    const to = new Date(anchor.getFullYear(), anchor.getMonth() + 1, 0);
    return { from: startOfDay(from), to: endOfDay(to) };
  }
  const from = new Date(anchor.getFullYear(), 0, 1);
  const to = new Date(anchor.getFullYear(), 11, 31);
  return { from: startOfDay(from), to: endOfDay(to) };
}

function rangeLabel(mode: RangeMode, anchor: Date): string {
  if (mode === 'week') {
    const { from, to } = rangeFor(mode, anchor);
    return `${from.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })} – ${to.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}`;
  }
  if (mode === 'month') return anchor.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
  return String(anchor.getFullYear());
}

function shiftAnchor(mode: RangeMode, anchor: Date, dir: 1 | -1): Date {
  const next = new Date(anchor);
  if (mode === 'week') next.setDate(next.getDate() + 7 * dir);
  else if (mode === 'month') next.setMonth(next.getMonth() + dir);
  else next.setFullYear(next.getFullYear() + dir);
  return next;
}

/** Aggregate dot color for a day's events: green only if every response is
 * "attending", red if any child is confirmed not attending, gray otherwise
 * (undecided/injured/no response yet). */
function dayDotColor(dayEvents: ChildEvent[]): string | null {
  if (!dayEvents.length) return null;
  if (dayEvents.some((e) => e.rsvp === 'not_attending')) return colors.red;
  if (dayEvents.every((e) => e.rsvp === 'attending')) return colors.green;
  return colors.inkSoft;
}

export default function ParentEventsScreen() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [personId, setPersonId] = useState<string | null>(null);
  const [children, setChildren] = useState<Child[]>([]);
  const [events, setEvents] = useState<ChildEvent[]>([]);
  const [mode, setMode] = useState<RangeMode>('week');
  const [anchor, setAnchor] = useState(new Date());
  const [selectedChildId, setSelectedChildId] = useState<string | 'all'>('all');
  const [selectedDate, setSelectedDate] = useState<Date>(startOfDay(new Date()));
  const [pendingKey, setPendingKey] = useState<string | null>(null);

  const range = useMemo(() => rangeFor(mode, anchor), [mode, anchor]);

  const loadChildren = useCallback(async () => {
    const id = await getCurrentPersonId();
    if (!id) {
      setError('No profile found for this account.');
      setLoading(false);
      return null;
    }
    setPersonId(id);
    const myChildren = await getMyChildren(id);
    setChildren(myChildren);
    return myChildren;
  }, []);

  const loadEvents = useCallback(async (myChildren: Child[], r: { from: Date; to: Date }) => {
    const myEvents = await getChildrenEvents(myChildren, r);
    setEvents(myEvents);
  }, []);

  useEffect(() => {
    (async () => {
      try {
        setError(null);
        const myChildren = await loadChildren();
        if (myChildren) await loadEvents(myChildren, rangeFor('week', new Date()));
      } catch (e) {
        setError(e instanceof Error ? e.message : 'Something went wrong loading your events.');
      } finally {
        setLoading(false);
      }
    })();
  }, [loadChildren, loadEvents]);

  useEffect(() => {
    if (!children.length) return;
    loadEvents(children, range).catch((e) => setError(e instanceof Error ? e.message : 'Failed to load events.'));
  }, [children, range, loadEvents]);

  async function respond(event: ChildEvent, status: EventStatus) {
    if (!personId) return;
    const key = `${event.id}:${event.childId}`;
    setPendingKey(key);
    try {
      await setEventResponse(event.id, event.childId, status, personId);
      setEvents((prev) => prev.map((e) => (e.id === event.id && e.childId === event.childId ? { ...e, rsvp: status } : e)));
    } catch {
      // See Home screen — best-effort, non-fatal.
    } finally {
      setPendingKey(null);
    }
  }

  const filteredEvents = useMemo(
    () => (selectedChildId === 'all' ? events : events.filter((e) => e.childId === selectedChildId)),
    [events, selectedChildId]
  );

  const weekDays = useMemo(() => {
    if (mode !== 'week') return [];
    const from = startOfWeek(anchor);
    return Array.from({ length: 7 }, (_, i) => {
      const d = new Date(from);
      d.setDate(d.getDate() + i);
      return d;
    });
  }, [mode, anchor]);

  const dayEvents = useCallback(
    (day: Date) => filteredEvents.filter((e) => isSameDay(new Date(e.startsAt), day)),
    [filteredEvents]
  );

  const visibleEvents = mode === 'week' ? dayEvents(selectedDate) : filteredEvents;

  const groupedByDay = useMemo(() => {
    if (mode === 'week') return null;
    const groups = new Map<string, ChildEvent[]>();
    for (const e of visibleEvents) {
      const dayKey = formatEventDay(e.startsAt);
      const list = groups.get(dayKey) ?? [];
      list.push(e);
      groups.set(dayKey, list);
    }
    return [...groups.entries()];
  }, [mode, visibleEvents]);

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

  if (children.length === 0) {
    return (
      <Screen>
        <SectionHeader title="EVENTS" />
        <Card>
          <Text style={styles.emptyText}>
            No children are linked to your account yet. Once a coach or club admin adds you as a guardian,
            their events will show up here.
          </Text>
        </Card>
      </Screen>
    );
  }

  return (
    <Screen>
      <SectionHeader title="EVENTS" />

      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chipRow}>
        <Chip label="All Children" active={selectedChildId === 'all'} onPress={() => setSelectedChildId('all')} />
        {children.map((child) => (
          <Chip
            key={child.id}
            label={child.name}
            active={selectedChildId === child.id}
            onPress={() => setSelectedChildId(child.id)}
          />
        ))}
      </ScrollView>

      <View style={styles.modeRow}>
        {(['week', 'month', 'year'] as RangeMode[]).map((m) => (
          <Chip key={m} label={m === 'week' ? 'Weekly' : m === 'month' ? 'Monthly' : 'Yearly'} active={mode === m} onPress={() => setMode(m)} />
        ))}
      </View>

      <View style={styles.rangeNav}>
        <Pressable onPress={() => setAnchor((a) => shiftAnchor(mode, a, -1))} hitSlop={8}>
          <Ionicons name="chevron-back" size={18} color={colors.navy} />
        </Pressable>
        <Text style={styles.rangeLabel}>{rangeLabel(mode, anchor)}</Text>
        <Pressable onPress={() => setAnchor((a) => shiftAnchor(mode, a, 1))} hitSlop={8}>
          <Ionicons name="chevron-forward" size={18} color={colors.navy} />
        </Pressable>
      </View>

      {mode === 'week' ? (
        <View style={styles.dayStrip}>
          {weekDays.map((day) => {
            const selected = isSameDay(day, selectedDate);
            const dot = dayDotColor(dayEvents(day));
            return (
              <Pressable key={day.toISOString()} onPress={() => setSelectedDate(day)} style={[styles.dayCell, selected && styles.dayCellSelected]}>
                <Text style={[styles.dayLetter, selected && styles.dayLetterSelected]}>
                  {day.toLocaleDateString('en-US', { weekday: 'narrow' })}
                </Text>
                <Text style={[styles.dayNumber, selected && styles.dayNumberSelected]}>{day.getDate()}</Text>
                <View style={[styles.dayDot, { backgroundColor: dot ?? 'transparent' }]} />
              </Pressable>
            );
          })}
        </View>
      ) : null}

      <View style={{ gap: 9 }}>
        {mode === 'week' ? (
          visibleEvents.length === 0 ? (
            <Card>
              <Text style={styles.emptyText}>No events on {formatEventDay(selectedDate.toISOString())}.</Text>
            </Card>
          ) : (
            visibleEvents.map((event) => (
              <EventCard key={`${event.id}:${event.childId}`} event={event} pendingKey={pendingKey} onRespond={respond} />
            ))
          )
        ) : groupedByDay && groupedByDay.length > 0 ? (
          groupedByDay.map(([day, dayEvts]) => (
            <View key={day} style={{ gap: 9 }}>
              <Text style={styles.groupHeader}>{day}</Text>
              {dayEvts.map((event) => (
                <EventCard key={`${event.id}:${event.childId}`} event={event} pendingKey={pendingKey} onRespond={respond} />
              ))}
            </View>
          ))
        ) : (
          <Card>
            <Text style={styles.emptyText}>No events in this {mode}.</Text>
          </Card>
        )}
      </View>
    </Screen>
  );
}

function EventCard({
  event,
  pendingKey,
  onRespond,
}: {
  event: ChildEvent;
  pendingKey: string | null;
  onRespond: (event: ChildEvent, status: EventStatus) => void;
}) {
  const key = `${event.id}:${event.childId}`;
  const isPending = pendingKey === key;
  const canAct = event.canRsvp && event.eventStatus === 'scheduled';

  return (
    <Card accentColor={event.childColor}>
      <View style={styles.eventRow}>
        <Avatar initials={event.childInitials} size={34} color={event.childColor} />
        <View style={{ flex: 1 }}>
          <Text style={styles.eventTitle}>
            {event.title} · {event.childName}
          </Text>
          <Text style={styles.eventMeta}>
            {formatEventDay(event.startsAt)} · {formatEventTime(event.startsAt)}
            {event.facilityName ? ` · ${event.facilityName}` : ''}
          </Text>
          {event.opponentName ? (
            <Text style={styles.eventMeta}>
              vs {event.opponentName} {event.isHomeGame ? '(Home)' : '(Away)'}
            </Text>
          ) : null}
        </View>
        {canAct ? (
          <View style={styles.rsvpActions}>
            <Pressable
              disabled={isPending}
              onPress={() => onRespond(event, 'attending')}
              style={[styles.rsvpBtn, event.rsvp === 'attending' && styles.rsvpBtnOnIn]}>
              <Ionicons name="checkmark" size={15} color={event.rsvp === 'attending' ? colors.white : colors.inkSoft} />
            </Pressable>
            <Pressable
              disabled={isPending}
              onPress={() => onRespond(event, 'not_attending')}
              style={[styles.rsvpBtn, event.rsvp === 'not_attending' && styles.rsvpBtnOnOut]}>
              <Ionicons name="close" size={15} color={event.rsvp === 'not_attending' ? colors.white : colors.inkSoft} />
            </Pressable>
          </View>
        ) : event.rsvp ? (
          <Badge label={STATUS_LABEL[event.rsvp]} tone={STATUS_TONE[event.rsvp]} />
        ) : (
          <Badge label="No Response" tone="neutral" />
        )}
      </View>
    </Card>
  );
}

const styles = StyleSheet.create({
  centered: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingTop: 60,
  },
  errorText: {
    fontSize: 13,
    color: colors.inkSoft,
    textAlign: 'center',
  },
  emptyText: {
    fontSize: 13,
    color: colors.inkSoft,
    lineHeight: 19,
  },
  chipRow: {
    flexDirection: 'row',
    gap: 8,
  },
  modeRow: {
    flexDirection: 'row',
    gap: 8,
  },
  rangeNav: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 14,
  },
  rangeLabel: {
    ...typography.heading,
    fontSize: 13,
    color: colors.navy,
  },
  dayStrip: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    backgroundColor: colors.white,
    borderWidth: 1,
    borderColor: colors.line,
    borderRadius: 14,
    padding: 8,
  },
  dayCell: {
    flex: 1,
    alignItems: 'center',
    gap: 4,
    paddingVertical: 8,
    borderRadius: 10,
  },
  dayCellSelected: {
    backgroundColor: colors.tintOrange,
  },
  dayLetter: {
    fontSize: 10,
    fontWeight: '700',
    color: colors.inkSoft,
  },
  dayLetterSelected: {
    color: colors.buzzerDark,
  },
  dayNumber: {
    fontSize: 14,
    fontWeight: '800',
    color: colors.navy,
  },
  dayNumberSelected: {
    color: colors.buzzerDark,
  },
  dayDot: {
    width: 6,
    height: 6,
    borderRadius: 3,
  },
  groupHeader: {
    ...typography.label,
    fontSize: 11,
    color: colors.inkSoft,
  },
  eventRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  eventTitle: {
    ...typography.heading,
    fontSize: 13.5,
    color: colors.navy,
  },
  eventMeta: {
    fontSize: 11,
    color: colors.inkSoft,
    marginTop: 1,
  },
  rsvpActions: {
    flexDirection: 'row',
    gap: 6,
  },
  rsvpBtn: {
    width: 28,
    height: 28,
    borderRadius: 8,
    borderWidth: 1.5,
    borderColor: colors.line,
    alignItems: 'center',
    justifyContent: 'center',
  },
  rsvpBtnOnIn: {
    backgroundColor: colors.green,
    borderColor: colors.green,
  },
  rsvpBtnOnOut: {
    backgroundColor: colors.red,
    borderColor: colors.red,
  },
});
