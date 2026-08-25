import { ComingSoon } from '@/components/ui/ComingSoon';
import { Screen } from '@/components/ui/Screen';
import { SectionHeader } from '@/components/ui/SectionHeader';

export default function CoachPlayersScreen() {
  return (
    <Screen>
      <SectionHeader title="PLAYERS" />
      <ComingSoon
        icon="people-outline"
        title="Roster & player profiles coming next"
        description="Identity, physical profile, box score stats and advanced analytics for every player on your teams."
      />
    </Screen>
  );
}
