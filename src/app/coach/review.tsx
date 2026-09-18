import { Ionicons } from '@expo/vector-icons';
import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';

import { Card } from '@/components/ui/Card';
import { Chip } from '@/components/ui/Chip';
import { Screen } from '@/components/ui/Screen';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { getCurrentPersonId } from '@/lib/auth';
import {
  type CoachEvent,
  type CoachTeam,
  type FeedbackEntry,
  type FeedbackType,
  type RosterPlayer,
  getFeedbackForEvent,
  getFeedbackTypes,
  getMyTeams,
  getRecentPractices,
  getRosters,
  saveFeedback,
} from '@/lib/coachData';
import { colors } from '@/theme/colors';
import { typography } from '@/theme/typography';

function fmtDay(iso: string) {
  return new Date(iso).toLocaleDateString('en-US', { weekday: 'short', day: 'numeric', month: 'short' });
}

export default function CoachReviewScreen() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [personId, setPersonId] = useState<string | null>(null);
  const [teams, setTeams] = useState<CoachTeam[]>([]);
  const [selectedTeamId, setSelectedTeamId] = useState<string | null>(null);
  const [practices, setPractices] = useState<CoachEvent[]>([]);
  const [selectedPracticeId, setSelectedPracticeId] = useState<string | null>(null);
  const [roster, setRoster] = useState<RosterPlayer[]>([]);
  const [feedback, setFeedback] = useState<Map<string, FeedbackEntry>>(new Map());
  const [feedbackTypes, setFeedbackTypes] = useState<FeedbackType[]>([]);
  const [expandedPlayerId, setExpandedPlayerId] = useState<string | null>(null);
  const [draftNote, setDraftNote] = useState('');
  const [draftTypeId, setDraftTypeId] = useState<number | null>(null);
  const [saving, setSaving] = useState(false);

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
      const [myTeams, types] = await Promise.all([getMyTeams(id), getFeedbackTypes()]);
      setTeams(myTeams);
      setFeedbackTypes(types);
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

  useEffect(() => {
    if (!selectedTeamId) return;
    (async () => {
      const [teamRoster, recent] = await Promise.all([getRosters([selectedTeamId]), getRecentPractices(selectedTeamId)]);
      setRoster(teamRoster);
      setPractices(recent);
      setSelectedPracticeId(recent[0]?.id ?? null);
    })().catch((e) => setError(e instanceof Error ? e.message : 'Failed to load practices.'));
  }, [selectedTeamId]);

  useEffect(() => {
    if (!selectedPracticeId || !personId) {
      setFeedback(new Map());
      return;
    }
    getFeedbackForEvent(selectedPracticeId, personId)
      .then(setFeedback)
      .catch((e) => setError(e instanceof Error ? e.message : 'Failed to load feedback.'));
    setExpandedPlayerId(null);
  }, [selectedPracticeId, personId]);

  function toggleExpand(player: RosterPlayer) {
    if (expandedPlayerId === player.id) {
      setExpandedPlayerId(null);
      return;
    }
    const existing = feedback.get(player.id);
    setDraftNote(existing?.note ?? '');
    setDraftTypeId(existing?.feedbackTypeId ?? null);
    setExpandedPlayerId(player.id);
  }

  async function handleSave(player: RosterPlayer) {
    if (!personId || !selectedTeamId || !selectedPracticeId) return;
    setSaving(true);
    try {
      const existing = feedback.get(player.id);
      const id = await saveFeedback(existing?.id ?? null, {
        coachId: personId,
        playerId: player.id,
        teamId: selectedTeamId,
        eventId: selectedPracticeId,
        note: draftNote.trim(),
        feedbackTypeId: draftTypeId,
      });
      setFeedback((prev) => new Map(prev).set(player.id, { id, note: draftNote.trim(), feedbackTypeId: draftTypeId }));
      setExpandedPlayerId(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to save feedback.');
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
        <SectionHeader title="REVIEW" />
        <Card>
          <Text style={styles.emptyText}>You&apos;re not assigned to coach any team yet.</Text>
        </Card>
      </Screen>
    );
  }

  const selectedPractice = practices.find((p) => p.id === selectedPracticeId) ?? null;

  return (
    <Screen>
      <SectionHeader title="REVIEW" />

      <View>
        <Text style={styles.scopeLabel}>TEAM:</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8 }}>
          {teams.map((team) => (
            <Chip key={team.id} label={team.name} active={selectedTeamId === team.id} onPress={() => setSelectedTeamId(team.id)} />
          ))}
        </ScrollView>
      </View>

      {practices.length === 0 ? (
        <Card>
          <Text style={styles.emptyText}>No past practices recorded yet for this team.</Text>
        </Card>
      ) : (
        <>
          <View>
            <Text style={styles.scopeLabel}>PRACTICE:</Text>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8 }}>
              {practices.map((p) => (
                <Chip key={p.id} label={fmtDay(p.startsAt)} active={selectedPracticeId === p.id} onPress={() => setSelectedPracticeId(p.id)} />
              ))}
            </ScrollView>
          </View>

          {selectedPractice ? (
            <Card>
              <Text style={styles.practiceTitle}>{fmtDay(selectedPractice.startsAt)}</Text>
              <Text style={styles.practiceMeta}>
                {new Date(selectedPractice.startsAt).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: false })} -{' '}
                {new Date(selectedPractice.endsAt).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: false })}
              </Text>
            </Card>
          ) : null}

          <View>
            <SectionHeader title="PLAYER FEEDBACK" />
            <View style={{ gap: 8, marginTop: 8 }}>
              {roster.map((player) => {
                const entry = feedback.get(player.id);
                const expanded = expandedPlayerId === player.id;
                return (
                  <Card key={player.id}>
                    <Pressable style={styles.playerRow} onPress={() => toggleExpand(player)}>
                      <Text style={styles.jersey}>{player.jersey ?? '–'}</Text>
                      <View style={{ flex: 1 }}>
                        <Text style={styles.playerName}>{player.name}</Text>
                        <Text style={styles.feedbackPreview} numberOfLines={1}>
                          {entry?.note || 'No feedback yet'}
                        </Text>
                      </View>
                      <Ionicons name={expanded ? 'chevron-up' : 'chevron-down'} size={16} color={colors.inkSoft} />
                    </Pressable>

                    {expanded ? (
                      <View style={styles.expandArea}>
                        {feedbackTypes.length > 0 ? (
                          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8, marginBottom: 8 }}>
                            {feedbackTypes.map((ft) => (
                              <Chip key={ft.id} label={ft.name} active={draftTypeId === ft.id} onPress={() => setDraftTypeId(draftTypeId === ft.id ? null : ft.id)} />
                            ))}
                          </ScrollView>
                        ) : null}
                        <Text style={styles.fieldLabel}>FEEDBACK FOR THIS PRACTICE</Text>
                        <TextInput
                          style={styles.textarea}
                          value={draftNote}
                          onChangeText={setDraftNote}
                          placeholder="e.g. Great hustle on defense, work on left-hand dribble..."
                          multiline
                          numberOfLines={3}
                        />
                        <Pressable style={styles.saveBtn} onPress={() => handleSave(player)} disabled={saving}>
                          <Text style={styles.saveBtnLabel}>{saving ? 'Saving…' : 'Save Feedback'}</Text>
                        </Pressable>
                      </View>
                    ) : null}
                  </Card>
                );
              })}
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
  practiceTitle: { ...typography.heading, fontSize: 15, color: colors.navy },
  practiceMeta: { fontSize: 12, color: colors.inkSoft, marginTop: 2 },
  playerRow: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  jersey: { ...typography.heading, fontSize: 16, color: colors.inkSoft, width: 24, textAlign: 'center' },
  playerName: { ...typography.heading, fontSize: 14, color: colors.navy },
  feedbackPreview: { fontSize: 12, color: colors.inkSoft, marginTop: 2 },
  expandArea: { marginTop: 12, borderTopWidth: 1, borderTopColor: colors.line, paddingTop: 12 },
  fieldLabel: { ...typography.label, fontSize: 10, color: colors.inkSoft, marginBottom: 6 },
  textarea: { borderWidth: 1, borderColor: colors.line, borderRadius: 10, padding: 12, fontSize: 13, color: colors.navy, minHeight: 72, textAlignVertical: 'top' },
  saveBtn: { backgroundColor: colors.buzzer, borderRadius: 10, paddingVertical: 11, alignItems: 'center', marginTop: 10 },
  saveBtnLabel: { color: colors.white, fontSize: 13, fontWeight: '800' },
});
