import { useCallback, useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, ScrollView, StyleSheet, Text, View } from 'react-native';

import { Badge, type BadgeTone } from '@/components/ui/Badge';
import { Card } from '@/components/ui/Card';
import { Chip } from '@/components/ui/Chip';
import { Screen } from '@/components/ui/Screen';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { getCurrentPersonId } from '@/lib/auth';
import {
  type CoachEvent,
  type CoachTeam,
  type EventStatus,
  type RosterPlayer,
  getMyTeams,
  getNextEventForTeam,
  getRosters,
  getRsvpStatusForEvent,
} from '@/lib/coachData';
import { errorMessage } from '@/lib/errors';
import { colors } from '@/theme/colors';
import { typography } from '@/theme/typography';

const STATUS_TONE: Record<EventStatus, BadgeTone> = { attending: 'in', not_attending: 'out', undecided: 'pending', injured: 'pending' };
const STATUS_LABEL: Record<EventStatus, string> = { attending: 'Confirmed', not_attending: 'Declined', undecided: 'Undecided', injured: 'Injured' };

function fmtTime(iso: string) {
  return new Date(iso).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: false });
}
function fmtDay(iso: string) {
  return new Date(iso).toLocaleDateString('en-US', { weekday: 'short', day: 'numeric', month: 'short' });
}

export default function CoachPlayersScreen() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [teams, setTeams] = useState<CoachTeam[]>([]);
  const [selectedTeamId, setSelectedTeamId] = useState<string | null>(null);
  const [roster, setRoster] = useState<RosterPlayer[]>([]);
  const [nextEvent, setNextEvent] = useState<CoachEvent | null>(null);
  const [statusByPlayer, setStatusByPlayer] = useState<Map<string, EventStatus>>(new Map());
  const [rosterLoading, setRosterLoading] = useState(false);

  const load = useCallback(async () => {
    try {
      setError(null);
      const id = await getCurrentPersonId();
      if (!id) {
        setError('No profile found for this account.');
        setLoading(false);
        return;
      }
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
    if (!selectedTeamId) return;
    setRosterLoading(true);
    (async () => {
      const teamRoster = await getRosters([selectedTeamId]);
      setRoster(teamRoster);
      const next = await getNextEventForTeam(selectedTeamId, teamRoster);
      setNextEvent(next);
      if (next) {
        const statuses = await getRsvpStatusForEvent(next.id);
        setStatusByPlayer(statuses);
      } else {
        setStatusByPlayer(new Map());
      }
    })()
      .catch((e) => setError(errorMessage(e, 'Failed to load roster.')))
      .finally(() => setRosterLoading(false));
  }, [selectedTeamId]);

  const counts = useMemo(() => {
    let confirmed = 0;
    let declined = 0;
    for (const p of roster) {
      const s = statusByPlayer.get(p.id);
      if (s === 'attending') confirmed += 1;
      else if (s === 'not_attending') declined += 1;
    }
    return { confirmed, declined, pending: Math.max(roster.length - confirmed - declined, 0) };
  }, [roster, statusByPlayer]);

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
        <SectionHeader title="PLAYERS" />
        <Card>
          <Text style={styles.emptyText}>You&apos;re not assigned to coach any team yet.</Text>
        </Card>
      </Screen>
    );
  }

  return (
    <Screen>
      <SectionHeader title="PLAYERS" />

      <View>
        <Text style={styles.scopeLabel}>TEAM:</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8 }}>
          {teams.map((team) => (
            <Chip key={team.id} label={team.name} active={selectedTeamId === team.id} onPress={() => setSelectedTeamId(team.id)} />
          ))}
        </ScrollView>
      </View>

      {rosterLoading ? (
        <ActivityIndicator color={colors.buzzer} />
      ) : (
        <>
          <Card>
            {nextEvent ? (
              <>
                <Text style={styles.nextLabel}>
                  Next {nextEvent.type === 'game' ? 'Game' : 'Practice'} · {teams.find((t) => t.id === selectedTeamId)?.name}
                </Text>
                <Text style={styles.nextTitle}>{fmtDay(nextEvent.startsAt)}</Text>
                <Text style={styles.nextMeta}>
                  {fmtTime(nextEvent.startsAt)} - {fmtTime(nextEvent.endsAt)}
                  {nextEvent.facilityName ? ` · ${nextEvent.facilityName}` : ''}
                </Text>
                <View style={styles.countRow}>
                  <View style={styles.countItem}>
                    <View style={[styles.countDot, { backgroundColor: colors.green }]} />
                    <Text style={styles.countText}>{counts.confirmed} confirmed</Text>
                  </View>
                  <View style={styles.countItem}>
                    <View style={[styles.countDot, { backgroundColor: colors.red }]} />
                    <Text style={styles.countText}>{counts.declined} declined</Text>
                  </View>
                  <View style={styles.countItem}>
                    <View style={[styles.countDot, { backgroundColor: colors.inkSoft }]} />
                    <Text style={styles.countText}>{counts.pending} pending</Text>
                  </View>
                </View>
              </>
            ) : (
              <Text style={styles.emptyText}>No upcoming event scheduled for this team.</Text>
            )}
          </Card>

          <View>
            <SectionHeader title="ROSTER" />
            <View style={{ gap: 8, marginTop: 8 }}>
              {roster.length === 0 ? (
                <Card>
                  <Text style={styles.emptyText}>No players on this roster yet.</Text>
                </Card>
              ) : (
                roster.map((player) => {
                  const status = statusByPlayer.get(player.id);
                  return (
                    <Card key={player.id}>
                      <View style={styles.playerRow}>
                        <Text style={styles.jersey}>{player.jersey ?? '–'}</Text>
                        <View style={{ flex: 1 }}>
                          <Text style={styles.playerName}>{player.name}</Text>
                          {player.position ? <Text style={styles.positionTag}>{player.position.toUpperCase()}</Text> : null}
                        </View>
                        {nextEvent ? <Badge label={status ? STATUS_LABEL[status] : 'No Response'} tone={status ? STATUS_TONE[status] : 'neutral'} /> : null}
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
  scopeLabel: { ...typography.label, fontSize: 10, color: colors.inkSoft, marginBottom: 8 },
  nextLabel: { ...typography.label, fontSize: 10, color: colors.buzzerDark },
  nextTitle: { ...typography.heading, fontSize: 16, color: colors.navy, marginTop: 4 },
  nextMeta: { fontSize: 12, color: colors.inkSoft, marginTop: 2 },
  countRow: { flexDirection: 'row', gap: 14, marginTop: 10 },
  countItem: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  countDot: { width: 8, height: 8, borderRadius: 4 },
  countText: { fontSize: 12, color: colors.navy, fontWeight: '600' },
  playerRow: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  jersey: { ...typography.heading, fontSize: 16, color: colors.inkSoft, width: 24, textAlign: 'center' },
  playerName: { ...typography.heading, fontSize: 14, color: colors.navy },
  positionTag: { fontSize: 10, fontWeight: '700', color: colors.buzzerDark, marginTop: 2 },
});
