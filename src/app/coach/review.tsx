import { ComingSoon } from '@/components/ui/ComingSoon';
import { Screen } from '@/components/ui/Screen';
import { SectionHeader } from '@/components/ui/SectionHeader';

export default function CoachReviewScreen() {
  return (
    <Screen>
      <SectionHeader title="REVIEW" />
      <ComingSoon
        icon="create-outline"
        title="Player feedback coming next"
        description="Write notes, upload short videos and build Performance Reviews for each player's file."
      />
    </Screen>
  );
}
