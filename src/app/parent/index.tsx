import { Ionicons } from '@expo/vector-icons';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { Avatar } from '@/components/ui/Avatar';
import { Card } from '@/components/ui/Card';
import { Screen } from '@/components/ui/Screen';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { actionItems, children, parent, parentEvents } from '@/data/mock/parent';
import { colors } from '@/theme/colors';
import { typography } from '@/theme/typography';

function childFor(id: string) {
  return children.find((c) => c.id === id)!;
}

export default function ParentHomeScreen() {
  return (
    <Screen>
      <View style={styles.header}>
        <Avatar initials={parent.initials} color={colors.buzzer} />
        <View style={{ flex: 1 }}>
          <Text style={styles.brand}>Parent · {parent.name}</Text>
        </View>
        <Ionicons name="notifications-outline" size={22} color={colors.navy} />
      </View>

      {actionItems.length > 0 ? (
        <View style={styles.actionBanner}>
          <View style={styles.actionHead}>
            <Ionicons name="alert-circle-outline" size={20} color={colors.buzzerDark} />
            <Text style={styles.actionHeadText}>
              {actionItems.length} action item{actionItems.length === 1 ? '' : 's'} need your attention
            </Text>
          </View>
          {actionItems.map((item) => {
            const child = childFor(item.childId);
            return (
              <View key={item.id} style={styles.actionRow}>
                <View style={{ flex: 1 }}>
                  <Text style={styles.actionChild}>{child.name}</Text>
                  <Text style={styles.actionTitle}>{item.title}</Text>
                </View>
                <Pressable style={styles.actionCta}>
                  <Text style={styles.actionCtaLabel}>{item.cta}</Text>
                </Pressable>
              </View>
            );
          })}
        </View>
      ) : null}

      <View>
        <SectionHeader title="UPCOMING EVENTS" />
        <View style={styles.legendRow}>
          {children.map((child) => (
            <View key={child.id} style={styles.legendItem}>
              <View style={[styles.legendDot, { backgroundColor: child.color }]} />
              <Text style={styles.legendLabel}>{child.name.split(' ')[0]}</Text>
            </View>
          ))}
        </View>
        <View style={{ gap: 9, marginTop: 10 }}>
          {parentEvents.map((event) => {
            const child = childFor(event.childId);
            return (
              <Card key={event.id}>
                <View style={styles.eventRow}>
                  <Avatar initials={child.initials} size={34} color={child.color} />
                  <View style={{ flex: 1 }}>
                    <Text style={styles.eventTitle}>
                      {event.title} · {child.name.split(' ')[0]}
                    </Text>
                    <Text style={styles.eventMeta}>
                      {event.date} · {event.time} · {event.location}
                    </Text>
                  </View>
                  <View style={styles.rsvpActions}>
                    <Pressable
                      style={[styles.rsvpBtn, event.rsvp === 'in' && styles.rsvpBtnOnIn]}>
                      <Ionicons
                        name="checkmark"
                        size={15}
                        color={event.rsvp === 'in' ? colors.white : colors.inkSoft}
                      />
                    </Pressable>
                    <Pressable style={styles.rsvpBtn}>
                      <Ionicons name="close" size={15} color={colors.inkSoft} />
                    </Pressable>
                  </View>
                </View>
              </Card>
            );
          })}
        </View>
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
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
  actionBanner: {
    backgroundColor: colors.tintOrange,
    borderWidth: 1.5,
    borderColor: colors.buzzer,
    borderRadius: 16,
    padding: 14,
    gap: 8,
  },
  actionHead: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginBottom: 4,
  },
  actionHeadText: {
    ...typography.heading,
    fontSize: 14,
    color: colors.navy,
    flex: 1,
  },
  actionRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    backgroundColor: colors.white,
    borderRadius: 11,
    padding: 12,
  },
  actionChild: {
    fontSize: 10,
    fontWeight: '700',
    color: colors.inkSoft,
    textTransform: 'uppercase',
  },
  actionTitle: {
    fontSize: 13,
    fontWeight: '700',
    color: colors.navy,
    marginTop: 2,
  },
  actionCta: {
    backgroundColor: colors.buzzer,
    borderRadius: 9,
    paddingVertical: 8,
    paddingHorizontal: 14,
  },
  actionCtaLabel: {
    color: colors.white,
    fontSize: 12,
    fontWeight: '800',
  },
  legendRow: {
    flexDirection: 'row',
    gap: 12,
    marginTop: 4,
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
});
