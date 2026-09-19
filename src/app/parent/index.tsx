import { Ionicons } from '@expo/vector-icons';
import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, Pressable, StyleSheet, Text, View } from 'react-native';

import { Avatar } from '@/components/ui/Avatar';
import { Badge, type BadgeTone } from '@/components/ui/Badge';
import { Card } from '@/components/ui/Card';
import { Screen } from '@/components/ui/Screen';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { getCurrentPersonId } from '@/lib/auth';
import {
  type Child,
  type ChildEvent,
  type EventStatus,
  formatEventDay,
  formatEventTime,
  getChildrenEvents,
  getMyChildren,
  getMyProfile,
  setEventResponse,
} from '@/lib/parentData';
import { errorMessage } from '@/lib/errors';
import { colors } from '@/theme/colors';
import { typography } from '@/theme/typography';

const UPCOMING_WINDOW_DAYS = 21;
const UPCOMING_LIMIT = 8;

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

export default function ParentHomeScreen() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [personId, setPersonId] = useState<string | null>(null);
  const [profile, setProfile] = useState<{ name: string; initials: string }>({ name: 'Parent', initials: '?' });
  const [children, setChildren] = useState<Child[]>([]);
  const [events, setEvents] = useState<ChildEvent[]>([]);
  const [pendingKey, setPendingKey] = useState<string | null>(null);

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

      const [me, myChildren] = await Promise.all([getMyProfile(id), getMyChildren(id)]);
      setProfile(me);
      setChildren(myChildren);

      const now = new Date();
      const to = new Date(now.getTime() + UPCOMING_WINDOW_DAYS * 24 * 60 * 60 * 1000);
      const myEvents = await getChildrenEvents(myChildren, { from: now, to });
      setEvents(myEvents.slice(0, UPCOMING_LIMIT));
    } catch (e) {
      setError(errorMessage(e, 'Something went wrong loading your family.'));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function respond(event: ChildEvent, status: EventStatus) {
    if (!personId) return;
    const key = `${event.id}:${event.childId}`;
    setPendingKey(key);
    try {
      await setEventResponse(event.id, event.childId, status, personId);
      setEvents((prev) => prev.map((e) => (e.id === event.id && e.childId === event.childId ? { ...e, rsvp: status } : e)));
    } catch {
      // Silently ignore — the buttons will simply not reflect the change,
      // and the next pull of this screen will show the true server state.
    } finally {
      setPendingKey(null);
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

  return (
    <Screen>
      <View style={styles.header}>
        <Avatar initials={profile.initials} color={colors.buzzer} />
        <View style={{ flex: 1 }}>
          <Text style={styles.brand}>Parent · {profile.name}</Text>
        </View>
        <Ionicons name="notifications-outline" size={22} color={colors.navy} />
      </View>

      {children.length === 0 ? (
        <Card>
          <Text style={styles.emptyText}>
            No children are linked to your account yet. Once a coach or club admin adds you as a guardian, they&apos;ll
            show up here.
          </Text>
        </Card>
      ) : (
        <View>
          <SectionHeader title="UPCOMING EVENTS" />
          <View style={styles.legendRow}>
            {children.map((child) => (
              <View key={child.id} style={styles.legendItem}>
                <View style={[styles.legendDot, { backgroundColor: child.color }]} />
                <Text style={styles.legendLabel}>{child.firstName}</Text>
              </View>
            ))}
          </View>

          {events.length === 0 ? (
            <Card style={{ marginTop: 10 }}>
              <Text style={styles.emptyText}>No upcoming events in the next {UPCOMING_WINDOW_DAYS} days.</Text>
            </Card>
          ) : (
            <View style={{ gap: 9, marginTop: 10 }}>
              {events.map((event) => {
                const key = `${event.id}:${event.childId}`;
                const isPending = pendingKey === key;
                const canAct = event.canRsvp && event.eventStatus === 'scheduled';
                return (
                  <Card key={key}>
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
                      </View>
                      {canAct ? (
                        <View style={styles.rsvpActions}>
                          <Pressable
                            disabled={isPending}
                            onPress={() => respond(event, 'attending')}
                            style={[styles.rsvpBtn, event.rsvp === 'attending' && styles.rsvpBtnOnIn]}>
                            <Ionicons
                              name="checkmark"
                              size={15}
                              color={event.rsvp === 'attending' ? colors.white : colors.inkSoft}
                            />
                          </Pressable>
                          <Pressable
                            disabled={isPending}
                            onPress={() => respond(event, 'not_attending')}
                            style={[styles.rsvpBtn, event.rsvp === 'not_attending' && styles.rsvpBtnOnOut]}>
                            <Ionicons
                              name="close"
                              size={15}
                              color={event.rsvp === 'not_attending' ? colors.white : colors.inkSoft}
                            />
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
              })}
            </View>
          )}
        </View>
      )}
    </Screen>
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
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  brand: {
    ...typography.heading,
    fontSize: 14,
    color: colors.navy,
  },
  legendRow: {
    flexDirection: 'row',
    gap: 12,
    marginTop: 4,
    flexWrap: 'wrap',
  },
  legendItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  legendDot: {
    width: 10,
    height: 10,
    borderRadius: 5,
  },
  legendLabel: {
    fontSize: 12,
    fontWeight: '700',
    color: colors.navy,
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
