import { ComingSoon } from '@/components/ui/ComingSoon';
import { Screen } from '@/components/ui/Screen';
import { SectionHeader } from '@/components/ui/SectionHeader';

export default function CoachScheduleScreen() {
  return (
    <Screen>
      <SectionHeader title="SCHEDULES" />
      <ComingSoon
        icon="calendar-outline"
        title="Roll call & event management coming next"
        description="Create, edit and cancel practices and games, then mark actual attendance to feed each player's streak."
      />
    </Screen>
  );
}
