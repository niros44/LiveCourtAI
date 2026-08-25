import { ComingSoon } from '@/components/ui/ComingSoon';
import { Screen } from '@/components/ui/Screen';
import { SectionHeader } from '@/components/ui/SectionHeader';

export default function ParentEventsScreen() {
  return (
    <Screen>
      <SectionHeader title="EVENTS" />
      <ComingSoon
        icon="calendar-outline"
        title="Week / month / year views coming next"
        description="Every event across all your children, filterable by child and by time range, with Waze/Maps links."
      />
    </Screen>
  );
}
