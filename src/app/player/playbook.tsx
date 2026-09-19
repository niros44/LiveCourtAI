import { Ionicons } from '@expo/vector-icons';
import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, Modal, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import { Card } from '@/components/ui/Card';
import { Chip } from '@/components/ui/Chip';
import { Screen } from '@/components/ui/Screen';
import { ScreenHeader } from '@/components/ui/ScreenHeader';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { getCurrentPersonId } from '@/lib/auth';
import { type CourtDiagram, type Play, type Playbook, getPlaybooks } from '@/lib/coachData';
import { type Playership, getMyPlayerships, logPlayView } from '@/lib/playerData';
import { errorMessage } from '@/lib/errors';
import { colors } from '@/theme/colors';
import { typography } from '@/theme/typography';

const MARKER_SIZE = 26;

function StaticCourt({ diagram }: { diagram: CourtDiagram }) {
  return (
    <View style={styles.court}>
      <View style={styles.key} />
      <View style={styles.ftCircle} />
      <View style={styles.basket} />
      {diagram.markers.map((m) => {
        const from = m.path[0];
        if (!from || (from.x === m.x && from.y === m.y)) return null;
        const dx = (m.x - from.x) * 100;
        const dy = (m.y - from.y) * 100;
        const length = Math.sqrt(dx * dx + dy * dy);
        const angle = (Math.atan2(dy, dx) * 180) / Math.PI;
        const centerX = ((from.x + m.x) / 2) * 100;
        const centerY = ((from.y + m.y) / 2) * 100;
        return (
          <View
            key={`line-${m.id}`}
            pointerEvents="none"
            style={{
              position: 'absolute',
              left: `${centerX - length / 2}%`,
              top: `${centerY}%`,
              width: `${length}%`,
              height: 3,
              borderRadius: 2,
              backgroundColor: m.side === 'offense' ? colors.blue : colors.red,
              transform: [{ rotate: `${angle}deg` }],
              opacity: 0.85,
            }}
          />
        );
      })}
      {diagram.markers.map((m) => (
        <View
          key={m.id}
          style={[
            styles.marker,
            {
              left: `${m.x * 100}%`,
              top: `${m.y * 100}%`,
              marginLeft: -MARKER_SIZE / 2,
              marginTop: -MARKER_SIZE / 2,
              backgroundColor: m.side === 'offense' ? colors.blue : colors.red,
            },
          ]}>
          <Text style={styles.markerLabel}>
            {m.side === 'offense' ? 'O' : 'X'}
            {m.num}
          </Text>
        </View>
      ))}
    </View>
  );
}

export default function PlayerPlaybookScreen() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [personId, setPersonId] = useState<string | null>(null);
  const [playerships, setPlayerships] = useState<Playership[]>([]);
  const [selectedTeamId, setSelectedTeamId] = useState<string | null>(null);
  const [playbooks, setPlaybooks] = useState<Playbook[]>([]);
  const [scopeLoading, setScopeLoading] = useState(false);
  const [activePlay, setActivePlay] = useState<{ playbook: Playbook; play: Play } | null>(null);

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
    getPlaybooks(selectedTeamId)
      .then(setPlaybooks)
      .catch((e) => setError(errorMessage(e, 'Failed to load the playbook.')))
      .finally(() => setScopeLoading(false));
  }, [selectedTeamId]);

  function openPlay(playbook: Playbook, play: Play) {
    setActivePlay({ playbook, play });
    if (personId) {
      logPlayView(play.id, personId).catch(() => {
        /* view logging is best-effort */
      });
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
        <ScreenHeader title="Playbook" />
        <Card>
          <Text style={styles.emptyText}>You&apos;re not on a team roster yet.</Text>
        </Card>
      </Screen>
    );
  }

  return (
    <Screen>
      <ScreenHeader title="Playbook" />

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
      ) : playbooks.length === 0 ? (
        <Card>
          <Text style={styles.emptyText}>Your coach hasn&apos;t shared any plays yet.</Text>
        </Card>
      ) : (
        <View style={{ gap: 14 }}>
          {playbooks.map((pb) => (
            <View key={pb.id}>
              <SectionHeader title={pb.title} tag={pb.category ? pb.category.toUpperCase() : undefined} />
              <View style={{ gap: 8, marginTop: 8 }}>
                {pb.plays.length === 0 ? (
                  <Card>
                    <Text style={styles.emptyText}>No drills saved in this playbook yet.</Text>
                  </Card>
                ) : (
                  pb.plays.map((play) => (
                    <Pressable key={play.id} onPress={() => openPlay(pb, play)}>
                      <Card style={styles.playRow}>
                        <Ionicons name="basketball-outline" size={18} color={colors.buzzerDark} />
                        <Text style={styles.playTitle}>{play.title}</Text>
                        <Ionicons name="chevron-forward" size={16} color={colors.inkSoft} />
                      </Card>
                    </Pressable>
                  ))
                )}
              </View>
            </View>
          ))}
        </View>
      )}

      <Modal visible={Boolean(activePlay)} transparent animationType="fade" onRequestClose={() => setActivePlay(null)}>
        <View style={styles.modalBackdrop}>
          <View style={styles.modalCard}>
            <View style={styles.modalHeader}>
              <View style={{ flex: 1 }}>
                <Text style={styles.modalTitle}>{activePlay?.play.title}</Text>
                {activePlay?.playbook.category ? <Text style={styles.modalCategory}>{activePlay.playbook.category.toUpperCase()}</Text> : null}
              </View>
              <Pressable onPress={() => setActivePlay(null)} hitSlop={8}>
                <Ionicons name="close" size={20} color={colors.inkSoft} />
              </Pressable>
            </View>
            {activePlay ? <StaticCourt diagram={activePlay.play.canvasData} /> : null}
            {activePlay?.play.notes ? <Text style={styles.modalNotes}>{activePlay.play.notes}</Text> : null}
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
  playRow: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  playTitle: { ...typography.heading, fontSize: 13, color: colors.navy, flex: 1 },
  court: {
    width: '100%',
    aspectRatio: 0.94,
    backgroundColor: colors.paper,
    borderWidth: 2,
    borderColor: colors.navy,
    borderRadius: 4,
    overflow: 'hidden',
    marginTop: 4,
  },
  key: { position: 'absolute', top: 0, left: '32%', width: '36%', height: '40%', borderWidth: 2, borderTopWidth: 0, borderColor: colors.navy },
  ftCircle: { position: 'absolute', top: '30%', left: '35%', width: '30%', aspectRatio: 1, borderRadius: 999, borderWidth: 2, borderColor: colors.navy },
  basket: { position: 'absolute', top: 8, left: '50%', marginLeft: -4, width: 8, height: 8, borderRadius: 4, backgroundColor: colors.buzzer },
  marker: {
    position: 'absolute',
    width: MARKER_SIZE,
    height: MARKER_SIZE,
    borderRadius: MARKER_SIZE / 2,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 2,
    borderColor: colors.white,
  },
  markerLabel: { color: colors.white, fontSize: 9, fontWeight: '800' },
  modalBackdrop: { flex: 1, backgroundColor: 'rgba(19,43,77,0.45)', alignItems: 'center', justifyContent: 'center', padding: 20 },
  modalCard: { backgroundColor: colors.white, borderRadius: 18, padding: 18, width: '100%', maxWidth: 420, gap: 10 },
  modalHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  modalTitle: { ...typography.heading, fontSize: 15, color: colors.navy },
  modalCategory: { fontSize: 10, fontWeight: '700', color: colors.buzzerDark, marginTop: 2 },
  modalNotes: { fontSize: 13, color: colors.inkSoft, lineHeight: 18 },
});
