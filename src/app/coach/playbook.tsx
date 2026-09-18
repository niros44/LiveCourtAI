import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { ActivityIndicator, LayoutChangeEvent, PanResponder, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';

import { Card } from '@/components/ui/Card';
import { Chip } from '@/components/ui/Chip';
import { Screen } from '@/components/ui/Screen';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { getCurrentPersonId } from '@/lib/auth';
import {
  type CoachTeam,
  type CourtDiagram,
  type CourtMarker,
  type Playbook,
  type PlaybookCategory,
  DEFAULT_DIAGRAM,
  createPlaybook,
  getMyTeams,
  getPlaybooks,
  savePlay,
} from '@/lib/coachData';
import { colors } from '@/theme/colors';
import { typography } from '@/theme/typography';

const CATEGORIES: PlaybookCategory[] = ['offense', 'defense', 'inbound', 'drill', 'special'];
const MARKER_SIZE = 28;

function clamp01(v: number) {
  return Math.max(0, Math.min(1, v));
}

function LineSegment({ from, to, color }: { from: { x: number; y: number }; to: { x: number; y: number }; color: string }) {
  const dx = to.x - from.x;
  const dy = to.y - from.y;
  const length = Math.sqrt(dx * dx + dy * dy);
  if (length < 2) return null;
  const angle = (Math.atan2(dy, dx) * 180) / Math.PI;
  const centerX = (from.x + to.x) / 2;
  const centerY = (from.y + to.y) / 2;
  return (
    <View
      pointerEvents="none"
      style={{
        position: 'absolute',
        left: centerX - length / 2,
        top: centerY - 1.5,
        width: length,
        height: 3,
        borderRadius: 2,
        backgroundColor: color,
        transform: [{ rotate: `${angle}deg` }],
        opacity: 0.85,
      }}
    />
  );
}

function DraggableMarker({
  marker,
  courtSize,
  onDragEnd,
}: {
  marker: CourtMarker;
  courtSize: { width: number; height: number };
  onDragEnd: (id: string, x: number, y: number, origin: { x: number; y: number }) => void;
}) {
  const basePixel = { x: marker.x * courtSize.width, y: marker.y * courtSize.height };
  const [offset, setOffset] = useState({ x: 0, y: 0 });
  const originRef = useRef(marker);

  const panResponder = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onPanResponderGrant: () => {
        originRef.current = marker;
        setOffset({ x: 0, y: 0 });
      },
      onPanResponderMove: (_evt, gesture) => {
        setOffset({ x: gesture.dx, y: gesture.dy });
      },
      onPanResponderRelease: (_evt, gesture) => {
        const nx = clamp01((basePixel.x + gesture.dx) / courtSize.width);
        const ny = clamp01((basePixel.y + gesture.dy) / courtSize.height);
        setOffset({ x: 0, y: 0 });
        onDragEnd(marker.id, nx, ny, { x: originRef.current.x, y: originRef.current.y });
      },
    })
  ).current;

  return (
    <View
      {...panResponder.panHandlers}
      style={[
        styles.marker,
        {
          left: basePixel.x - MARKER_SIZE / 2 + offset.x,
          top: basePixel.y - MARKER_SIZE / 2 + offset.y,
          backgroundColor: marker.side === 'offense' ? colors.blue : colors.red,
        },
      ]}>
      <Text style={styles.markerLabel}>
        {marker.side === 'offense' ? 'O' : 'X'}
        {marker.num}
      </Text>
    </View>
  );
}

export default function CoachPlaybookScreen() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [personId, setPersonId] = useState<string | null>(null);
  const [teams, setTeams] = useState<CoachTeam[]>([]);
  const [selectedTeamId, setSelectedTeamId] = useState<string | null>(null);
  const [playbooks, setPlaybooks] = useState<Playbook[]>([]);
  const [diagram, setDiagram] = useState<CourtDiagram>(DEFAULT_DIAGRAM);
  const [history, setHistory] = useState<CourtDiagram[]>([]);
  const [courtSize, setCourtSize] = useState({ width: 0, height: 0 });
  const [drillName, setDrillName] = useState('');
  const [category, setCategory] = useState<PlaybookCategory>('drill');
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
      setError(e instanceof Error ? e.message : 'Something went wrong loading your teams.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const reloadPlaybooks = useCallback(async (teamId: string) => {
    const pbs = await getPlaybooks(teamId);
    setPlaybooks(pbs);
  }, []);

  useEffect(() => {
    if (!selectedTeamId) return;
    reloadPlaybooks(selectedTeamId).catch((e) => setError(e instanceof Error ? e.message : 'Failed to load saved drills.'));
    setDiagram(DEFAULT_DIAGRAM);
    setHistory([]);
    setDrillName('');
  }, [selectedTeamId, reloadPlaybooks]);

  function onCourtLayout(e: LayoutChangeEvent) {
    const { width, height } = e.nativeEvent.layout;
    setCourtSize({ width, height });
  }

  function handleDragEnd(id: string, x: number, y: number, origin: { x: number; y: number }) {
    setHistory((h) => [...h, diagram]);
    setDiagram((d) => ({
      markers: d.markers.map((m) => (m.id === id ? { ...m, x, y, path: [origin] } : m)),
    }));
  }

  function handleUndo() {
    setHistory((h) => {
      if (!h.length) return h;
      const prev = h[h.length - 1];
      setDiagram(prev);
      return h.slice(0, -1);
    });
  }

  function handleClear() {
    setHistory((h) => [...h, diagram]);
    setDiagram(DEFAULT_DIAGRAM);
  }

  function loadDrill(pb: Playbook) {
    const play = pb.plays[0];
    if (!play) return;
    setDiagram(play.canvasData);
    setHistory([]);
    setDrillName(pb.title);
    setCategory(pb.category ?? 'drill');
  }

  async function handleSave() {
    if (!personId || !selectedTeam || !drillName.trim()) return;
    setSaving(true);
    try {
      const playbookId = await createPlaybook({ authorId: personId, clubId: selectedTeam.clubId, teamId: selectedTeam.id, title: drillName.trim(), category });
      await savePlay({ playbookId, title: drillName.trim(), canvasData: diagram, displayOrder: 0 });
      setDrillName('');
      setDiagram(DEFAULT_DIAGRAM);
      setHistory([]);
      await reloadPlaybooks(selectedTeam.id);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to save drill.');
    } finally {
      setSaving(false);
    }
  }

  const linesToDraw = useMemo(() => {
    if (!courtSize.width) return [];
    return diagram.markers
      .filter((m) => m.path.length > 0 && (m.path[0].x !== m.x || m.path[0].y !== m.y))
      .map((m) => ({
        id: m.id,
        color: m.side === 'offense' ? colors.blue : colors.red,
        from: { x: m.path[0].x * courtSize.width, y: m.path[0].y * courtSize.height },
        to: { x: m.x * courtSize.width, y: m.y * courtSize.height },
      }));
  }, [diagram, courtSize]);

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
        <SectionHeader title="PLAYBOOK" />
        <Card>
          <Text style={styles.emptyText}>You&apos;re not assigned to coach any team yet.</Text>
        </Card>
      </Screen>
    );
  }

  return (
    <Screen>
      <SectionHeader title="PLAYBOOK" />

      <View>
        <Text style={styles.scopeLabel}>FILTER SAVED DRILLS BY TEAM:</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8 }}>
          {teams.map((team) => (
            <Chip key={team.id} label={team.name} active={selectedTeamId === team.id} onPress={() => setSelectedTeamId(team.id)} />
          ))}
        </ScrollView>
      </View>

      <View onLayout={onCourtLayout} style={styles.court}>
        <View style={styles.key} />
        <View style={styles.ftCircle} />
        <View style={styles.basket} />
        {courtSize.width > 0 ? linesToDraw.map((l) => <LineSegment key={l.id} from={l.from} to={l.to} color={l.color} />) : null}
        {courtSize.width > 0
          ? diagram.markers.map((m) => <DraggableMarker key={m.id} marker={m} courtSize={courtSize} onDragEnd={handleDragEnd} />)
          : null}
      </View>
      <Text style={styles.hint}>Drag any circle to draw its movement</Text>

      <View style={styles.formRow}>
        <Pressable style={styles.toolBtn} onPress={handleUndo} disabled={!history.length}>
          <Text style={[styles.toolBtnLabel, !history.length && { opacity: 0.4 }]}>↺ Undo</Text>
        </Pressable>
        <Pressable style={styles.toolBtn} onPress={handleClear}>
          <Text style={styles.toolBtnLabel}>Clear</Text>
        </Pressable>
      </View>

      <TextInput style={styles.input} value={drillName} onChangeText={setDrillName} placeholder="Name this drill..." />

      <Text style={styles.scopeLabel}>CATEGORY:</Text>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8 }}>
        {CATEGORIES.map((c) => (
          <Chip key={c} label={c[0].toUpperCase() + c.slice(1)} active={category === c} onPress={() => setCategory(c)} />
        ))}
      </ScrollView>

      <Pressable style={[styles.saveBtn, (!drillName.trim() || saving) && { opacity: 0.5 }]} onPress={handleSave} disabled={!drillName.trim() || saving}>
        <Text style={styles.saveBtnLabel}>{saving ? 'Saving…' : 'Save Drill'}</Text>
      </Pressable>

      <View>
        <SectionHeader title="SAVED DRILLS" />
        <View style={{ gap: 8, marginTop: 8 }}>
          {playbooks.length === 0 ? (
            <Card>
              <Text style={styles.emptyText}>No saved drills yet for this team.</Text>
            </Card>
          ) : (
            playbooks.map((pb) => (
              <Pressable key={pb.id} onPress={() => loadDrill(pb)}>
                <Card>
                  <View style={styles.drillRow}>
                    <View style={{ flex: 1 }}>
                      <Text style={styles.drillTitle}>{pb.title}</Text>
                      {pb.category ? <Text style={styles.drillCategory}>{pb.category.toUpperCase()}</Text> : null}
                    </View>
                    <Text style={styles.drillLoad}>Load</Text>
                  </View>
                </Card>
              </Pressable>
            ))
          )}
        </View>
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingTop: 60 },
  errorText: { fontSize: 13, color: colors.inkSoft, textAlign: 'center' },
  emptyText: { fontSize: 13, color: colors.inkSoft, lineHeight: 19 },
  scopeLabel: { ...typography.label, fontSize: 10, color: colors.inkSoft, marginBottom: 8 },
  court: {
    width: '100%',
    aspectRatio: 0.94,
    backgroundColor: colors.paper,
    borderWidth: 2,
    borderColor: colors.navy,
    borderRadius: 4,
    overflow: 'hidden',
  },
  key: {
    position: 'absolute',
    top: 0,
    left: '32%',
    width: '36%',
    height: '40%',
    borderWidth: 2,
    borderTopWidth: 0,
    borderColor: colors.navy,
  },
  ftCircle: {
    position: 'absolute',
    top: '30%',
    left: '35%',
    width: '30%',
    aspectRatio: 1,
    borderRadius: 999,
    borderWidth: 2,
    borderColor: colors.navy,
  },
  basket: {
    position: 'absolute',
    top: 8,
    left: '50%',
    marginLeft: -4,
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: colors.buzzer,
  },
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
  markerLabel: { color: colors.white, fontSize: 10, fontWeight: '800' },
  hint: { fontSize: 11, color: colors.inkSoft, textAlign: 'center' },
  formRow: { flexDirection: 'row', gap: 8 },
  toolBtn: { flex: 1, borderWidth: 1, borderColor: colors.line, borderRadius: 10, paddingVertical: 10, alignItems: 'center' },
  toolBtnLabel: { fontSize: 13, fontWeight: '700', color: colors.navy },
  input: { borderWidth: 1, borderColor: colors.line, borderRadius: 10, paddingVertical: 10, paddingHorizontal: 12, fontSize: 14, color: colors.navy },
  saveBtn: { backgroundColor: colors.buzzer, borderRadius: 12, paddingVertical: 13, alignItems: 'center' },
  saveBtnLabel: { color: colors.white, fontSize: 14, fontWeight: '800' },
  drillRow: { flexDirection: 'row', alignItems: 'center' },
  drillTitle: { ...typography.heading, fontSize: 14, color: colors.navy },
  drillCategory: { fontSize: 10, fontWeight: '700', color: colors.buzzerDark, marginTop: 2 },
  drillLoad: { fontSize: 12, fontWeight: '700', color: colors.buzzerDark },
});
