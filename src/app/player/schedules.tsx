import { ComingSoon } from '@/components/ui/ComingSoon';
import { Screen } from '@/components/ui/Screen';
import { SectionHeader } from '@/components/ui/SectionHeader';

export default function PlayerSchedulesScreen() {
  return (
    <Screen>
      <SectionHeader title="SCHEDULE" />
      <ComingSoon
        icon="calendar-outline"
        title="Team calendar coming next"
        description="Chronological view of every practice and game, synced with the coach's schedule."
      />
    </Screen>
  );
}
