import { ComingSoon } from '@/components/ui/ComingSoon';
import { Screen } from '@/components/ui/Screen';
import { SectionHeader } from '@/components/ui/SectionHeader';

export default function PlayerTeamScreen() {
  return (
    <Screen>
      <SectionHeader title="TEAM" />
      <ComingSoon
        icon="people-outline"
        title="Roster & contacts coming next"
        description="Browse teammates, positions and jersey numbers, with a contact card for each player."
      />
    </Screen>
  );
}
