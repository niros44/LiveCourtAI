import { Ionicons } from '@expo/vector-icons';
import { useMemo, useState } from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';

import { Avatar } from '@/components/ui/Avatar';
import { Card } from '@/components/ui/Card';
import { Chip } from '@/components/ui/Chip';
import { Screen } from '@/components/ui/Screen';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { coach, coachEvents, coachTeams } from '@/data/mock/coach';
import { colors } from '@/theme/colors';
import { typography } from '@/theme/typography';

export default function CoachHomeScreen() {
  const [selectedTeamId, setSelectedTeamId] = useState<string>('all');

  const visibleEvents = useMemo(
    () =>
      selectedTeamId === 'all'
        ? coachEvents
        : coachEvents.filter((event) => event.teamId === selectedTeamId),
    [selectedTeamId]
  );

  return (
    <Screen>
      <View style={styles.header}>
        <Avatar initials={coach.initials} color={colors.navy} />
        <View style={{ flex: 1 }}>
          <Text style={styles.brand}>Coach · {coach.name}</Text>
        </View>
        <Ionicons name="notifications-outline" size={22} color={colors.navy} />
      </View>

      <View>
        <Text style={styles.scopeLabel}>SHOWING:</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8 }}>
          <Chip label="All Teams" active={selectedTeamId === 'all'} onPress={() => setSelectedTeamId('all')} />
          {coachTeams.map((team) => (
            <Chip
              key={team.id}
              label={team.name}
              active={selectedTeamId === team.id}
              onPress={() => setSelectedTeamId(team.id)}
            />
          ))}
        </ScrollView>
      </View>

      <View>
        <SectionHeader title="MY WEEK" tag="Today" />
        <View style={{ gap: 10, marginTop: 10 }}>
          {visibleEvents.map((event) => {
            const team = coachTeams.find((t) => t.id === event.teamId);
            const ratio = event.attending / event.roster;
            const low = ratio < 0.6;
            return (
              <Card key={event.id} style={low ? { borderLeftWidth: 3, borderLeftColor: colors.red } : undefined}>
                <View style={styles.eventTop}>
                  <View style={{ flex: 1 }}>
                    <Text style={[styles.teamTag, { color: team?.color, backgroundColor: `${team?.color}1A` }]}>
                      {team?.name}
                    </Text>
                    <Text style={styles.eventTitle}>{event.title}</Text>
                    <View style={styles.metaRow}>
                      <Ionicons name="time-outline" size={13} color={colors.inkSoft} />
                      <Text style={styles.metaText}>{event.time}</Text>
                    </View>
                    <View style={styles.metaRow}>
                      <Ionicons name="location-outline" size={13} color={colors.inkSoft} />
                      <Text style={styles.metaText}>{event.location}</Text>
                    </View>
                  </View>
                  <View style={styles.attendCol}>
                    <Text style={styles.attendLabel}>ATTENDING</Text>
                    <Text style={styles.attendValue}>
                      {event.attending}
                      <Text style={styles.attendOf}>/{event.roster}</Text>
                    </Text>
                  </View>
                </View>
                <View style={styles.barTrack}>
                  <View
                    style={[
                      styles.barFill,
                      { width: `${ratio * 100}%`, backgroundColor: low ? colors.red : colors.green },
                    ]}
                  />
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
  scopeLabel: {
    ...typography.label,
    fontSize: 10,
    color: colors.inkSoft,
    marginBottom: 8,
  },
  eventTop: {
    flexDirection: 'row',
    gap: 10,
  },
  teamTag: {
    alignSelf: 'flex-start',
    fontSize: 11,
    fontWeight: '700',
    paddingVertical: 3,
    paddingHorizontal: 9,
    borderRadius: 6,
    marginBottom: 8,
  },
  eventTitle: {
    ...typography.heading,
    fontSize: 17,
    color: colors.navy,
    marginBottom: 6,
  },
  metaRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    marginBottom: 3,
  },
  metaText: {
    fontSize: 12,
    color: colors.inkSoft,
  },
  attendCol: {
    width: 78,
    alignItems: 'flex-end',
  },
  attendLabel: {
    fontSize: 10,
    letterSpacing: 0.5,
    color: colors.inkSoft,
    textTransform: 'uppercase',
  },
  attendValue: {
    ...typography.heading,
    fontSize: 22,
    color: colors.navy,
  },
  attendOf: {
    fontSize: 13,
    fontWeight: '400',
    color: colors.inkSoft,
  },
  barTrack: {
    height: 5,
    borderRadius: 3,
    backgroundColor: colors.tintNavy,
    marginTop: 10,
    overflow: 'hidden',
  },
  barFill: {
    height: '100%',
    borderRadius: 3,
  },
});
