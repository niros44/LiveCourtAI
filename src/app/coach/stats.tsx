import { useCallback, useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, ScrollView, StyleSheet, Text, View } from 'react-native';

import { Card } from '@/components/ui/Card';
import { Chip } from '@/components/ui/Chip';
import { Screen } from '@/components/ui/Screen';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { getCurrentPersonId } from '@/lib/auth';
import {
  type BoxScoreRow,
  type CoachTeam,
  type GameLogEntry,
  type Measurement,
  type RosterPlayer,
  type TrendPoint,
  getCurrentMeasurements,
  getLastGameBoxScore,
  getMyTeams,
  getPlayerGameLog,
  getRosters,
  getShootingTrend,
} from '@/lib/coachData';
import { colors } from '@/theme/colors';
import { typography } from '@/theme/typography';

type SubTab = 'last' | 'trends' | 'physical';

function fmtDay(iso: string) {
  return new Date(iso).toLocaleDateString('en-US', { weekday: 'short', day: 'numeric', month: 'short' });
}

function BoxScoreTable({ rows, rosterById }: { rows: BoxScoreRow[]; rosterById: Map<string, RosterPlayer> }) {
  if (rows.length === 0) {
    return <Text style={styles.emptyText}>No stats recorded for this game yet.</Text>;
  }
  return (
    <View>
      <View style={styles.tableHeaderRow}>
        <Text style={[styles.tableHeaderCell, { flex: 2, textAlign: 'left' }]}>PLAYER</Text>
        {['PTS', 'REB', 'AST', 'STL', 'BLK', 'FG%'].map((h) => (
          <Text key={h} style={styles.tableHeaderCell}>
            {h}
          </Text>
        ))}
      </View>
      {rows
        .sort((a, b) => b.pts - a.pts)
        .map((row) => {
          const p = rosterById.get(row.playerId);
          return (
            <View key={row.playerId} style={styles.tableRow}>
              <Text style={[styles.tableCell, { flex: 2, textAlign: 'left', fontWeight: '700', color: colors.navy }]} numberOfLines={1}>
                #{p?.jersey ?? '–'} {p?.name ?? 'Player'}
              </Text>
              <Text style={styles.tableCell}>{row.pts}</Text>
              <Text style={styles.tableCell}>{row.reb}</Text>
              <Text style={styles.tableCell}>{row.ast}</Text>
              <Text style={styles.tableCell}>{row.stl}</Text>
              <Text style={styles.tableCell}>{row.blk}</Text>
              <Text style={styles.tableCell}>{row.fgPct !== null ? `${row.fgPct}%` : '–'}</Text>
            </View>
          );
        })}
    </View>
  );
}

export default function CoachStatsScreen() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [teams, setTeams] = useState<CoachTeam[]>([]);
  const [selectedTeamId, setSelectedTeamId] = useState<string | null>(null);
  const [roster, setRoster] = useState<RosterPlayer[]>([]);
  const [selectedPlayerId, setSelectedPlayerId] = useState<string | null>(null);
  const [subTab, setSubTab] = useState<SubTab>('last');

  const [lastGame, setLastGame] = useState<{ event: any; rows: BoxScoreRow[]; score: { home: number; away: number } | null } | null>(null);
  const [gameLog, setGameLog] = useState<GameLogEntry[]>([]);
  const [trend, setTrend] = useState<TrendPoint[]>([]);
  const [measurements, setMeasurements] = useState<Map<string, Measurement>>(new Map());
  const [panelLoading, setPanelLoading] = useState(false);

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
    getRosters([selectedTeamId])
      .then((r) => {
        setRoster(r);
        setSelectedPlayerId(null);
      })
      .catch((e) => setError(e instanceof Error ? e.message : 'Failed to load roster.'));
  }, [selectedTeamId]);

  const rosterById = useMemo(() => new Map(roster.map((p) => [p.id, p])), [roster]);
  const selectedPlayer = selectedPlayerId ? rosterById.get(selectedPlayerId) ?? null : null;

  useEffect(() => {
    if (!selectedTeamId) return;
    setPanelLoading(true);
    (async () => {
      if (subTab === 'last') {
        if (selectedPlayerId) setGameLog(await getPlayerGameLog(selectedTeamId, selectedPlayerId));
        else setLastGame(await getLastGameBoxScore(selectedTeamId));
      } else if (subTab === 'trends' && selectedPlayerId) {
        setTrend(await getShootingTrend(selectedTeamId, selectedPlayerId));
      } else if (subTab === 'physical') {
        const ids = selectedPlayerId ? [selectedPlayerId] : roster.map((p) => p.id);
        setMeasurements(await getCurrentMeasurements(ids));
      }
    })()
      .catch((e) => setError(e instanceof Error ? e.message : 'Failed to load stats.'))
      .finally(() => setPanelLoading(false));
  }, [selectedTeamId, selectedPlayerId, subTab, roster]);

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
        <SectionHeader title="STATS" />
        <Card>
          <Text style={styles.emptyText}>You&apos;re not assigned to coach any team yet.</Text>
        </Card>
      </Screen>
    );
  }

  const physicalRows = selectedPlayerId ? roster.filter((p) => p.id === selectedPlayerId) : roster;

  return (
    <Screen>
      <SectionHeader title="STATS" />

      <View>
        <Text style={styles.scopeLabel}>TEAM:</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8 }}>
          {teams.map((team) => (
            <Chip key={team.id} label={team.name} active={selectedTeamId === team.id} onPress={() => setSelectedTeamId(team.id)} />
          ))}
        </ScrollView>
      </View>

      {selectedPlayer ? (
        <View style={styles.showingBar}>
          <Text style={styles.showingText} numberOfLines={1}>
            Showing: #{selectedPlayer.jersey ?? '–'} {selectedPlayer.name}
          </Text>
          <Text style={styles.showingAction} onPress={() => setSelectedPlayerId(null)}>
            Show whole team
          </Text>
        </View>
      ) : (
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8 }}>
          {roster.map((p) => (
            <Chip key={p.id} label={`#${p.jersey ?? '–'} ${p.name}`} onPress={() => setSelectedPlayerId(p.id)} />
          ))}
        </ScrollView>
      )}

      <View style={styles.formRow}>
        <Chip label="Last Game" active={subTab === 'last'} onPress={() => setSubTab('last')} />
        <Chip label="Trends" active={subTab === 'trends'} onPress={() => setSubTab('trends')} />
        <Chip label="Physical Stats" active={subTab === 'physical'} onPress={() => setSubTab('physical')} />
      </View>

      {panelLoading ? (
        <ActivityIndicator color={colors.buzzer} />
      ) : subTab === 'last' ? (
        selectedPlayerId ? (
          <Card>
            <Text style={styles.cardTitle}>Game log · {gameLog.length} game{gameLog.length === 1 ? '' : 's'} recorded</Text>
            {gameLog.length === 0 ? (
              <Text style={styles.emptyText}>No stats recorded yet.</Text>
            ) : (
              gameLog.map(({ event, row }) => (
                <View key={event.id} style={styles.logRow}>
                  <Text style={styles.logOpponent}>
                    vs {event.opponentName ?? 'Opponent'} · {fmtDay(event.startsAt)}
                  </Text>
                  <Text style={styles.logStats}>
                    {row.pts} PTS · {row.reb} REB · {row.ast} AST · {row.fgPct !== null ? `${row.fgPct}% FG` : '– FG'}
                  </Text>
                </View>
              ))
            )}
          </Card>
        ) : (
          <Card>
            {lastGame?.event ? (
              <>
                <View style={styles.lastGameHeader}>
                  <Text style={styles.cardTitle}>vs {lastGame.event.opponentName ?? 'Opponent'}</Text>
                  {lastGame.score ? (
                    <Text style={styles.scoreTag}>
                      {lastGame.score.home > lastGame.score.away ? 'W' : lastGame.score.home < lastGame.score.away ? 'L' : 'T'} · {lastGame.score.home}-{lastGame.score.away}
                    </Text>
                  ) : null}
                </View>
                <Text style={styles.practiceMeta}>
                  {fmtDay(lastGame.event.startsAt)} · {lastGame.event.isHomeGame ? 'Home' : 'Away'}
                </Text>
                <View style={{ marginTop: 10 }}>
                  <BoxScoreTable rows={lastGame.rows} rosterById={rosterById} />
                </View>
              </>
            ) : (
              <Text style={styles.emptyText}>No completed games recorded yet for this team.</Text>
            )}
          </Card>
        )
      ) : subTab === 'trends' ? (
        <Card>
          {!selectedPlayerId ? (
            <Text style={styles.emptyText}>Pick a player above to see their shooting trend.</Text>
          ) : trend.length === 0 || trend.every((t) => t.fgPct === null) ? (
            <Text style={styles.emptyText}>No shot data recorded yet for this player.</Text>
          ) : (
            <>
              <Text style={styles.cardTitle}>{selectedPlayer?.name}</Text>
              <Text style={styles.practiceMeta}>Shooting % over last games</Text>
              <View style={styles.trendRow}>
                {trend.map((t) => (
                  <View key={t.eventId} style={styles.trendBarWrap}>
                    <Text style={styles.trendValue}>{t.fgPct !== null ? `${t.fgPct}%` : '–'}</Text>
                    <View style={[styles.trendBar, { height: Math.max((t.fgPct ?? 0) * 0.6, 3) }]} />
                    <Text style={styles.trendLabel}>{t.label}</Text>
                  </View>
                ))}
              </View>
            </>
          )}
        </Card>
      ) : (
        <Card>
          <View style={styles.tableHeaderRow}>
            <Text style={[styles.tableHeaderCell, { flex: 2, textAlign: 'left' }]}>PLAYER</Text>
            <Text style={styles.tableHeaderCell}>HEIGHT</Text>
            <Text style={styles.tableHeaderCell}>WEIGHT</Text>
            <Text style={[styles.tableHeaderCell, { flex: 1.4 }]}>POSITION</Text>
          </View>
          {physicalRows.length === 0 ? (
            <Text style={styles.emptyText}>No players on this roster yet.</Text>
          ) : (
            physicalRows.map((p) => {
              const m = measurements.get(p.id);
              return (
                <View key={p.id} style={styles.tableRow}>
                  <Text style={[styles.tableCell, { flex: 2, textAlign: 'left', fontWeight: '700', color: colors.navy }]} numberOfLines={1}>
                    #{p.jersey ?? '–'} {p.name}
                  </Text>
                  <Text style={styles.tableCell}>{m?.heightCm ? `${m.heightCm} cm` : '–'}</Text>
                  <Text style={styles.tableCell}>{m?.weightKg ? `${m.weightKg} kg` : '–'}</Text>
                  <Text style={[styles.tableCell, { flex: 1.4 }]}>{p.position ?? '–'}</Text>
                </View>
              );
            })
          )}
          {physicalRows.length > 0 && [...measurements.values()].length === 0 ? (
            <Text style={[styles.emptyText, { marginTop: 10 }]}>No physical measurements have been recorded yet.</Text>
          ) : null}
        </Card>
      )}
    </Screen>
  );
}

const styles = StyleSheet.create({
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingTop: 60 },
  errorText: { fontSize: 13, color: colors.inkSoft, textAlign: 'center' },
  emptyText: { fontSize: 13, color: colors.inkSoft, lineHeight: 19 },
  scopeLabel: { ...typography.label, fontSize: 10, color: colors.inkSoft, marginBottom: 8 },
  showingBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: colors.navy,
    borderRadius: 10,
    paddingVertical: 10,
    paddingHorizontal: 14,
  },
  showingText: { color: colors.white, fontSize: 13, fontWeight: '700', flex: 1 },
  showingAction: { color: colors.gold, fontSize: 12, fontWeight: '700' },
  formRow: { flexDirection: 'row', gap: 8 },
  cardTitle: { ...typography.heading, fontSize: 15, color: colors.navy },
  practiceMeta: { fontSize: 12, color: colors.inkSoft, marginTop: 2 },
  lastGameHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  scoreTag: { fontSize: 12, fontWeight: '800', color: colors.greenDark, backgroundColor: '#E9F7EF', paddingVertical: 3, paddingHorizontal: 9, borderRadius: 8 },
  tableHeaderRow: { flexDirection: 'row', borderBottomWidth: 1, borderBottomColor: colors.line, paddingBottom: 8, marginBottom: 4 },
  tableHeaderCell: { flex: 1, fontSize: 10, fontWeight: '700', color: colors.inkSoft, textAlign: 'center' },
  tableRow: { flexDirection: 'row', paddingVertical: 8, borderBottomWidth: 1, borderBottomColor: colors.line },
  tableCell: { flex: 1, fontSize: 12, color: colors.navy, textAlign: 'center' },
  logRow: { borderTopWidth: 1, borderTopColor: colors.line, paddingVertical: 10 },
  logOpponent: { fontSize: 13, fontWeight: '700', color: colors.navy },
  logStats: { fontSize: 12, color: colors.inkSoft, marginTop: 2 },
  trendRow: { flexDirection: 'row', justifyContent: 'space-around', alignItems: 'flex-end', height: 110, marginTop: 14 },
  trendBarWrap: { alignItems: 'center', gap: 4, justifyContent: 'flex-end', flex: 1 },
  trendValue: { fontSize: 10, color: colors.inkSoft, fontWeight: '700' },
  trendBar: { width: 14, borderRadius: 4, backgroundColor: colors.buzzer },
  trendLabel: { fontSize: 10, color: colors.inkSoft },
});
