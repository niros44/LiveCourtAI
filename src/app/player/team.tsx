import { Ionicons } from '@expo/vector-icons';
import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, Linking, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import { Avatar } from '@/components/ui/Avatar';
import { Card } from '@/components/ui/Card';
import { Chip } from '@/components/ui/Chip';
import { Screen } from '@/components/ui/Screen';
import { ScreenHeader } from '@/components/ui/ScreenHeader';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { getCurrentPersonId } from '@/lib/auth';
import { type Playership, type TeamHeader, type TeammateContact, getMyPlayerships, getTeamHeader, getTeamRoster } from '@/lib/playerData';
import { errorMessage } from '@/lib/errors';
import { colors } from '@/theme/colors';
import { typography } from '@/theme/typography';

export default function PlayerTeamScreen() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [playerships, setPlayerships] = useState<Playership[]>([]);
  const [selectedTeamId, setSelectedTeamId] = useState<string | null>(null);
  const [header, setHeader] = useState<TeamHeader | null>(null);
  const [roster, setRoster] = useState<TeammateContact[]>([]);
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [scopeLoading, setScopeLoading] = useState(false);

  const load = useCallback(async () => {
    try {
      setError(null);
      const id = await getCurrentPersonId();
      if (!id) {
        setError('No profile found for this account.');
        setLoading(false);
        return;
      }
      const ships = await getMyPlayerships(id);
      setPlayerships(ships);
      if (ships.length) setSelectedTeamId(ships[0].teamId);
    } catch (e) {
      setError(errorMessage(e, 'Something went wrong loading your team.'));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    if (!selectedTeamId) return;
    setScopeLoading(true);
    setExpandedId(null);
    Promise.all([getTeamHeader(selectedTeamId), getTeamRoster(selectedTeamId)])
      .then(([h, r]) => {
        setHeader(h);
        setRoster(r);
      })
      .catch((e) => setError(errorMessage(e, 'Failed to load team info.')))
      .finally(() => setScopeLoading(false));
  }, [selectedTeamId]);

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
        <ScreenHeader title="Team" />
        <Card>
          <Text style={styles.emptyText}>You&apos;re not on a team roster yet.</Text>
        </Card>
      </Screen>
    );
  }

  return (
    <Screen>
      <ScreenHeader title="Team" />

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

      {scopeLoading ? (
        <ActivityIndicator color={colors.buzzer} />
      ) : (
        <>
          {header ? (
            <Card>
              <Text style={styles.teamName}>{header.teamName}</Text>
              <Text style={styles.clubName}>
                {header.clubName}
                {header.ageGroupName ? ` · ${header.ageGroupName}` : ''}
              </Text>
              {header.headCoachName ? <Text style={styles.coachLine}>Coach: {header.headCoachName}</Text> : null}
              {header.record ? (
                <Text style={styles.recordLine}>
                  Season record: {header.record.wins}-{header.record.losses}
                </Text>
              ) : null}
            </Card>
          ) : null}

          <View>
            <SectionHeader title="ROSTER" tag={`${roster.length} player${roster.length === 1 ? '' : 's'}`} />
            <View style={{ gap: 8, marginTop: 8 }}>
              {roster.length === 0 ? (
                <Card>
                  <Text style={styles.emptyText}>No players on this roster yet.</Text>
                </Card>
              ) : (
                roster.map((p) => {
                  const expanded = expandedId === p.playerId;
                  return (
                    <Card key={p.playerId}>
                      <Pressable style={styles.playerRow} onPress={() => setExpandedId(expanded ? null : p.playerId)}>
                        <Text style={styles.jersey}>{p.jersey ?? '–'}</Text>
                        <Avatar initials={p.initials} size={36} color={colors.navy} />
                        <View style={{ flex: 1 }}>
                          <Text style={styles.playerName}>{p.name}</Text>
                          {p.position ? <Text style={styles.positionTag}>{p.position.toUpperCase()}</Text> : null}
                        </View>
                        <Ionicons name={expanded ? 'chevron-up' : 'chevron-down'} size={16} color={colors.inkSoft} />
                      </Pressable>

                      {expanded ? (
                        <View style={styles.contactArea}>
                          {p.cellphone ? (
                            <Pressable style={styles.contactRow} onPress={() => Linking.openURL(`tel:${p.cellphone}`)}>
                              <Ionicons name="call-outline" size={14} color={colors.buzzerDark} />
                              <Text style={styles.contactText}>{p.cellphone}</Text>
                            </Pressable>
                          ) : null}
                          {p.email ? (
                            <Pressable style={styles.contactRow} onPress={() => Linking.openURL(`mailto:${p.email}`)}>
                              <Ionicons name="mail-outline" size={14} color={colors.buzzerDark} />
                              <Text style={styles.contactText}>{p.email}</Text>
                            </Pressable>
                          ) : null}
                          {!p.cellphone && !p.email ? <Text style={styles.emptyText}>No contact info on file.</Text> : null}
                        </View>
                      ) : null}
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
  teamName: { ...typography.heading, fontSize: 17, color: colors.navy },
  clubName: { fontSize: 12, color: colors.inkSoft, marginTop: 2 },
  coachLine: { fontSize: 12, color: colors.navy, marginTop: 8, fontWeight: '600' },
  recordLine: { fontSize: 12, color: colors.inkSoft, marginTop: 4 },
  playerRow: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  jersey: { ...typography.heading, fontSize: 15, color: colors.inkSoft, width: 20, textAlign: 'center' },
  playerName: { ...typography.heading, fontSize: 14, color: colors.navy },
  positionTag: { fontSize: 10, fontWeight: '700', color: colors.buzzerDark, marginTop: 2 },
  contactArea: { marginTop: 12, borderTopWidth: 1, borderTopColor: colors.line, paddingTop: 12, gap: 8 },
  contactRow: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  contactText: { fontSize: 13, color: colors.navy, fontWeight: '600' },
});
