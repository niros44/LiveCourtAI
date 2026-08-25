import { Tabs } from 'expo-router';

import { sharedTabsScreenOptions, tabIcon } from '@/components/navigation/tabBarOptions';

export default function CoachTabsLayout() {
  return (
    <Tabs screenOptions={sharedTabsScreenOptions}>
      <Tabs.Screen name="index" options={{ title: 'Home', ...tabIcon('home-outline') }} />
      <Tabs.Screen name="schedule" options={{ title: 'Schedule', ...tabIcon('calendar-outline') }} />
      <Tabs.Screen name="players" options={{ title: 'Players', ...tabIcon('people-outline') }} />
      <Tabs.Screen name="review" options={{ title: 'Review', ...tabIcon('create-outline') }} />
      <Tabs.Screen name="playbook" options={{ title: 'Playbook', ...tabIcon('book-outline') }} />
      <Tabs.Screen name="stats" options={{ title: 'Stats', ...tabIcon('stats-chart-outline') }} />
    </Tabs>
  );
}
