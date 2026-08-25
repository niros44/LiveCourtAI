import { ComingSoon } from '@/components/ui/ComingSoon';
import { Screen } from '@/components/ui/Screen';
import { SectionHeader } from '@/components/ui/SectionHeader';

export default function ParentCarpoolScreen() {
  return (
    <Screen>
      <SectionHeader title="CARPOOL" />
      <ComingSoon
        icon="car-outline"
        title="Ride sharing coming next"
        description="Offer a ride or request a seat for practices and away games, and see who's driving."
      />
    </Screen>
  );
}
