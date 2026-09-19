import { Ionicons } from '@expo/vector-icons';
import { StyleSheet, Text, View } from 'react-native';

import { Badge, type BadgeTone } from '@/components/ui/Badge';
import { Card } from '@/components/ui/Card';
import { colors } from '@/theme/colors';
import { fontSize, radius, spacing } from '@/theme/tokens';
import { typography } from '@/theme/typography';

export type RsvpState = 'attending' | 'not_attending' | 'undecided' | 'injured' | null;

const RSVP_BADGE: Record<Exclude<RsvpState, null>, { label: string; tone: BadgeTone }> = {
  attending: { label: 'In', tone: 'in' },
  not_attending: { label: 'Out', tone: 'out' },
  undecided: { label: 'Maybe', tone: 'pending' },
  injured: { label: 'Injured', tone: 'out' },
};

/** Game / practice pill. Games get the stronger (filled) look — they matter more than practices. */
export function EventTypeTag({ type }: { type: string }) {
  const isGame = type === 'game';
  return (
    <View style={[tagStyles.tag, isGame ? tagStyles.game : tagStyles.practice]}>
      <Text style={[tagStyles.label, isGame ? tagStyles.gameLabel : tagStyles.practiceLabel]}>{type.toUpperCase()}</Text>
    </View>
  );
}

type EventRowProps = {
  type: string;
  title: string;
  /** Pre-formatted, e.g. "Tue, Sep 22 · 19:30". */
  when: string;
  where?: string | null;
  rsvp?: RsvpState;
};

/** Compact event line: type tag, title, when/where, and the person's RSVP at the end. */
export function EventRow({ type, title, when, where, rsvp }: EventRowProps) {
  return (
    <Card style={styles.row}>
      <EventTypeTag type={type} />
      <View style={styles.body}>
        <Text style={styles.title} numberOfLines={1}>
          {title}
        </Text>
        <View style={styles.meta}>
          <Ionicons name="time-outline" size={12} color={colors.inkSoft} />
          <Text style={styles.metaText}>{when}</Text>
          {where ? (
            <>
              <Text style={styles.metaText}>·</Text>
              <Text style={[styles.metaText, styles.where]} numberOfLines={1}>
                {where}
              </Text>
            </>
          ) : null}
        </View>
      </View>
      {rsvp ? <Badge label={RSVP_BADGE[rsvp].label} tone={RSVP_BADGE[rsvp].tone} /> : null}
    </Card>
  );
}

const tagStyles = StyleSheet.create({
  tag: { width: 58, alignItems: 'center', paddingVertical: 4, borderRadius: radius.sm - 2 },
  practice: { backgroundColor: colors.tintNavy },
  game: { backgroundColor: colors.navy },
  label: { fontSize: 9, fontWeight: '800', letterSpacing: 0.5 },
  practiceLabel: { color: colors.navy },
  gameLabel: { color: colors.white },
});

const styles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
  body: { flex: 1, gap: 3 },
  title: { ...typography.heading, fontSize: fontSize.body, color: colors.navy },
  meta: { flexDirection: 'row', alignItems: 'center', gap: 4 },
  metaText: { fontSize: fontSize.caption, color: colors.inkSoft },
  where: { flexShrink: 1 },
});
