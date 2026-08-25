import { ComingSoon } from '@/components/ui/ComingSoon';
import { Screen } from '@/components/ui/Screen';
import { SectionHeader } from '@/components/ui/SectionHeader';

export default function PlayerPlaybookScreen() {
  return (
    <Screen>
      <SectionHeader title="PLAYBOOK" />
      <ComingSoon
        icon="book-outline"
        title="Drills shared by your coach"
        description="Watch the animated plays your coach shares with the team before practice."
      />
    </Screen>
  );
}
