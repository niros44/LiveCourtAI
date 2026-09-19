import { Ionicons } from '@expo/vector-icons';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { Badge, type BadgeTone } from '@/components/ui/Badge';
import { Card } from '@/components/ui/Card';
import { colors } from '@/theme/colors';
import { fontSize, radius, spacing, touchTarget } from '@/theme/tokens';
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

type RsvpToggleProps = {
  value: RsvpState;
  onChange: (status: 'attending' | 'not_attending') => void;
  disabled?: boolean;
};

/** "I'm in / Can't make it" — the current answer is filled in status colour, so it can be changed any time. */
export function RsvpToggle({ value, onChange, disabled }: RsvpToggleProps) {
  return (
    <View style={toggleStyles.row}>
      <Pressable
        accessibilityRole="button"
        disabled={disabled}
        onPress={() => onChange('attending')}
        style={[toggleStyles.btn, value === 'attending' && toggleStyles.inOn]}>
        <Text style={[toggleStyles.label, value === 'attending' && toggleStyles.inLabelOn]}>I&apos;m in</Text>
      </Pressable>
      <Pressable
        accessibilityRole="button"
        disabled={disabled}
        onPress={() => onChange('not_attending')}
        style={[toggleStyles.btn, value === 'not_attending' && toggleStyles.outOn]}>
        <Text style={[toggleStyles.label, value === 'not_attending' && toggleStyles.outLabelOn]}>Can&apos;t make it</Text>
      </Pressable>
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
  /** When given, the row shows the RSVP toggle; otherwise just the current answer as a badge. */
  onRsvp?: (status: 'attending' | 'not_attending') => void;
  rsvpDisabled?: boolean;
};

/** Event line: type tag, title, when/where, and the person's RSVP (badge, or toggle when answerable). */
export function EventRow({ type, title, when, where, rsvp, onRsvp, rsvpDisabled }: EventRowProps) {
  // With the toggle the answer is already visible; still flag states the toggle can't express.
  const showBadge = rsvp && (onRsvp ? rsvp === 'injured' : true);

  return (
    <Card style={styles.card}>
      <View style={styles.row}>
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
        {showBadge ? <Badge label={RSVP_BADGE[rsvp as Exclude<RsvpState, null>].label} tone={RSVP_BADGE[rsvp as Exclude<RsvpState, null>].tone} /> : null}
      </View>
      {onRsvp ? <RsvpToggle value={rsvp ?? null} onChange={onRsvp} disabled={rsvpDisabled} /> : null}
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

const toggleStyles = StyleSheet.create({
  row: { flexDirection: 'row', gap: spacing.sm },
  btn: {
    flex: 1,
    minHeight: touchTarget,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: radius.md,
    borderWidth: 1,
    borderColor: colors.line,
    backgroundColor: colors.white,
  },
  label: { fontSize: fontSize.body, fontWeight: '700', color: colors.navy },
  inOn: { backgroundColor: '#E9F7EF', borderColor: colors.green },
  inLabelOn: { color: colors.greenDark },
  outOn: { backgroundColor: '#FDEDEC', borderColor: colors.red },
  outLabelOn: { color: colors.redDark },
});

const styles = StyleSheet.create({
  card: { gap: spacing.md },
  row: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
  body: { flex: 1, gap: 3 },
  title: { ...typography.heading, fontSize: fontSize.body, color: colors.navy },
  meta: { flexDirection: 'row', alignItems: 'center', gap: 4 },
  metaText: { fontSize: fontSize.caption, color: colors.inkSoft },
  where: { flexShrink: 1 },
});
