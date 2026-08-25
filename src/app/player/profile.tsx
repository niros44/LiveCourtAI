import { ComingSoon } from '@/components/ui/ComingSoon';
import { Screen } from '@/components/ui/Screen';
import { SectionHeader } from '@/components/ui/SectionHeader';

export default function PlayerProfileScreen() {
  return (
    <Screen>
      <SectionHeader title="PROFILE" />
      <ComingSoon
        icon="person-outline"
        title="Player passport coming next"
        description="Personal details, growth tracking and coach feedback history, in one place."
      />
    </Screen>
  );
}
