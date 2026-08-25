import { ComingSoon } from '@/components/ui/ComingSoon';
import { Screen } from '@/components/ui/Screen';
import { SectionHeader } from '@/components/ui/SectionHeader';

export default function ParentAdminScreen() {
  return (
    <Screen>
      <SectionHeader title="TRANSACTIONS" />
      <ComingSoon
        icon="card-outline"
        title="Payments & forms coming next"
        description="Outstanding balances, payment history and consent forms to sign, for every child."
      />
    </Screen>
  );
}
