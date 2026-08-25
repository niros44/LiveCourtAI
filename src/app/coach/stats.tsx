import { ComingSoon } from '@/components/ui/ComingSoon';
import { Screen } from '@/components/ui/Screen';
import { SectionHeader } from '@/components/ui/SectionHeader';

export default function CoachStatsScreen() {
  return (
    <Screen>
      <SectionHeader title="STATS" />
      <ComingSoon
        icon="stats-chart-outline"
        title="Box scores & trends coming next"
        description="Post-game box scores, shooting trend charts and physical-test tracking, per team."
      />
    </Screen>
  );
}
