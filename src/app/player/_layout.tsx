import { Tabs } from 'expo-router';

import { sharedTabsScreenOptions, tabIcon } from '@/components/navigation/tabBarOptions';

export default function PlayerTabsLayout() {
  return (
    <Tabs screenOptions={sharedTabsScreenOptions}>
      <Tabs.Screen name="index" options={{ title: 'Home', ...tabIcon('home-outline') }} />
      <Tabs.Screen name="schedules" options={{ title: 'Schedule', ...tabIcon('calendar-outline') }} />
      <Tabs.Screen name="team" options={{ title: 'Team', ...tabIcon('people-outline') }} />
      <Tabs.Screen name="playbook" options={{ title: 'Playbook', ...tabIcon('book-outline') }} />
      <Tabs.Screen name="profile" options={{ title: 'Profile', ...tabIcon('person-outline') }} />
    </Tabs>
  );
}
