import { Ionicons } from '@expo/vector-icons';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { Avatar } from '@/components/ui/Avatar';
import { Badge } from '@/components/ui/Badge';
import { Card } from '@/components/ui/Card';
import { Screen } from '@/components/ui/Screen';
import { SectionHeader } from '@/components/ui/SectionHeader';
import {
  attendanceStreak,
  coachMessages,
  currentPlayer,
  nextEvent,
  upcomingEvents,
  weeklyFocus,
  yearStats,
} from '@/data/mock/player';
import { colors } from '@/theme/colors';
import { typography } from '@/theme/typography';

export default function PlayerHomeScreen() {
  return (
    <Screen>
      <View style={styles.header}>
        <Avatar initials={currentPlayer.initials} color={colors.buzzer} />
        <View style={{ flex: 1 }}>
          <Text style={styles.brand}>{currentPlayer.team}</Text>
        </View>
        <Ionicons name="notifications-outline" size={22} color={colors.navy} />
      </View>

      <Card accentColor={colors.buzzer}>
        <Text style={styles.eventLabel}>NEXT UP</Text>
        <Text style={styles.eventTitle}>{nextEvent.title}</Text>
        <Text style={styles.eventMeta}>
          {nextEvent.date} · {nextEvent.time} · {nextEvent.location}
        </Text>
        <Text style={styles.rsvpQuestion}>Are you in?</Text>
        <View style={styles.rsvpRow}>
          <Pressable style={[styles.rsvpBtn, styles.rsvpIn]}>
            <Ionicons name="checkmark" size={18} color={colors.white} />
            <Text style={styles.rsvpBtnLabel}>I&rsquo;m in</Text>
          </Pressable>
          <Pressable style={[styles.rsvpBtn, styles.rsvpOut]}>
            <Ionicons name="close" size={18} color={colors.white} />
            <Text style={styles.rsvpBtnLabel}>Can&rsquo;t make it</Text>
          </Pressable>
        </View>
      </Card>

      <View>
        <SectionHeader title="THIS WEEK'S FOCUS" />
        <Card style={{ marginTop: 10 }}>
          <Text style={styles.focusText}>{weeklyFocus}</Text>
        </Card>
      </View>

      <View style={styles.streakRow}>
        <Ionicons name="flame" size={20} color={colors.buzzerDark} />
        <Text style={styles.streakText}>
          <Text style={styles.streakNum}>{attendanceStreak}</Text> practice attendance streak
        </Text>
      </View>

      <View>
        <SectionHeader title="SEASON STATS" />
        <View style={styles.statGrid}>
          {yearStats.map((stat) => (
            <Card key={stat.label} style={styles.statTile}>
              <Text style={styles.statValue}>{stat.value}</Text>
              <Text style={styles.statLabel}>{stat.label}</Text>
            </Card>
          ))}
        </View>
      </View>

      <View>
        <SectionHeader title="UPCOMING" tag="Schedule" />
        <View style={{ gap: 8, marginTop: 10 }}>
          {upcomingEvents.map((event) => (
            <Card key={event.id} style={styles.eventRow}>
              <View style={{ flex: 1 }}>
                <Text style={styles.eventRowTitle}>{event.title}</Text>
                <Text style={styles.eventRowMeta}>
                  {event.date} · {event.time}
                </Text>
              </View>
              <Badge label={event.type === 'game' ? 'Game' : 'Practice'} tone="neutral" />
            </Card>
          ))}
        </View>
      </View>

      <View>
        <SectionHeader title="COACH MESSAGES" />
        <View style={{ gap: 8, marginTop: 10 }}>
          {coachMessages.map((message) => (
            <Card key={message.id} accentColor={colors.gold}>
              <View style={styles.messageHead}>
                <Text style={styles.messageAuthor}>{message.author}</Text>
                <Text style={styles.messageDate}>{message.date}</Text>
              </View>
              <Text style={styles.messageText}>{message.text}</Text>
            </Card>
          ))}
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
  eventLabel: {
    ...typography.label,
    fontSize: 10,
    color: colors.buzzerDark,
  },
  eventTitle: {
    ...typography.heading,
    fontSize: 19,
    color: colors.navy,
    marginTop: 4,
  },
  eventMeta: {
    fontSize: 12.5,
    color: colors.inkSoft,
    marginTop: 3,
  },
  rsvpQuestion: {
    fontSize: 13,
    fontWeight: '700',
    color: colors.navy,
    marginTop: 12,
  },
  rsvpRow: {
    flexDirection: 'row',
    gap: 8,
    marginTop: 8,
  },
  rsvpBtn: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    borderRadius: 10,
    paddingVertical: 11,
  },
  rsvpIn: { backgroundColor: colors.green },
  rsvpOut: { backgroundColor: colors.red },
  rsvpBtnLabel: {
    color: colors.white,
    fontWeight: '700',
    fontSize: 13,
  },
  focusText: {
    fontSize: 13.5,
    color: colors.navy,
    lineHeight: 19,
  },
  streakRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    backgroundColor: colors.tintOrange,
    borderRadius: 12,
    paddingVertical: 10,
    paddingHorizontal: 14,
  },
  streakText: {
    fontSize: 13,
    color: colors.navy,
  },
  streakNum: {
    fontWeight: '800',
  },
  statGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
    marginTop: 10,
  },
  statTile: {
    width: '47%',
    gap: 4,
  },
  statValue: {
    ...typography.heading,
    fontSize: 22,
    color: colors.navy,
  },
  statLabel: {
    ...typography.label,
    fontSize: 9.5,
    color: colors.inkSoft,
  },
  eventRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  eventRowTitle: {
    fontSize: 13,
    fontWeight: '700',
    color: colors.navy,
  },
  eventRowMeta: {
    fontSize: 11.5,
    color: colors.inkSoft,
    marginTop: 2,
  },
  messageHead: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  messageAuthor: {
    fontSize: 12,
    fontWeight: '700',
    color: colors.navy,
  },
  messageDate: {
    fontSize: 10,
    color: colors.inkSoft,
  },
  messageText: {
    fontSize: 12.5,
    color: colors.inkSoft,
    marginTop: 4,
    lineHeight: 17,
  },
});
