import { ComingSoon } from '@/components/ui/ComingSoon';
import { Screen } from '@/components/ui/Screen';
import { SectionHeader } from '@/components/ui/SectionHeader';

export default function CoachPlaybookScreen() {
  return (
    <Screen>
      <SectionHeader title="PLAYBOOK" />
      <ComingSoon
        icon="book-outline"
        title="Play Designer coming next"
        description="Draw animated drills, assign them to teams and see who's viewed them before practice."
      />
    </Screen>
  );
}
